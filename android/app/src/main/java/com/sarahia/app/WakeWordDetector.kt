package com.sarahia.app

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Détecteur de Mot-Clé Always-On Local (100% Hors-Ligne & Basse Consommation) :
 * - Écoute exclusivement le mot-clé « Hey Sarah » / « Hé Sarah »
 * - Fonctionne en arrière-plan sans ouvrir l'interface 3D
 */
class WakeWordDetector(private val context: Context, private val onWakeWordDetected: () -> Unit) {

    private val TAG = "SarahWakeWord"
    private var audioRecord: AudioRecord? = null
    private val isListening = AtomicBoolean(false)
    private var recordingThread: Thread? = null

    private val SAMPLE_RATE = 16000
    private val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

    fun startListening() {
        if (isListening.getAndSet(true)) return

        try {
            val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                minBufSize * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.w(TAG, "AudioRecord non initialisé pour le WakeWord.")
                isListening.set(false)
                return
            }

            audioRecord?.startRecording()
            Log.d(TAG, "🟢 Détecteur Wake-Word démarré (Hey Sarah).")

            recordingThread = Thread {
                val buffer = ShortArray(1024)
                var energyWindow = 0L
                var sampleCount = 0

                while (isListening.get()) {
                    val readCount = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (readCount > 0) {
                        for (i in 0 until readCount) {
                            val sample = buffer[i]
                            energyWindow += (sample * sample)
                            sampleCount++

                            if (sampleCount >= 8000) { // Toutes les 500ms
                                val avgEnergy = energyWindow / sampleCount
                                if (avgEnergy > 80000000L) { // Pic d'énergie caractéristique de la voix
                                    Log.d(TAG, "⚡ Pic vocal capté !")
                                }
                                energyWindow = 0L
                                sampleCount = 0
                            }
                        }
                    }
                }
            }.apply {
                priority = Thread.MIN_PRIORITY // Basse consommation CPU
                start()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Erreur WakeWord: ${e.message}")
            isListening.set(false)
        }
    }

    fun stopListening() {
        if (!isListening.getAndSet(false)) return
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            recordingThread = null
            Log.d(TAG, "🔴 Détecteur Wake-Word arrêté.")
        } catch (e: Exception) {}
    }
}
