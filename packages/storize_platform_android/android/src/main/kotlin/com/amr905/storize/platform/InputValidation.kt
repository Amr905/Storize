package com.amr905.storize.platform

import java.io.File

/** Argument checks shared by the media operations. No Android imports. */
object InputValidation {
    val allowedMimes: Set<String> = setOf("image/jpeg", "image/png", "image/webp", "video/mp4")

    private const val MAX_SEGMENT = 100
    private const val MAX_NAME = 255
    private const val FORBIDDEN = ":*?\"<>|\\"

    fun requireMime(mime: String?): String {
        if (mime == null || mime !in allowedMimes) {
            throw PluginException(ErrorCodes.UNSUPPORTED_MIME, "Unsupported mime type: ${mime ?: "null"}")
        }
        return mime
    }

    /** Relative folder under `Pictures/Storize/`: one or more safe segments joined by `/`. */
    fun requireRelativeDir(value: String?): String {
        if (value.isNullOrEmpty()) invalid("relativeDir is required")
        if (value.startsWith("/") || value.startsWith("~") || Regex("^[A-Za-z]:").containsMatchIn(value)) {
            invalid("relativeDir must be relative")
        }
        for (segment in value.split("/")) {
            if (segment.isEmpty()) invalid("relativeDir has an empty segment")
            checkSegment(segment, "relativeDir", MAX_SEGMENT)
        }
        return value
    }

    /** A bare file name: no separators, no `..`, no leading dot. */
    fun requireDisplayName(value: String?): String {
        if (value.isNullOrEmpty()) invalid("displayName is required")
        if (value.contains('/')) invalid("displayName must not contain '/'")
        if (value.startsWith(".")) invalid("displayName must not start with '.'")
        checkSegment(value, "displayName", MAX_NAME)
        return value
    }

    fun relativePath(topDir: String, relativeDir: String): String = "$topDir/Storize/$relativeDir/"

    private fun checkSegment(segment: String, label: String, max: Int) {
        if (segment.length > max) invalid("$label is too long")
        if (segment.contains("..")) invalid("$label must not contain '..'")
        if (segment == ".") invalid("$label must not be '.'")
        if (segment.endsWith(".") || segment.endsWith(" ")) invalid("$label must not end with '.' or space")
        for (c in segment) {
            if (c.code < 0x20 || c.code == 0x7F || FORBIDDEN.indexOf(c) >= 0) {
                invalid("$label contains a forbidden character")
            }
        }
    }

    private fun invalid(message: String): Nothing = throw PluginException(ErrorCodes.INVALID_ARGUMENT, message)
}

/** Name and path helpers for the API <= 28 direct-write path. */
object FileNames {
    /** `a.jpg` -> `a (1).jpg`, `a (2).jpg`, ... until [exists] says the name is free. */
    fun unique(name: String, exists: (String) -> Boolean): String {
        if (!exists(name)) return name
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (true) {
            val candidate = "$base ($i)$ext"
            if (!exists(candidate)) return candidate
            i++
        }
    }

    /** True if [candidate] resolves to a location inside [root] (symlinks and `..` resolved). */
    fun isInside(root: File, candidate: File): Boolean {
        val rootPath = root.canonicalFile.path
        val path = candidate.canonicalFile.path
        return path.startsWith(rootPath + File.separator)
    }
}

/** Which URIs the plugin will touch: only MediaStore rows (and our own files on API <= 28). */
object UriPolicy {
    fun isManaged(scheme: String?, authority: String?): Boolean =
        (scheme == "content" && authority == "media") || scheme == "file"
}
