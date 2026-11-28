package com.amr905.storize.platform

import android.content.Intent
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Text shared into Storize (FR-80): "Share -> Storize" sends `ACTION_SEND` with `text/plain`.
 *
 * The launch intent is read once (`initialText`); later intents arrive in `onNewIntent` and are
 * pushed to Dart as `onText`. The text is a link the user chose to share; it is never logged.
 */
class ShareInOps : PluginRegistry.NewIntentListener {
    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: String? = null

    fun attachChannel(channel: MethodChannel) {
        this.channel = channel
    }

    fun detachChannel() {
        channel = null
    }

    fun attach(binding: ActivityPluginBinding) {
        this.binding?.removeOnNewIntentListener(this)
        this.binding = binding
        binding.addOnNewIntentListener(this)
        val intent = binding.activity.intent
        val text = sharedText(intent?.action, intent?.type, intent?.getStringExtra(Intent.EXTRA_TEXT))
        if (text != null) {
            pending = text
            // The same intent comes back after a process restore: read it only once.
            intent?.removeExtra(Intent.EXTRA_TEXT)
        }
    }

    fun detach() {
        binding?.removeOnNewIntentListener(this)
        binding = null
    }

    /** The text of the launch intent, once. */
    fun takeInitialText(): String? = pending.also { pending = null }

    override fun onNewIntent(intent: Intent): Boolean {
        val text = sharedText(intent.action, intent.type, intent.getStringExtra(Intent.EXTRA_TEXT)) ?: return false
        intent.removeExtra(Intent.EXTRA_TEXT)
        val ch = channel
        if (ch == null) {
            pending = text
        } else {
            ch.invokeMethod("onText", text)
        }
        return true
    }
}

/** The shared text of an intent, or null when it is not a plain-text share (pure, unit tested). */
internal fun sharedText(
    action: String?,
    type: String?,
    text: String?,
): String? {
    if (action != Intent.ACTION_SEND) return null
    if (type == null || !type.startsWith("text/")) return null
    val trimmed = text?.trim()
    return if (trimmed.isNullOrEmpty() || trimmed.length > MAX_SHARED_TEXT) null else trimmed
}

internal const val MAX_SHARED_TEXT = 4096
