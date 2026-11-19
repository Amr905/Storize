package com.amr905.storize.platform

import java.io.File

/**
 * Which MediaStore rows and files the plugin may read or delete: only ours, under
 * `Pictures/Storize/` or `Movies/Storize/` (the Movies folder is the video fallback).
 * Pure Kotlin so it can be unit-tested on the JVM.
 */
object StorizePolicy {
    private val topDirs = setOf("Pictures", "Movies")

    /**
     * API 29+: the `RELATIVE_PATH` column, e.g. `Pictures/Storize/nour_k/`.
     * Segments are compared exactly, so `Pictures/StorizeX/` does not match.
     */
    fun relativePathAllowed(relativePath: String?): Boolean {
        if (relativePath.isNullOrEmpty() || relativePath.contains('\\')) return false
        val parts = relativePath.trimEnd('/').split("/")
        if (parts.any { it.isEmpty() || it == "." || it == ".." }) return false
        return parts.size >= 3 && parts[0] in topDirs && parts[1] == "Storize"
    }

    /**
     * API <= 28: the `DATA` column (absolute path). The path is canonicalised and must be
     * strictly inside one of [roots] (for example `<storage>/Pictures/Storize`).
     */
    fun dataPathAllowed(data: String?, roots: List<File>): Boolean {
        if (data.isNullOrEmpty()) return false
        val file = File(data)
        return roots.any { FileNames.isInside(it, file) }
    }

    /** Whether [file] may be handed to the thumbnail code: inside a Storize root or the app cache. */
    fun thumbnailPathAllowed(file: File, storizeRoots: List<File>, cacheDir: File): Boolean =
        FileNames.isInside(cacheDir, file) || storizeRoots.any { FileNames.isInside(it, file) }
}
