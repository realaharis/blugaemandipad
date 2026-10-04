package com.blugaemand.hid

import org.junit.Assert.*
import org.junit.Test

class DualShock4ProfileTest {
    private fun u(b: ByteArray, i: Int) = b[i].toInt() and 255
    private fun signed(b: ByteArray, i: Int) = (u(b,i) or (u(b,i+1) shl 8)).toShort().toInt()
    @Test fun compactDescriptorMatchesPacketLengths() {
        val d = DualShock4Profile().descriptor
        assertTrue(d.size + 16 < 246)
        var i=0; var size=0; var count=0; var id=0
        val lengths=mutableMapOf<Pair<Int,Int>,Int>()
        while (i<d.size) {
            val prefix=u(d,i++); val n=when(prefix and 3) { 3 -> 4; else -> prefix and 3 }
            var value=0
            repeat(n) { value=value or (u(d,i++) shl (it*8)) }
            when(prefix and 0xFC) {
                0x74 -> size=value; 0x94 -> count=value; 0x84 -> id=value
                0x80,0x90,0xB0 -> { val key=(prefix and 0xFC) to id; lengths[key]=(lengths[key]?:0)+size*count }
            }
        }
        assertEquals(mapOf((0x80 to 1) to 72,(0x80 to 17) to 616,(0x90 to 17) to 616,
            (0xB0 to 2) to 288,(0xB0 to 5) to 320,(0xB0 to 163) to 384),lengths)
    }
    @Test fun neutralPacketMatchesIndependentGolden() {
        val body=DualShock4Profile().inputReport(17,GamepadState.NEUTRAL,0)!!
        val expected="c00080808080080000000000000000000000000000000000002000000000000a00000100800000008000000000000000000000000000000000000000000000000000000000000000006b141c51"
        assertEquals(expected,body.joinToString("") { "%02x".format(it.toInt() and 255) })
    }
    @Test fun negotiatesAndResetsMode() {
        val p=DualShock4Profile()
        assertEquals(1,p.reportId); assertEquals(9,p.encode(GamepadState.NEUTRAL).size)
        p.featureReport(5); assertEquals(17,p.reportId); assertEquals(77,p.encode(GamepadState.NEUTRAL).size)
        p.resetSession(); assertEquals(1,p.reportId)
        assertNull(p.inputReport(2,GamepadState.NEUTRAL)); assertNull(p.featureReport(0xF0))
    }
    @Test fun calibrationHasNonzeroPhysicalScaleAndCrc() {
        val p=DualShock4Profile(); val b=p.featureReport(5)!!
        assertEquals(40,b.size); assertTrue(DualShock4Profile.validCrc(0xA3,5,b))
        repeat(3) { assertEquals(32000,signed(b,6+it*2)-signed(b,12+it*2)) }
        assertEquals(100,1600*(signed(b,18)+signed(b,20))/(signed(b,6)-signed(b,12)))
        assertEquals(16384,signed(b,22)-signed(b,24))
        val usb=p.featureReport(2)!!; assertEquals(36,usb.size); assertEquals(-16000,signed(usb,8))
        val fw=p.featureReport(0xA3)!!; assertEquals(48,fw.size); assertEquals(0x100,signed(fw,40))
    }
    @Test fun controlsMotionAndTouchEncodeAndRelease() {
        val p=DualShock4Profile(); p.touch=Ds4Touch(Ds4Contact(127,1919,941),clicked=true)
        p.motion=Ds4Motion(-1600,0,1600,8192,-8192,0)
        val s=GamepadState(leftStickX=-10,rightStickY=300,hat=Hat.EAST,leftTrigger=255,
            buttons=GamepadButton.SOUTH.bit or GamepadButton.WEST.bit or GamepadButton.GUIDE.bit)
        val b=p.inputReport(17,s,16000)!!
        assertEquals(0,u(b,2)); assertEquals(255,u(b,5)); assertEquals(0xA2,u(b,6))
        assertEquals(4,u(b,7)); assertEquals(3,u(b,8)); assertEquals(3,signed(b,11))
        assertEquals(-1600,signed(b,14)); assertEquals(8192,signed(b,20)); assertEquals(-8192,signed(b,22))
        assertEquals(127,u(b,36)); assertEquals(1919,u(b,37) or ((u(b,38) and 15) shl 8))
        assertEquals(941,(u(b,38) shr 4) or (u(b,39) shl 4)); assertEquals(128,u(b,40))
        p.touch=Ds4Touch(); val released=p.inputReport(17,GamepadState.NEUTRAL,0)!!
        assertEquals(4,u(released,8)); assertEquals(128,u(released,36))
    }
    @Test fun outputsRespectFlagsAndRejectCorruption() {
        val p=DualShock4Profile(); val b=ByteArray(77)
        b[0]=0xC0.toByte(); b[2]=7; b[5]=33; b[6]=100; b[7]=12; b[8]=34; b[9]=56; b[10]=5; b[11]=8
        DualShock4Profile.writeCrc(0xA2,17,b)
        assertTrue(p.handleOutputReport(17,b)); assertEquals(Ds4Output(33,100,12,34,56,5,8),p.output)
        b[7]=13; assertFalse(p.handleOutputReport(17,b))
        assertFalse(p.handleOutputReport(17,ByteArray(4))); assertFalse(p.handleOutputReport(18,b)); assertFalse(p.handleOutputReport(17,null))
        b[2]=1; b[5]=0; b[6]=0; DualShock4Profile.writeCrc(0xA2,17,b)
        assertTrue(p.handleOutputReport(17,b)); assertEquals(12,p.output.red); assertEquals(0,p.output.largeMotor)
        assertEquals(77,p.outputReport(17)!!.size)
    }
    @Test fun boundedRepliesIncludeReportIdInHostLimit() {
        val b=DualShock4Profile().featureReport(5)!!
        listOf(0 to 40,41 to 40,10 to 9,1 to 0,100 to 40).forEach { (limit,size) ->
            assertEquals(size,DualShock4Profile.boundedReply(b,limit).size)
        }
        assertTrue(DualShock4Profile.validCrc(0xA3,5,b))
    }
}
