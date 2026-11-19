package com.amr905.storize.platform

import android.graphics.Bitmap
import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Run on an emulator or phone at API 28, 29 and 34+ (see README). Files go to
 * Pictures/Storize/storize_test/ and are removed afterwards.
 */
@RunWith(AndroidJUnit4::class)
class MediaStoreOpsInstrumentedTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val ops = MediaStoreOps(context)
    private val inserted = mutableListOf<String>()
    private lateinit var workDir: File

    @Before
    fun setUp() {
        if (Build.VERSION.SDK_INT <= 28) {
            instrumentation.uiAutomation.grantRuntimePermission(
                context.packageName,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
            )
        }
        workDir = File(context.cacheDir, "storize_test").apply { mkdirs() }
    }

    @After
    fun tearDown() {
        for (uri in inserted) {
            try {
                ops.delete(uri)
            } catch (_: Exception) {
                // Already gone.
            }
        }
        workDir.deleteRecursively()
    }

    private fun imageFile(name: String): File {
        val file = File(workDir, name)
        val bitmap = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        bitmap.recycle()
        return file
    }

    private fun insertImage(name: String): Map<String, Any?> {
        val source = imageFile("src_$name")
        val result = ops.insert(source.absolutePath, "storize_test", name, "image/jpeg")
        inserted += result["uri"] as String
        return result
    }

    @Test
    fun insertExistsSizeDelete() {
        val source = imageFile("src_a.jpg")
        val result = insertImage("a_${System.nanoTime()}.jpg")
        val uri = result["uri"] as String
        assertEquals(source.length(), (result["size"] as Number).toLong())
        assertTrue((result["relativePath"] as String).startsWith("Pictures/Storize/storize_test/"))
        assertTrue(ops.exists(uri))
        assertEquals(source.length(), ops.size(uri))

        assertTrue(ops.delete(uri))
        assertFalse(ops.exists(uri))
        assertNull(ops.size(uri))
    }

    @Test
    fun deleteOfMissingFileReturnsFalse() {
        val result = insertImage("b_${System.nanoTime()}.jpg")
        val uri = result["uri"] as String
        assertTrue(ops.delete(uri))
        assertFalse(ops.delete(uri))
    }

    @Test
    fun sameNameTwiceKeepsBothFiles() {
        val name = "dup_${System.nanoTime()}.jpg"
        val first = insertImage(name)["uri"] as String
        val second = insertImage(name)["uri"] as String
        assertTrue(first != second)
        assertTrue(ops.exists(first))
        assertTrue(ops.exists(second))
    }

    @Test
    fun videoLandsUnderPicturesOrMoviesFallback() {
        val source = File(workDir, "v.mp4").apply { writeBytes(ByteArray(64) { it.toByte() }) }
        val result = ops.insert(source.absolutePath, "storize_test", "v_${System.nanoTime()}.mp4", "video/mp4")
        inserted += result["uri"] as String
        val path = result["relativePath"] as String
        assertTrue(path, path.startsWith("Pictures/Storize/") || path.startsWith("Movies/Storize/"))
        assertTrue(ops.exists(result["uri"] as String))
    }

    @Test
    fun rejectsBadInputsWithCodes() {
        val source = imageFile("src_c.jpg")
        fun codeOf(block: () -> Unit) = assertThrows(PluginException::class.java) { block() }.code
        assertEquals(ErrorCodes.INVALID_ARGUMENT, codeOf { ops.insert(source.absolutePath, "../x", "a.jpg", "image/jpeg") })
        assertEquals(ErrorCodes.INVALID_ARGUMENT, codeOf { ops.insert(source.absolutePath, "d", "a/b.jpg", "image/jpeg") })
        assertEquals(ErrorCodes.UNSUPPORTED_MIME, codeOf { ops.insert(source.absolutePath, "d", "a.gif", "image/gif") })
        assertEquals(ErrorCodes.SOURCE_NOT_FOUND, codeOf { ops.insert("/no/such/file", "d", "a.jpg", "image/jpeg") })
    }

    @Test
    fun refusesForeignUris() {
        assertThrows(PluginException::class.java) { ops.delete("content://com.android.contacts/contacts/1") }
    }

    @Test
    fun thumbnailOfNonVideoFailsCleanly() {
        val bogus = File(workDir, "bogus.mp4").apply { writeBytes(ByteArray(32)) }
        val code = assertThrows(PluginException::class.java) {
            ThumbnailOps(context).videoThumbnail(null, bogus.absolutePath, 128)
        }.code
        assertEquals(ErrorCodes.THUMBNAIL_FAILED, code)
        assertNotNull(code)
    }

    @Test
    fun batteryAndManufacturerAnswer() {
        val battery = BatteryOps(context)
        battery.isIgnoringBatteryOptimizations()
        assertTrue(battery.manufacturer().isNotEmpty())
    }

    @Test
    fun stopReasonsAreAListOnEveryApi() {
        val reasons = ExitReasonOps(context).lastStopReasons(5)
        if (Build.VERSION.SDK_INT < 30) assertTrue(reasons.isEmpty())
        assertTrue(reasons.size <= 5)
    }

    @Test
    fun rowOutsideStorizeIsNotTouched() {
        org.junit.Assume.assumeTrue(Build.VERSION.SDK_INT >= 29)
        val values =
            android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, "outside_${System.nanoTime()}.jpg")
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/StorizeX_test/")
            }
        val uri =
            context.contentResolver.insert(
                android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values,
            )!!
        try {
            assertFalse(ops.exists(uri.toString()))
            assertNull(ops.size(uri.toString()))
            val code = assertThrows(PluginException::class.java) { ops.delete(uri.toString()) }.code
            assertEquals(ErrorCodes.PERMISSION_DENIED, code)
        } finally {
            context.contentResolver.delete(uri, null, null)
        }
    }

    @Test
    fun insertReturnsTheFinalName() {
        val name = "final_${System.nanoTime()}.jpg"
        val first = insertImage(name)
        val second = insertImage(name)
        assertEquals(name, first["displayName"])
        assertTrue(second["displayName"] as String != name)
    }
}
