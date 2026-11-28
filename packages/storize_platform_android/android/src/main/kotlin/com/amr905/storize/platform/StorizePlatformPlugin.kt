package com.amr905.storize.platform

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Native Android entry point for Storize (ADR-11). Channels:
 * `storize/media` (gallery), `storize/system` (battery, OEM, stop reasons) and `storize/share_in`
 * (text shared into the app, FR-80).
 * MethodChannels are in-process, and the plugin manifest exports no components.
 */
class StorizePlatformPlugin :
    FlutterPlugin,
    ActivityAware {
    private var mediaChannel: MethodChannel? = null
    private var systemChannel: MethodChannel? = null
    private var shareInChannel: MethodChannel? = null
    private val shareIn = ShareInOps()
    private var executor: ExecutorService? = null
    private var permissions: PermissionOps? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        executor = Executors.newSingleThreadExecutor()

        val media = MediaStoreOps(context)
        val thumbnails = ThumbnailOps(context)
        val storage = StorageStatsOps()
        val share = ShareOps(context)
        val battery = BatteryOps(context)
        val exits = ExitReasonOps(context)
        val perms = PermissionOps(context).also { permissions = it }

        mediaChannel =
            MethodChannel(binding.binaryMessenger, MEDIA_CHANNEL).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "insert" ->
                            background(result) {
                                media.insert(
                                    call.argument<String>("sourcePath"),
                                    call.argument<String>("relativeDir"),
                                    call.argument<String>("displayName"),
                                    call.argument<String>("mime"),
                                )
                            }
                        "delete" -> background(result) { media.delete(call.argument<String>("uri")) }
                        "exists" -> background(result) { media.exists(call.argument<String>("uri")) }
                        "exportToFile" ->
                            background(result) {
                                media.exportToFile(
                                    call.argument<String>("uri"),
                                    call.argument<String>("destPath"),
                                )
                            }
                        "findByName" ->
                            background(result) {
                                media.findByName(
                                    call.argument<String>("relativeDir"),
                                    call.argument<String>("displayName"),
                                )
                            }
                        "readBytes" ->
                            background(result) {
                                media.readBytes(
                                    call.argument<String>("uri"),
                                    intArg(call, "maxBytes"),
                                )
                            }
                        "shareFiles" ->
                            mainThread(result) {
                                share.share(
                                    call.argument<List<String>>("uris"),
                                    call.argument<List<String>>("mimes"),
                                )
                            }
                        "size" -> background(result) { media.size(call.argument<String>("uri")) }
                        "storageStats" -> background(result) { storage.storageStats() }
                        "videoThumbnail" ->
                            background(result) {
                                thumbnails.videoThumbnail(
                                    call.argument<String>("uri"),
                                    call.argument<String>("path"),
                                    intArg(call, "maxSize"),
                                )
                            }
                        else -> result.notImplemented()
                    }
                }
            }

        systemChannel =
            MethodChannel(binding.binaryMessenger, SYSTEM_CHANNEL).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isIgnoringBatteryOptimizations" -> mainThread(result) { battery.isIgnoringBatteryOptimizations() }
                        "openBatterySettings" -> mainThread(result) { battery.openBatterySettings(call.argument<String>("oem")) }
                        "manufacturer" -> mainThread(result) { battery.manufacturer() }
                        "sdkInt" -> mainThread(result) { perms.sdkInt() }
                        "checkPermission" -> mainThread(result) { perms.check(call.argument<String>("name")) }
                        "requestPermission" ->
                            try {
                                perms.request(call.argument<String>("name"), result)
                            } catch (e: Throwable) {
                                val (code, message) = mapThrowable(e)
                                result.error(code, message, null)
                            }
                        "openAppSettings" -> mainThread(result) { perms.openAppSettings() }
                        "lastStopReasons" -> background(result) { exits.lastStopReasons(intArg(call, "limit")) }
                        else -> result.notImplemented()
                    }
                }
            }

        shareInChannel =
            MethodChannel(binding.binaryMessenger, SHARE_IN_CHANNEL).also { channel ->
                shareIn.attachChannel(channel)
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "initialText" -> result.success(shareIn.takeInitialText())
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mediaChannel?.setMethodCallHandler(null)
        systemChannel?.setMethodCallHandler(null)
        shareInChannel?.setMethodCallHandler(null)
        shareIn.detachChannel()
        mediaChannel = null
        systemChannel = null
        shareInChannel = null
        executor?.shutdown()
        executor = null
        permissions = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        permissions?.attach(binding)
        shareIn.attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        permissions?.detach()
        shareIn.detach()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        permissions?.attach(binding)
        shareIn.attach(binding)
    }

    override fun onDetachedFromActivity() {
        permissions?.detach()
        shareIn.detach()
    }

    private fun intArg(
        call: MethodCall,
        key: String,
    ): Int? = (call.argument<Any>(key) as? Number)?.toInt()

    private fun mainThread(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        deliver(result, runCatching(block))
    }

    private fun background(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        val exec = executor
        if (exec == null) {
            result.error(ErrorCodes.UNAVAILABLE, "Plugin is detached", null)
            return
        }
        try {
            exec.execute {
                val outcome = runCatching(block)
                mainHandler.post { deliver(result, outcome) }
            }
        } catch (e: RejectedExecutionException) {
            result.error(ErrorCodes.UNAVAILABLE, "Plugin is detached", null)
        }
    }

    private fun deliver(
        result: MethodChannel.Result,
        outcome: Result<Any?>,
    ) {
        outcome.fold(
            onSuccess = { result.success(it) },
            onFailure = {
                val (code, message) = mapThrowable(it)
                result.error(code, message, null)
            },
        )
    }

    companion object {
        const val MEDIA_CHANNEL = "storize/media"
        const val SYSTEM_CHANNEL = "storize/system"
        const val SHARE_IN_CHANNEL = "storize/share_in"
    }
}
