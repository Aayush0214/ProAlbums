package com.aayush.proalbums

import org.junit.Assert.assertEquals
import org.junit.Test

class MemoryExportTest {
    @Test
    fun aPictureFadesInAndOut() {
        // 3.2 s picture, 0.4 s fades.
        assertEquals(0f, PictureFade.brightness(0, 3_200_000, 400_000), 1e-6f)
        assertEquals(0.5f, PictureFade.brightness(200_000, 3_200_000, 400_000), 1e-6f)
        assertEquals(1f, PictureFade.brightness(1_600_000, 3_200_000, 400_000), 1e-6f)
        assertEquals(0.5f, PictureFade.brightness(3_000_000, 3_200_000, 400_000), 1e-6f)
        // The first picture: no fade from dark (its first frame = thumbnail).
        assertEquals(1f, PictureFade.brightness(0, 3_200_000, 400_000, fadeIn = false), 1e-6f)
    }

    @Test
    fun waveBarsShowQuietAndLoudParts() {
        val bars = WaveBars(4, 4_000_000)
        bars.add(100_000, 10)
        bars.add(900_000, 30) // bar 0: average 20
        bars.addLevel(1, 60)
        bars.addLevel(3, 40)
        // Bar 2 silent; the others stretched between 20 and 60.
        assertEquals(listOf(0.0, 1.0, 0.0, 0.5), bars.normalized())
    }
}
