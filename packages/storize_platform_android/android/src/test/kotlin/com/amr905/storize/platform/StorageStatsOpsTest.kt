package com.amr905.storize.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertFalse
import org.junit.Test

class StorageStatsOpsTest {
    private class Fake(val free: Long, val total: Long) : VolumeStats {
        override fun freeBytes(): Long = free

        override fun totalBytes(): Long = total
    }

    private fun code(block: () -> Unit): PluginException = assertThrows(PluginException::class.java) { block() }

    @Test
    fun mapsFreeAndTotal() {
        val result = StorageStatsOps { Fake(5L, 10L) }.storageStats()
        assertEquals(mapOf("freeBytes" to 5L, "totalBytes" to 10L), result)
    }

    @Test
    fun clampsFreeToTotal() {
        assertEquals(10L, StorageStatsOps.map(50L, 10L)["freeBytes"])
    }

    @Test
    fun acceptsZeroFree() {
        assertEquals(0L, StorageStatsOps.map(0L, 10L)["freeBytes"])
    }

    @Test
    fun rejectsImpossibleNumbers() {
        for ((free, total) in listOf(-1L to 10L, 1L to 0L, 1L to -5L)) {
            assertEquals(ErrorCodes.IO_ERROR, code { StorageStatsOps.map(free, total) }.code)
        }
    }

    @Test
    fun openFailureIsIoErrorWithoutPath() {
        val e = code { StorageStatsOps { throw IllegalArgumentException("Invalid path: /storage/emulated/0") }.storageStats() }
        assertEquals(ErrorCodes.IO_ERROR, e.code)
        assertFalse(e.message!!.contains("/storage"))
    }

    @Test
    fun readFailureIsIoErrorWithoutPath() {
        val broken =
            object : VolumeStats {
                override fun freeBytes(): Long = throw IllegalStateException("/storage/emulated/0 gone")

                override fun totalBytes(): Long = 1L
            }
        val e = code { StorageStatsOps { broken }.storageStats() }
        assertEquals(ErrorCodes.IO_ERROR, e.code)
        assertFalse(e.message!!.contains("/storage"))
    }
}
