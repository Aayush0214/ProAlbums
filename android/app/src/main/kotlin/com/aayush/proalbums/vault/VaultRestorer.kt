package com.aayush.proalbums.vault

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.provider.MediaStore
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.FileInputStream

/**
 * Unhide / Delete from the vault.
 *
 *  - [restore]: decrypt a hidden item back into the gallery — the SAME
 *    folder, name and date it was hidden from (Android renames it if the
 *    name is taken). If Android does not allow that folder for that kind of
 *    file any more, Pictures/Restored (Movies/Restored for videos). The vault
 *    file is removed only after the copy is complete.
 *  - [restore] with toTrash: the restored copy goes straight to Android's
 *    trash ("Recently deleted", 30 days); it is ours, so no system dialog.
 *  - [deleteForGood]: the vault file is deleted (nothing to decrypt).
 */
class VaultRestorer(
    private val resolver: ContentResolver,
    private val folder: VaultFolder,
) {
    /** A restored item: its new gallery id, and whether it had a heart. */
    class Restored(val galleryId: Long, val favorite: Boolean)

    /**
     * Restored (and trashed when asked), the vault file removed; null =
     * could not (the vault file stays).
     */
    fun restore(fileId: Long, dek: ByteArray, toTrash: Boolean): Restored? {
        val vaultFile = folder.uriOf(fileId)
        val restored = resolver.openFileDescriptor(vaultFile, "r")!!.use { descriptor ->
            FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
                VaultItemReader(FileChannelVaultSource(channel), dek).use { reader ->
                    val header = JSONObject(String(reader.header()))
                    val target = insertPending(header) ?: return null
                    try {
                        val out = resolver.openOutputStream(target, "w")
                            ?: throw IllegalStateException("Cannot write")
                        BufferedOutputStream(out, 1 shl 16).use { reader.copyTo(it) }
                        publish(target, toTrash)
                        Restored(
                            ContentUris.parseId(target),
                            header.optBoolean(VaultHeader.FAVORITE, false),
                        )
                    } catch (error: Exception) {
                        resolver.delete(target, null, null)
                        throw error
                    }
                }
            }
        }
        // The copy is complete: only now does the vault file go.
        folder.delete(vaultFile)
        return restored
    }

    fun deleteForGood(fileId: Long): Boolean =
        resolver.delete(folder.uriOf(fileId), null, null) > 0

    /** A pending gallery file where the item was; the fallback folder if not allowed. */
    private fun insertPending(header: JSONObject): Uri? {
        val video = header.optBoolean(VaultHeader.VIDEO)
        val collection = if (video) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val original = header.optString(VaultHeader.PATH)
        val fallback = if (video) "Movies/Restored/" else "Pictures/Restored/"
        for (path in listOf(original, fallback).filter { it.isNotEmpty() }.distinct()) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, header.optString(VaultHeader.NAME, "restored"))
                header.optString(VaultHeader.MIME).takeIf { it.isNotEmpty() }?.let {
                    put(MediaStore.MediaColumns.MIME_TYPE, it)
                }
                put(MediaStore.MediaColumns.RELATIVE_PATH, path)
                header.optLong(VaultHeader.TAKEN_MS, 0).takeIf { it > 0 }?.let {
                    put(MediaStore.MediaColumns.DATE_TAKEN, it)
                }
                if (!video) {
                    header.optInt(VaultHeader.ORIENTATION, 0).takeIf { it != 0 }?.let {
                        put(MediaStore.MediaColumns.ORIENTATION, it)
                    }
                }
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            try {
                resolver.insert(collection, values)?.let { return it }
            } catch (error: IllegalArgumentException) {
                // That folder is not allowed for this kind of file: next one.
            }
        }
        return null
    }

    /** Visible again; then (Delete with Recently deleted on) to the trash. */
    private fun publish(uri: Uri, toTrash: Boolean) {
        resolver.update(
            uri,
            ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
            null,
            null,
        )
        if (toTrash) {
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_TRASHED, 1) },
                null,
                null,
            )
        }
    }
}
