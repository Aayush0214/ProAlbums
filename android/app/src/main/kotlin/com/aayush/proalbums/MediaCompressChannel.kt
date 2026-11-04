package com.aayush.proalbums

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Viewer > More > Compress size. Always makes a NEW, smaller copy next to the
 * original (same folder, same "taken" date, so it sits beside it in the grid);
 * the original is never touched.
 *
 *  - imageInfo / videoInfo: upright size, bytes, length.
 *  - estimateImage {id, scale, quality}: about how big the copy will be. A
 *    sample of the picture (long side ≤ 2048, decoded once and kept) is really
 *    encoded, then scaled up by area: quick enough to follow the sliders.
 *  - compressImage: decode → scale → JPEG at that quality, EXIF dates /
 *    camera data copied, saved as IMG_YYYYMMDD_HHMMSS.jpg. Answers {id, size}.
 *  - compressVideo {id, width, height, bitrate}: Media3 Transformer → H.264 at
 *    that size and bitrate, progress 'compressProgress' {percent} to Dart,
 *    saved as video_YYYYMMDD_HHMMSS.mp4. Answers {id, size} or {cancelled}.
 *  - cancelVideo: stops it (the half-made file is deleted).
 */
class MediaCompressChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")?.toLongOrNull()
        when (call.method) {
            "imageInfo" -> background(result) { id?.let { imageInfo(it) } }
            "estimateImage" -> background(result) {
                id?.let {
                    estimateImage(
                        it,
                        call.argument<Number>("scale")?.toDouble() ?: 1.0,
                        call.argument<Number>("quality")?.toInt() ?: 90,
                    )
                }
            }
            "compressImage" -> background(result) {
                id?.let {
                    compressImage(
                        it,
                        call.argument<Number>("scale")?.toDouble() ?: 1.0,
                        call.argument<Number>("quality")?.toInt() ?: 90,
                    )
                }
            }
            "videoInfo" -> background(result) { id?.let { videoInfo(it) } }
            "videoCodec" -> background(result) { id?.let { videoCodec(it) } }
            "compressVideo" -> {
                // No width / height = keep the size (Convert to H.264).
                val width = call.argument<Number>("width")?.toInt()
                val height = call.argument<Number>("height")?.toInt()
                val bitrate = call.argument<Number>("bitrate")?.toInt()
                if (id == null || bitrate == null) {
                    result.success(null)
                } else {
                    compressVideo(id, width, height, bitrate, result)
                }
            }
            "cancelVideo" -> {
                cancelVideo()
                result.success(null)
            }
            "forget" -> {
                sample = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- pictures ----------------------------------------------------------------

    private class Source(
        val name: String,
        val folder: String?,
        val takenMs: Long?,
        val size: Long,
    )

    private fun imageUri(id: Long) =
        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)

    private fun videoUri(id: Long) =
        ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)

    private fun source(uri: Uri): Source? = activity.contentResolver.query(
        uri,
        arrayOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.SIZE,
        ),
        null,
        null,
        null,
    )?.use { cursor ->
        if (!cursor.moveToFirst()) return null
        Source(
            name = cursor.getString(0) ?: "",
            folder = cursor.getString(1),
            takenMs = if (cursor.isNull(2)) null else cursor.getLong(2),
            size = cursor.getLong(3),
        )
    }

    /** Degrees the picture must turn to stand upright (from its EXIF). */
    private fun rotationOf(uri: Uri): Int = try {
        activity.contentResolver.openInputStream(uri)!!.use {
            when (
                ExifInterface(it).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_TRANSPOSE -> 90
                ExifInterface.ORIENTATION_ROTATE_180, ExifInterface.ORIENTATION_FLIP_VERTICAL -> 180
                ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSVERSE -> 270
                else -> 0
            }
        }
    } catch (error: Exception) {
        0
    }

    private fun boundsOf(uri: Uri): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        activity.contentResolver.openInputStream(uri)!!.use {
            BitmapFactory.decodeStream(it, null, options)
        }
        return options.outWidth to options.outHeight
    }

    private fun imageInfo(id: Long): Map<String, Any>? {
        val uri = imageUri(id)
        val source = source(uri) ?: return null
        val (w, h) = boundsOf(uri)
        val turned = rotationOf(uri) % 180 != 0
        return mapOf(
            "width" to if (turned) h else w,
            "height" to if (turned) w else h,
            "size" to source.size,
        )
    }

    /** The decoded sample kept while the sheet is open (for estimates). */
    private class Sample(val id: Long, val bitmap: Bitmap, val fullW: Int, val fullH: Int)

    @Volatile
    private var sample: Sample? = null

    private fun sampleOf(id: Long): Sample {
        sample?.takeIf { it.id == id }?.let { return it }
        val uri = imageUri(id)
        val (w, h) = boundsOf(uri)
        var inSample = 1
        while (max(w, h) / (inSample * 2) >= SAMPLE_LONG_EDGE) inSample *= 2
        val bitmap = activity.contentResolver.openInputStream(uri)!!.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = inSample })
        } ?: error("cannot decode")
        return Sample(id, bitmap, w, h).also { sample = it }
    }

    private fun estimateImage(id: Long, scale: Double, quality: Int): Long {
        val sample = sampleOf(id)
        val targetW = (sample.fullW * scale).roundToInt().coerceAtLeast(1)
        val targetH = (sample.fullH * scale).roundToInt().coerceAtLeast(1)
        val bitmap = sample.bitmap
        return if (targetW < bitmap.width) {
            // The copy is smaller than the sample: encode exactly that size.
            val scaled = Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
            val bytes = jpegSize(scaled, quality)
            scaled.recycle()
            bytes
        } else {
            val area = targetW.toDouble() * targetH / (bitmap.width.toDouble() * bitmap.height)
            (jpegSize(bitmap, quality) * area).toLong()
        }
    }

    private fun jpegSize(bitmap: Bitmap, quality: Int): Long =
        ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, it)
            it.size().toLong()
        }

    private fun compressImage(id: Long, scale: Double, quality: Int): Map<String, Any>? {
        val uri = imageUri(id)
        val source = source(uri) ?: return null
        val (w, h) = boundsOf(uri)
        val targetW = (w * scale).roundToInt().coerceAtLeast(1)
        val targetH = (h * scale).roundToInt().coerceAtLeast(1)
        // Decode only as big as needed (power of two), then scale exactly.
        var inSample = 1
        while (w / (inSample * 2) >= targetW && h / (inSample * 2) >= targetH) inSample *= 2
        val decoded = activity.contentResolver.openInputStream(uri)!!.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = inSample })
        } ?: return null
        var picture = if (decoded.width != targetW || decoded.height != targetH) {
            Bitmap.createScaledBitmap(decoded, targetW, targetH, true).also { decoded.recycle() }
        } else {
            decoded
        }
        // Upright in the pixels themselves (the copy has no turn in its EXIF).
        val rotation = rotationOf(uri)
        if (rotation != 0) {
            val turned = Bitmap.createBitmap(
                picture, 0, 0, picture.width, picture.height,
                Matrix().apply { postRotate(rotation.toFloat()) }, true,
            )
            picture.recycle()
            picture = turned
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "IMG_${stamp()}.jpg")
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, imageFolder(source.folder))
            source.takenMs?.let { put(MediaStore.MediaColumns.DATE_TAKEN, it) }
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = activity.contentResolver
        val target = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null
        try {
            resolver.openOutputStream(target, "w")!!.use {
                picture.compress(Bitmap.CompressFormat.JPEG, quality, it)
            }
            picture.recycle()
            copyExif(uri, target)
            resolver.update(
                target,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null,
            )
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            return null
        }
        return mapOf("id" to ContentUris.parseId(target).toString(), "size" to sizeOf(target))
    }

    /** Dates, camera and place of the original go into the copy too. */
    private fun copyExif(from: Uri, to: Uri) {
        try {
            val old = activity.contentResolver.openInputStream(from)!!.use { ExifInterface(it) }
            activity.contentResolver.openFileDescriptor(to, "rw")!!.use { file ->
                val copy = ExifInterface(file.fileDescriptor)
                for (tag in EXIF_TAGS) old.getAttribute(tag)?.let { copy.setAttribute(tag, it) }
                copy.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
                copy.saveAttributes()
            }
        } catch (error: Exception) {
            // The picture is fine without them.
        }
    }

    // --- videos ------------------------------------------------------------------

    private fun videoInfo(id: Long): Map<String, Any>? {
        val uri = videoUri(id)
        val source = source(uri) ?: return null
        return MediaMetadataRetriever().run {
            try {
                activity.contentResolver.openFileDescriptor(uri, "r")!!.use { setDataSource(it.fileDescriptor) }
                val w = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
                val h = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
                val rotation = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
                val duration = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0
                val turned = rotation % 180 != 0
                mapOf(
                    "width" to if (turned) h else w,
                    "height" to if (turned) w else h,
                    "durationMs" to duration,
                    "size" to source.size,
                )
            } finally {
                release()
            }
        }
    }

    private var transformer: Transformer? = null
    private var progressTicker: Runnable? = null
    private var output: File? = null
    private var pending: MethodChannel.Result? = null

    /** The video track's format, e.g. "video/avc" (H.264) or "video/hevc". */
    private fun videoCodec(id: Long): String? {
        val extractor = android.media.MediaExtractor()
        try {
            activity.contentResolver.openFileDescriptor(videoUri(id), "r")!!.use {
                extractor.setDataSource(it.fileDescriptor)
            }
            for (track in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(track)
                    .getString(android.media.MediaFormat.KEY_MIME)
                if (mime?.startsWith("video/") == true) return mime
            }
            return null
        } finally {
            extractor.release()
        }
    }

    private fun compressVideo(id: Long, width: Int?, height: Int?, bitrate: Int, result: MethodChannel.Result) {
        cancelVideo()
        val uri = videoUri(id)
        val source = source(uri)
        if (source == null) {
            result.success(null)
            return
        }
        val file = File(activity.cacheDir, "compress/${System.currentTimeMillis()}.mp4").apply {
            parentFile?.mkdirs()
        }
        output = file
        pending = result

        val builder = EditedMediaItem.Builder(MediaItem.fromUri(uri))
        if (width != null && height != null) {
            builder.setEffects(
                Effects(
                    emptyList(),
                    listOf(Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT)),
                ),
            )
        }
        val edited = builder.build()
        val job = Transformer.Builder(activity)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(activity)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(bitrate).build(),
                    )
                    .build(),
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopTicker()
                    transformer = null
                    val done = pending ?: return
                    pending = null
                    worker.execute {
                        val saved = try {
                            saveVideo(file, source)
                        } catch (error: Exception) {
                            null
                        } finally {
                            file.delete()
                        }
                        main.post { done.success(saved) }
                    }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    stopTicker()
                    transformer = null
                    file.delete()
                    pending?.success(null)
                    pending = null
                }
            })
            .build()
        transformer = job
        job.start(edited, file.absolutePath)
        startTicker(job)
    }

    private fun startTicker(job: Transformer) {
        val holder = ProgressHolder()
        val tick = object : Runnable {
            override fun run() {
                if (transformer !== job) return
                if (job.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel?.invokeMethod("compressProgress", mapOf("percent" to holder.progress))
                }
                main.postDelayed(this, 200)
            }
        }
        progressTicker = tick
        main.post(tick)
    }

    private fun stopTicker() {
        progressTicker?.let { main.removeCallbacks(it) }
        progressTicker = null
    }

    private fun cancelVideo() {
        val job = transformer ?: return
        transformer = null
        stopTicker()
        job.cancel()
        output?.delete()
        pending?.success(mapOf("cancelled" to true))
        pending = null
    }

    private fun saveVideo(file: File, source: Source): Map<String, Any>? {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "video_${stamp()}.mp4")
            put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            put(MediaStore.MediaColumns.RELATIVE_PATH, videoFolder(source.folder))
            source.takenMs?.let { put(MediaStore.MediaColumns.DATE_TAKEN, it) }
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val target = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        try {
            resolver.openOutputStream(target, "w")!!.use { out -> file.inputStream().use { it.copyTo(out) } }
            resolver.update(
                target,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null,
            )
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            return null
        }
        return mapOf("id" to ContentUris.parseId(target).toString(), "size" to sizeOf(target))
    }

    // --- helpers -----------------------------------------------------------------

    private fun sizeOf(uri: Uri): Long = activity.contentResolver.query(
        uri, arrayOf(MediaStore.MediaColumns.SIZE), null, null, null,
    )?.use { if (it.moveToFirst()) it.getLong(0) else 0L } ?: 0L

    private fun stamp() = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())

    /** Pictures may only go under DCIM/ or Pictures/. */
    private fun imageFolder(folder: String?) =
        folder?.takeIf { it.startsWith("DCIM/") || it.startsWith("Pictures/") } ?: "Pictures/"

    /** Videos may go under DCIM/, Movies/ or Pictures/. */
    private fun videoFolder(folder: String?) = folder?.takeIf {
        it.startsWith("DCIM/") || it.startsWith("Movies/") || it.startsWith("Pictures/")
    } ?: "Movies/"

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        worker.execute {
            val answer = try {
                work()
            } catch (error: Throwable) {
                // OutOfMemoryError on a huge picture included.
                null
            }
            main.post { result.success(answer) }
        }
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/compress"
        const val SAMPLE_LONG_EDGE = 2048

        val EXIF_TAGS = listOf(
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_OFFSET_TIME,
            ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_F_NUMBER,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_ISO_SPEED_RATINGS,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
        )
    }
}
