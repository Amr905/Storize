package com.amr905.storize.platform

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File

/** Video frame to WEBP bytes. Blocking: call from a background thread. */
class ThumbnailOps(private val context: Context) {
    private val guard = StorizeGuard(context)

    fun videoThumbnail(
        uriString: String?,
        path: String?,
        maxSize: Int?,
    ): ByteArray {
        val max = maxSize ?: ThumbnailMath.DEFAULT_MAX
        if (max < ThumbnailMath.MIN_MAX || max > ThumbnailMath.MAX_MAX) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "maxSize must be between 16 and 4096")
        }
        if ((uriString == null) == (path == null)) {
            throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Pass exactly one of uri or path")
        }
        val retriever = MediaMetadataRetriever()
        var frame: Bitmap? = null
        var scaled: Bitmap? = null
        try {
            if (path != null) {
                val file = File(path)
                if (!StorizePolicy.thumbnailPathAllowed(file, guard.roots(), context.cacheDir)) {
                    throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Path is outside the Storize folder and the app cache")
                }
                if (!file.isFile) {
                    throw PluginException(ErrorCodes.SOURCE_NOT_FOUND, "Video file does not exist")
                }
                retriever.setDataSource(path)
            } else {
                val uri = Uri.parse(uriString)
                if (uri.scheme != "content" || !UriPolicy.isManaged(uri.scheme, uri.authority) ||
                    UriPolicy.mediaItemId(uriString) == null
                ) {
                    throw PluginException(ErrorCodes.INVALID_ARGUMENT, "Only MediaStore item URIs are accepted")
                }
                if (guard.classify(uri) != RowCheck.ALLOWED) {
                    throw PluginException(ErrorCodes.INVALID_ARGUMENT, "URI is not a Storize file")
                }
                retriever.setDataSource(context, uri)
            }
            frame =
                retriever.getFrameAtTime(1_000_000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: retriever.getFrameAtTime(0L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: throw PluginException(ErrorCodes.THUMBNAIL_FAILED, "No video frame available")
            val (w, h) = ThumbnailMath.targetSize(frame.width, frame.height, max)
            scaled = if (w == frame.width && h == frame.height) frame else Bitmap.createScaledBitmap(frame, w, h, true)
            val out = ByteArrayOutputStream()
            if (!scaled.compress(webpFormat(), 80, out)) {
                throw PluginException(ErrorCodes.THUMBNAIL_FAILED, "WEBP compression failed")
            }
            return out.toByteArray()
        } catch (e: PluginException) {
            throw e
        } catch (e: RuntimeException) {
            throw PluginException(ErrorCodes.THUMBNAIL_FAILED, "Could not read the video: ${e.javaClass.simpleName}")
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // Nothing to do.
            }
            if (scaled != null && scaled !== frame) scaled.recycle()
            frame?.recycle()
        }
    }

    @Suppress("DEPRECATION")
    private fun webpFormat(): Bitmap.CompressFormat =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            Bitmap.CompressFormat.WEBP
        }
}
