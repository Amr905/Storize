package com.amr905.storize.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SharedTextTest {
    private val send = "android.intent.action.SEND"

    @Test
    fun plainTextShareGivesTheTrimmedText() {
        assertEquals("https://www.instagram.com/p/ZZFAKE_c1/", sharedText(send, "text/plain", "  https://www.instagram.com/p/ZZFAKE_c1/\n"))
    }

    @Test
    fun otherActionsTypesAndEmptyTextGiveNull() {
        assertNull(sharedText("android.intent.action.VIEW", "text/plain", "x"))
        assertNull(sharedText(send, "image/png", "x"))
        assertNull(sharedText(send, null, "x"))
        assertNull(sharedText(send, "text/plain", null))
        assertNull(sharedText(send, "text/plain", "   "))
        assertNull(sharedText(null, null, null))
    }

    @Test
    fun hugeTextIsRefused() {
        assertNull(sharedText(send, "text/plain", "a".repeat(MAX_SHARED_TEXT + 1)))
    }
}
