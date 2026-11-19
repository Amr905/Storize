package com.amr905.storize.platform

import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/** What a MediaStore row turned out to be. */
enum class RowCheck { ALLOWED, FOREIGN, MISSING }

/** Android side of [StorizePolicy]: looks rows and paths up and applies the pure policy. */
class StorizeGuard(private val context: Context) {
    /** Pictures/Storize and Movies/Storize on primary storage. */
    @Suppress("DEPRECATION")
    fun roots(): List<File> =
        listOf(Environment.DIRECTORY_PICTURES, Environment.DIRECTORY_MOVIES).map {
            File(Environment.getExternalStoragePublicDirectory(it), "Storize")
        }

    /** The folder the API <= 28 path writes into. */
    @Suppress("DEPRECATION")
    fun legacyRoot(): File = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Storize")

    fun fileAllowed(file: File): Boolean = roots().any { FileNames.isInside(it, file) }

    /**
     * Looks the row up and checks it is ours: `RELATIVE_PATH` on API 29+, `DATA` on API <= 28.
     * A row we cannot see (other apps' rows are hidden on API 29+) counts as missing.
     */
    @Suppress("DEPRECATION")
    fun classify(uri: Uri): RowCheck {
        val column =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.MediaColumns.RELATIVE_PATH
            } else {
                MediaStore.MediaColumns.DATA
            }
        val value: String? =
            try {
                val cursor = context.contentResolver.query(uri, arrayOf(column), null, null, null)
                if (cursor == null) {
                    return RowCheck.MISSING
                }
                cursor.use {
                    if (!it.moveToFirst()) return RowCheck.MISSING
                    if (it.isNull(0)) null else it.getString(0)
                }
            } catch (e: SecurityException) {
                return RowCheck.FOREIGN
            } catch (e: IllegalArgumentException) {
                return RowCheck.MISSING
            }
        val allowed =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                StorizePolicy.relativePathAllowed(value)
            } else {
                StorizePolicy.dataPathAllowed(value, roots())
            }
        return if (allowed) RowCheck.ALLOWED else RowCheck.FOREIGN
    }
}
