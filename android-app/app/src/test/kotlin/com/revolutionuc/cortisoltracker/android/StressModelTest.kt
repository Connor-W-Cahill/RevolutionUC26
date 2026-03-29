package com.revolutionuc.cortisoltracker.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StressModelTest {
    @Test
    fun `derived stress uses pulse and breathing formula`() {
        val reading = CortisolReading(userId = "user-1", pulseRate = 80.0, breathingRate = 16.0)
        assertEquals(50.0, reading.stressLevel, 0.001)
    }

    @Test
    fun `stress is clamped to valid range`() {
        val reading = CortisolReading(userId = "user-1", pulseRate = 220.0, breathingRate = 40.0)
        assertTrue(reading.stressLevel in 0.0..100.0)
    }
}
