package com.aayush.proalbums

import org.junit.Assert.assertEquals
import org.junit.Test

class LabelTextTest {
    @Test
    fun labelsBecomeOneShortText() {
        assertEquals(
            "Car:0.83,Fast food:0.71",
            LabelText.of(listOf("Car" to 0.8312f, "Fast food" to 0.71f)),
        )
    }

    @Test
    fun noLabelsIsEmpty() {
        assertEquals("", LabelText.of(emptyList()))
    }

    @Test
    fun separatorsInsideANameAreRemoved() {
        assertEquals("a b:0.50", LabelText.of(listOf("a,b" to 0.5f)))
    }

    @Test
    fun frontCamerasHaveAShortButNotUltraWideLens() {
        assertEquals("front", CameraSide.of(3.82, 28, null)) // iQOO Z9 front
        assertEquals("back", CameraSide.of(4.84, 26, null)) // iQOO Z9 back
        assertEquals("front", CameraSide.of(3.61, 29, null)) // Nothing front
        assertEquals("back", CameraSide.of(5.56, 24, null)) // Nothing back
        assertEquals("back", CameraSide.of(2.15, 14, null)) // ultra-wide
        assertEquals("back", CameraSide.of(12.19, 80, null)) // telephoto
    }

    @Test
    fun noCameraDataIsUnknown() {
        assertEquals("", CameraSide.of(0.0, 0, null))
    }

    @Test
    fun aLensNameWins() {
        assertEquals("front", CameraSide.of(5.0, 26, "Front camera"))
    }

    @Test
    fun textStatsCountCharactersAndCoveredShare() {
        val stats = TextStats.of(listOf(10 to 200L, 5 to 300L), pictureArea = 1000)
        assertEquals(15, stats.chars)
        assertEquals(0.5, stats.area, 1e-9)
        assertEquals(1.0, TextStats.of(listOf(1 to 5000L), 1000).area, 1e-9)
        assertEquals(0.0, TextStats.of(emptyList(), 1000).area, 1e-9)
    }

    @Test
    fun searchTextIsLowerCaseOneSpaceApart() {
        assertEquals("my definition of wealth", SearchText.of("My Definition\nOf  Wealth "))
        assertEquals("", SearchText.of("  \n "))
    }

    @Test
    fun searchTextIsCut() {
        assertEquals(SearchText.MAX, SearchText.of("a ".repeat(4000)).length)
    }
}
