package com.amr905.storize.platform

import android.os.Environment
import android.os.StatFs

/** Raw numbers of one storage volume. Kept small so tests can fake it. */
interface VolumeStats {
    fun freeBytes(): Long

    fun totalBytes(): Long
}

/** [VolumeStats] over `StatFs` for the primary shared storage (where the gallery lives). */
class StatFsVolumeStats : VolumeStats {
    private val statFs: StatFs

    init {
        @Suppress("DEPRECATION")
        val path = Environment.getExternalStorageDirectory().path
        statFs = StatFs(path)
    }

    override fun freeBytes(): Long = statFs.availableBytes

    override fun totalBytes(): Long = statFs.totalBytes
}

/** Free and total space of the gallery volume (NFR-13). */
class StorageStatsOps(private val open: () -> VolumeStats = { StatFsVolumeStats() }) {
    /** Returns `{freeBytes, totalBytes}`. Throws [PluginException] with `IO_ERROR`; messages never contain a path. */
    fun storageStats(): Map<String, Long> {
        val stats =
            try {
                open()
            } catch (e: RuntimeException) {
                throw PluginException(ErrorCodes.IO_ERROR, UNAVAILABLE_MESSAGE)
            }
        val free: Long
        val total: Long
        try {
            free = stats.freeBytes()
            total = stats.totalBytes()
        } catch (e: RuntimeException) {
            throw PluginException(ErrorCodes.IO_ERROR, UNAVAILABLE_MESSAGE)
        }
        return map(free, total)
    }

    companion object {
        const val UNAVAILABLE_MESSAGE = "Storage statistics unavailable"

        /** Pure mapping: rejects impossible numbers, clamps free to total. */
        fun map(
            free: Long,
            total: Long,
        ): Map<String, Long> {
            if (total <= 0L || free < 0L) {
                throw PluginException(ErrorCodes.IO_ERROR, UNAVAILABLE_MESSAGE)
            }
            return mapOf("freeBytes" to minOf(free, total), "totalBytes" to total)
        }
    }
}
