package com.amr905.storize.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/** QA additions for T-010a. */
class QaStorageStatsOpsTest {
    private class Fake(val free: Long, val total: Long) : VolumeStats {
        override fun freeBytes(): Long = free

        override fun totalBytes(): Long = total
    }

    @Test
    fun keepsValuesAbove32Bits() {
        val big = 1L shl 50
        val r = StorageStatsOps { Fake(big - 1, big) }.storageStats()
        assertEquals(big - 1, r["freeBytes"])
        assertEquals(big, r["totalBytes"])
    }

    @Test
    fun freeEqualToTotalIsKept() {
        assertEquals(10L, StorageStatsOps.map(10L, 10L)["freeBytes"])
    }

    @Test
    fun extremeFreeIsClampedToTotal() {
        assertEquals(7L, StorageStatsOps.map(Long.MAX_VALUE, 7L)["freeBytes"])
    }

    @Test
    fun minValueIsRejected() {
        val e = assertThrows(PluginException::class.java) { StorageStatsOps.map(Long.MIN_VALUE, 10L) }
        assertEquals(ErrorCodes.IO_ERROR, e.code)
    }

    @Test
    fun errorsAreNotSwallowedAsRuntimeFailures() {
        // An Error is not a RuntimeException: it reaches the plugin's runCatching, which maps it to UNKNOWN.
        val e = assertThrows(AssertionError::class.java) { StorageStatsOps { throw AssertionError("boom") }.storageStats() }
        assertEquals("boom", e.message)
    }

    @Test
    fun mapOfAnErrorHasUnknownCode() {
        assertEquals(ErrorCodes.UNKNOWN, mapThrowable(AssertionError("x")).first)
    }
}
