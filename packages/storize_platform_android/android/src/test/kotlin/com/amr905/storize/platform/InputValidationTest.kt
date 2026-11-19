package com.amr905.storize.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class InputValidationTest {
    private fun code(block: () -> Unit): String = assertThrows(PluginException::class.java) { block() }.code

    @Test
    fun acceptsSafeRelativeDirs() {
        assertEquals("nour_k", InputValidation.requireRelativeDir("nour_k"))
        assertEquals("a.b/c_d", InputValidation.requireRelativeDir("a.b/c_d"))
    }

    @Test
    fun rejectsUnsafeRelativeDirs() {
        val bad = listOf(null, "", "/abs", "~/x", "C:/x", "..", "a/../b", "a//b", "a/", "a\\b", "a:b", "a\u0000b", "x.")
        for (value in bad) {
            assertEquals("for $value", ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireRelativeDir(value) })
        }
    }

    @Test
    fun acceptsSafeDisplayNames() {
        assertEquals("nour_k_20261119_101503_3245_2.jpg", InputValidation.requireDisplayName("nour_k_20261119_101503_3245_2.jpg"))
    }

    @Test
    fun rejectsUnsafeDisplayNames() {
        val bad = listOf(null, "", "a/b.jpg", "../a.jpg", "a..jpg", ".hidden.jpg", "a\\b.jpg", "a\u0001.jpg", "x".repeat(256))
        for (value in bad) {
            assertEquals("for $value", ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireDisplayName(value) })
        }
    }

    @Test
    fun allowsOnlyTheFourMimes() {
        for (mime in listOf("image/jpeg", "image/png", "image/webp", "video/mp4")) {
            assertEquals(mime, InputValidation.requireMime(mime))
        }
        for (mime in listOf(null, "", "image/gif", "video/webm", "application/octet-stream", "IMAGE/JPEG")) {
            assertEquals(ErrorCodes.UNSUPPORTED_MIME, code { InputValidation.requireMime(mime) })
        }
    }

    @Test
    fun mapsMimeToCollection() {
        assertEquals(MediaKind.IMAGE, MediaKind.fromMime("image/jpeg"))
        assertEquals(MediaKind.IMAGE, MediaKind.fromMime("image/webp"))
        assertEquals(MediaKind.VIDEO, MediaKind.fromMime("video/mp4"))
        assertEquals(ErrorCodes.UNSUPPORTED_MIME, code { MediaKind.fromMime("text/plain") })
    }

    @Test
    fun buildsRelativePath() {
        assertEquals("Pictures/Storize/nour_k/", InputValidation.relativePath("Pictures", "nour_k"))
        assertEquals("Movies/Storize/nour_k/", InputValidation.relativePath(MediaKind.VIDEO.fallbackDir!!, "nour_k"))
    }

    @Test
    fun uniqueNameAddsCounter() {
        val taken = setOf("a.jpg", "a (1).jpg")
        assertEquals("b.jpg", FileNames.unique("b.jpg") { it in taken })
        assertEquals("a (2).jpg", FileNames.unique("a.jpg") { it in taken })
    }

    @Test
    fun uriPolicyAcceptsOnlyMediaStoreAndFiles() {
        assertTrue(UriPolicy.isManaged("content", "media"))
        assertTrue(UriPolicy.isManaged("file", null))
        assertFalse(UriPolicy.isManaged("content", "com.other.provider"))
        assertFalse(UriPolicy.isManaged("http", "media"))
        assertFalse(UriPolicy.isManaged(null, null))
    }

    @Test
    fun insideCheckRejectsEscapes() {
        val root = createTempDir("storize")
        try {
            assertTrue(FileNames.isInside(root, java.io.File(root, "a/b.jpg")))
            assertFalse(FileNames.isInside(root, java.io.File(root, "../x.jpg")))
            assertFalse(FileNames.isInside(root, root))
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun mapsThrowables() {
        assertEquals(ErrorCodes.STORAGE_FULL, mapThrowable(java.io.IOException("write failed: ENOSPC (No space left on device)")).first)
        assertEquals(ErrorCodes.IO_ERROR, mapThrowable(java.io.IOException("x")).first)
        assertEquals(ErrorCodes.PERMISSION_DENIED, mapThrowable(SecurityException("x")).first)
        assertEquals(ErrorCodes.INSERT_FAILED, mapThrowable(PluginException(ErrorCodes.INSERT_FAILED, "x")).first)
        assertEquals(ErrorCodes.UNKNOWN, mapThrowable(IllegalStateException("x")).first)
    }
}
