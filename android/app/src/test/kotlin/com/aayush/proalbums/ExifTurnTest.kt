package com.aayush.proalbums

import org.junit.Assert.assertEquals
import org.junit.Test

class ExifTurnTest {
    @Test
    fun plainPicturesTurnClockwiseAndComeBackAfterFour() {
        assertEquals(6, ExifTurn.clockwise(1)) // upright → 90°
        assertEquals(3, ExifTurn.clockwise(6)) // 90° → 180°
        assertEquals(8, ExifTurn.clockwise(3)) // 180° → 270°
        assertEquals(1, ExifTurn.clockwise(8)) // 270° → upright
    }

    @Test
    fun mirroredPicturesStayMirrored() {
        assertEquals(7, ExifTurn.clockwise(2))
        assertEquals(4, ExifTurn.clockwise(7))
        assertEquals(5, ExifTurn.clockwise(4))
        assertEquals(2, ExifTurn.clockwise(5))
    }

    @Test
    fun unknownCountsAsUpright() {
        assertEquals(6, ExifTurn.clockwise(0))
        assertEquals(6, ExifTurn.clockwise(42))
    }
}
