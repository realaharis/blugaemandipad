package com.blugaemand.hid

/**
 * Apple-compatible classic Bluetooth HID gamepad profile.
 *
 * iPadOS/iOS are stricter than desktop HID hosts about how a game controller describes itself.
 * This layout follows Apple's documented gamepad usages instead of the generic desktop profile:
 *
 * - X/Y/Z/Rz for the two sticks
 * - Button 7/8 as analogue L2/R2
 * - four dedicated D-pad usages instead of a hat switch
 * - Buttons 1..6 and 9..10 for face/shoulder/stick buttons
 * - Consumer AC Home / AC Properties / AC Exit for Guide / Back / Start
 *
 * Input reports have no report ID and are exactly 8 bytes. The descriptor also exposes the
 * four-bit LED output field Apple documents; output reports are accepted and intentionally ignored.
 */
object AppleHidProfile : GamepadProfile {

    override val id: String = "apple-hid-gamepad"
    override val sdpName: String = "Blugaemand Gamepad"
    override val sdpDescription: String = "Bluetooth Game Controller"
    override val sdpProvider: String = "Blugaemand"

    // HID device subclass byte for a gamepad in the SDP record.
    override val subclass: Byte = 0x08

    // Apple's sample descriptor does not use Report IDs.
    override val reportId: Int = 0

    const val REPORT_SIZE = 8

    override val descriptor: ByteArray = byteArrayOf(
        0x05.b, 0x01.b,             // Usage Page (Generic Desktop)
        0x09.b, 0x05.b,             // Usage (Game Pad)
        0xA1.b, 0x01.b,             // Collection (Application)
        0x09.b, 0x05.b,             //   Usage (Game Pad)
        0xA1.b, 0x02.b,             //   Collection (Logical)

        // Left/right joysticks: signed -127..127, one byte each.
        0x15.b, 0x81.b,             //     Logical Minimum (-127)
        0x25.b, 0x7F.b,             //     Logical Maximum (127)
        0x35.b, 0x81.b,             //     Physical Minimum (-127)
        0x45.b, 0x7F.b,             //     Physical Maximum (127)
        0x05.b, 0x01.b,             //     Usage Page (Generic Desktop)
        0x09.b, 0x01.b,             //     Usage (Pointer)
        0xA1.b, 0x00.b,             //     Collection (Physical)
        0x75.b, 0x08.b,             //       Report Size (8)
        0x95.b, 0x04.b,             //       Report Count (4)
        0x09.b, 0x30.b,             //       Usage (X)
        0x09.b, 0x31.b,             //       Usage (Y)
        0x09.b, 0x32.b,             //       Usage (Z)
        0x09.b, 0x35.b,             //       Usage (Rz)
        0x81.b, 0x02.b,             //       Input (Data,Var,Abs)
        0xC0.b,                     //     End Collection

        // L2 / R2: Apple maps analogue Button 7 and Button 8 to the two triggers.
        0x75.b, 0x08.b,             //     Report Size (8)
        0x95.b, 0x02.b,             //     Report Count (2)
        0x15.b, 0x00.b,             //     Logical Minimum (0)
        0x26.b, 0xFF.b, 0x00.b,     //     Logical Maximum (255)
        0x35.b, 0x00.b,             //     Physical Minimum (0)
        0x46.b, 0xFF.b, 0x00.b,     //     Physical Maximum (255)
        0x05.b, 0x09.b,             //     Usage Page (Button)
        0x09.b, 0x07.b,             //     Usage (Button 7 / L2)
        0x09.b, 0x08.b,             //     Usage (Button 8 / R2)
        0x81.b, 0x02.b,             //     Input (Data,Var,Abs)

        // D-pad: Apple expects four Generic Desktop directional usages.
        0x75.b, 0x01.b,             //     Report Size (1)
        0x95.b, 0x04.b,             //     Report Count (4)
        0x15.b, 0x00.b,             //     Logical Minimum (0)
        0x25.b, 0x01.b,             //     Logical Maximum (1)
        0x35.b, 0x00.b,             //     Physical Minimum (0)
        0x45.b, 0x01.b,             //     Physical Maximum (1)
        0x05.b, 0x01.b,             //     Usage Page (Generic Desktop)
        0x09.b, 0x90.b,             //     Usage (D-pad Up)
        0x09.b, 0x92.b,             //     Usage (D-pad Right)
        0x09.b, 0x91.b,             //     Usage (D-pad Down)
        0x09.b, 0x93.b,             //     Usage (D-pad Left)
        0x81.b, 0x02.b,             //     Input (Data,Var,Abs)

        // A, B, X, Y, L1, R1.
        0x95.b, 0x06.b,             //     Report Count (6)
        0x05.b, 0x09.b,             //     Usage Page (Button)
        0x19.b, 0x01.b,             //     Usage Minimum (Button 1)
        0x29.b, 0x06.b,             //     Usage Maximum (Button 6)
        0x81.b, 0x02.b,             //     Input (Data,Var,Abs)

        // L3 / R3.
        0x95.b, 0x02.b,             //     Report Count (2)
        0x09.b, 0x09.b,             //     Usage (Button 9)
        0x09.b, 0x0A.b,             //     Usage (Button 10)
        0x81.b, 0x02.b,             //     Input (Data,Var,Abs)

        // Guide / Back / Start mapped to Apple's Home / Options / Menu functions.
        0x95.b, 0x03.b,             //     Report Count (3)
        0x05.b, 0x0C.b,             //     Usage Page (Consumer)
        0x0A.b, 0x23.b, 0x02.b,     //     Usage (AC Home)
        0x0A.b, 0x09.b, 0x02.b,     //     Usage (AC Properties)
        0x0A.b, 0x04.b, 0x02.b,     //     Usage (AC Exit)
        0x81.b, 0x02.b,             //     Input (Data,Var,Abs)

        // One pad bit completes the two packed input bytes after the triggers.
        0x75.b, 0x01.b,             //     Report Size (1)
        0x95.b, 0x01.b,             //     Report Count (1)
        0x81.b, 0x03.b,             //     Input (Constant)

        // Four controller LEDs plus four output padding bits.
        0x05.b, 0x08.b,             //     Usage Page (LEDs)
        0x75.b, 0x01.b,             //     Report Size (1)
        0x95.b, 0x04.b,             //     Report Count (4)
        0x1A.b, 0x00.b, 0xFF.b,     //     Usage Minimum (0xFF00)
        0x2A.b, 0x03.b, 0xFF.b,     //     Usage Maximum (0xFF03)
        0x91.b, 0x02.b,             //     Output (Data,Var,Abs)
        0x95.b, 0x04.b,             //     Report Count (4)
        0x91.b, 0x01.b,             //     Output (Constant,Array,Abs)

        0xC0.b,                     //   End Collection (Logical)
        0xC0.b,                     // End Collection (Application)
    )

