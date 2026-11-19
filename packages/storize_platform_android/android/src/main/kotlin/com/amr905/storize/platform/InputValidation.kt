package com.amr905.storize.platform

import java.io.File

/** Argument checks shared by the media operations. No Android imports. */
object InputValidation {
    val allowedMimes: Set<String> = setOf("image/jpeg", "image/png", "image/webp", "video/mp4")

    private const val MAX_SEGMENT = 100
    private const val MAX_NAME = 255
    private const val MAX_SEGMENTS = 4
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
        val segments = value.split("/")
        if (segments.size > MAX_SEGMENTS) invalid("relativeDir has too many segments")
        for (segment in segments) {
            if (segment.isEmpty()) invalid("relativeDir has an empty segment")
            checkSegment(segment, "relativeDir", MAX_SEGMENT)
        }
        return value
    }

    /** A bare file name: no separators, no `..`, no leading dot. */
    fun requireDisplayName(value: String?): String {
        if (value.isNullOrEmpty()) invalid("displayName is required")
        if (value.contains('/')) invalid("displayName must not contain '/'")
        checkSegment(value, "displayName", MAX_NAME)
        return value
    }

    fun relativePath(topDir: String, relativeDir: String): String = "$topDir/Storize/$relativeDir/"

    private fun checkSegment(segment: String, label: String, max: Int) {
        if (segment.length > max) invalid("$label is too long")
        if (segment.contains("..")) invalid("$label must not contain '..'")
        if (segment.startsWith(".")) invalid("$label must not start with '.'")
        if (segment.endsWith(".") || segment.endsWith(" ")) invalid("$label must not end with '.' or space")
        var i = 0
        while (i < segment.length) {
            val cp = segment.codePointAt(i)
            if ((cp < 0x80 && FORBIDDEN.indexOf(cp.toChar()) >= 0) || isHiddenControl(cp)) {
                invalid("$label contains a forbidden character")
            }
            i += Character.charCount(cp)
        }
    }

    /** Control (C0, DEL, C1), format (bidi marks, zero-width) and line/paragraph separators. */
    private fun isHiddenControl(cp: Int): Boolean =
        when (Character.getType(cp).toByte()) {
            Character.CONTROL,
            Character.FORMAT,
            Character.LINE_SEPARATOR,
            Character.PARAGRAPH_SEPARATOR,
            -> true
            else -> false
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
    private const val ITEM_PREFIX = "content://media/"
    private val volume = Regex("[A-Za-z0-9_-]+")
    private val id = Regex("[1-9][0-9]*")

    fun isManaged(scheme: String?, authority: String?): Boolean =
        (scheme == "content" && authority == "media") || scheme == "file"

    /**
     * The row id of a MediaStore item URI, or null for anything else. Accepts only
     * `content://media/<volume>/(images|video)/media/<id>` with a positive integer id and no
     * query string or fragment. Collection URIs (no id) are rejected so that a delete can
     * never reach more than one row.
     */
    fun mediaItemId(raw: String?): Long? {
        if (raw == null || !raw.startsWith(ITEM_PREFIX)) return null
        if (raw.contains('?') || raw.contains('#')) return null
        val parts = raw.substring(ITEM_PREFIX.length).split("/")
        if (parts.size != 4) return null
        if (!volume.matches(parts[0])) return null
        if (parts[1] != "images" && parts[1] != "video") return null
        if (parts[2] != "media") return null
        if (!id.matches(parts[3])) return null
        return parts[3].toLongOrNull()
    }
}
