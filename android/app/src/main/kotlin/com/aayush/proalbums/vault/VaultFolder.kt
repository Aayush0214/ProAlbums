package com.aayush.proalbums.vault

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.provider.MediaStore

/**
 * The vault folder in shared storage: Documents/ProAlbums Vault/. Written
 * through MediaStore (no permission needed for our own files in
 * Documents/), so it SURVIVES UNINSTALL. Everything in it is encrypted; the
 * file names are random.
 *
 * While the app stays installed it owns these files and finds them with a
 * MediaStore query. After a reinstall it no longer owns them: the person
 * picks the folder once (Restore vault, a later phase).
 */
class VaultFolder(private val resolver: ContentResolver) {

    private val collection: Uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

    /** Our file called [name] in the vault folder, or null. */
    fun find(name: String): Uri? {
        resolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND " +
                "${MediaStore.MediaColumns.DISPLAY_NAME} = ?",
            arrayOf(RELATIVE_PATH, name),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
        }
        return null
    }

    fun read(uri: Uri): ByteArray =
        resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Cannot read $uri")

    /**
     * A new file [name] with [bytes] (hidden from other apps until complete).
     * Android renames it if the name is taken, so [name] should be unique.
     */
    fun create(name: String, bytes: ByteArray): Uri {
        val uri = insertPending(name)
        try {
            resolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                ?: throw IllegalStateException("Cannot write $name")
            publish(uri)
            return uri
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    /** A new, still hidden (pending) file to stream into; see [publish]. */
    fun insertPending(name: String): Uri {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, MIME)
            put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_PATH)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        return resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore refused $name")
    }

    fun publish(uri: Uri) {
        resolver.update(
            uri,
            ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
            null,
            null,
        )
    }

    fun delete(uri: Uri) {
        resolver.delete(uri, null, null)
    }

    companion object {
        const val RELATIVE_PATH = "Documents/ProAlbums Vault/"
        const val KEY_FILE = "vault.key"
        const val MIME = "application/octet-stream"
    }
}
