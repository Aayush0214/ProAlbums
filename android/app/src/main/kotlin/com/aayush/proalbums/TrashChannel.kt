package com.aayush.proalbums

import android.app.Activity
import android.content.ContentUris
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Moves pictures and videos to Android's own trash (MediaStore IS_TRASHED).
 * Files stay on the phone and Android removes them for good after 30 days.
 * Also the "Recently deleted" screen: list what is in the trash, restore it,
 * or delete it for good.
 *
 * Two ways, the best one first:
 *  1. "Media management" access (the person turns it on ONCE in Settings):
 *     the flag is set directly, with NO system dialog.
 *  2. Without it: createTrashRequest, Android asks "Allow ProAlbums to move
 *     these to trash?" once per delete.
 */
class TrashChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // Answers that wait for a system screen to come back.
    private var pendingTrash: MethodChannel.Result? = null
    private var pendingTrashAnswer = "trashed"
    private var pendingManage: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canManage" -> result.success(MediaStore.canManageMedia(activity))
            "requestManage" -> requestManage(result)
            "trash" -> setTrashed(call, result, true)
            "restore" -> setTrashed(call, result, false)
            "deleteForever" -> deleteForever(call, result)
            "listTrashed" -> listTrashed(result)
            "thumbnail" -> thumbnail(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestManage(result: MethodChannel.Result) {
        if (MediaStore.canManageMedia(activity)) {
            result.success(true)
            return
        }
        pendingManage?.success(false)
        pendingManage = result
        val intent = Intent(Settings.ACTION_REQUEST_MANAGE_MEDIA)
            .setData(Uri.parse("package:${activity.packageName}"))
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_MANAGE)
        } catch (error: Exception) {
            pendingManage = null
            result.success(false)
        }
    }

    private fun urisOf(call: MethodCall): List<Uri> {
        val ids = call.argument<List<String>>("ids").orEmpty()
        val videos = call.argument<List<Boolean>>("videos").orEmpty()
        if (ids.isEmpty() || ids.size != videos.size) return emptyList()
        return ids.indices.mapNotNull { i ->
            val id = ids[i].toLongOrNull() ?: return@mapNotNull null
            val base = if (videos[i]) {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            ContentUris.withAppendedId(base, id)
        }
    }

    /** Also finds the items that are IN the trash (they are hidden otherwise). */
    private fun includeTrashed() = Bundle().apply {
        putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
    }

    /** Into the trash ([trashed] true) or back out of it (false). */
    private fun setTrashed(call: MethodCall, result: MethodChannel.Result, trashed: Boolean) {
        val uris = urisOf(call)
        if (uris.isEmpty()) {
            result.error("bad_args", "No valid ids", null)
            return
        }

        if (!MediaStore.canManageMedia(activity)) {
            askSystem(uris, trashed, result)
            return
        }

        // Many files can take a moment: not on the main thread.
        worker.execute {
            val done = try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_TRASHED, if (trashed) 1 else 0)
                }
                uris.all {
                    activity.contentResolver.update(it, values, includeTrashed()) > 0
                }
            } catch (error: SecurityException) {
                false
            }
            main.post {
                if (done) result.success(if (trashed) "trashed" else "done")
                else askSystem(uris, trashed, result)
            }
        }
    }

    /** Android's own "Allow ... to move to trash?" dialog. */
    private fun askSystem(uris: List<Uri>, trashed: Boolean, result: MethodChannel.Result) {
        pendingTrash?.success("cancelled")
        pendingTrash = result
        pendingTrashAnswer = if (trashed) "trashed" else "done"
        try {
            val request = MediaStore.createTrashRequest(
                activity.contentResolver, uris, trashed,
            )
            @Suppress("DEPRECATION")
            activity.startIntentSenderForResult(
                request.intentSender,
                if (trashed) REQUEST_TRASH else REQUEST_RESTORE,
                null, 0, 0, 0,
            )
        } catch (error: Exception) {
            pendingTrash = null
            result.error("trash_failed", error.message, null)
        }
    }

    /** Delete for good (from "Recently deleted"). */
    private fun deleteForever(call: MethodCall, result: MethodChannel.Result) {
        val uris = urisOf(call)
        if (uris.isEmpty()) {
            result.error("bad_args", "No valid ids", null)
            return
        }
        if (!MediaStore.canManageMedia(activity)) {
            askDelete(uris, result)
            return
        }
        worker.execute {
            val done = try {
                uris.all { activity.contentResolver.delete(it, includeTrashed()) > 0 }
            } catch (error: SecurityException) {
                false
            }
            main.post {
                if (done) result.success("done") else askDelete(uris, result)
            }
        }
    }

    private fun askDelete(uris: List<Uri>, result: MethodChannel.Result) {
        pendingTrash?.success("cancelled")
        pendingTrash = result
        pendingTrashAnswer = "done"
        try {
            val request = MediaStore.createDeleteRequest(activity.contentResolver, uris)
            @Suppress("DEPRECATION")
            activity.startIntentSenderForResult(
                request.intentSender, REQUEST_DELETE, null, 0, 0, 0,
            )
        } catch (error: Exception) {
            pendingTrash = null
            result.error("delete_failed", error.message, null)
        }
    }

    /** Everything in the trash, the most recently deleted first. */
    private fun listTrashed(result: MethodChannel.Result) {
        worker.execute {
            val rows = ArrayList<Map<String, Any?>>()
            try {
                val args = Bundle().apply {
                    putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_ONLY)
                    putString(
                        ContentResolver.QUERY_ARG_SQL_SELECTION,
                        "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
                            "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}," +
                            "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})",
                    )
                    putStringArray(
                        ContentResolver.QUERY_ARG_SORT_COLUMNS,
                        arrayOf(MediaStore.MediaColumns.DATE_EXPIRES),
                    )
                    putInt(
                        ContentResolver.QUERY_ARG_SORT_DIRECTION,
                        ContentResolver.QUERY_SORT_DIRECTION_DESCENDING,
                    )
                }
                val projection = arrayOf(
                    MediaStore.MediaColumns._ID,
                    MediaStore.Files.FileColumns.MEDIA_TYPE,
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    MediaStore.MediaColumns.WIDTH,
                    MediaStore.MediaColumns.HEIGHT,
                    MediaStore.MediaColumns.DURATION,
                    MediaStore.MediaColumns.DATE_TAKEN,
                    MediaStore.MediaColumns.DATE_ADDED,
                    MediaStore.MediaColumns.DATE_EXPIRES,
                    MediaStore.MediaColumns.DATA,
                )
                activity.contentResolver.query(
                    MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
                    projection, args, null,
                )?.use { c ->
                    val id = c.getColumnIndexOrThrow(projection[0])
                    val type = c.getColumnIndexOrThrow(projection[1])
                    val name = c.getColumnIndexOrThrow(projection[2])
                    val width = c.getColumnIndexOrThrow(projection[3])
                    val height = c.getColumnIndexOrThrow(projection[4])
                    val duration = c.getColumnIndexOrThrow(projection[5])
                    val taken = c.getColumnIndexOrThrow(projection[6])
                    val added = c.getColumnIndexOrThrow(projection[7])
                    val expires = c.getColumnIndexOrThrow(projection[8])
                    val data = c.getColumnIndexOrThrow(projection[9])
                    while (c.moveToNext()) {
                        val takenMs = c.getLong(taken)
                        rows.add(
                            mapOf(
                                "id" to c.getLong(id).toString(),
                                "video" to (c.getInt(type) ==
                                    MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO),
                                "name" to (c.getString(name) ?: ""),
                                "width" to c.getInt(width),
                                "height" to c.getInt(height),
                                "durationMs" to c.getLong(duration),
                                "createdMs" to
                                    (if (takenMs > 0) takenMs else c.getLong(added) * 1000),
                                // 0 = Android gave no date: the app counts 30 days.
                                "expiresMs" to c.getLong(expires) * 1000,
                                "path" to (c.getString(data) ?: ""),
                            ),
                        )
                    }
                }
            } catch (error: Exception) {
                main.post { result.error("list_failed", error.message, null) }
                return@execute
            }
            main.post { result.success(rows) }
        }
    }

    /**
     * A small picture of an item that is in the trash.
     *
     * The file of a trashed item is hidden (".trashed-...") and an app may NOT
     * open it by its path (EACCES). It must go through MediaStore, with the
     * "include trashed" flag on the uri. Two ways, the first that works wins:
     *  1. open the item through the ContentResolver and decode it,
     *  2. ask MediaStore for its own thumbnail.
     */
    private fun thumbnail(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")?.toLongOrNull()
        val video = call.argument<Boolean>("video") ?: false
        val size = call.argument<Int>("size") ?: 256
        if (id == null) {
            result.success(null)
            return
        }
        worker.execute {
            val bytes = try {
                makeThumbnail(trashedUri(id, video), video, size)
            } catch (error: Exception) {
                Log.w(TAG, "Trash thumbnail failed for $id", error)
                null
            }
            main.post { result.success(bytes) }
        }
    }

    /** The uri of an item, also when it is in the trash. */
    private fun trashedUri(id: Long, video: Boolean): Uri {
        val base = if (video) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        return ContentUris.withAppendedId(base, id).buildUpon()
            .appendQueryParameter("includeTrashed", "1")
            .build()
    }

    private fun makeThumbnail(uri: Uri, video: Boolean, size: Int): ByteArray? {
        var bitmap: Bitmap? = try {
            if (video) frameOf(uri) else decodeImage(uri, size)
        } catch (error: Exception) {
            Log.w(TAG, "Direct read failed for $uri", error)
            null
        }
        if (bitmap == null) {
            bitmap = try {
                activity.contentResolver.loadThumbnail(uri, Size(size, size), null)
            } catch (error: Exception) {
                Log.w(TAG, "loadThumbnail failed for $uri", error)
                null
            }
        }
        if (bitmap == null) return null
        val longest = maxOf(bitmap.width, bitmap.height)
        if (longest > size) {
            val scale = size.toFloat() / longest
            bitmap = Bitmap.createScaledBitmap(
                bitmap,
                maxOf(1, (bitmap.width * scale).toInt()),
                maxOf(1, (bitmap.height * scale).toInt()),
                true,
            )
        }
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
        return out.toByteArray()
    }

    private fun frameOf(uri: Uri): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            activity.contentResolver.openFileDescriptor(uri, "r")?.use {
                retriever.setDataSource(it.fileDescriptor)
                retriever.getFrameAtTime(0)
            }
        } finally {
            retriever.release()
        }
    }

    private fun decodeImage(uri: Uri, size: Int): Bitmap? {
        val resolver = activity.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openFileDescriptor(uri, "r")?.use {
            BitmapFactory.decodeFileDescriptor(it.fileDescriptor, null, bounds)
        }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= size &&
            bounds.outHeight / (sample * 2) >= size
        ) sample *= 2
        val decoded = resolver.openFileDescriptor(uri, "r")?.use {
            BitmapFactory.decodeFileDescriptor(
                it.fileDescriptor, null,
                BitmapFactory.Options().apply { inSampleSize = sample },
            )
        } ?: return null
        val orientation = resolver.openFileDescriptor(uri, "r")?.use {
            ExifInterface(it.fileDescriptor).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL,
            )
        } ?: ExifInterface.ORIENTATION_NORMAL
        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (degrees == 0f) return decoded
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
    }

    /** MainActivity forwards the answers of the system screens here. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        when (requestCode) {
            REQUEST_TRASH, REQUEST_RESTORE, REQUEST_DELETE -> {
                pendingTrash?.success(
                    if (resultCode == Activity.RESULT_OK) pendingTrashAnswer else "cancelled",
                )
                pendingTrash = null
                return true
            }
            REQUEST_MANAGE -> {
                pendingManage?.success(MediaStore.canManageMedia(activity))
                pendingManage = null
                return true
            }
        }
        return false
    }

    private companion object {
        const val TAG = "TrashChannel"
        const val CHANNEL = "com.aayush.proalbums/trash"
        const val REQUEST_TRASH = 7101
        const val REQUEST_MANAGE = 7102
        const val REQUEST_RESTORE = 7104
        const val REQUEST_DELETE = 7105
    }
}
