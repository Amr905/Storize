package com.amr905.storize.platform

/** Size maths for thumbnails. */
object ThumbnailMath {
    const val DEFAULT_MAX = 512
    const val MIN_MAX = 16
    const val MAX_MAX = 4096

    /** Scales (w, h) so the longer side is at most [max]. Never upscales; never returns 0. */
    fun targetSize(width: Int, height: Int, max: Int): Pair<Int, Int> {
        val longest = maxOf(width, height)
        if (longest <= max || longest <= 0) return width to height
        val ratio = max.toDouble() / longest
        return maxOf(1, Math.round(width * ratio).toInt()) to maxOf(1, Math.round(height * ratio).toInt())
    }
}
