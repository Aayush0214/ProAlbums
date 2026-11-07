package com.aayush.proalbums

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.media.ExifInterface
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
 *    duration (ms), dated (DATE_TAKEN known), modified}], newest first.
 *  - exifDates {ids}: id → when the picture was taken from its EXIF
 *    (DateTimeOriginal, else DateTime; ms) for pictures MediaStore has no
 *    date for; pictures without one are left out.
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
            "exifDates" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                    .mapNotNull { it.toLongOrNull() }
                background(result) { exifDates(ids) }
            }
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
            MediaStore.Files.FileColumns.DATE_MODIFIED,
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
                        // No DATE_TAKEN (copied from another phone…): the
                        // real date is in the EXIF, see exifDates.
                        "dated" to !c.isNull(3),
                        "modified" to c.getLong(10),
                    ),
                )
            }
        }
        return rows
    }

    private fun exifDates(ids: List<Long>): Map<String, Long> {
        val out = mutableMapOf<String, Long>()
        for (id in ids) {
            val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
            try {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    val exif = ExifInterface(input)
                    val taken = ExifDate.parse(
                        exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                            ?: exif.getAttribute(ExifInterface.TAG_DATETIME),
                        exif.getAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL),
                    )
                    if (taken != null) out[id.toString()] = taken
                }
            } catch (error: Exception) {
                // Unreadable: no date (asked again only when the file changes).
            }
        }
        return out
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

/**
 * Pure (JVM-tested): an EXIF date ("2021:02:09 18:42:07") as ms. With an
 * offset ("+05:30") it is exact; without one it is read as the phone's
 * time zone (where the picture was most likely taken). Empty / zero dates
 * ("0000:00:00 00:00:00") and years before 1990 are no date.
 */
internal object ExifDate {
    fun parse(date: String?, offset: String?, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): Long? {
        val text = date?.trim() ?: return null
        val format = java.text.SimpleDateFormat("yyyy:MM:dd HH:mm:ss", java.util.Locale.ROOT)
        format.isLenient = false
        val clean = offset?.trim()
        format.timeZone = if (clean != null && Regex("[+-]\\d{2}:\\d{2}").matches(clean)) {
            java.util.TimeZone.getTimeZone("GMT$clean")
        } else {
            zone
        }
        val parsed = try {
            format.parse(text)
        } catch (error: java.text.ParseException) {
            null
        } ?: return null
        val year = java.util.Calendar.getInstance(format.timeZone).apply { time = parsed }.get(java.util.Calendar.YEAR)
        return if (year < 1990) null else parsed.time
    }
}
