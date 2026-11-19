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

    @Test
    fun pinsLiteralPercentAndUnicodeSlashes() {
        assertEquals("%2e%2e", InputValidation.requireRelativeDir("%2e%2e"))
        assertEquals("a\uFF0Fb", InputValidation.requireRelativeDir("a\uFF0Fb"))
        assertEquals("a\u2215b.jpg", InputValidation.requireDisplayName("a\u2215b.jpg"))
    }

    @Test
    fun rejectsDotOnlyAndTrailingNames() {
        for (v in listOf(".", "..", "...", "a.", "a ")) {
            assertEquals(v, ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireDisplayName(v) })
            assertEquals(v, ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireRelativeDir(v) })
        }
    }

    @Test
    fun lengthBoundaries() {
        InputValidation.requireRelativeDir("x".repeat(100))
        InputValidation.requireDisplayName("x".repeat(251) + ".jpg")
        assertEquals(ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireRelativeDir("x".repeat(101)) })
        assertEquals(ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireDisplayName("x".repeat(252) + ".jpg") })
    }

    @Test
    fun rejectsFormatControlAndHiddenDirs() {
        for (v in listOf("a\u202Eb", "a\u200Eb", "a\u0085b", "a\u0080b", "a\u009Fb", "a\u007Fb", "a\u2028b", "a\u2029b", ".hidden", "a/.nomedia")) {
            assertEquals(v, ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireRelativeDir(v) })
        }
        assertEquals(ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireDisplayName("a\u202Eb.jpg") })
        assertEquals(ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireDisplayName(".nomedia") })
    }

    @Test
    fun allowsEmojiAndNonLatinLetters() {
        assertEquals("caf\u00e9_\uD83D\uDE00", InputValidation.requireRelativeDir("caf\u00e9_\uD83D\uDE00"))
    }

    @Test
    fun capsSegmentCountAtFour() {
        assertEquals("a/b/c/d", InputValidation.requireRelativeDir("a/b/c/d"))
        assertEquals(ErrorCodes.INVALID_ARGUMENT, code { InputValidation.requireRelativeDir("a/b/c/d/e") })
    }

    @Test
    fun uriPolicyEdgeCases() {
        assertFalse(UriPolicy.isManaged("content", "user@media"))
        assertFalse(UriPolicy.isManaged("content", "MEDIA"))
        assertFalse(UriPolicy.isManaged("content", "com.android.contacts"))
        assertFalse(UriPolicy.isManaged("content", null))
    }

    @Test
    fun isInsideSiblingPrefixAndSymlink() {
        val parent = createTempDir("p")
        try {
            val root = java.io.File(parent, "Storize").apply { mkdirs() }
            assertFalse(FileNames.isInside(root, java.io.File(parent, "StorizeEvil/x.jpg")))
            val link = java.nio.file.Files.createSymbolicLink(java.io.File(root, "l").toPath(), parent.toPath())
            assertFalse(FileNames.isInside(root, java.io.File(link.toFile(), "x.jpg")))
        } finally {
            parent.deleteRecursively()
        }
    }

    @Test
    fun uniqueEdgeCases() {
        assertEquals("a (1)", FileNames.unique("a") { it == "a" })
        assertEquals(".nm (1)", FileNames.unique(".nm") { it == ".nm" })
    }

    @Test
    fun mapsSecurityExceptionSubclass() {
        class Sub : SecurityException("x")
        assertEquals(ErrorCodes.PERMISSION_DENIED, mapThrowable(Sub()).first)
    }

    @Test
    fun relativePathPolicyAcceptsOnlyStorizeFolders() {
        for (ok in listOf("Pictures/Storize/nour_k/", "Pictures/Storize/nour_k", "Movies/Storize/a/b/")) {
            assertTrue(ok, StorizePolicy.relativePathAllowed(ok))
        }
        val bad =
            listOf(
                null, "", "Pictures/", "Pictures/Storize/", "Pictures/StorizeX/a/", "Pictures/Storize2/a/", "pictures/Storize/a/",
                "DCIM/Storize/a/", "Download/Storize/a/", "Pictures/Other/Storize/a/", "Pictures/Storize/../x/", "Pictures/Storize/./a/",
                "/Pictures/Storize/a/", "Pictures//Storize/a/", "Pictures\\Storize\\a\\", "Music/Storize/a/",
            )
        for (v in bad) assertFalse("for $v", StorizePolicy.relativePathAllowed(v))
    }

    @Test
    fun dataPathPolicyIsCanonicalAndSiblingSafe() {
        val parent = createTempDir("storage")
        try {
            val pictures = java.io.File(parent, "Pictures/Storize").apply { mkdirs() }
            val movies = java.io.File(parent, "Movies/Storize").apply { mkdirs() }
            val roots = listOf(pictures, movies)
            assertTrue(StorizePolicy.dataPathAllowed(java.io.File(pictures, "u/a.jpg").path, roots))
            assertTrue(StorizePolicy.dataPathAllowed(java.io.File(movies, "u/a.mp4").path, roots))
            assertFalse(StorizePolicy.dataPathAllowed(java.io.File(parent, "Pictures/StorizeX/a.jpg").path, roots))
            assertFalse(StorizePolicy.dataPathAllowed(java.io.File(parent, "Pictures/Storize/../Other/a.jpg").path, roots))
            assertFalse(StorizePolicy.dataPathAllowed(java.io.File(parent, "DCIM/a.jpg").path, roots))
            assertFalse(StorizePolicy.dataPathAllowed(pictures.path, roots))
            assertFalse(StorizePolicy.dataPathAllowed(null, roots))
            assertFalse(StorizePolicy.dataPathAllowed("", roots))
        } finally {
            parent.deleteRecursively()
        }
    }

    @Test
    fun thumbnailPathPolicyAllowsStorizeAndCacheOnly() {
        val parent = createTempDir("t")
        try {
            val storize = java.io.File(parent, "Pictures/Storize").apply { mkdirs() }
            val cache = java.io.File(parent, "cache").apply { mkdirs() }
            assertTrue(StorizePolicy.thumbnailPathAllowed(java.io.File(cache, "v.mp4"), listOf(storize), cache))
            assertTrue(StorizePolicy.thumbnailPathAllowed(java.io.File(storize, "u/v.mp4"), listOf(storize), cache))
            assertFalse(StorizePolicy.thumbnailPathAllowed(java.io.File(parent, "other/v.mp4"), listOf(storize), cache))
            assertFalse(StorizePolicy.thumbnailPathAllowed(java.io.File(cache, "../x.mp4"), listOf(storize), cache))
        } finally {
            parent.deleteRecursively()
        }
    }
}
