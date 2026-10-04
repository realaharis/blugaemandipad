package com.blugaemand.hid

import java.util.zip.CRC32

/** Experimental DS4 gameplay protocol. Console authentication and audio are not implemented. */
class DualShock4Profile : GamepadProfile {
    override val id = "ds4-begonia-v2"
    override val sdpName = "Wireless Controller"
    override val sdpDescription = "Wireless Controller"
    override val sdpProvider = "Sony Interactive Entertainment"
    override val subclass: Byte = 0x08
    override val requiredAdapterName = "Wireless Controller"
    @Volatile private var extended = false
    override val reportId: Int get() = if (extended) 0x11 else 0x01
    private var sequence = 0
    @Volatile var motion = Ds4Motion()
    @Volatile var touch = Ds4Touch()
    @Volatile var batteryPercent = 100
    @Volatile var charging = false
    @Volatile var output = Ds4Output()
        private set
    private var lastOutput = ByteArray(77)

    // 115 bytes: avoids the SDP attr_len=454/max_list_len=246 failure in the begonia log.
    // Preserve gameplay usages and packet layout, omit unsupported audio/vendor/auth reports.
    override val descriptor = hex(
        "05 01 09 05 A1 01 85 01 09 30 09 31 09 32 09 35 " +
        "15 00 26 FF 00 75 08 95 04 81 02 " +
        "09 39 25 07 75 04 95 01 81 42 " +
        "05 09 19 01 29 0E 25 01 75 01 95 0E 81 02 " +
        "75 06 95 01 81 01 " +
        "05 01 09 33 09 34 26 FF 00 75 08 95 02 81 02 " +
        "06 04 FF 85 02 09 24 95 24 B1 02 " +
        "85 05 09 26 95 28 B1 02 " +
        "85 A3 09 25 95 30 B1 02 " +
        "06 00 FF 85 11 09 20 95 4D 81 02 09 21 91 02 C0"
    )

    @Synchronized fun resetSession() {
        extended = false; sequence = 0; touch = Ds4Touch(); output = Ds4Output()
        lastOutput = ByteArray(77)
    }
    override fun encode(state: GamepadState): ByteArray = inputReport(reportId, state)!!

    @Synchronized fun inputReport(id: Int, state: GamepadState, nowNanos: Long = System.nanoTime()): ByteArray? {
        if (id != 0x01 && id != 0x11) return null
        if (id == 0x11) extended = true
        val out = ByteArray(if (id == 0x11) 77 else 9)
        val p = if (id == 0x11) 2 else 0
        if (id == 0x11) out[0] = 0xC0.toByte()
        out[p] = GamepadState.clampAxis(state.leftStickX).toByte()
        out[p+1] = GamepadState.clampAxis(state.leftStickY).toByte()
        out[p+2] = GamepadState.clampAxis(state.rightStickX).toByte()
        out[p+3] = GamepadState.clampAxis(state.rightStickY).toByte()
        var b0 = state.hat.value and 15
        // Existing layouts use Linux aliases: NORTH is X/Square, WEST is Y/Triangle.
        listOf(GamepadButton.NORTH, GamepadButton.SOUTH, GamepadButton.EAST, GamepadButton.WEST)
            .forEachIndexed { i, b -> if (state.isPressed(b)) b0 = b0 or (0x10 shl i) }
        out[p+4] = b0.toByte()
        var b1 = 0
        listOf(GamepadButton.L1, GamepadButton.R1, GamepadButton.L2, GamepadButton.R2,
            GamepadButton.BACK, GamepadButton.START, GamepadButton.L3, GamepadButton.R3)
            .forEachIndexed { i, b -> if (state.isPressed(b)) b1 = b1 or (1 shl i) }
        if (state.leftTrigger > 31) b1 = b1 or 4
        if (state.rightTrigger > 31) b1 = b1 or 8
        out[p+5] = b1.toByte()
        val t = touch
        out[p+6] = ((if (state.isPressed(GamepadButton.GUIDE)) 1 else 0) or
            (if (t.clicked) 2 else 0) or ((sequence and 63) shl 2)).toByte()
        out[p+7] = GamepadState.clampAxis(state.leftTrigger).toByte()
        out[p+8] = GamepadState.clampAxis(state.rightTrigger).toByte()
        if (id == 0x11) {
            put16(out, 11, ((nowNanos / 1000L * 3L / 16L) and 65535).toInt())
            val m = motion
            listOf(m.gx,m.gy,m.gz,m.ax,m.ay,m.az).forEachIndexed { i,v -> put16(out,14+i*2,v.coerceIn(-32768,32767)) }
            out[31] = ((batteryPercent.coerceIn(0,100)/10) or (if (charging) 0x10 else 0)).toByte()
            out[34] = 1; out[35] = sequence.toByte()
            writeTouch(out,36,t.first); writeTouch(out,40,t.second)
            writeCrc(0xA1,id,out)
        }
        sequence = (sequence+1) and 255
        return out
    }

