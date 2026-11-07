package com.aayush.proalbums

import android.content.ContentResolver
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Search: the whole library in one MediaStore query (pictures and videos,
 * not in the trash), with what Search matches that the gallery list does
 * not carry: the file name and the folder (album) name.
 *  - listMedia: [{id, name, album, taken (ms), video, w, h (upright),
 *    duration (ms)}], newest first.
 */
class SearchChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listMedia" -> background(result) { listMedia() }
            else -> result.notImplemented()
        }
    }

    private fun listMedia(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME,
            MediaStore.Files.FileColumns.DATE_TAKEN,
            MediaStore.Files.FileColumns.DATE_ADDED,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.Files.FileColumns.WIDTH,
            MediaStore.Files.FileColumns.HEIGHT,
            MediaStore.Files.FileColumns.ORIENTATION,
            MediaStore.Files.FileColumns.DURATION,
        )
        val image = MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE
        val video = MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
        val args = Bundle().apply {
            putString(
                ContentResolver.QUERY_ARG_SQL_SELECTION,
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN ($image, $video)",
            )
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
            putString(
                ContentResolver.QUERY_ARG_SQL_SORT_ORDER,
                "${MediaStore.Files.FileColumns.DATE_TAKEN} DESC",
            )
        }
        context.contentResolver.query(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL), projection, args, null,
        )?.use { c ->
            while (c.moveToNext()) {
                val added = c.getLong(4) * 1000
                val turned = !c.isNull(8) && c.getInt(8) % 180 != 0
                val w = c.getInt(6)
                val h = c.getInt(7)
                rows.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "name" to (c.getString(1) ?: ""),
                        "album" to (c.getString(2) ?: ""),
                        "taken" to if (c.isNull(3)) added else c.getLong(3),
                        "video" to (c.getInt(5) == video),
                        "w" to if (turned) h else w,
                        "h" to if (turned) w else h,
                        "duration" to if (c.isNull(9)) 0L else c.getLong(9),
                    ),
                )
            }
        }
        return rows
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
        const val CHANNEL = "com.aayush.proalbums/search"
    }
}
