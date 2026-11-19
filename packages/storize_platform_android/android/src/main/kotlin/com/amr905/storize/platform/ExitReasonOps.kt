package com.amr905.storize.platform

import android.annotation.TargetApi
import android.app.ActivityManager
import android.content.Context
import android.os.Build

/**
 * Why the app's process died recently (API 30+), via `ApplicationExitInfo`.
 * Used instead of `WorkInfo.stopReason` so the plugin needs no work-runtime dependency.
 * Returns an empty list below API 30.
 */
class ExitReasonOps(private val context: Context) {
    fun lastStopReasons(limit: Int?): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        return read((limit ?: 10).coerceIn(1, 50))
    }

    @TargetApi(Build.VERSION_CODES.R)
    private fun read(limit: Int): List<Map<String, Any?>> {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return manager.getHistoricalProcessExitReasons(context.packageName, 0, limit).map {
            mapOf(
                "workName" to "process",
                "reason" to ExitReasonNames.nameOf(it.reason),
                "timestampMs" to it.timestamp,
            )
        }
    }
}
