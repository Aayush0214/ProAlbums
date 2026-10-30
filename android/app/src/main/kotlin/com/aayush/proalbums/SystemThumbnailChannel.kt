package com.aayush.proalbums

import android.content.ContentResolver
import android.content.ContentUris
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Gives Flutter the thumbnails that Android ALREADY made for its own gallery
 * (ContentResolver.loadThumbnail), instead of decoding the full 12 MB photo.
 *
 * Any problem answers `null`, and the Dart side then uses the old way
 * (photo_manager), so this can only make things faster, never break them.
 */
class SystemThumbnailChannel(private val resolver: ContentResolver) :
    MethodChannel.MethodCallHandler {

    private val executor: ExecutorService = Executors.newFixedThreadPool(WORKERS)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "load") {
            result.notImplemented()
            return
        }
        val id = call.argument<String>("id")?.toLongOrNull()
        val size = call.argument<Int>("size")
        val isVideo = call.argument<Boolean>("isVideo") ?: false
        if (id == null || size == null) {
            result.success(null)
            return
        }

        // Decoding runs on a background thread; the answer goes back on main.
        executor.execute {
            val bytes: ByteArray? = try {
                load(id, size, isVideo)
            } catch (e: Exception) {
                null
            }
            mainHandler.post { result.success(bytes) }
        }
    }

    private fun load(id: Long, size: Int, isVideo: Boolean): ByteArray? {
        val collection: Uri = if (isVideo) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val uri: Uri = ContentUris.withAppendedId(collection, id)

        val loaded: Bitmap = resolver.loadThumbnail(uri, Size(size, size), null)

        // The phone often returns a bigger picture (~512 px) than we asked.
        // Shrink it so the SHORT side is [size] (the grid crops to a square),
        // which makes the JPEG smaller and Flutter's decoding cheaper.
        val shortSide = minOf(loaded.width, loaded.height)
        val bitmap: Bitmap = if (shortSide > size) {
            val scale = size.toFloat() / shortSide
            val scaled = Bitmap.createScaledBitmap(
                loaded,
                maxOf(1, Math.round(loaded.width * scale)),
                maxOf(1, Math.round(loaded.height * scale)),
                true,
            )
            loaded.recycle()
            scaled
        } else {
            loaded
        }

        val output = ByteArrayOutputStream(size * size / 6)
        bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)
        bitmap.recycle()
        return output.toByteArray()
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/thumbnails"
        const val WORKERS = 4
        const val JPEG_QUALITY = 80
    }
}
