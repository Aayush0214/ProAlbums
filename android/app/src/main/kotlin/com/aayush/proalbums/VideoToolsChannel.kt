package com.aayush.proalbums

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * The viewer's video tools that need Android:
 *  - captureFrame: the frame on screen, full size, saved as
 *    Pictures/Screenshots/Videoshot_YYYYMMDD_HHMMSS.jpg (like the system
 *    gallery); answers a small preview of it (for the "fly away" animation).
 *  - brightness / setBrightness: THIS window's brightness (the player's left
 *    side swipe); null = back to the phone's own brightness.
 *  - volume / setVolume: the media volume 0..1 (right side swipe), without
 *    the system volume panel (the player shows its own).
 *  - pickSubtitle: the person picks a .srt / .vtt file; answers its name and
 *    text (nothing is copied or kept).
 */
class VideoToolsChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "captureFrame" -> {
                val id = call.argument<String>("id")?.toLongOrNull()
                val positionMs = call.argument<Number>("positionMs")?.toLong()
                if (id == null || positionMs == null) {
                    result.success(null)
                    return
                }
                worker.execute {
                    val preview = try {
                        capture(id, positionMs)
                    } catch (error: Exception) {
                        null
                    }
                    main.post { result.success(preview) }
                }
            }
            "brightness" -> result.success(brightness())
            "setBrightness" -> {
                val value = call.argument<Number>("value")?.toFloat()
                val params = activity.window.attributes
                params.screenBrightness = if (value == null || value < 0f) {
                    WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                } else {
                    value.coerceIn(MIN_BRIGHTNESS, 1f)
                }
                activity.window.attributes = params
                result.success(null)
            }
            "volume" -> result.success(volume())
            "setVolume" -> {
                val value = call.argument<Number>("value")?.toDouble() ?: 0.0
                val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                try {
                    // flags 0: no system volume panel.
                    audio.setStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        Math.round(value.coerceIn(0.0, 1.0) * max).toInt(),
                        0,
                    )
                } catch (error: SecurityException) {
                    // Do Not Disturb may refuse it; the swipe then does nothing.
                }
                result.success(volume())
            }
            "pickSubtitle" -> pickSubtitle(result)
            else -> result.notImplemented()
        }
    }

    /** This window's brightness 0..1 (the phone's own while not overridden). */
    private fun brightness(): Double {
        val own = activity.window.attributes.screenBrightness
        if (own >= 0f) return own.toDouble()
        return try {
            Settings.System.getInt(
                activity.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
            ) / 255.0
        } catch (error: Settings.SettingNotFoundException) {
            0.5
        }
    }

    private fun volume(): Double {
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    // --- subtitle file ---------------------------------------------------------

    private var pendingPick: MethodChannel.Result? = null

    private fun pickSubtitle(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        // .srt files often have no known type on Android, so every file is
        // offered and the name is checked in Dart.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            pendingPick = result
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_SUBTITLE)
        } catch (error: ActivityNotFoundException) {
            pendingPick = null
            result.success(null)
        }
    }

    /** From MainActivity; true when it was our request. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SUBTITLE) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        worker.execute {
            val answer = try {
                readSubtitle(uri)
            } catch (error: Exception) {
                null
            }
            main.post { result.success(answer) }
        }
        return true
    }

    private fun readSubtitle(uri: Uri): Map<String, String>? {
        val resolver = activity.contentResolver
        var name = "subtitle"
        var size = -1L
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use {
            if (it.moveToFirst()) {
                name = it.getString(0) ?: name
                if (!it.isNull(1)) size = it.getLong(1)
            }
        }
        // A subtitle file is small; anything big is not one.
        if (size > MAX_SUBTITLE_BYTES) return null
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        if (bytes.size > MAX_SUBTITLE_BYTES) return null
        return mapOf("name" to name, "text" to String(bytes, Charsets.UTF_8))
    }

    /** Saves the frame at [positionMs] of video [id]; a small JPEG preview, or null. */
    private fun capture(id: Long, positionMs: Long): ByteArray? {
        val uri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
        val frame = MediaMetadataRetriever().run {
            try {
                activity.contentResolver.openFileDescriptor(uri, "r")!!.use {
                    setDataSource(it.fileDescriptor)
                    // The exact frame shown (not the nearest keyframe).
                    getFrameAtTime(positionMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                }
            } finally {
                release()
            }
        } ?: return null

        val name = "Videoshot_" +
            SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + ".jpg"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Screenshots/")
            put(MediaStore.MediaColumns.DATE_TAKEN, System.currentTimeMillis())
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = activity.contentResolver
        val target = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null
        try {
            resolver.openOutputStream(target, "w")!!.use {
                frame.compress(Bitmap.CompressFormat.JPEG, 95, it)
            }
            resolver.update(
                target,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null,
            )
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            frame.recycle()
            return null
        }

        // A small copy for the animation.
        val scale = PREVIEW_PX.toFloat() / maxOf(frame.width, frame.height)
        val small = if (scale < 1f) {
            Bitmap.createScaledBitmap(
                frame,
                (frame.width * scale).toInt().coerceAtLeast(1),
                (frame.height * scale).toInt().coerceAtLeast(1),
                true,
            )
        } else {
            frame
        }
        val preview = ByteArrayOutputStream().use { out ->
            small.compress(Bitmap.CompressFormat.JPEG, 85, out)
            out.toByteArray()
        }
        if (small !== frame) small.recycle()
        frame.recycle()
        return preview
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/video_tools"
        const val PREVIEW_PX = 480
        const val REQUEST_SUBTITLE = 7205
        const val MAX_SUBTITLE_BYTES = 4L * 1024 * 1024

        // Fully dark would look like the screen switched off.
        const val MIN_BRIGHTNESS = 0.01f
    }
}
