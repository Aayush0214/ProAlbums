package com.aayush.proalbums

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.TimeZone

class ExifDateTest {
    private val india = TimeZone.getTimeZone("Asia/Kolkata")

    @Test
    fun readsTheDateInThePhonesZone() {
        // 2021-02-09 18:42:07 IST = 13:12:07 UTC.
        assertEquals(1612876327000L, ExifDate.parse("2021:02:09 18:42:07", null, india))
    }

    @Test
    fun anOffsetWins() {
        assertEquals(1612876327000L, ExifDate.parse("2021:02:09 13:12:07", "+00:00", india))
    }

    @Test
    fun emptyOrZeroIsNoDate() {
        assertNull(ExifDate.parse(null, null, india))
        assertNull(ExifDate.parse("", null, india))
        assertNull(ExifDate.parse("0000:00:00 00:00:00", null, india))
        assertNull(ExifDate.parse("garbage", null, india))
    }
}
