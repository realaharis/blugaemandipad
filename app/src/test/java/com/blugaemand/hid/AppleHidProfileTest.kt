package com.blugaemand.hid

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppleHidProfileTest {

    @Test
    fun neutralReportMatchesAppleLayout() {
        assertArrayEquals(
            byteArrayOf(0, 0, 0, 0, 0, 0, 0, 0),
            AppleHidProfile.encode(GamepadState.NEUTRAL),
        )
    }

    @Test
    fun sticksUseSignedAppleRange() {
        val report = AppleHidProfile.encode(
            GamepadState(
                leftStickX = 0,
                leftStickY = 255,
                rightStickX = 128,
                rightStickY = 129,
            ),
        )

        assertEquals(-127, report[0].toInt())
        assertEquals(127, report[1].toInt())
        assertEquals(0, report[2].toInt())
        assertEquals(1, report[3].toInt())
    }

    @Test
    fun dpadAndButtonsPackIntoExpectedBits() {
        val state = GamepadState(
            hat = Hat.NORTH_EAST,
            buttons = GamepadButton.SOUTH.bit or
                GamepadButton.WEST.bit or
                GamepadButton.L1.bit or
                GamepadButton.L3.bit or
                GamepadButton.GUIDE.bit or
                GamepadButton.START.bit,
        )

        val report = AppleHidProfile.encode(state)
        val packed = (report[6].toInt() and 0xFF) or ((report[7].toInt() and 0xFF) shl 8)

        assertEquals(0b0011, packed and 0x0F)
        assertTrue(packed and (1 shl 4) != 0)   // A
        assertTrue(packed and (1 shl 6) != 0)   // X
        assertTrue(packed and (1 shl 8) != 0)   // L1
        assertTrue(packed and (1 shl 10) != 0)  // L3
        assertTrue(packed and (1 shl 12) != 0)  // Home
        assertTrue(packed and (1 shl 14) != 0)  // Menu
    }

    @Test
    fun appleProfileHasNoReportIdAndEightByteInputReport() {
        assertEquals(0, AppleHidProfile.reportId)
        assertEquals(AppleHidProfile.REPORT_SIZE, AppleHidProfile.encode(GamepadState.NEUTRAL).size)
    }
}
