package com.amr905.storize.platform

/** Which MediaStore collection a mime type belongs to. Pure Kotlin, JVM-testable. */
enum class MediaKind(
    /** Top-level directory we ask for first (ADR-5: everything under Pictures/Storize). */
    val primaryDir: String,
    /** Used only if the system refuses [primaryDir] for this collection. */
    val fallbackDir: String?,
) {
    IMAGE("Pictures", null),
    VIDEO("Pictures", "Movies"),
    ;

    companion object {
        fun fromMime(mime: String): MediaKind =
            when (mime) {
                "image/jpeg", "image/png", "image/webp" -> IMAGE
                "video/mp4" -> VIDEO
                else -> throw PluginException(ErrorCodes.UNSUPPORTED_MIME, "Unsupported mime type: $mime")
            }
    }
}
