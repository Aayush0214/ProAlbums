package com.aayush.proalbums

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CleanupMathTest {
    @Test
    fun flatPictureHasEmptyHashAndNoSharpness() {
        assertEquals(0L, DHash.of(IntArray(72) { 128 }))
        assertEquals(0.0, Sharpness.of(IntArray(64 * 64) { 128 }, 64), 1e-9)
    }

    @Test
    fun darkeningToTheRightSetsEveryBit() {
        // Each row goes from bright to dark: every "x brighter than x+1" is true.
        val grey = IntArray(72) { i -> 255 - (i % 9) * 20 }
        assertEquals(-1L, DHash.of(grey)) // all 64 bits set
    }

    @Test
    fun aSlightlyBrighterCopyKeepsTheSameHash() {
        val grey = IntArray(72) { i -> (i * 37) % 200 }
        val brighter = IntArray(72) { grey[it] + 20 }
        assertEquals(DHash.of(grey), DHash.of(brighter))
    }

    @Test
    fun sharpEdgesScoreHigherThanBlur() {
        val sharp = IntArray(64 * 64) { i -> if ((i % 64) / 8 % 2 == 0) 0 else 255 }
        val blurred = IntArray(64 * 64) { i -> (i % 64) * 4 }
        assertTrue(Sharpness.of(sharp, 64) > Sharpness.of(blurred, 64) * 10)
    }
}
