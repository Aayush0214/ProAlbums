package com.aayush.proalbums

import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class FaceAlignTest {
    private fun apply(t: FloatArray, x: Float, y: Float) =
        Pair(t[0] * x - t[1] * y + t[2], t[1] * x + t[0] * y + t[3])

    @Test
    fun theTemplateMapsOntoItself() {
        val t = FaceAlign.similarity(FaceAlign.TEMPLATE, FaceAlign.TEMPLATE)
        assertEquals(1f, t[0], 1e-4f)
        assertEquals(0f, t[1], 1e-4f)
        assertEquals(0f, t[2], 1e-3f)
        assertEquals(0f, t[3], 1e-3f)
    }

    @Test
    fun aTurnedBiggerMovedFaceComesBackToTheTemplate() {
        // Make a face: the template turned 30°, 4× bigger, moved.
        val angle = Math.toRadians(30.0)
        val scale = 4.0
        val face = FloatArray(10)
        for (i in 0 until 5) {
            val x = FaceAlign.TEMPLATE[2 * i].toDouble()
            val y = FaceAlign.TEMPLATE[2 * i + 1].toDouble()
            face[2 * i] = (scale * (x * cos(angle) - y * sin(angle)) + 300).toFloat()
            face[2 * i + 1] = (scale * (x * sin(angle) + y * cos(angle)) + 120).toFloat()
        }
        val t = FaceAlign.similarity(face, FaceAlign.TEMPLATE)
        for (i in 0 until 5) {
            val (x, y) = apply(t, face[2 * i], face[2 * i + 1])
            assertEquals(FaceAlign.TEMPLATE[2 * i], x, 1e-2f)
            assertEquals(FaceAlign.TEMPLATE[2 * i + 1], y, 1e-2f)
        }
    }

    @Test
    fun normalizedHasLengthOne() {
        val v = FaceAlign.normalized(floatArrayOf(3f, 4f))
        assertEquals(0.6f, v[0], 1e-6f)
        assertEquals(0.8f, v[1], 1e-6f)
    }
}
