package com.aayush.proalbums

import android.content.ContentResolver
import android.content.ContentUris
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * One picture of a video at a given time, for the strip under the player.
 *
 * Any problem answers `null` (the strip then shows a plain box).
 * MediaMetadataRetriever is not thread-safe, so ONE worker thread does all the
 * work, and the retriever of the current video is kept open between frames
 * (opening it for every frame would be slow).
 */
class VideoFrameChannel(private val resolver: ContentResolver) :
    MethodChannel.MethodCallHandler {

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Only touched on the worker thread.
    private var openId: Long? = null
    private var retriever: MediaMetadataRetriever? = null
    private var videoWidth = 0
    private var videoHeight = 0

    private val releaseWhenIdle = Runnable { executor.execute { release() } }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "frame") {
            result.notImplemented()
            return
        }
        val id = call.argument<String>("id")?.toLongOrNull()
        val positionMs = call.argument<Number>("positionMs")?.toLong()
        val size = call.argument<Number>("size")?.toInt()
        if (id == null || positionMs == null || size == null) {
            result.success(null)
            return
        }

        mainHandler.removeCallbacks(releaseWhenIdle)
        executor.execute {
            val bytes: ByteArray? = try {
                frame(id, positionMs, size)
            } catch (e: Exception) {
                release()
                null
            }
            mainHandler.post {
                result.success(bytes)
                mainHandler.postDelayed(releaseWhenIdle, IDLE_RELEASE_MS)
            }
        }
    }

    private fun frame(id: Long, positionMs: Long, size: Int): ByteArray? {
        val mmr = retrieverFor(id) ?: return null
        val timeUs = positionMs * 1000

        // Ask for a frame that is already the right size: decoding a 4K frame
        // and shrinking it afterwards would be much slower.
        val scale = size.toFloat() / max(videoWidth, videoHeight).coerceAtLeast(1)
        val outW = max(1, (videoWidth * scale).toInt())
        val outH = max(1, (videoHeight * scale).toInt())

        val bitmap: Bitmap = mmr.getScaledFrameAtTime(
            timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, outW, outH
        ) ?: return null

        val output = ByteArrayOutputStream(outW * outH / 4)
        bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)
        bitmap.recycle()
        return output.toByteArray()
    }

    private fun retrieverFor(id: Long): MediaMetadataRetriever? {
        if (openId == id && retriever != null) return retriever
        release()

        val uri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
        val mmr = MediaMetadataRetriever()
        try {
            resolver.openFileDescriptor(uri, "r").use { fd ->
                if (fd == null) { mmr.release(); return null }
                mmr.setDataSource(fd.fileDescriptor)
            }
            var w = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var h = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            // A video filmed upright is stored sideways with a "turn 90" note.
            if (rotation == 90 || rotation == 270) { val t = w; w = h; h = t }
            if (w <= 0 || h <= 0) { mmr.release(); return null }
            videoWidth = w
            videoHeight = h
        } catch (e: Exception) {
            mmr.release()
            return null
        }
        retriever = mmr
        openId = id
        return mmr
    }

    private fun release() {
        try { retriever?.release() } catch (_: Exception) {}
        retriever = null
        openId = null
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/video_frames"
        const val JPEG_QUALITY = 70
        const val IDLE_RELEASE_MS = 20_000L
    }
}
