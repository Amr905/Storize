package com.amr905.storize.platform

import java.io.IOException

/** Error codes sent over the channels. Mirrored by `StorizePlatformErrorKind` in Dart. */
object ErrorCodes {
    const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val UNSUPPORTED_MIME = "UNSUPPORTED_MIME"
    const val SOURCE_NOT_FOUND = "SOURCE_NOT_FOUND"
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val STORAGE_FULL = "STORAGE_FULL"
    const val IO_ERROR = "IO_ERROR"
    const val INSERT_FAILED = "INSERT_FAILED"
    const val THUMBNAIL_FAILED = "THUMBNAIL_FAILED"
    const val UNAVAILABLE = "UNAVAILABLE"
    const val UNKNOWN = "UNKNOWN"
}

/** A failure with a stable [code] that the Dart side maps to a typed exception. */
class PluginException(val code: String, message: String) : Exception(message)

/** Turns any throwable into a (code, message) pair for `result.error`. */
fun mapThrowable(t: Throwable): Pair<String, String> =
    when (t) {
        is PluginException -> t.code to (t.message ?: t.code)
        is SecurityException -> ErrorCodes.PERMISSION_DENIED to (t.message ?: "Permission denied")
        is IOException -> {
            val text = t.message ?: ""
            if (text.contains("ENOSPC") || text.contains("No space left")) {
                ErrorCodes.STORAGE_FULL to "Not enough storage space"
            } else {
                ErrorCodes.IO_ERROR to (t.message ?: "I/O error")
            }
        }
        else -> ErrorCodes.UNKNOWN to "${t.javaClass.simpleName}: ${t.message ?: ""}"
    }
