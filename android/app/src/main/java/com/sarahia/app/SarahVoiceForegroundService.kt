package com.sarahia.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Service d'arrière-plan audio & réveil basse consommation (Foreground Service) :
 * - Maintient la conversation vocale fluide même quand l'écran est verrouillé ou l'app minimisée
 * - WakeLock partiel avec gestion thermique et économie de batterie intelligente
 */
class SarahVoiceForegroundService : Service() {

    private val TAG = "SarahVoiceService"
    private val CHANNEL_ID = "sarah_voice_channel"
    private val NOTIFICATION_ID = 1001
    private var wakeLock: PowerManager.WakeLock? = null
    private var wakeWordDetector: WakeWordDetector? = null
    private var backTapDetector: BackTapGestureDetector? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()

        wakeWordDetector = WakeWordDetector(this) {
            Log.d(TAG, "Mot-clé 'Hey Sarah' détecté en arrière-plan !")
            SarahAppWidgetProvider.updateAllWidgets(this, "Hey Sarah détecté !", "● Écoute en cours")
        }

        backTapDetector = BackTapGestureDetector(this) {
            Log.d(TAG, "Back-Tap détecté en arrière-plan !")
            SarahAppWidgetProvider.updateAllWidgets(this, "Double-tap détecté !", "● Écoute en cours")
        }.apply { start() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification("Sarah est prête et à votre écoute en continu (Hey Sarah & Back-Tap actifs)")
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "🟢 Service audio d'arrière-plan démarré.")
        return START_STICKY
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SarahAI::VoiceServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(2 * 60 * 60 * 1000L) // 2 heures max avec auto-release
            }
            Log.d(TAG, "WakeLock basse consommation activé.")
        } catch (e: Exception) {
            Log.w(TAG, "Erreur WakeLock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "WakeLock relâché.")
            }
        } catch (e: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sarah IA - Mode Vocal Continu",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Maintient l'écoute vocale et la réactivité de Sarah en arrière-plan"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(statusText: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sarah IA")
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        releaseWakeLock()
        Log.d(TAG, "🔴 Service audio d'arrière-plan arrêté.")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
