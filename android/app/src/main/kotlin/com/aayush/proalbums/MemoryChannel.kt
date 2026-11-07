package com.aayush.proalbums

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.graphics.Matrix
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbMatrix
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * For You > memories.
 *  - pickAudio: the person picks a song with Android's own picker (Files,
 *    Drive, music apps…; no permission needed). The app keeps a lasting
 *    read permission so the memory can play it later. Answers
 *    {uri, name} or null (cancelled).
 *  - canRead {uri}: the song can still be opened (deleted / permission
 *    gone = false).
 *  - waveform {uri, bars}: the song's loudness {bars: 0–1 each, durationMs}
 *    (decoded with MediaCodec) for the "choose a part" page.
 *  - exportVideo {ids, audio, audioStartMs, perPictureMs, toGallery}: the
 *    memory as an MP4 (Media3 Transformer): every picture [perPictureMs]
 *    long with a slow zoom and a fade from / to dark, fitted into 1080×1920
 *    (portrait) on black, H.264 4 Mbit/s, the song from [audioStartMs]
 *    looped under it (audio = "asset:..." / "content://..." / null =
 *    silent). toGallery: Movies/ProAlbums/MV_YYYYMMDD_HHMMSS.mp4 → {id};
 *    else a cache file to share → {path}. Progress "exportProgress"
 *    {percent}. {cancelled: true} / null = failed.
 *  - cancelExport.
 */
class MemoryChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private var pendingPick: MethodChannel.Result? = null
    private var channel: MethodChannel? = null

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var transformer: Transformer? = null
    private var pendingExport: MethodChannel.Result? = null
    private var exportFile: File? = null
    private var ticker: Runnable? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickAudio" -> pickAudio(result)
            "canRead" -> result.success(canRead(call.argument<String>("uri")))
            "exportVideo" -> exportVideo(
                ids = call.argument<List<String>>("ids").orEmpty().mapNotNull { it.toLongOrNull() },
                audio = call.argument<String>("audio"),
                perPictureMs = call.argument<Int>("perPictureMs") ?: 3200,
                audioStartMs = (call.argument<Number>("audioStartMs") ?: 0).toLong(),
                toGallery = call.argument<Boolean>("toGallery") ?: true,
                result = result,
            )
            "waveform" -> {
                val uri = call.argument<String>("uri")
                val bars = call.argument<Int>("bars") ?: 120
                if (uri == null) {
                    result.success(null)
                } else {
                    worker.execute {
                        val answer = try {
                            waveform(Uri.parse(uri), bars)
                        } catch (error: Exception) {
                            null
                        }
                        main.post { result.success(answer) }
                    }
                }
            }
            "cancelExport" -> {
                cancelExport()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- waveform ----------------------------------------------------------

    /** The song's loudness as [bars] values 0–1, and its length (ms). */
    private fun waveform(uri: Uri, bars: Int): Map<String, Any>? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(activity, uri, null)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null
            val format = extractor.getTrackFormat(track)
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
            if (durationUs <= 0) return null
            extractor.selectTrack(track)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            val loudness = WaveBars(bars, durationUs)
            try {
                codec.configure(format, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                // Not the whole song (a big FLAC took ~15 s): a few buffers at
                // the place of every bar.
                for (bar in 0 until bars) {
                    val atUs = durationUs * bar / bars
                    extractor.seekTo(atUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    codec.flush()
                    var got = 0
                    var fed = 0
                    var spins = 0
                    while (got < BUFFERS_PER_BAR && spins < 200) {
                        spins++
                        if (fed < BUFFERS_PER_BAR + 4) {
                            val inIndex = codec.dequeueInputBuffer(5_000)
                            if (inIndex >= 0) {
                                val buffer = codec.getInputBuffer(inIndex)!!
                                val size = extractor.readSampleData(buffer, 0)
                                if (size < 0) {
                                    codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    fed = Int.MAX_VALUE
                                } else {
                                    codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                                    extractor.advance()
                                    fed++
                                }
                            }
                        }
                        val outIndex = codec.dequeueOutputBuffer(info, 5_000)
                        if (outIndex >= 0) {
                            val out = codec.getOutputBuffer(outIndex)
                            if (out != null && info.size > 0) {
                                out.position(info.offset)
                                out.limit(info.offset + info.size)
                                val shorts = out.order(java.nio.ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                                var sum = 0L
                                var n = 0
                                var i = 0
                                while (i < shorts.remaining()) {
                                    sum += kotlin.math.abs(shorts.get(i).toInt())
                                    n++
                                    i += 16
                                }
                                if (n > 0) loudness.addLevel(bar, (sum / n).toInt())
                                got++
                            }
                            codec.releaseOutputBuffer(outIndex, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                        }
                    }
                }
            } finally {
                codec.stop()
                codec.release()
            }
            return mapOf("bars" to loudness.normalized(), "durationMs" to durationUs / 1000)
        } finally {
            extractor.release()
        }
    }

    // --- export ------------------------------------------------------------

    @androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
    private fun exportVideo(
        ids: List<Long>,
        audio: String?,
        perPictureMs: Int,
        audioStartMs: Long,
        toGallery: Boolean,
        result: MethodChannel.Result,
    ) {
        cancelExport()
        if (ids.isEmpty()) {
            result.success(null)
            return
        }
        // A video to share stays in the cache (the last one replaced).
        val folder = File(activity.cacheDir, if (toGallery) "memory" else "memory_share")
        if (!toGallery) folder.listFiles()?.forEach { it.delete() }
        val file = File(folder, "MV_${stamp()}.mp4").apply { parentFile?.mkdirs() }
        exportFile = file
        pendingExport = result

        val perPictureUs = perPictureMs * 1000L
        // Slow zoom in, the same on every picture (time inside the picture).
        val zoom = MatrixTransformation { timeUs ->
            val t = (timeUs % perPictureUs).toFloat() / perPictureUs
            val s = 1f + ZOOM * t
            Matrix().apply { setScale(s, s) }
        }
        // Each picture comes up from dark and goes down to dark.
        val fadeUs = FADE_MS * 1000L
        // The FIRST picture starts bright (the video's first frame is its
        // thumbnail: a fade from dark made it black).
        fun fade(first: Boolean) = RgbMatrix { timeUs, _ ->
            val b = PictureFade.brightness(timeUs % perPictureUs, perPictureUs, fadeUs, fadeIn = !first)
            floatArrayOf(b, 0f, 0f, 0f, 0f, b, 0f, 0f, 0f, 0f, b, 0f, 0f, 0f, 0f, 1f)
        }
        val frame = Presentation.createForWidthAndHeight(WIDTH, HEIGHT, Presentation.LAYOUT_SCALE_TO_FIT)
        val pictures = ids.mapIndexed { index, id ->
            val item = MediaItem.Builder()
                .setUri(ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id))
                .setImageDurationMs(perPictureMs.toLong())
                .build()
            EditedMediaItem.Builder(item)
                .setFrameRate(FPS)
                .setEffects(Effects(emptyList(), listOf(zoom, frame, fade(first = index == 0))))
                .build()
        }
        val sequences = mutableListOf(EditedMediaItemSequence.Builder(pictures).build())
        if (audio != null) {
            // The part chosen (the user's own song), then looping.
            val songItem = MediaItem.Builder()
                .setUri(audio)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder().setStartPositionMs(audioStartMs).build(),
                )
                .build()
            val song = EditedMediaItem.Builder(songItem).setRemoveVideo(true).build()
            // Looping: the song repeats until the pictures end.
            sequences.add(EditedMediaItemSequence.Builder(song).setIsLooping(true).build())
        }
        val composition = Composition.Builder(sequences).build()

        val job = Transformer.Builder(activity)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            // Slow pictures need little: ~4 Mbit/s (the default made 46 MB
            // for 44 s).
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(activity)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(BITRATE).build(),
                    )
                    .build(),
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopTicker()
                    transformer = null
                    val done = pendingExport ?: return
                    pendingExport = null
                    if (!toGallery) {
                        done.success(mapOf("path" to file.absolutePath))
                        return
                    }
                    worker.execute {
                        val saved = try {
                            save(file)
                        } catch (error: Exception) {
                            null
                        } finally {
                            file.delete()
                        }
                        main.post { done.success(saved?.let { mapOf("id" to it) }) }
                    }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    android.util.Log.e("MemoryChannel", "Export failed", exportException)
                    stopTicker()
                    transformer = null
                    file.delete()
                    pendingExport?.success(null)
                    pendingExport = null
                }
            })
            .build()
        transformer = job
        job.start(composition, file.absolutePath)
        startTicker(job)
    }

    private fun startTicker(job: Transformer) {
        val holder = ProgressHolder()
        val tick = object : Runnable {
            override fun run() {
                if (transformer !== job) return
                if (job.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel?.invokeMethod("exportProgress", mapOf("percent" to holder.progress))
                }
                main.postDelayed(this, 200)
            }
        }
        ticker = tick
        main.post(tick)
    }

    private fun stopTicker() {
        ticker?.let { main.removeCallbacks(it) }
        ticker = null
    }

    private fun cancelExport() {
        val job = transformer ?: return
        transformer = null
        stopTicker()
        job.cancel()
        exportFile?.delete()
        pendingExport?.success(mapOf("cancelled" to true))
        pendingExport = null
    }

    private fun stamp(): String = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.ROOT).format(Date())

    /** Into Movies/ProAlbums; the new video's MediaStore id. */
    private fun save(file: File): String? {
        val resolver = activity.contentResolver
        val stamp = stamp()
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "MV_$stamp.mp4")
            put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "Movies/ProAlbums")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val target = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        return try {
            resolver.openOutputStream(target, "w")!!.use { out -> file.inputStream().use { it.copyTo(out) } }
            resolver.update(
                target,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null,
            )
            ContentUris.parseId(target).toString()
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            null
        }
    }

    private fun pickAudio(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            // Start in the phone's Music folder (else Android opens the last
            // folder used by the app, e.g. the vault's).
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:Music",
                ),
            )
        }
        try {
            pendingPick = result
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_AUDIO)
        } catch (error: ActivityNotFoundException) {
            pendingPick = null
            result.success(null)
        }
    }

    /** From MainActivity; true when it was our request. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_AUDIO) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (error: SecurityException) {
            // Some providers give no lasting permission: it still plays now.
        }
        result.success(mapOf("uri" to uri.toString(), "name" to nameOf(uri)))
        return true
    }

    private fun nameOf(uri: Uri): String {
        try {
            activity.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use {
                if (it.moveToFirst() && !it.isNull(0)) {
                    return it.getString(0).substringBeforeLast('.')
                }
            }
        } catch (error: Exception) {
            // Below.
        }
        return "My music"
    }

    private fun canRead(uri: String?): Boolean {
        if (uri == null) return false
        return try {
            activity.contentResolver.openFileDescriptor(Uri.parse(uri), "r")?.use { true } ?: false
        } catch (error: Exception) {
            false
        }
    }

    internal companion object {
        const val CHANNEL = "com.aayush.proalbums/memories"
        const val REQUEST_AUDIO = 7208

        // The exported video: portrait 1080×1920, 30 fps, zoom 1 → 1.15.
        const val WIDTH = 1080
        const val HEIGHT = 1920
        const val FPS = 30
        const val ZOOM = 0.15f
        const val BITRATE = 4_000_000
        const val FADE_MS = 400L

        // Waveform: decoded buffers read at each bar.
        const val BUFFERS_PER_BAR = 3
    }
}

/**
 * Pure (JVM-tested): how bright a picture is at [timeUs] of its
 * [durationUs]: up from dark over [fadeUs], then full, then down to dark
 * over the last [fadeUs].
 */
