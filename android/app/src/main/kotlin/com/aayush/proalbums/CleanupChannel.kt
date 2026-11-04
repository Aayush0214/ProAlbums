package com.aayush.proalbums

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/**
 * Albums > Cleanup suggestions: what the phone can tell quickly about the
 * pictures (Dart groups them and keeps the answers in its database, so each
 * picture is looked at once):
 *  - listImages: every picture (not in the trash): id, size, width, height,
 *    taken and modified times.
 *  - fingerprints {ids}: a 64-bit "difference hash" (dHash: does the
 *    brightness go up or down from pixel to pixel in a 9×8 grey copy — near
 *    pictures have near hashes) and a sharpness number (how much the edges
 *    stand out in a 64×64 grey copy; blurred = low). Both from Android's own
 *    small thumbnail, so no full picture is decoded.
 *  - contentHashes {ids}: SHA-1 of the file bytes (exact duplicates). Only
 *    asked for pictures that already share size and dimensions.
 */
class CleanupChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val pool = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listImages" -> background(result) { listImages() }
            "fingerprints" -> {
                val ids = ids(call)
                background(result) { fingerprints(ids) }
            }
            "contentHashes" -> {
                val ids = ids(call)
                background(result) { contentHashes(ids) }
            }
            else -> result.notImplemented()
        }
    }

    private fun ids(call: MethodCall): List<Long> =
        call.argument<List<String>>("ids").orEmpty().mapNotNull { it.toLongOrNull() }

    private fun uriOf(id: Long) =
        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)

    private fun listImages(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        // Not the trash (it is the default, said out loud).
        val args = Bundle().apply {
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns.DATE_TAKEN} DESC")
        }
        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, projection, args, null,
        )?.use { c ->
            while (c.moveToNext()) {
                val added = c.getLong(6) * 1000
                val taken = if (c.isNull(4)) added else c.getLong(4)
                rows.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "size" to c.getLong(1),
                        "width" to c.getInt(2),
                        "height" to c.getInt(3),
                        "taken" to taken,
                        "modified" to c.getLong(5),
                    ),
                )
            }
        }
        return rows
    }

    private fun fingerprints(ids: List<Long>): List<Map<String, Any>> {
        val jobs = ids.map { id ->
            pool.submit(Callable {
                try {
                    val thumb = context.contentResolver.loadThumbnail(uriOf(id), Size(96, 96), null)
                    val hash = dHash(thumb)
                    val sharpness = sharpness(thumb)
                    thumb.recycle()
                    mapOf("id" to id.toString(), "dhash" to hash, "sharpness" to sharpness)
                } catch (error: Exception) {
                    null
                }
            })
        }
        return jobs.mapNotNull { it.get() }
    }

    private fun contentHashes(ids: List<Long>): Map<String, String> {
        val jobs = ids.map { id ->
            id to pool.submit(Callable {
                try {
                    val digest = MessageDigest.getInstance("SHA-1")
                    context.contentResolver.openInputStream(uriOf(id))?.use { input ->
                        val buffer = ByteArray(1 shl 16)
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            digest.update(buffer, 0, read)
                        }
                    } ?: return@Callable null
                    digest.digest().joinToString("") { "%02x".format(it) }
                } catch (error: Exception) {
                    null
                }
            })
        }
        val out = mutableMapOf<String, String>()
        for ((id, job) in jobs) job.get()?.let { out[id.toString()] = it }
        return out
    }

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        worker.execute {
            val answer = try {
                work()
            } catch (error: Throwable) {
                null
            }
            main.post { result.success(answer) }
        }
    }

    internal companion object {
        const val CHANNEL = "com.aayush.proalbums/cleanup"

        private fun grey(pixel: Int): Int =
            (Color.red(pixel) * 299 + Color.green(pixel) * 587 + Color.blue(pixel) * 114) / 1000

        /** 64 bits: for each of 8 rows, is pixel x brighter than x+1 (9 wide)? */
        fun dHash(bitmap: Bitmap): Long {
            val small = Bitmap.createScaledBitmap(bitmap, 9, 8, true)
            val pixels = IntArray(72)
            small.getPixels(pixels, 0, 9, 0, 0, 9, 8)
            if (small !== bitmap) small.recycle()
            return DHash.of(IntArray(72) { grey(pixels[it]) })
        }

        /** Variance of the Laplacian of a 64×64 grey copy: blurred = low. */
        fun sharpness(bitmap: Bitmap): Double {
            val small = Bitmap.createScaledBitmap(bitmap, 64, 64, true)
            val pixels = IntArray(64 * 64)
            small.getPixels(pixels, 0, 64, 0, 0, 64, 64)
            if (small !== bitmap) small.recycle()
            return Sharpness.of(IntArray(64 * 64) { grey(pixels[it]) }, 64)
        }
    }
}

/** Pure maths (JVM-tested). [grey] is 9 × 8, row by row. */
internal object DHash {
    fun of(grey: IntArray): Long {
        var hash = 0L
        var bit = 0
        for (y in 0 until 8) {
            for (x in 0 until 8) {
                if (grey[y * 9 + x] > grey[y * 9 + x + 1]) hash = hash or (1L shl bit)
                bit++
            }
        }
        return hash
    }
}

/** Pure maths (JVM-tested). [grey] is [side] × [side], row by row. */
internal object Sharpness {
    fun of(grey: IntArray, side: Int): Double {
        var sum = 0.0
        var sumSq = 0.0
        var n = 0
        for (y in 1 until side - 1) {
            for (x in 1 until side - 1) {
                val i = y * side + x
                val lap = 4 * grey[i] - grey[i - 1] - grey[i + 1] - grey[i - side] - grey[i + side]
                sum += lap
                sumSq += lap.toDouble() * lap
                n++
            }
        }
        if (n == 0) return 0.0
        val mean = sum / n
        return sumSq / n - mean * mean
    }
}
