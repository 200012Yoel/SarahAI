package com.sarahia.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log

/**
 * Détecteur de Geste "Back-Tap" (Double-Tap au dos du téléphone) :
 * - Analyse les impulsions sur l'axe Z de l'accéléromètre
 * - Réveille Sarah instantanément par un double-tap physique à l'arrière de l'appareil
 */
class BackTapGestureDetector(private val context: Context, private val onBackTapDetected: () -> Unit) : SensorEventListener {

    private val TAG = "SarahBackTap"
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    private var lastZ = 0f
    private var lastTapTime = 0L
    private var tapCount = 0

    private val TAP_THRESHOLD = 3.5f // Seuil d'accélération brusque sur l'axe Z
    private val DOUBLE_TAP_TIMEOUT = 500L // Temps max entre 2 taps (500ms)
    private val MIN_TAP_INTERVAL = 120L // Temps min pour éviter les rebonds

    fun start() {
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            Log.d(TAG, "🟢 Détecteur Back-Tap actif.")
        }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
        Log.d(TAG, "🔴 Détecteur Back-Tap arrêté.")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val z = event.values[2]
        val deltaZ = Math.abs(z - lastZ)
        lastZ = z

        val now = System.currentTimeMillis()

        if (deltaZ > TAP_THRESHOLD) {
            val interval = now - lastTapTime
            if (interval in MIN_TAP_INTERVAL..DOUBLE_TAP_TIMEOUT) {
                tapCount++
                if (tapCount >= 2) {
                    Log.d(TAG, "⚡ Double-tap au dos détecté !")
                    tapCount = 0
                    lastTapTime = 0L
                    onBackTapDetected()
                }
            } else if (interval > DOUBLE_TAP_TIMEOUT) {
                tapCount = 1
                lastTapTime = now
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
