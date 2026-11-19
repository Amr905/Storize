package com.amr905.storize.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OemIntentsTest {
    @Test
    fun normalizesManufacturers() {
        assertEquals("samsung", OemIntents.normalize("samsung"))
        assertEquals("samsung", OemIntents.normalize("SAMSUNG "))
        assertEquals("xiaomi", OemIntents.normalize("Xiaomi"))
        assertEquals("xiaomi", OemIntents.normalize("Redmi"))
        assertEquals("xiaomi", OemIntents.normalize("POCO"))
        assertEquals("oppo", OemIntents.normalize("OPPO"))
        assertEquals("oppo", OemIntents.normalize("realme"))
        assertEquals("oppo", OemIntents.normalize("OnePlus"))
        assertEquals("vivo", OemIntents.normalize("vivo"))
        assertEquals("vivo", OemIntents.normalize("iQOO"))
        assertEquals("huawei", OemIntents.normalize("HUAWEI"))
        assertEquals("huawei", OemIntents.normalize("HONOR"))
        assertEquals("other", OemIntents.normalize("Google"))
        assertEquals("other", OemIntents.normalize(""))
        assertEquals("other", OemIntents.normalize(null))
    }

    @Test
    fun everyKnownOemHasComponents() {
        for (oem in listOf("samsung", "xiaomi", "oppo", "vivo", "huawei")) {
            val list = OemIntents.components(oem)
            assertTrue(oem, list.isNotEmpty())
            assertTrue(oem, list.all { it.packageName.isNotEmpty() && it.className.contains('.') })
        }
    }

    @Test
    fun aliasesShareTheirParentList() {
        assertEquals(OemIntents.components("xiaomi"), OemIntents.components("Redmi"))
        assertEquals(OemIntents.components("oppo"), OemIntents.components("realme"))
    }

    @Test
    fun unknownOemHasNoComponents() {
        assertTrue(OemIntents.components("google").isEmpty())
        assertTrue(OemIntents.components(null).isEmpty())
    }

    @Test
    fun xiaomiAutostartComesFirst() {
        assertEquals("com.miui.securitycenter", OemIntents.components("xiaomi").first().packageName)
    }

    @Test
    fun namesExitReasons() {
        assertEquals("LOW_MEMORY", ExitReasonNames.nameOf(3))
        assertEquals("USER_REQUESTED", ExitReasonNames.nameOf(10))
        assertEquals("REASON_99", ExitReasonNames.nameOf(99))
    }

    @Test
    fun scalesThumbnailsWithoutUpscaling() {
        assertEquals(512 to 288, ThumbnailMath.targetSize(1920, 1080, 512))
        assertEquals(288 to 512, ThumbnailMath.targetSize(1080, 1920, 512))
        assertEquals(100 to 50, ThumbnailMath.targetSize(100, 50, 512))
        assertEquals(16 to 1, ThumbnailMath.targetSize(4000, 1, 16))
    }

    @Test
    fun thumbnailMathDegenerate() {
        assertEquals(0 to 0, ThumbnailMath.targetSize(0, 0, 512))
    }

    @Test
    fun oemNormalizeEdges() {
        assertEquals("other", OemIntents.normalize("   "))
        assertEquals("xiaomi", OemIntents.normalize("BlackShark"))
        assertEquals("other", OemIntents.normalize("nokia"))
    }
}
