package com.aayush.proalbums

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.media.ExifInterface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Saving collages (Grid > Collage) as Pictures/Collage/Collage_YYYYMMDD_HHMMSS.jpg
 * — that folder IS the "Collage" album (it appears under More albums by
 * itself).
 *  - saveRgba {rgba, width, height}: the collage drawn by Flutter.
 *  - stitch {ids, width}: pictures one under the other at one width (a long
 *    picture can be taller than the GPU allows, so it is drawn here).
 * Both answer the new picture's gallery id, or null.
 */
class CollageChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveRgba" -> {
                val rgba = call.argument<ByteArray>("rgba")
                val width = call.argument<Number>("width")?.toInt()
                val height = call.argument<Number>("height")?.toInt()
                if (rgba == null || width == null || height == null) {
                    result.success(null)
                    return
                }
                background(result) {
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
                    save(bitmap)
                }
            }
            "stitch" -> {
                val ids = call.argument<List<String>>("ids").orEmpty().mapNotNull { it.toLongOrNull() }
                val width = call.argument<Number>("width")?.toInt() ?: 1080
                if (ids.isEmpty()) {
                    result.success(null)
                    return
                }
                background(result) { save(stitch(ids, width)) }
            }
            else -> result.notImplemented()
        }
    }

    private fun stitch(ids: List<Long>, width: Int): Bitmap {
        val uris = ids.map { ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, it) }
        // Upright size of each, then its height at [width].
        val sizes = uris.map { upright(it) }
        var targetWidth = width
        var heights = sizes.map { (w, h) -> (h.toLong() * targetWidth / w.coerceAtLeast(1)).toInt() }
        // Keep the whole picture under ~50 megapixels (memory).
        while (targetWidth.toLong() * heights.sum() > MAX_PIXELS && targetWidth > 360) {
            targetWidth = targetWidth * 3 / 4
            heights = sizes.map { (w, h) -> (h.toLong() * targetWidth / w.coerceAtLeast(1)).toInt() }
        }
        val out = Bitmap.createBitmap(targetWidth, heights.sum().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawColor(android.graphics.Color.WHITE)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        var top = 0
        uris.forEachIndexed { index, uri ->
            val height = heights[index]
            decodeUpright(uri, targetWidth)?.let { picture ->
                canvas.drawBitmap(picture, null, Rect(0, top, targetWidth, top + height), paint)
                picture.recycle()
            }
            top += height
        }
        return out
    }

    /** Width and height as seen (EXIF turn applied). */
    private fun upright(uri: Uri): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        activity.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
        return if (rotationOf(uri) % 180 != 0) {
            options.outHeight to options.outWidth
        } else {
            options.outWidth to options.outHeight
        }
    }

    /** The picture upright, decoded about [width] wide (not much bigger). */
    private fun decodeUpright(uri: Uri, width: Int): Bitmap? {
        val (w, h) = upright(uri)
        var sample = 1
        while (w / (sample * 2) >= width) sample *= 2
        val decoded = activity.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val rotation = rotationOf(uri)
        if (rotation == 0) return decoded
        return Bitmap.createBitmap(
            decoded, 0, 0, decoded.width, decoded.height,
            Matrix().apply { postRotate(rotation.toFloat()) }, true,
        ).also { if (it !== decoded) decoded.recycle() }
    }

    private fun rotationOf(uri: Uri): Int = try {
        activity.contentResolver.openInputStream(uri)!!.use {
            when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_TRANSPOSE -> 90
                ExifInterface.ORIENTATION_ROTATE_180, ExifInterface.ORIENTATION_FLIP_VERTICAL -> 180
                ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSVERSE -> 270
                else -> 0
            }
        }
    } catch (error: Exception) {
        0
    }

    private fun save(bitmap: Bitmap): String? {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "Collage_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())}.jpg")
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, FOLDER)
            put(MediaStore.MediaColumns.DATE_TAKEN, System.currentTimeMillis())
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val target = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        return try {
            resolver.openOutputStream(target, "w")!!.use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }
            resolver.update(target, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
            ContentUris.parseId(target).toString()
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            null
        } finally {
            bitmap.recycle()
        }
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

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/collage"
        const val FOLDER = "Pictures/Collage/"
        const val MAX_PIXELS = 50_000_000L
    }
}
