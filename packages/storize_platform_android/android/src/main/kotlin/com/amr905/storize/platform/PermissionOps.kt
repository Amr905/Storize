package com.amr905.storize.platform

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Which runtime permissions Dart may ask about, and on which Android versions
 * they exist. Pure logic, unit-tested.
 */
object PermissionPolicy {
    const val POST_NOTIFICATIONS = "POST_NOTIFICATIONS"
    const val WRITE_EXTERNAL_STORAGE = "WRITE_EXTERNAL_STORAGE"

    /** True if [name] is on the allowlist. */
    fun isAllowed(name: String?): Boolean = name == POST_NOTIFICATIONS || name == WRITE_EXTERNAL_STORAGE

    /** True if [name] is a runtime permission on [sdk] (otherwise it counts as granted). */
    fun appliesTo(
        name: String,
        sdk: Int,
    ): Boolean =
        when (name) {
            POST_NOTIFICATIONS -> sdk >= 33
            WRITE_EXTERNAL_STORAGE -> sdk <= 28
            else -> false
        }

    /** The Android permission string for an allowlisted [name]. */
    fun manifestName(name: String): String = "android.permission.$name"

    /** The answer for a denied request: permanent when the system will not show the prompt again. */
    fun deniedStatus(canAskAgain: Boolean): String = if (canAskAgain) "denied" else "permanentlyDenied"
}

/**
 * Runtime permission prompts for onboarding (S-03). Call on the main thread.
 * Only the names in [PermissionPolicy] are accepted; any other name is an
 * INVALID_ARGUMENT error with a fixed message.
 */
class PermissionOps(private val context: Context) : PluginRegistry.RequestPermissionsResultListener {
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var pendingPermission: String? = null

    fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    fun detach() {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        finish("denied")
    }

    fun sdkInt(): Int = Build.VERSION.SDK_INT

    fun check(name: String?): Boolean {
        val allowed = requireAllowed(name)
        if (!PermissionPolicy.appliesTo(allowed, Build.VERSION.SDK_INT)) return true
        return context.checkSelfPermission(PermissionPolicy.manifestName(allowed)) == PackageManager.PERMISSION_GRANTED
    }

    /** Answers [result] with `granted`, `denied` or `permanentlyDenied`. Never throws for a missing activity. */
    fun request(
        name: String?,
        result: MethodChannel.Result,
    ) {
        val allowed = requireAllowed(name)
        if (!PermissionPolicy.appliesTo(allowed, Build.VERSION.SDK_INT) || check(allowed)) {
            result.success("granted")
            return
        }
        val activity = binding?.activity
        if (activity == null || pending != null) {
            result.success("denied")
            return
        }
        val permission = PermissionPolicy.manifestName(allowed)
        pending = result
        pendingPermission = permission
        activity.requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            finish("granted")
        } else {
            val permission = pendingPermission
            val activity = binding?.activity
            val canAskAgain =
                permission != null && activity != null && activity.shouldShowRequestPermissionRationale(permission)
            finish(PermissionPolicy.deniedStatus(canAskAgain))
        }
        return true
    }

    /** Opens this app's system settings page. Returns false if no screen could be opened. */
    fun openAppSettings(): Boolean {
        val intent =
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (e: android.content.ActivityNotFoundException) {
            false
        }
    }

    private fun finish(status: String) {
        val result = pending
        pending = null
        pendingPermission = null
        result?.success(status)
    }

    private fun requireAllowed(name: String?): String {
        if (!PermissionPolicy.isAllowed(name)) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Unsupported permission")
        }
        return name!!
    }

    companion object {
        const val REQUEST_CODE = 0x5702
    }
}
