package com.aayush.proalbums.vault

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.FileInputStream
import java.util.Arrays
import kotlin.math.max

/**
 * Reads hidden items for the vault grid and viewer. Everything is decrypted
 * in memory only; nothing plain is ever written to disk.
 */
class VaultViewer(
    private val resolver: ContentResolver,
    private val folder: VaultFolder,
) {
    /** Opens hidden item [id] and runs [use] with its reader. */
    private fun <T> open(id: Long, dek: ByteArray, use: (VaultItemReader) -> T): T {
        resolver.openFileDescriptor(folder.uriOf(id), "r")!!.use { descriptor ->
            FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
                VaultItemReader(FileChannelVaultSource(channel), dek).use { reader ->
                    return use(reader)
                }
            }
        }
    }

    /**
     * Every hidden item: id + its header fields, width / height already
     * turned by the picture's orientation. Unreadable files are skipped.
     */
    fun list(dek: ByteArray): List<Map<String, Any>> =
        folder.itemIds().mapNotNull { id ->
            try {
                val header = open(id, dek) { JSONObject(String(it.header())) }
                val turned = header.optInt(VaultHeader.ORIENTATION, 0) % 180 != 0
                val width = header.optLong(VaultHeader.WIDTH, 0)
                val height = header.optLong(VaultHeader.HEIGHT, 0)
                mapOf(
                    "id" to id.toString(),
                    "name" to header.optString(VaultHeader.NAME),
                    "video" to header.optBoolean(VaultHeader.VIDEO),
                    "takenMs" to createdMs(header),
                    "width" to (if (turned) height else width),
                    "height" to (if (turned) width else height),
                    "durationMs" to header.optLong(VaultHeader.DURATION_MS, 0),
                    "size" to header.optLong(VaultHeader.SIZE, 0),
                    "mime" to header.optString(VaultHeader.MIME),
                )
            } catch (error: Exception) {
                null
            }
        }

    /** When it was taken; else last changed; else when it was hidden. */
    private fun createdMs(header: JSONObject): Long = when {
        header.optLong(VaultHeader.TAKEN_MS, 0) > 0 -> header.getLong(VaultHeader.TAKEN_MS)
        header.optLong(VaultHeader.MODIFIED_S, 0) > 0 -> header.getLong(VaultHeader.MODIFIED_S) * 1000
        else -> header.optLong(VaultHeader.HIDDEN_AT_MS, 0)
    }

    /** The small grid picture (JPEG), or null when there is none. */
    fun thumbnail(id: Long, dek: ByteArray): ByteArray? =
        open(id, dek) { it.thumbnail() }.takeIf { it.isNotEmpty() }

    /**
     * The viewer's picture: the original decoded no bigger than
     * [maxLongEdge] on its long side, turned upright, as a JPEG. Videos give
     * their thumbnail (they play in a later phase).
     */
    fun picture(id: Long, dek: ByteArray, maxLongEdge: Int): ByteArray? = open(id, dek) { reader ->
        val header = JSONObject(String(reader.header()))
        if (header.optBoolean(VaultHeader.VIDEO)) {
            return@open reader.thumbnail().takeIf { it.isNotEmpty() }
        }
        val original = ByteArrayOutputStream(reader.plainSize.toInt().coerceAtLeast(32))
        reader.copyTo(original)
        val bytes = original.toByteArray()
        try {
            decodeUpright(bytes, header.optInt(VaultHeader.ORIENTATION, 0), maxLongEdge)
        } finally {
            Arrays.fill(bytes, 0)
        }
    }

    private fun decodeUpright(bytes: ByteArray, orientation: Int, maxLongEdge: Int): ByteArray? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val longEdge = max(bounds.outWidth, bounds.outHeight)
        if (longEdge <= 0) return null
        var sample = 1
        while (longEdge / (sample * 2) >= maxLongEdge) sample *= 2
        var bitmap = BitmapFactory.decodeByteArray(
            bytes,
            0,
            bytes.size,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        val scale = maxLongEdge.toFloat() / max(bitmap.width, bitmap.height)
        if (scale < 1f || orientation % 360 != 0) {
            val matrix = Matrix().apply {
                if (scale < 1f) postScale(scale, scale)
                if (orientation % 360 != 0) postRotate(orientation.toFloat())
            }
            val turned = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (turned !== bitmap) bitmap.recycle()
            bitmap = turned
        }
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }

    /** Details for the Info card (no path: privacy). */
    fun details(id: Long, dek: ByteArray): Map<String, Any> = open(id, dek) { reader ->
        val header = JSONObject(String(reader.header()))
        val turned = header.optInt(VaultHeader.ORIENTATION, 0) % 180 != 0
        val width = header.optLong(VaultHeader.WIDTH, 0)
        val height = header.optLong(VaultHeader.HEIGHT, 0)
        mapOf(
            "name" to header.optString(VaultHeader.NAME).substringBeforeLast('.'),
            "width" to (if (turned) height else width),
            "height" to (if (turned) width else height),
            "size" to reader.plainSize,
        )
    }
}
