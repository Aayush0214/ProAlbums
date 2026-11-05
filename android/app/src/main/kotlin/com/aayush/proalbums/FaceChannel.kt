package com.aayush.proalbums

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Intelligent classification > People: who is in each picture. Dart keeps
 * the answers (each picture is looked at once) and groups the faces.
 *  - listImages: every picture (not in the trash): id, modified, taken.
 *  - analyze {ids}: for each picture its faces: where (0–1 of the upright
 *    picture), how big and sharp (to choose covers / featured pictures) and
 *    a 128-number "embedding" (float32 bytes): faces of the same person
 *    have close embeddings.
 *
 * How: Android's own thumbnail at ≤1024 px (upright) → ML Kit finds the
 * faces and their eyes and mouth corners → the face is turned and
 * scaled so those points sit where the model expects them (112×112) →
 * SFace (OpenCV Zoo, Apache-2.0) gives the embedding. Nothing leaves the
 * phone.
 */
class FaceChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()

    // 2 threads: fast enough, and leaves the phone smooth while scanning.
    private val pool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    private val detector: FaceDetector by lazy {
        FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                // Accurate: better eye / mouth points = better embeddings
                // (slower, but each picture is looked at once).
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                .setMinFaceSize(MIN_FACE_SHARE)
                .build(),
        )
    }

    private val environment: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }

    private val session: OrtSession by lazy {
        val model = context.assets.open(MODEL).use { it.readBytes() }
        val options = OrtSession.SessionOptions().apply { setIntraOpNumThreads(1) }
        environment.createSession(model, options)
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listImages" -> background(result) { listImages() }
            "analyze" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                    .mapNotNull { it.toLongOrNull() }
                background(result) { analyze(ids) }
            }
            else -> result.notImplemented()
        }
    }

    private fun uriOf(id: Long) =
        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)

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
            // Not screenshots (faces of other apps' screens, Aayush).
            putString(
                ContentResolver.QUERY_ARG_SQL_SELECTION,
                "${MediaStore.MediaColumns.RELATIVE_PATH} NOT LIKE ?",
            )
            putStringArray(
                ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS,
                arrayOf("%Screenshots%"),
            )
            // Newest first: the pictures people look at come in first.
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

    /** One entry per picture that could be read (no faces = empty list). */
    private fun analyze(ids: List<Long>): List<Map<String, Any>> {
        val jobs = ids.map { id ->
            pool.submit(Callable {
                try {
                    mapOf("id" to id.toString(), "faces" to facesOf(id))
                } catch (error: Throwable) {
                    null
                }
            })
        }
        return jobs.mapNotNull { it.get() }
    }

    private fun facesOf(id: Long): List<Map<String, Any>> {
        val loaded = context.contentResolver.loadThumbnail(uriOf(id), Size(SIDE, SIDE), null)
        // ML Kit and getPixels need a normal (not GPU-only) bitmap.
        val picture = if (loaded.config == Bitmap.Config.ARGB_8888) {
            loaded
        } else {
            loaded.copy(Bitmap.Config.ARGB_8888, false).also { loaded.recycle() }
        }
        try {
            val found = Tasks.await(detector.process(InputImage.fromBitmap(picture, 0)))
            val width = picture.width.toFloat()
            val height = picture.height.toFloat()
            val out = mutableListOf<Map<String, Any>>()
            for (face in found) {
                val box = face.boundingBox
                if (box.width() < MIN_FACE_PX) continue
                // Turned too far sideways: the model cannot tell who it is.
                if (abs(face.headEulerAngleY) > MAX_TURN) continue
                // Eyes and mouth corners only: ML Kit's nose point is the
                // BASE of the nose, the model's is the TIP — using it tilted
                // every face a little.
                val points = listOf(
                    FaceLandmark.LEFT_EYE, FaceLandmark.RIGHT_EYE,
                    FaceLandmark.MOUTH_LEFT, FaceLandmark.MOUTH_RIGHT,
                ).map { face.getLandmark(it)?.position ?: return@map null }
                if (points.any { it == null }) continue
                val p = points.requireNoNulls()
                // As seen in the picture: eye on the left first, then right.
                val eyes = listOf(p[0], p[1]).sortedBy { it.x }
                val mouth = listOf(p[2], p[3]).sortedBy { it.x }
                val source = floatArrayOf(
                    eyes[0].x, eyes[0].y, eyes[1].x, eyes[1].y,
                    mouth[0].x, mouth[0].y, mouth[1].x, mouth[1].y,
                )
                val crop = aligned(picture, FaceAlign.similarity(source, FaceAlign.EYES_AND_MOUTH))
                val embedding = embed(crop)
                val sharpness = sharpness(crop)
                crop.recycle()
                out.add(
                    mapOf(
                        "left" to (box.left / width).coerceIn(0f, 1f).toDouble(),
                        "top" to (box.top / height).coerceIn(0f, 1f).toDouble(),
                        "right" to (box.right / width).coerceIn(0f, 1f).toDouble(),
                        "bottom" to (box.bottom / height).coerceIn(0f, 1f).toDouble(),
                        // Face width as a share of the picture's short side.
                        "size" to (box.width() / minOf(width, height)).toDouble(),
                        "sharpness" to sharpness,
                        "embedding" to bytesOf(embedding),
                    ),
                )
            }
            return out
        } finally {
            picture.recycle()
        }
    }

    /** The face turned and scaled into the model's 112×112 square. */
    private fun aligned(picture: Bitmap, t: FloatArray): Bitmap {
        val crop = Bitmap.createBitmap(INPUT, INPUT, Bitmap.Config.ARGB_8888)
        val matrix = Matrix().apply {
            setValues(floatArrayOf(t[0], -t[1], t[2], t[1], t[0], t[3], 0f, 0f, 1f))
        }
        Canvas(crop).drawBitmap(picture, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
        return crop
    }

    /** SFace: RGB, 0–255, channels first → 128 numbers, length 1. */
    private fun embed(crop: Bitmap): FloatArray {
        val pixels = IntArray(INPUT * INPUT)
        crop.getPixels(pixels, 0, INPUT, 0, 0, INPUT, INPUT)
        val plane = INPUT * INPUT
        val input = FloatBuffer.allocate(3 * plane)
        for (i in 0 until plane) {
            val c = pixels[i]
            input.put(i, Color.red(c).toFloat())
            input.put(plane + i, Color.green(c).toFloat())
            input.put(2 * plane + i, Color.blue(c).toFloat())
        }
        val shape = longArrayOf(1, 3, INPUT.toLong(), INPUT.toLong())
        OnnxTensor.createTensor(environment, input, shape).use { tensor ->
            session.run(mapOf(session.inputNames.first() to tensor)).use { output ->
                @Suppress("UNCHECKED_CAST")
                val vector = (output[0].value as Array<FloatArray>)[0]
                return FaceAlign.normalized(vector)
            }
        }
    }

    private fun sharpness(crop: Bitmap): Double {
        val pixels = IntArray(INPUT * INPUT)
        crop.getPixels(pixels, 0, INPUT, 0, 0, INPUT, INPUT)
        val grey = IntArray(pixels.size) {
            val c = pixels[it]
            (Color.red(c) * 299 + Color.green(c) * 587 + Color.blue(c) * 114) / 1000
        }
        return Sharpness.of(grey, INPUT)
    }

    private fun bytesOf(vector: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(vector.size * 4).order(ByteOrder.LITTLE_ENDIAN)
        buffer.asFloatBuffer().put(vector)
        return buffer.array()
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
        const val CHANNEL = "com.aayush.proalbums/faces"
        const val MODEL = "models/face_recognition_sface_2021dec_int8.onnx"

        /** Long edge of the picture the faces are looked for in. */
        const val SIDE = 1024

        /** SFace input side. */
        const val INPUT = 112

        /** Faces smaller than this (px in the 1024 picture) are skipped. */
        const val MIN_FACE_PX = 40

        /** ML Kit: smallest face as a share of the picture width. */
        const val MIN_FACE_SHARE = 0.05f

        /** Head turned more than this (degrees) is skipped. */
        const val MAX_TURN = 40f
    }
}

