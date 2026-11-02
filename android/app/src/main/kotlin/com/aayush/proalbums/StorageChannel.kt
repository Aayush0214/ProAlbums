package com.aayush.proalbums

import android.content.ContentResolver
import android.content.Context
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * "Internal storage" card of the Albums tab: how big the phone's storage is,
 * how much is free, and how much of it is taken by photos, videos,
 * screenshots and the "Recently deleted" trash.
 *
 * The sizes come from MediaStore (a sum of the SIZE column), so no file is
 * opened. "Other" (apps, system, documents ...) is worked out in Dart:
 * used - (the four numbers here).
 */
class StorageChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "usage" -> usage(result)
            else -> result.notImplemented()
        }
    }

    private fun usage(result: MethodChannel.Result) {
        worker.execute {
            val answer = try {
                val stat = StatFs(Environment.getExternalStorageDirectory().path)
                val sizes = mediaSizes()
                mapOf(
                    "total" to stat.totalBytes,
                    "free" to stat.availableBytes,
                    "photos" to sizes[0],
                    "videos" to sizes[1],
                    "screenshots" to sizes[2],
                    "trash" to sizes[3],
                )
            } catch (error: Exception) {
                null
            }
            main.post {
                if (answer != null) result.success(answer)
                else result.error("storage_failed", "Could not read the storage", null)
            }
        }
    }

    /** [photos, videos, screenshots, trash] in bytes. */
    private fun mediaSizes(): LongArray {
        var photos = 0L
        var videos = 0L
        var screenshots = 0L
        var trash = 0L

        val args = Bundle().apply {
            // Also the items that are in the trash.
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
            putString(
                ContentResolver.QUERY_ARG_SQL_SELECTION,
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
                    "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}," +
                    "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})",
            )
        }
        val projection = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.IS_TRASHED,
        )
        context.contentResolver.query(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
            projection, args, null,
        )?.use { c ->
            val type = c.getColumnIndexOrThrow(projection[0])
            val size = c.getColumnIndexOrThrow(projection[1])
            val path = c.getColumnIndexOrThrow(projection[2])
            val trashed = c.getColumnIndexOrThrow(projection[3])
            while (c.moveToNext()) {
                val bytes = c.getLong(size)
                when {
                    c.getInt(trashed) == 1 -> trash += bytes
                    c.getInt(type) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
                        videos += bytes
                    (c.getString(path) ?: "").contains("screenshots", ignoreCase = true) ->
                        screenshots += bytes
                    else -> photos += bytes
                }
            }
        }
        return longArrayOf(photos, videos, screenshots, trash)
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/storage"
    }
}
