package com.amr905.storize.platform

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/** Battery-optimization status and settings screens (FR-51). Call on the main thread. */
class BatteryOps(private val context: Context) {
    fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun manufacturer(): String = OemIntents.normalize(Build.MANUFACTURER)

    /**
     * Opens the best screen and returns which one: `request_ignore`, `oem_<name>`,
     * `app_details` or `none`.
     *
     * The ignore-battery-optimizations request is skipped when the app is already
     * exempt, so a second call (after the user granted it) lands on the OEM screen.
     */
    fun openBatterySettings(oem: String?): String {
        val oemName = if (oem.isNullOrBlank()) manufacturer() else OemIntents.normalize(oem)

        if (!isIgnoringBatteryOptimizations()) {
            val request =
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:${context.packageName}"))
            if (tryStart(request)) return "request_ignore"
        }
        for (component in OemIntents.components(oemName)) {
            val intent = Intent().setComponent(ComponentName(component.packageName, component.className))
            if (tryStart(intent)) return "oem_$oemName"
        }
        val details =
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", context.packageName, null))
        if (tryStart(details)) return "app_details"
        return "none"
    }

    private fun tryStart(intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(context.packageManager) == null) return false
        return try {
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }
}