/** Pure maths (JVM-tested). */
internal object FaceAlign {
    /**
     * Where the 5 points (eye left, eye right, nose, mouth left, mouth
     * right, as seen in the picture) sit in the 112×112 model input
     * (the usual ArcFace / SFace layout).
     */
    val TEMPLATE = floatArrayOf(
        38.2946f, 51.6963f, 73.5318f, 51.5014f, 56.0252f, 71.7366f,
        41.5493f, 92.3655f, 70.7299f, 92.2041f,
    )

    /** [TEMPLATE] without the nose: eye left, eye right, mouth left, right. */
    val EYES_AND_MOUTH = floatArrayOf(
        38.2946f, 51.6963f, 73.5318f, 51.5014f,
        41.5493f, 92.3655f, 70.7299f, 92.2041f,
    )

    /**
     * The turn + scale + move that best puts [source] points on [target]
     * points (least squares; x,y pairs). Returns (a, b, tx, ty):
     * x' = a·x − b·y + tx, y' = b·x + a·y + ty.
     */
    fun similarity(source: FloatArray, target: FloatArray): FloatArray {
        val n = source.size / 2
        var sx = 0.0; var sy = 0.0; var tx = 0.0; var ty = 0.0
        for (i in 0 until n) {
            sx += source[2 * i]; sy += source[2 * i + 1]
            tx += target[2 * i]; ty += target[2 * i + 1]
        }
        sx /= n; sy /= n; tx /= n; ty /= n
        var dot = 0.0; var cross = 0.0; var norm = 0.0
        for (i in 0 until n) {
            val x = source[2 * i] - sx
            val y = source[2 * i + 1] - sy
            val u = target[2 * i] - tx
            val v = target[2 * i + 1] - ty
            dot += x * u + y * v
            cross += x * v - y * u
            norm += x * x + y * y
        }
        if (norm == 0.0) return floatArrayOf(1f, 0f, 0f, 0f)
        val a = dot / norm
        val b = cross / norm
        return floatArrayOf(
            a.toFloat(),
            b.toFloat(),
            (tx - (a * sx - b * sy)).toFloat(),
            (ty - (b * sx + a * sy)).toFloat(),
        )
    }

    /** Length 1 (so a dot product is the cosine). */
    fun normalized(vector: FloatArray): FloatArray {
        var sum = 0.0
        for (v in vector) sum += v.toDouble() * v
        val length = sqrt(sum)
        if (length == 0.0) return vector
        return FloatArray(vector.size) { (vector[it] / length).toFloat() }
    }
}