internal object PictureFade {
    fun brightness(timeUs: Long, durationUs: Long, fadeUs: Long, fadeIn: Boolean = true): Float {
        if (fadeUs <= 0 || durationUs <= 0) return 1f
        val edge = minOf(fadeUs, durationUs / 2)
        val fromEnd = durationUs - timeUs
        return when {
            fadeIn && timeUs < edge -> timeUs.toFloat() / edge
            fromEnd < edge -> fromEnd.toFloat() / edge
            else -> 1f
        }.coerceIn(0f, 1f)
    }
}

/**
 * Pure (JVM-tested): the AVERAGE loudness of each of [bars] equal parts of
 * a song of [durationUs] (the loudest sample is near full everywhere in a
 * mastered song: all bars looked the same). [normalized] = 0–1 stretched
 * between the quietest and the loudest part, so quiet and loud places show.
 */
internal class WaveBars(private val bars: Int, private val durationUs: Long) {
    private val sums = LongArray(bars)
    private val counts = IntArray(bars)

    /** A level heard at [timeUs]. */
    fun add(timeUs: Long, level: Int) {
        if (bars <= 0 || durationUs <= 0) return
        addLevel(((timeUs.toDouble() / durationUs) * bars).toInt(), level)
    }

    /** A level of bar [index]. */
    fun addLevel(index: Int, level: Int) {
        if (bars <= 0) return
        val i = index.coerceIn(0, bars - 1)
        sums[i] += level
        counts[i]++
    }

    fun normalized(): List<Double> {
        val levels = DoubleArray(bars) { if (counts[it] == 0) 0.0 else sums[it].toDouble() / counts[it] }
        val heard = levels.filter { it > 0 }
        if (heard.isEmpty()) return List(bars) { 0.0 }
        val min = heard.min()
        val max = heard.max()
        if (max == min) return levels.map { if (it > 0) 1.0 else 0.0 }
        return levels.map { if (it <= 0) 0.0 else (it - min) / (max - min) }
    }
}
