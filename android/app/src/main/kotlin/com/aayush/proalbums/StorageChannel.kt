package com.aayush.proalbums

import android.app.usage.StorageStatsManager
import android.content.ContentResolver
import android.content.Context
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.os.storage.StorageManager
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
                // Like Settings and the Files app: the whole storage as sold
                // (128 GB, the system partition included) and what is free.
                // StatFs saw only the data partition (~115 GB of 128).
                val stats = context.getSystemService(StorageStatsManager::class.java)
                val total: Long
                val free: Long
                if (stats != null) {
                    total = stats.getTotalBytes(StorageManager.UUID_DEFAULT)
                    free = stats.getFreeBytes(StorageManager.UUID_DEFAULT)
                } else {
                    val stat = StatFs(Environment.getDataDirectory().path)
                    total = stat.totalBytes
                    free = stat.availableBytes
                }
                val sizes = mediaSizes()
                mapOf(
                    "total" to total,
                    "free" to free,
                    "photos" to sizes[0],
                    "videos" to sizes[1],
                    "screenshots" to sizes[2],
                    "trash" to sizes[3],
                    "camera" to sizes[4],
                    "whatsapp" to sizes[5],
                    "downloads" to sizes[6],
                    "hidden" to hiddenSize(),
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

    /**
     * [photos, videos, screenshots, trash, camera, whatsapp, downloads] in
     * bytes. The last three are WHERE pictures / videos are (they are also in
     * photos / videos / screenshots), trash not counted.
     */
    private fun mediaSizes(): LongArray {
        var photos = 0L
        var videos = 0L
        var screenshots = 0L
        var trash = 0L
        var camera = 0L
        var whatsapp = 0L
        var downloads = 0L

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
                val folder = c.getString(path) ?: ""
                if (c.getInt(trashed) == 1) {
                    trash += bytes
                    continue
                }
                when {
                    c.getInt(type) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
                        videos += bytes
                    folder.contains("screenshots", ignoreCase = true) ->
                        screenshots += bytes
                    else -> photos += bytes
                }
                when {
                    folder.startsWith("DCIM/Camera", ignoreCase = true) -> camera += bytes
                    // Android/media/com.whatsapp/WhatsApp/Media/… (and the old
                    // WhatsApp/ folder).
                    folder.contains("WhatsApp", ignoreCase = true) -> whatsapp += bytes
                    folder.startsWith("Download", ignoreCase = true) -> downloads += bytes
                }
            }
        }
        return longArrayOf(photos, videos, screenshots, trash, camera, whatsapp, downloads)
    }

    /** The private vault's encrypted files (Documents/ProAlbums Vault/). */
    private fun hiddenSize(): Long {
        var total = 0L
        context.contentResolver.query(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
            arrayOf(MediaStore.MediaColumns.SIZE),
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ?",
            arrayOf("Documents/ProAlbums Vault/"),
            null,
        )?.use { c ->
            while (c.moveToNext()) total += c.getLong(0)
        }
        return total
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/storage"
    }
}
