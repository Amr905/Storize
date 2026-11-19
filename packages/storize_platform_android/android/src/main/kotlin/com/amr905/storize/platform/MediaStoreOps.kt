package com.amr905.storize.platform

import android.annotation.TargetApi
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Gallery operations (ADR-5, ADR-11). Everything here blocks, so the plugin calls it
 * from a background thread.
 *
 * - API 29+: MediaStore insert with IS_PENDING, copy through the content resolver.
 *   The returned URI is a `content://media/...` URI.
 * - API <= 28: direct file write under Pictures/Storize, then a MediaScanner scan.
 *   The returned URI is the `content://media/...` URI from the scan; if the scan does
 *   not answer within 5 s we return the `file://` URI instead. Both are accepted by
 *   delete / exists / size.
 */
class MediaStoreOps(private val context: Context) {
    private val resolver get() = context.contentResolver
    private val guard = StorizeGuard(context)

    fun insert(
        sourcePath: String?,
        relativeDir: String?,
        displayName: String?,
        mime: String?,
    ): Map<String, Any?> {
        val dir = InputValidation.requireRelativeDir(relativeDir)
        val name = InputValidation.requireDisplayName(displayName)
        val mimeType = InputValidation.requireMime(mime)
        val kind = MediaKind.fromMime(mimeType)
        if (sourcePath.isNullOrEmpty()) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "sourcePath is required")
        }
        val source = File(sourcePath)
        if (!source.isFile) {
            throw PluginException(ErrorCodes.SOURCE_NOT_FOUND, "Source file does not exist")
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            insertScoped(source, dir, name, mimeType, kind)
        } else {
            insertLegacy(source, dir, name, mimeType)
        }
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun insertScoped(
        source: File,
        dir: String,
        name: String,
        mime: String,
        kind: MediaKind,
    ): Map<String, Any?> {
        val collection =
            when (kind) {
                MediaKind.IMAGE -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                MediaKind.VIDEO -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
        var relativePath = InputValidation.relativePath(kind.primaryDir, dir)
        var uri = tryInsert(collection, name, mime, relativePath)
        val fallback = kind.fallbackDir
        if (uri == null && fallback != null) {
            // Some Android versions refuse Pictures/ for the video collection.
            relativePath = InputValidation.relativePath(fallback, dir)
            uri = tryInsert(collection, name, mime, relativePath)
        }
        if (uri == null) {
            throw PluginException(ErrorCodes.INSERT_FAILED, "MediaStore refused the insert")
        }
        try {
            val out =
                resolver.openOutputStream(uri, "w")
                    ?: throw IOException("openOutputStream returned null")
            out.use { target -> FileInputStream(source).use { it.copyTo(target) } }
            val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            if (resolver.update(uri, done, null, null) < 1) {
                throw IOException("Could not clear IS_PENDING")
            }
            val size = sizeOf(uri) ?: source.length()
            return mapOf(
                "uri" to uri.toString(),
                "size" to size,
                "displayName" to (queryDisplayName(uri) ?: name),
                "relativePath" to relativePath,
            )
        } catch (e: Throwable) {
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
                // Best effort: the pending row is hidden from the gallery anyway.
            }
            throw e
        }
    }

    /** The name MediaStore really used (it renames duplicates to `name (1).ext`). */
    private fun queryDisplayName(uri: Uri): String? =
        try {
            resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst() && !it.isNull(0)) it.getString(0) else null
            }
        } catch (e: RuntimeException) {
            null
        }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun tryInsert(
        collection: Uri,
        name: String,
        mime: String,
        relativePath: String,
    ): Uri? {
        val values =
            ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        return try {
            resolver.insert(collection, values)
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    private fun insertLegacy(
        source: File,
        dir: String,
        name: String,
        mime: String,
    ): Map<String, Any?> {
        if (context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw PluginException(ErrorCodes.PERMISSION_DENIED, "WRITE_EXTERNAL_STORAGE is not granted")
        }
        if (Environment.getExternalStorageState() != Environment.MEDIA_MOUNTED) {
            throw PluginException(ErrorCodes.IO_ERROR, "External storage is not mounted")
        }
        val root = guard.legacyRoot()
        val targetDir = File(root, dir)
        if (!FileNames.isInside(root, File(targetDir, "x"))) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "relativeDir escapes the Storize folder")
        }
        if (!targetDir.isDirectory && !targetDir.mkdirs()) {
            throw PluginException(ErrorCodes.IO_ERROR, "Could not create the target folder")
        }
        val finalName = FileNames.unique(name) { File(targetDir, it).exists() }
        val target = File(targetDir, finalName)
        try {
            FileInputStream(source).use { input -> target.outputStream().use { input.copyTo(it) } }
        } catch (e: Exception) {
            target.delete()
            throw e
        }
        val scanned = scan(target, mime)
        val uri = scanned?.toString() ?: Uri.fromFile(target).toString()
        val relative = "Pictures/Storize/$dir/"
        return mapOf(
            "uri" to uri,
            "size" to target.length(),
            "displayName" to finalName,
            "relativePath" to relative,
        )
    }

    fun delete(uriString: String?): Boolean {
        val uri = managedUri(uriString)
        if (uri.scheme == "file") {
            val file = File(requireNotNull(uri.path))
            if (!file.isFile) return false
            val deleted = file.delete()
            if (deleted) scan(file, null)
            return deleted
        }
        when (guard.classify(uri)) {
            RowCheck.MISSING -> return false
            RowCheck.FOREIGN -> throw PluginException(ErrorCodes.PERMISSION_DENIED, "This file is not in the Storize folder")
            RowCheck.ALLOWED -> Unit
        }
        return try {
            resolver.delete(uri, null, null) > 0
        } catch (e: SecurityException) {
            throw PluginException(ErrorCodes.PERMISSION_DENIED, "This file is not owned by the app")
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    fun exists(uriString: String?): Boolean {
        val uri = managedUri(uriString)
        if (uri.scheme == "file") return File(requireNotNull(uri.path)).isFile
        if (guard.classify(uri) != RowCheck.ALLOWED) return false
        return try {
            resolver.openFileDescriptor(uri, "r")?.use { true } ?: false
        } catch (e: FileNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    fun size(uriString: String?): Long? {
        val uri = managedUri(uriString)
        if (uri.scheme == "file") {
            val file = File(requireNotNull(uri.path))
            return if (file.isFile) file.length() else null
        }
        if (guard.classify(uri) != RowCheck.ALLOWED) return null
        return sizeOf(uri)
    }

    private fun sizeOf(uri: Uri): Long? {
        val fd =
            try {
                resolver.openFileDescriptor(uri, "r")
            } catch (e: FileNotFoundException) {
                null
            } catch (e: SecurityException) {
                null
            } catch (e: IllegalArgumentException) {
                null
            }
        if (fd == null) return null
        val statSize = fd.use { it.statSize }
        if (statSize >= 0) return statSize
        return try {
            resolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use {
                if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else null
            }
        } catch (e: RuntimeException) {
            null
        }
    }

    private fun managedUri(value: String?): Uri {
        if (value.isNullOrEmpty()) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "uri is required")
        }
        val uri = Uri.parse(value)
        if (!UriPolicy.isManaged(uri.scheme, uri.authority)) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Only MediaStore or Storize file URIs are accepted")
        }
        if (uri.scheme == "file") {
            val path = uri.path
            if (path.isNullOrEmpty() || !guard.fileAllowed(File(path))) {
                throw PluginException(ErrorCodes.INVALID_ARGUMENT, "File is outside the Storize folder")
            }
        }
        return uri
    }

    /** Scans [file]; returns the MediaStore URI or null if the scanner did not answer in time. */
    private fun scan(
        file: File,
        mime: String?,
    ): Uri? {
        val latch = CountDownLatch(1)
        val found = AtomicReference<Uri?>(null)
        val listener =
            MediaScannerConnection.OnScanCompletedListener { _, uri ->
                found.set(uri)
                latch.countDown()
            }
        MediaScannerConnection.scanFile(
            context,
            arrayOf(file.absolutePath),
            if (mime == null) null else arrayOf(mime),
            listener,
        )
        latch.await(5, TimeUnit.SECONDS)
        return found.get()
    }
}
