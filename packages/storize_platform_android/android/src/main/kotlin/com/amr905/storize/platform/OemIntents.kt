package com.amr905.storize.platform

/** One candidate settings screen: an explicit package and activity class. */
data class OemComponent(val packageName: String, val className: String)

/**
 * Manufacturer normalization and the known battery / autostart screens per OEM.
 * Class names come from community lists and change between ROM versions, so each
 * one is tried behind a resolve check and the caller falls back to app details.
 */
object OemIntents {
    const val OTHER = "other"

    fun normalize(raw: String?): String {
        val m = (raw ?: "").trim().lowercase()
        return when {
            m.isEmpty() -> OTHER
            m.startsWith("samsung") -> "samsung"
            m.startsWith("xiaomi") || m == "redmi" || m == "poco" || m.startsWith("blackshark") -> "xiaomi"
            m.startsWith("oppo") || m == "realme" || m.startsWith("oneplus") -> "oppo"
            m.startsWith("vivo") || m == "iqoo" -> "vivo"
            m.startsWith("huawei") || m == "honor" -> "huawei"
            else -> OTHER
        }
    }

    fun components(oem: String?): List<OemComponent> =
        when (normalize(oem)) {
            "xiaomi" ->
                listOf(
                    OemComponent("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
                    OemComponent("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"),
                )
            "samsung" ->
                listOf(
                    OemComponent("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
                    OemComponent("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
                    OemComponent("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.battery.BatteryActivity"),
                    OemComponent("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity"),
                )
            "oppo" ->
                listOf(
                    OemComponent("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
                    OemComponent("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
                    OemComponent("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
                    OemComponent("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"),
                )
            "vivo" ->
                listOf(
                    OemComponent("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                    OemComponent("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
                    OemComponent("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
                )
            "huawei" ->
                listOf(
                    OemComponent("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                    OemComponent("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
                    OemComponent("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"),
                )
            else -> emptyList()
        }
}
