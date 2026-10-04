package com.blugaemand.hid

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Surface
import android.view.WindowManager
import kotlin.math.roundToInt

/** Reads phone motion and approximates the two DS4 motors with one phone vibrator. */
@Suppress("DEPRECATION")
class Ds4Hardware(private val context: Context,private val profile: DualShock4Profile): SensorEventListener {
    private val sensors=context.getSystemService(SensorManager::class.java)
    private val vibrator=context.getSystemService(Vibrator::class.java)
    private val handler=Handler(Looper.getMainLooper())
    private var amplitude=0
    private val stopRumble=Runnable { vibrator?.cancel(); amplitude=0 }
    private var listening=false
    private var gyro=intArrayOf(0,0,0)
    private var accel=intArrayOf(0,0,8192)
    fun start() {
        if (listening) return
        listening=true; gyro=intArrayOf(0,0,0); accel=intArrayOf(0,0,8192)
        listOf(Sensor.TYPE_GYROSCOPE,Sensor.TYPE_ACCELEROMETER).forEach { type ->
            sensors?.getDefaultSensor(type)?.let { sensors.registerListener(this,it,10_000) }
        }
        val b=context.registerReceiver(null,IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return
        val scale=b.getIntExtra(BatteryManager.EXTRA_SCALE,100).coerceAtLeast(1)
        profile.batteryPercent=b.getIntExtra(BatteryManager.EXTRA_LEVEL,100)*100/scale
        profile.charging=b.getIntExtra(BatteryManager.EXTRA_PLUGGED,0)!=0
    }
    fun stop() {
        sensors?.unregisterListener(this); listening=false
        handler.removeCallbacks(stopRumble); stopRumble.run(); profile.motion=Ds4Motion()
    }
    fun applyOutput(output: Ds4Output) {
        val next=maxOf(output.smallMotor,output.largeMotor)
        handler.removeCallbacks(stopRumble)
        if (next==0) stopRumble.run() else {
            if (next!=amplitude) {
                val level=if (vibrator?.hasAmplitudeControl()==true) next else VibrationEffect.DEFAULT_AMPLITUDE
                vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0,250),intArrayOf(0,level),0))
                amplitude=next
            }
            handler.postDelayed(stopRumble,5000)
        }
    }
    override fun onSensorChanged(event: SensorEvent) {
        val rotation=context.getSystemService(WindowManager::class.java).defaultDisplay.rotation
        val x=event.values[0]; val y=event.values[1]; val z=event.values[2]
        val (right,forward)=when(rotation) {
            Surface.ROTATION_90 -> -y to x
            Surface.ROTATION_180 -> -x to -y
            Surface.ROTATION_270 -> y to -x
            else -> x to y
        }
        val factor=if (event.sensor.type==Sensor.TYPE_GYROSCOPE) 16.0*180.0/Math.PI else 8192.0/SensorManager.GRAVITY_EARTH
        val values=listOf(right,forward,z).map { (it*factor).roundToInt().coerceIn(-32768,32767) }.toIntArray()
        if (event.sensor.type==Sensor.TYPE_GYROSCOPE) gyro=values else accel=values
        profile.motion=Ds4Motion(gyro[0],gyro[1],gyro[2],accel[0],accel[1],accel[2])
    }
    override fun onAccuracyChanged(sensor: Sensor?,accuracy: Int)=Unit
}
