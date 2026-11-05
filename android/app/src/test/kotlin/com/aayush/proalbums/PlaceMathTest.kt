package com.aayush.proalbums

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaceMathTest {
    @Test
    fun zeroZeroIsNoPlace() {
        assertFalse(PlaceMath.isReal(0.0, 0.0))
    }

    @Test
    fun ujjainIsAPlace() {
        assertTrue(PlaceMath.isReal(23.18, 75.78))
    }

    @Test
    fun outsideTheWorldIsNoPlace() {
        assertFalse(PlaceMath.isReal(95.0, 10.0))
        assertFalse(PlaceMath.isReal(10.0, 190.0))
    }
}
