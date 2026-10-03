package com.blugaemand.hid

import org.junit.Assert.assertEquals
import org.junit.Test

class AppleGenericV2ProfileTest {
    @Test
    fun neutralReportIsSeventeenBytes() {
        val report = AppleGenericV2Profile.encode(GamepadState.NEUTRAL)
        assertEquals(17, report.size)
        assertEquals(0, AppleGenericV2Profile.reportId)
        assertEquals(0, report[0].toInt() and 0xFF)
        assertEquals(0, report[12].toInt() and 0xFF)
        assertEquals(0, report[13].toInt())
        assertEquals(0, report[14].toInt())
        assertEquals(0, report[15].toInt())
        assertEquals(0, report[16].toInt())
    }

    @Test
    fun dpadAndButtonsMatchNimbusLayout() {
        val state = GamepadState(
            hat = Hat.NORTH_EAST,
            leftTrigger = 255,
            buttons = GamepadButton.SOUTH.bit or GamepadButton.GUIDE.bit,
        )
        val report = AppleGenericV2Profile.encode(state)

        assertEquals(255, report[0].toInt() and 0xFF)
        assertEquals(255, report[1].toInt() and 0xFF)
        assertEquals(0, report[2].toInt() and 0xFF)
        assertEquals(0, report[3].toInt() and 0xFF)
        assertEquals(255, report[4].toInt() and 0xFF)
        assertEquals(255, report[10].toInt() and 0xFF)
        assertEquals(1, report[12].toInt() and 0x01)
    }

    @Test
    fun sticksUseSignedRange() {
        val report = AppleGenericV2Profile.encode(
            GamepadState(
                leftStickX = 0,
                leftStickY = 255,
                rightStickX = 128,
                rightStickY = 129,
            ),
        )

        assertEquals(-127, report[13].toInt())
        assertEquals(127, report[14].toInt())
        assertEquals(0, report[15].toInt())
        assertEquals(1, report[16].toInt())
    }
}