    override fun encode(state: GamepadState): ByteArray {
        val packed = packButtons(state)
        return byteArrayOf(
            signedStick(state.leftStickX),
            signedStick(state.leftStickY),
            signedStick(state.rightStickX),
            signedStick(state.rightStickY),
            GamepadState.clampAxis(state.leftTrigger).toByte(),
            GamepadState.clampAxis(state.rightTrigger).toByte(),
            (packed and 0xFF).toByte(),
            ((packed ushr 8) and 0xFF).toByte(),
        )
    }

    override fun handleOutputReport(reportId: Int, data: ByteArray?): Boolean =
        reportId == 0 && data != null

    private fun signedStick(value: Int): Byte =
        (GamepadState.clampAxis(value) - GamepadState.AXIS_CENTER)
            .coerceIn(-127, 127)
            .toByte()

    private fun packButtons(state: GamepadState): Int {
        var bits = dpadBits(state.hat)

        fun set(bit: Int, pressed: Boolean) {
            if (pressed) bits = bits or (1 shl bit)
        }

        set(4, state.isPressed(GamepadButton.SOUTH)) // A / Button 1
        set(5, state.isPressed(GamepadButton.EAST))  // B / Button 2
        set(6, state.isPressed(GamepadButton.WEST))  // X / Button 3
        set(7, state.isPressed(GamepadButton.NORTH)) // Y / Button 4
        set(8, state.isPressed(GamepadButton.L1))    // Button 5
        set(9, state.isPressed(GamepadButton.R1))    // Button 6
        set(10, state.isPressed(GamepadButton.L3))   // Button 9
        set(11, state.isPressed(GamepadButton.R3))   // Button 10
        set(12, state.isPressed(GamepadButton.GUIDE))
        set(13, state.isPressed(GamepadButton.BACK))
        set(14, state.isPressed(GamepadButton.START))

        return bits
    }

    private fun dpadBits(hat: Hat): Int = when (hat) {
        Hat.NORTH -> 0b0001
        Hat.NORTH_EAST -> 0b0011
        Hat.EAST -> 0b0010
        Hat.SOUTH_EAST -> 0b0110
        Hat.SOUTH -> 0b0100
        Hat.SOUTH_WEST -> 0b1100
        Hat.WEST -> 0b1000
        Hat.NORTH_WEST -> 0b1001
        Hat.CENTER -> 0
    }
}

private inline val Int.b: Byte get() = this.toByte()
