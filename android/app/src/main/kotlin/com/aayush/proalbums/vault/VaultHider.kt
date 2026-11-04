package com.aayush.proalbums.vault

import android.content.ContentResolver
import android.content.ContentUris
import android.graphics.Bitmap
import android.net.Uri
import android.provider.MediaStore
import android.util.Size
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.util.UUID

/**
 * Hide = encrypt each picture / video into the vault folder. The originals
 * are NOT touched here: the caller removes them afterwards with ONE system
 * delete request, and [rollback] removes the vault copies if the person says
 * no (nothing changes then).
 */
class VaultHider(
    private val resolver: ContentResolver,
    private val folder: VaultFolder,
) {
    /** One item to hide (MediaStore id + kind). */
    class Source(val id: Long, val video: Boolean, val favorite: Boolean = false) {
        val uri: Uri
            get() = ContentUris.withAppendedId(
                if (video) {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                },
                id,
            )
    }

    /** An item encrypted into the vault: its original and its vault file. */
    class Hidden(val original: Uri, val vaultFile: Uri)

    /**
     * Encrypts every source with [dek]. [onProgress] after each item (done,
     * total). Items that fail are skipped (counted by the caller as
     * hidden.size < sources.size); their half-written vault files are removed.
     */
    fun encryptAll(
        sources: List<Source>,
        dek: ByteArray,
        onProgress: (done: Int, total: Int) -> Unit,
    ): List<Hidden> {
        val hidden = mutableListOf<Hidden>()
        sources.forEachIndexed { index, source ->
            encryptOne(source, dek)?.let(hidden::add)
            onProgress(index + 1, sources.size)
        }
        return hidden
    }

    private fun encryptOne(source: Source, dek: ByteArray): Hidden? {
        val original = source.uri
        val header = header(original, source.video, source.favorite) ?: return null
        val thumbnail = thumbnail(original)
        val name = "${UUID.randomUUID().toString().replace("-", "")}.pav"
        val vaultFile = folder.insertPending(name)
        try {
            val input = resolver.openInputStream(original)
                ?: throw IllegalStateException("Cannot read the original")
            val written = input.use { content ->
                val out = resolver.openOutputStream(vaultFile, "w")
                    ?: throw IllegalStateException("Cannot write the vault file")
                BufferedOutputStream(out, 1 shl 16).use { buffered ->
                    VaultItemFormat.write(
                        buffered,
                        dek,
                        header.toString().toByteArray(),
                        thumbnail,
                        content,
                    )
                }
            }
            check(vaultFile, dek, header, written)
            folder.publish(vaultFile)
            return Hidden(original, vaultFile)
        } catch (error: Exception) {
            folder.delete(vaultFile)
            return null
        }
    }

    /**
     * Opens what was written: the header must decrypt to what was put in
     * and hold exactly the bytes read from the original, before the
     * original may go. (MediaStore's SIZE can be stale, so not that.)
     */
    private fun check(vaultFile: Uri, dek: ByteArray, header: JSONObject, written: Long) {
        resolver.openFileDescriptor(vaultFile, "r")!!.use { descriptor ->
            java.io.FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
                VaultItemReader(FileChannelVaultSource(channel), dek).use { reader ->
                    val read = JSONObject(String(reader.header()))
                    if (read.optString(VaultHeader.NAME) != header.optString(VaultHeader.NAME) ||
                        reader.plainSize != written
                    ) {
                        throw VaultFormatException("Check failed")
                    }
                }
            }
        }
    }

    /** What Unhide needs to put the item back exactly where it was. */
    private fun header(uri: Uri, video: Boolean, favorite: Boolean): JSONObject? {
        val columns = mutableListOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.ORIENTATION,
        )
        if (video) columns += MediaStore.MediaColumns.DURATION
        resolver.query(uri, columns.toTypedArray(), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            fun text(column: String) =
                cursor.getColumnIndex(column).takeIf { it >= 0 }?.let(cursor::getString)
            fun number(column: String) =
                cursor.getColumnIndex(column).takeIf { it >= 0 && !cursor.isNull(it) }
                    ?.let(cursor::getLong)
            return JSONObject().apply {
                put(VaultHeader.VERSION, 1)
                put(VaultHeader.NAME, text(MediaStore.MediaColumns.DISPLAY_NAME) ?: "hidden")
                put(VaultHeader.PATH, text(MediaStore.MediaColumns.RELATIVE_PATH) ?: "")
                put(VaultHeader.MIME, text(MediaStore.MediaColumns.MIME_TYPE) ?: "")
                put(VaultHeader.VIDEO, video)
                number(MediaStore.MediaColumns.DATE_TAKEN)?.let { put(VaultHeader.TAKEN_MS, it) }
                number(MediaStore.MediaColumns.DATE_ADDED)?.let { put(VaultHeader.ADDED_S, it) }
                number(MediaStore.MediaColumns.DATE_MODIFIED)?.let { put(VaultHeader.MODIFIED_S, it) }
                number(MediaStore.MediaColumns.SIZE)?.let { put(VaultHeader.SIZE, it) }
                number(MediaStore.MediaColumns.WIDTH)?.let { put(VaultHeader.WIDTH, it) }
                number(MediaStore.MediaColumns.HEIGHT)?.let { put(VaultHeader.HEIGHT, it) }
                number(MediaStore.MediaColumns.ORIENTATION)?.let { put(VaultHeader.ORIENTATION, it) }
                number(MediaStore.MediaColumns.DURATION)?.let { put(VaultHeader.DURATION_MS, it) }
                put(VaultHeader.HIDDEN_AT_MS, System.currentTimeMillis())
                // Gets its heart back when it is unhidden.
                if (favorite) put(VaultHeader.FAVORITE, true)
            }
        }
        return null
    }

    /** A small JPEG for the vault grid (the system's own thumbnail). */
    private fun thumbnail(uri: Uri): ByteArray = try {
        val bitmap = resolver.loadThumbnail(uri, Size(THUMB_PX, THUMB_PX), null)
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            bitmap.recycle()
            out.toByteArray()
        }
    } catch (error: Exception) {
        ByteArray(0)
    }

    /** The person said no to deleting the originals: remove the copies. */
    fun rollback(hidden: List<Hidden>) {
        hidden.forEach { folder.delete(it.vaultFile) }
    }

    private companion object {
        const val THUMB_PX = 512
    }
}

/** Keys of a hidden item's (encrypted) header. */
object VaultHeader {
    const val VERSION = "v"
    const val NAME = "name"
    const val PATH = "path"
    const val MIME = "mime"
    const val VIDEO = "video"
    const val TAKEN_MS = "taken"
    const val ADDED_S = "added"
    const val MODIFIED_S = "modified"
    const val SIZE = "size"
    const val WIDTH = "width"
    const val HEIGHT = "height"
    const val ORIENTATION = "orientation"
    const val DURATION_MS = "duration"
    const val HIDDEN_AT_MS = "hiddenAt"
    const val FAVORITE = "fav"
}

/** A vault file read through a FileChannel (random access, for videos too). */
class FileChannelVaultSource(private val channel: java.nio.channels.FileChannel) : VaultSource {
    override val size: Long get() = channel.size()

    override fun readFully(position: Long, into: ByteArray, length: Int) {
        val buffer = java.nio.ByteBuffer.wrap(into, 0, length)
        var at = position
        while (buffer.hasRemaining()) {
            val read = channel.read(buffer, at)
            if (read < 0) throw java.io.EOFException()
            at += read
        }
    }
}
