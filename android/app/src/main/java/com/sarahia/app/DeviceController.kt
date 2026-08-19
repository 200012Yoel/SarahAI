package com.sarahia.app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.os.Vibrator
import android.provider.Settings
import android.util.Log

/**
 * Contrôleur Matériel & Système Local pour Android (100% Hors-Ligne) :
 * - Gestion du Volume (AudioManager)
 * - Statut Batterie & Alimentation (BatteryManager)
 * - Raccourcis Système & Paramètres (Wi-Fi, Bluetooth, Mode Ne Pas Déranger)
 */
class DeviceController(private val context: Context) {

    private val TAG = "SarahDeviceController"
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    data class BatteryInfo(
        val level: Int,
        val isCharging: Boolean,
        val description: String
    )

    fun getBatteryStatus(): BatteryInfo {
        return try {
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, filter)
            val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1

            val pct = if (level >= 0 && scale > 0) (level * 100 / scale) else 50
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

            val desc = if (isCharging) {
                "Votre batterie est actuellement à $pct% et est en cours de charge ⚡."
            } else {
                "Votre batterie est à $pct%."
            }

            BatteryInfo(level = pct, isCharging = isCharging, description = desc)
        } catch (e: Exception) {
            Log.e(TAG, "Erreur lecture batterie: ${e.message}")
            BatteryInfo(50, false, "Statut de batterie inaccessible.")
        }
    }

    fun setVolume(direction: Int): String {
        return try {
            val flag = AudioManager.FLAG_SHOW_UI
            if (direction > 0) {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, flag)
                "Volume augmenté !"
            } else if (direction < 0) {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, flag)
                "Volume diminué !"
            } else {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_SAME, flag)
                "Volume ajusté."
            }
        } catch (e: Exception) {
            "Impossible d'ajuster le volume."
        }
    }

    fun vibrate(millis: Long = 150) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.vibrate(millis)
        } catch (e: Exception) {}
    }

    fun openSystemSettings(action: String): String {
        return try {
            val intent = when (action.lowercase()) {
                "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
                "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                "display", "luminosite" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
                "son", "volume" -> Intent(Settings.ACTION_SOUND_SETTINGS)
                else -> Intent(Settings.ACTION_SETTINGS)
            }.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            "J'ouvre les paramètres de votre appareil."
        } catch (e: Exception) {
            "Impossible d'ouvrir les paramètres."
        }
    }
}
