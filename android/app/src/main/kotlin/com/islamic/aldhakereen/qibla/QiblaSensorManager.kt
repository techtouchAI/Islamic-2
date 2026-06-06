package com.islamic.aldhakereen.qibla

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

class QiblaSensorManager(context: Context) : SensorEventListener {
    private val sensorManager: SensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val magnetometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private val R = FloatArray(9)
    private val I = FloatArray(9)

    private var eventSink: EventChannel.EventSink? = null

    fun start(sink: EventChannel.EventSink) {
        eventSink = sink
        accelerometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        magnetometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
        eventSink = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        // Low-pass filter logic similar to decompiled bg/a.java
        val alpha = 0.97f
        val beta = 1.0f - alpha

        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            gravity[0] = alpha * gravity[0] + beta * event.values[0]
            gravity[1] = alpha * gravity[1] + beta * event.values[1]
            gravity[2] = alpha * gravity[2] + beta * event.values[2]
        }
        if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            geomagnetic[0] = alpha * geomagnetic[0] + beta * event.values[0]
            geomagnetic[1] = alpha * geomagnetic[1] + beta * event.values[1]
            geomagnetic[2] = alpha * geomagnetic[2] + beta * event.values[2]
        }

        if (SensorManager.getRotationMatrix(R, I, gravity, geomagnetic)) {
            val orientation = FloatArray(3)
            SensorManager.getOrientation(R, orientation)

            var degrees = Math.toDegrees(orientation[0].toDouble()).toFloat()
            degrees = (degrees + 360) % 360

            eventSink?.success(degrees.toDouble())
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
