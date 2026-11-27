package com.amr905.storize.platform

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import java.io.File

/**
 * Share sheet (FR-79). `content://media/` items are passed as they are; `file://` paths are
 * turned into FileProvider URIs, only inside `<external files>/Pictures/Storize/`.
 */
class ShareOps(private val context: Context) {
    fun share(
        uris: List<String>?,
        mimes: List<String>?,
    ): Boolean {
        if (uris.isNullOrEmpty() || mimes == null || mimes.size != uris.size) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "uris and mimes must be equal-length and not empty")
        }
        val resolved = uris.map { resolve(it) }
        val types = mimes.map { requireShareMime(it) }
        val common =
            types.map { it.substringBefore('/') }.distinct().let { if (it.size == 1) "${it[0]}/*" else "*/*" }
        val intent =
            if (resolved.size == 1) {
                Intent(Intent.ACTION_SEND).apply {
                    type = types[0]
                    putExtra(Intent.EXTRA_STREAM, resolved[0])
                }
            } else {
                Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                    type = common
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(resolved))
                }
            }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.clipData =
            ClipData.newUri(context.contentResolver, "storize", resolved[0]).also { clip ->
                resolved.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
            }
        val chooser =
            Intent.createChooser(intent, null).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        try {
            context.startActivity(chooser)
        } catch (e: ActivityNotFoundException) {
            throw PluginException(ErrorCodes.UNAVAILABLE, "No app can handle the share")
        }
        return true
    }

    private fun resolve(raw: String): Uri {
        if (UriPolicy.mediaItemId(raw) != null) return Uri.parse(raw)
        if (!raw.startsWith("file://")) throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Unsupported uri")
        val path = Uri.parse(raw).path ?: throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Unsupported uri")
        val root =
            context.getExternalFilesDir(Environment.DIRECTORY_PICTURES)?.let { File(it, "Storize") }
                ?: throw PluginException(ErrorCodes.UNAVAILABLE, "No private storage")
        val file = File(path)
        if (!FileNames.isInside(root, file)) {
            throw PluginException(ErrorCodes.PERMISSION_DENIED, "Path is outside the private folder")
        }
        if (!file.isFile) throw PluginException(ErrorCodes.SOURCE_NOT_FOUND, "File is missing")
        return try {
            FileProvider.getUriForFile(context, context.packageName + ".storize.files", file)
        } catch (e: IllegalArgumentException) {
            throw PluginException(ErrorCodes.PERMISSION_DENIED, "Path is not shareable")
        }
    }

    private fun requireShareMime(mime: String): String {
        if (mime == "image/*" || mime == "video/*" || mime in InputValidation.allowedMimes) return mime
        throw PluginException(ErrorCodes.UNSUPPORTED_MIME, "Unsupported mime type")
    }
}
