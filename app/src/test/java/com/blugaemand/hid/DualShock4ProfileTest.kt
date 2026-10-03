package com.blugaemand.hid

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.zip.CRC32

class DualShock4ProfileTest {
    @Test
    fun neutralBluetoothReportHasExpectedShapeAndCrc() {
        val body = DualShock4Profile.encode(GamepadState.NEUTRAL)
        assertEquals(77, body.size)
        assertEquals(0xC0, body[0].toInt() and 0xFF)
        assertEquals(128, body[2].toInt() and 0xFF)
        assertEquals(8, body[6].toInt() and 0x0F)

        val crc = CRC32()
        crc.update(0xA1)
        crc.update(0x11)
        crc.update(body, 0, body.size - 4)
        val p = body.size - 4
        val stored =
            (body[p].toLong() and 0xFF) or
            ((body[p + 1].toLong() and 0xFF) shl 8) or
            ((body[p + 2].toLong() and 0xFF) shl 16) or
            ((body[p + 3].toLong() and 0xFF) shl 24)
        assertEquals(crc.value, stored)
    }

    @Test
    fun mapsFaceButtonsAndTriggersLikeDs4() {
        val state = GamepadState(
            hat = Hat.EAST,
            leftTrigger = 255,
            buttons = GamepadButton.SOUTH.bit or GamepadButton.NORTH.bit,
        )
        val body = DualShock4Profile.encode(state)
        assertEquals(2, body[6].toInt() and 0x0F)
        assertTrue((body[6].toInt() and 0x20) != 0)
        assertTrue((body[6].toInt() and 0x80) != 0)
        assertTrue((body[7].toInt() and 0x04) != 0)
        assertEquals(255, body[9].toInt() and 0xFF)
    }
}
