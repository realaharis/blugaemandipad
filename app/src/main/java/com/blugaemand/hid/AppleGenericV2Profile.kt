package com.blugaemand.hid

/**
 * Generic Apple-oriented HID profile based on the real SteelSeries Nimbus descriptor used by
 * Apple's WebKit gamepad tests. This intentionally avoids console-specific identity and
 * authentication while matching a controller layout Apple already treats as a modern gamepad.
 *
 * Input report layout (17 bytes, no report ID):
 *   0..3   D-pad Up/Right/Down/Left as 0 or 255
 *   4..11  Buttons 1..8 as 0 or 255
 *   12     AC Home bit + padding
 *   13..16 X/Y/Z/Rz sticks as signed -127..127
 */
object AppleGenericV2Profile : GamepadProfile {
    override val id: String = "apple-generic-v2"
    override val sdpName: String = "Wireless Gamepad"
    override val sdpDescription: String = "Bluetooth Gamepad"
    override val sdpProvider: String = "Blugaemand"
    override val subclass: Byte = 0x08
    override val reportId: Int = 0
    override val requiredAdapterName: String = "Wireless Gamepad"

    const val REPORT_SIZE = 17

    override val descriptor: ByteArray = byteArrayOf(
        0x05.b, 0x01.b, 0x09.b, 0x05.b, 0xA1.b, 0x01.b, 0x09.b, 0x05.b, 0xA1.b, 0x02.b, 0x75.b, 0x08.b, 0x95.b, 0x04.b, 0x15.b, 0x00.b,
        0x26.b, 0xFF.b, 0x00.b, 0x35.b, 0x00.b, 0x46.b, 0xFF.b, 0x00.b, 0x05.b, 0x01.b, 0x09.b, 0x90.b, 0x09.b, 0x92.b, 0x09.b, 0x91.b,
        0x09.b, 0x93.b, 0x81.b, 0x02.b, 0x95.b, 0x08.b, 0x05.b, 0x09.b, 0x19.b, 0x01.b, 0x29.b, 0x08.b, 0x81.b, 0x02.b, 0x15.b, 0x00.b,
        0x25.b, 0x01.b, 0x35.b, 0x00.b, 0x45.b, 0x01.b, 0x75.b, 0x01.b, 0x95.b, 0x01.b, 0x05.b, 0x0C.b, 0x0A.b, 0x23.b, 0x02.b, 0x81.b,
        0x02.b, 0x95.b, 0x07.b, 0x81.b, 0x03.b, 0x15.b, 0x00.b, 0x25.b, 0x01.b, 0x35.b, 0x00.b, 0x45.b, 0x01.b, 0x75.b, 0x01.b, 0x95.b,
        0x04.b, 0x05.b, 0x08.b, 0x1A.b, 0x00.b, 0xFF.b, 0x2A.b, 0x03.b, 0xFF.b, 0x91.b, 0x02.b, 0x75.b, 0x04.b, 0x95.b, 0x01.b, 0x91.b,
        0x01.b, 0x15.b, 0x81.b, 0x25.b, 0x7F.b, 0x35.b, 0x81.b, 0x45.b, 0x7F.b, 0x05.b, 0x01.b, 0x09.b, 0x01.b, 0xA1.b, 0x00.b, 0x75.b,
        0x08.b, 0x95.b, 0x04.b, 0x09.b, 0x30.b, 0x09.b, 0x31.b, 0x09.b, 0x32.b, 0x09.b, 0x35.b, 0x81.b, 0x02.b, 0xC0.b, 0xC0.b, 0xC0.b,
    )

    override fun encode(state: GamepadState): ByteArray {
        val out = ByteArray(REPORT_SIZE)

        val up = state.hat == Hat.NORTH || state.hat == Hat.NORTH_EAST || state.hat == Hat.NORTH_WEST
        val right = state.hat == Hat.EAST || state.hat == Hat.NORTH_EAST || state.hat == Hat.SOUTH_EAST
        val down = state.hat == Hat.SOUTH || state.hat == Hat.SOUTH_EAST || state.hat == Hat.SOUTH_WEST
        val left = state.hat == Hat.WEST || state.hat == Hat.NORTH_WEST || state.hat == Hat.SOUTH_WEST

        out[0] = digitalByte(up)
        out[1] = digitalByte(right)
        out[2] = digitalByte(down)
        out[3] = digitalByte(left)

        // Nimbus-style 8 analog button bytes.
        out[4] = digitalByte(state.isPressed(GamepadButton.SOUTH))
        out[5] = digitalByte(state.isPressed(GamepadButton.EAST))
        out[6] = digitalByte(state.isPressed(GamepadButton.WEST))
        out[7] = digitalByte(state.isPressed(GamepadButton.NORTH))
        out[8] = digitalByte(state.isPressed(GamepadButton.L1))
        out[9] = digitalByte(state.isPressed(GamepadButton.R1))
        out[10] = GamepadState.clampAxis(state.leftTrigger).toByte()
        out[11] = GamepadState.clampAxis(state.rightTrigger).toByte()

        // AC Home. Keep the remaining seven bits as descriptor padding.
        out[12] = if (state.isPressed(GamepadButton.GUIDE)) 0x01 else 0x00

        out[13] = signedAxis(state.leftStickX)
        out[14] = signedAxis(state.leftStickY)
        out[15] = signedAxis(state.rightStickX)
        out[16] = signedAxis(state.rightStickY)

        return out
    }

    override fun handleOutputReport(reportId: Int, data: ByteArray?): Boolean =
        reportId == 0 && data != null && data.isNotEmpty()

    private fun digitalByte(pressed: Boolean): Byte = if (pressed) 0xFF.toByte() else 0x00

    private fun signedAxis(value: Int): Byte =
        (GamepadState.clampAxis(value) - GamepadState.AXIS_CENTER)
            .coerceIn(-127, 127)
            .toByte()
}

private inline val Int.b: Byte get() = this.toByte()
