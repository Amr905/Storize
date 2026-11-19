package com.amr905.storize.platform

import java.io.File

/**
 * Which MediaStore rows and files the plugin may read or delete: only ours, under
 * `Pictures/Storize/` or `Movies/Storize/` (the Movies folder is the video fallback).
 * Pure Kotlin so it can be unit-tested on the JVM.
 */
object StorizePolicy {
    private val topDirs = setOf("Pictures", "Movies")

    /** `RELATIVE_PATH` prefixes (API 29+) a delete may touch. */
    val relativePrefixes: List<String> = listOf("Pictures/Storize/", "Movies/Storize/")

    /** `DATA` prefixes (API <= 28) for the given Storize roots, each ending in `/`. */
    fun dataPrefixes(roots: List<File>): List<String> = roots.map { it.absolutePath.trimEnd('/') + "/" }

    /** A SQL selection and its arguments. */
    data class Selection(val selection: String, val args: List<String>)

    /**
     * Selection for deleting one Storize row: `idColumn = id` AND [pathColumn] starts with one
     * of [prefixes]. The prefix test is a plain range comparison (`>= prefix` and `< prefix` with
     * the trailing `/` bumped to `0`), so there are no `LIKE` wildcards and `StorizeX/` cannot match.
     */
    fun deleteSelection(
        idColumn: String,
        pathColumn: String,
        id: Long,
        prefixes: List<String>,
    ): Selection {
        require(id > 0) { "id must be positive" }
        require(prefixes.isNotEmpty() && prefixes.all { it.endsWith("/") && it.length > 1 }) { "bad prefixes" }
        val args = mutableListOf(id.toString())
        val clauses =
            prefixes.map {
                args += it
                args += it.dropLast(1) + "0"
                "($pathColumn >= ? AND $pathColumn < ?)"
            }
        return Selection("$idColumn = ? AND (${clauses.joinToString(" OR ")})", args)
    }

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
