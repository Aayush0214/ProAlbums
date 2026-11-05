package com.aayush.proalbums

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.media.ExifInterface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/**
 * Intelligent classification > the things (Documents, Plants, Food, Cars…):
 * what is in each picture, from ML Kit's on-device image labeler (~430
 * labels, model inside the app). Dart keeps the answers (each picture is
 * looked at once) and turns labels into categories.
 *  - listImages: every picture (not in the trash): id, modified, taken.
 *  - labels {ids}: id → labels "Label:0.83,Label:0.71" (confidence ≥
 *    MIN_CONFIDENCE, "" = none), camera (front / back / ""), textChars +
 *    textArea (ML Kit text recognition, for Documents), screenshot.
 */
class LabelChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val pool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    private val labeler: ImageLabeler by lazy {
        ImageLabeling.getClient(
            ImageLabelerOptions.Builder().setConfidenceThreshold(MIN_CONFIDENCE).build(),
        )
    }

    /** Documents: how much text a picture has (Latin script, inside the app). */
    private val reader: TextRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listImages" -> background(result) { listImages() }
            "labels" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                    .mapNotNull { it.toLongOrNull() }
                background(result) { labels(ids) }
            }
            else -> result.notImplemented()
        }
    }

    private fun listImages(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        val args = Bundle().apply {
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns.DATE_TAKEN} DESC")
        }
        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, projection, args, null,
        )?.use { c ->
            while (c.moveToNext()) {
                val added = c.getLong(3) * 1000
                rows.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "modified" to c.getLong(1),
                        "taken" to if (c.isNull(2)) added else c.getLong(2),
                    ),
                )
            }
        }
        return rows
    }

    private fun labels(ids: List<Long>): Map<String, Map<String, Any>> {
        val shots = screenshotsAmong(ids)
        val jobs = ids.map { id ->
            id to pool.submit(Callable {
                try {
                    val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                    val loaded = context.contentResolver.loadThumbnail(uri, Size(SIDE, SIDE), null)
                    val picture = if (loaded.config == Bitmap.Config.ARGB_8888) {
                        loaded
                    } else {
                        loaded.copy(Bitmap.Config.ARGB_8888, false).also { loaded.recycle() }
                    }
                    val (labelText, text) = try {
                        val image = InputImage.fromBitmap(picture, 0)
                        val found = Tasks.await(labeler.process(image))
                        val read = Tasks.await(reader.process(image))
                        LabelText.of(found.map { it.text to it.confidence }) to TextStats.of(
                            blocks = read.textBlocks.map { block ->
                                val box = block.boundingBox
                                val area = if (box == null) 0L else box.width().toLong() * box.height()
                                block.text.count { !it.isWhitespace() } to area
                            },
                            pictureArea = picture.width.toLong() * picture.height,
                        )
                    } finally {
                        picture.recycle()
                    }
                    mapOf(
                        "labels" to labelText,
                        "camera" to cameraOf(uri),
                        "textChars" to text.chars,
                        "textArea" to text.area,
                        "screenshot" to (id in shots),
                    )
                } catch (error: Throwable) {
                    null
                }
            })
        }
        val out = mutableMapOf<String, Map<String, Any>>()
        for ((id, job) in jobs) job.get()?.let { out[id.toString()] = it }
        return out
    }

    /** The pictures (of [ids]) that are screenshots (by folder). */
    private fun screenshotsAmong(ids: List<Long>): Set<Long> {
        if (ids.isEmpty()) return emptySet()
        val out = mutableSetOf<Long>()
        val args = Bundle().apply {
            putString(
                ContentResolver.QUERY_ARG_SQL_SELECTION,
                "${MediaStore.MediaColumns._ID} IN (${ids.joinToString(",")}) AND " +
                    "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?",
            )
            putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, arrayOf("%Screenshots%"))
        }
        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns._ID),
            args,
            null,
        )?.use { c -> while (c.moveToNext()) out.add(c.getLong(0)) }
        return out
    }

    /** "front" / "back" / "" (no camera data, e.g. a WhatsApp copy). */
    private fun cameraOf(uri: android.net.Uri): String = try {
        context.contentResolver.openInputStream(uri)?.use { input ->
            val exif = ExifInterface(input)
            CameraSide.of(
                focalMm = exif.getAttributeDouble(ExifInterface.TAG_FOCAL_LENGTH, 0.0),
                focal35 = exif.getAttributeInt(ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM, 0),
                lensModel = exif.getAttribute("LensModel"),
            )
        } ?: ""
    } catch (error: Exception) {
        ""
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
        const val CHANNEL = "com.aayush.proalbums/labels"

        /** Big enough to read a document's text (the labeler shrinks it). */
        const val SIDE = 1024

        /** Labels below this are not kept (Dart decides per category). */
        const val MIN_CONFIDENCE = 0.5f
    }
}

/**
 * Pure (JVM-tested): which camera took a picture, from its EXIF. Phones
 * write no "front" flag, but a front camera has a short lens (under
 * 4.2 mm; the back main camera is ~4.8–7 mm) that is NOT ultra-wide (35 mm
 * equivalent 22–35; a back ultra-wide is ~13–16). Checked on the iQOO Z9
 * (front 3.82 mm / 28, back 4.84 mm / 26) and Nothing Phone 2a Plus
 * (front 3.61 mm / 29, back 5.56 mm / 24).
 */
internal object CameraSide {
    fun of(focalMm: Double, focal35: Int, lensModel: String?): String {
        val lens = lensModel?.lowercase()
        if (lens != null) {
            if ("front" in lens) return "front"
            if ("back" in lens || "rear" in lens) return "back"
        }
        if (focalMm <= 0.0) return ""
        return if (focalMm < 4.2 && focal35 in 22..35) "front" else "back"
    }
}

/** Pure (JVM-tested): how much text a picture has. */
internal object TextStats {
    data class Result(val chars: Int, val area: Double)

    /**
     * [blocks]: (non-space characters, box area in px²) per text block.
     * area = share of the picture covered by text boxes (at most 1).
     */
    fun of(blocks: List<Pair<Int, Long>>, pictureArea: Long): Result {
        val chars = blocks.sumOf { it.first }
        val covered = blocks.sumOf { it.second }
        val area = if (pictureArea <= 0) 0.0 else (covered.toDouble() / pictureArea).coerceAtMost(1.0)
        return Result(chars, area)
    }
}

/** Pure (JVM-tested): labels as one short text. */
internal object LabelText {
    fun of(labels: List<Pair<String, Float>>): String =
        labels.joinToString(",") { (name, confidence) ->
            "${name.replace(",", " ").replace(":", " ")}:${"%.2f".format(java.util.Locale.ROOT, confidence)}"
        }
}
