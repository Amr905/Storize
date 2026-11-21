package com.amr905.storize.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PermissionPolicyTest {
    @Test
    fun allowsOnlyTheTwoNames() {
        assertTrue(PermissionPolicy.isAllowed("POST_NOTIFICATIONS"))
        assertTrue(PermissionPolicy.isAllowed("WRITE_EXTERNAL_STORAGE"))
        for (bad in listOf(null, "", "CAMERA", "android.permission.CAMERA", "post_notifications")) {
            assertFalse("for $bad", PermissionPolicy.isAllowed(bad))
        }
    }

    @Test
    fun notificationsApplyFromApi33() {
        assertFalse(PermissionPolicy.appliesTo("POST_NOTIFICATIONS", 32))
        assertTrue(PermissionPolicy.appliesTo("POST_NOTIFICATIONS", 33))
    }

    @Test
    fun storageAppliesUpToApi28() {
        assertTrue(PermissionPolicy.appliesTo("WRITE_EXTERNAL_STORAGE", 28))
        assertFalse(PermissionPolicy.appliesTo("WRITE_EXTERNAL_STORAGE", 29))
    }

    @Test
    fun deniedStatusDependsOnRationale() {
        assertEquals("denied", PermissionPolicy.deniedStatus(true))
        assertEquals("permanentlyDenied", PermissionPolicy.deniedStatus(false))
    }
}