    @Synchronized override fun featureReport(reportId: Int): ByteArray? = when (reportId and 255) {
        0x02,0x05 -> {
            extended = true
            val bt = (reportId and 255) == 5
            ByteArray(if (bt) 40 else 36).also { b ->
                // Ideal virtual sensors: 16 counts/degree/s, 8192 counts/g, zero bias.
                val gyro = if (bt) listOf(16000,16000,16000,-16000,-16000,-16000)
                    else listOf(16000,-16000,16000,-16000,16000,-16000)
                gyro.forEachIndexed { i,v -> put16(b,6+i*2,v) }
                put16(b,18,1000); put16(b,20,1000)
                listOf(8192,-8192,8192,-8192,8192,-8192).forEachIndexed { i,v -> put16(b,22+i*2,v) }
                if (bt) writeCrc(0xA3,5,b)
            }
        }
        0xA3 -> ByteArray(48).also {
            // Virtual firmware metadata, not extracted Sony firmware. A3 does not carry CRC.
            "Oct 03 2026".toByteArray(Charsets.US_ASCII).copyInto(it,0)
            "00:00:00".toByteArray(Charsets.US_ASCII).copyInto(it,16)
            put16(it,34,0x0100); put16(it,40,0x0100)
        }
        else -> null
    }
    @Synchronized fun outputReport(id: Int): ByteArray? =
        if (id == 17) lastOutput.copyOf().also { writeCrc(0xA2,id,it) } else null

    @Synchronized override fun handleOutputReport(reportId: Int, data: ByteArray?): Boolean {
        if (reportId != 17 || data == null || data.size != 77) return false
        val hw = data[0].toInt() and 255
        if (hw and 0x40 != 0 && !validCrc(0xA2,reportId,data)) return false
        lastOutput = data.copyOf()
        if (hw and 0x80 != 0) {
            extended = true
            val flags = data[2].toInt() and 255
            fun u(i: Int) = data[i].toInt() and 255
            output = output.copy(
                smallMotor = if (flags and 1 != 0) u(5) else output.smallMotor,
                largeMotor = if (flags and 1 != 0) u(6) else output.largeMotor,
                red = if (flags and 2 != 0) u(7) else output.red,
                green = if (flags and 2 != 0) u(8) else output.green,
                blue = if (flags and 2 != 0) u(9) else output.blue,
                flashOn = if (flags and 4 != 0) u(10) else output.flashOn,
                flashOff = if (flags and 4 != 0) u(11) else output.flashOff)
        }
        return true
    }
    companion object {
        private fun hex(s: String) = s.split(' ').map { it.toInt(16).toByte() }.toByteArray()
        private fun put16(b: ByteArray,p: Int,v: Int) { b[p]=v.toByte(); b[p+1]=(v shr 8).toByte() }
        private fun writeTouch(b: ByteArray,p: Int,t: Ds4Contact?) {
            if (t == null) { b[p]=0x80.toByte(); return }
            val x=t.x.coerceIn(0,1919); val y=t.y.coerceIn(0,941)
            b[p]=(t.id and 127).toByte(); b[p+1]=x.toByte()
            b[p+2]=((x shr 8) or ((y and 15) shl 4)).toByte(); b[p+3]=(y shr 4).toByte()
        }
        fun crc(seed: Int,id: Int,b: ByteArray): Long = CRC32().apply {
            update(seed); update(id); update(b,0,b.size-4)
        }.value
        fun writeCrc(seed: Int,id: Int,b: ByteArray) {
            val c=crc(seed,id,b)
            for (i in 0..3) b[b.size-4+i]=(c ushr (i*8)).toByte()
        }
        fun validCrc(seed: Int,id: Int,b: ByteArray): Boolean {
            if (b.size<4) return false
            val c=crc(seed,id,b)
            return (0..3).all { b[b.size-4+it] == (c ushr (it*8)).toByte() }
        }
        // HIDP BufferSize includes Report ID, which Android inserts separately.
        fun boundedReply(b: ByteArray,bufferSize: Int): ByteArray =
            if (bufferSize>0) b.copyOfRange(0,minOf(b.size,bufferSize-1)) else b
    }
}
data class Ds4Motion(val gx: Int=0,val gy: Int=0,val gz: Int=0,val ax: Int=0,val ay: Int=0,val az: Int=8192)
data class Ds4Contact(val id: Int,val x: Int,val y: Int)
data class Ds4Touch(val first: Ds4Contact?=null,val second: Ds4Contact?=null,val clicked: Boolean=false)
data class Ds4Output(val smallMotor: Int=0,val largeMotor: Int=0,val red: Int=0,val green: Int=0,val blue: Int=64,val flashOn: Int=0,val flashOff: Int=0)
