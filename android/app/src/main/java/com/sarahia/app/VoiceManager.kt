package com.sarahia.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import android.util.Log
import java.util.Locale

/**
 * Gestionnaire Vocal & TTS Haute Fidélité pour SarahAI :
 * - Synthèse vocale jeune fille naturelle, cristalline, dynamique et chaleureuse (Pitch 1.38f, Rate 1.08f)
 * - Filtrage strict et absolu des voix masculines ou robotiques
 * - Reconnaissance vocale continue résiliente avec protection anti-auto-écoute (pas d'auto-coupure TTS)
 * - Connexion directe du flux audio -> Cerveau IA local -> Synthèse vocale & Lip-Sync 3D
 */
class VoiceManager(
    private val context: Context,
    private val onStatusUpdate: (String) -> Unit,
    private val onSpeakingStateChanged: (Boolean) -> Unit,
    private val onLiveTranscription: (String) -> Unit
) {
    private val TAG = "SarahVoiceManager"
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognizerIntent: Intent? = null
    private var tts: TextToSpeech? = null
    
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isListening = false
    private var isSpeaking = false
    private var shouldKeepListening = true
    private val brain = SarahBrain(context)

    init {
        initTTS()
        initSpeechRecognizer()
    }

    public fun getBrain(): SarahBrain = brain

    private fun initTTS() {
        try {
            tts = TextToSpeech(context) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.setLanguage(Locale.FRENCH)
                    
                    try {
                        val audioAttributes = android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                        tts?.setAudioAttributes(audioAttributes)
                    } catch (e: Exception) {}
                    
                    applyYoungFemaleVoice()

                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {
                            mainHandler.post {
                                isSpeaking = true
                                onSpeakingStateChanged(true)
                                onStatusUpdate("🗣️ Sarah parle...")
                            }
                        }

                        override fun onDone(utteranceId: String?) {
                            mainHandler.post {
                                isSpeaking = false
                                onSpeakingStateChanged(false)
                                onStatusUpdate("Sarah vous écoute en continu")
                                // Reprise de l'écoute après la fin de la parole (délai de 350ms pour dissiper l'écho)
                                if (shouldKeepListening) {
                                    restartListeningWithDelay(350)
                                }
                            }
                        }

                        override fun onError(utteranceId: String?) {
                            mainHandler.post {
                                isSpeaking = false
                                onSpeakingStateChanged(false)
                                onStatusUpdate("Sarah vous écoute en continu")
                                if (shouldKeepListening) {
                                    restartListeningWithDelay(350)
                                }
                            }
                        }
                    })

                    Log.d(TAG, "✅ TTS initialisé avec succès.")
                    mainHandler.postDelayed({
                        speak("Bonjour ! Je m'appelle Sarah. Je vous écoute !")
                    }, 400)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Erreur initialisation TTS: ${e.message}")
        }
    }

    private fun applyYoungFemaleVoice() {
        try {
            val availableVoices = tts?.voices
            if (!availableVoices.isNullOrEmpty()) {
                val frVoices = availableVoices.filter { voice ->
                    val lang = voice.locale?.language ?: ""
                    lang.equals("fr", ignoreCase = true) || lang.startsWith("fr")
                }

                // 1. Liste noire stricte des voix d'homme
                val maleBanned = listOf("male", "homme", "masculin", "fra", "frb", "fre", "frf", "thomas", "nicolas", "paul", "antoine", "remi", "alain", "guy", "jean", "bernard", "pierre", "garcon", "garçon")
                val cleanFrVoices = frVoices.filter { voice ->
                    val name = voice.name.lowercase()
                    !maleBanned.any { name.contains(it) }
                }

                // 2. Mots-clés féminins prioritaires (Google Neural, Samsung, etc.)
                val femaleKeywords = listOf(
                    "fr-fr-x-frd", "fr-fr-x-frc", "fr-fr-x-frg", "fr-fr-x-frh",
                    "fr-ca-x-cac", "fr-ca-x-cad",
                    "female", "feminin", "féminin",
                    "audrey", "hortense", "amelie", "amélie", "celine", "julie", "lea", "clara", "chloe", "chloé", "manon", "camille", "sarah", "virginie", "alice", "siwis"
                )

                var chosenVoice: Voice? = cleanFrVoices.firstOrNull { voice ->
                    val name = voice.name.lowercase()
                    femaleKeywords.any { name.contains(it) }
                }

                if (chosenVoice == null) {
                    chosenVoice = cleanFrVoices.firstOrNull { voice ->
                        voice.features?.any { it.contains("female", ignoreCase = true) || it.contains("gender=2") } == true
                    } ?: cleanFrVoices.firstOrNull()
                }

                if (chosenVoice != null) {
                    tts?.voice = chosenVoice
                    Log.d(TAG, "🎙️ Voix féminine appliquée : ${chosenVoice.name}")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Exception sélection voix: ${e.message}")
        }

        // Configuration du timbre jeune fille : Pitch 1.38f (aigu, clair, dynamique), Vitesse 1.08f
        tts?.setPitch(1.38f)
        tts?.setSpeechRate(1.08f)
    }

    private fun initSpeechRecognizer() {
        mainHandler.post {
            try {
                if (SpeechRecognizer.isRecognitionAvailable(context)) {
                    speechRecognizer?.destroy()
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                    
                    speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            if (!isSpeaking) {
                                onStatusUpdate("🎙️ Sarah vous écoute...")
                            }
                        }

                        override fun onBeginningOfSpeech() {
                            if (!isSpeaking) {
                                onStatusUpdate("🎙️ Écoute de votre voix...")
                            }
                        }

                        override fun onRmsChanged(rmsdB: Float) {
                            // Ne pas déclencher de barge-in sur sa propre voix
                        }

                        override fun onBufferReceived(buffer: ByteArray?) {}

                        override fun onEndOfSpeech() {
                            if (!isSpeaking) {
                                onStatusUpdate("🧠 Traitement...")
                            }
                        }

                        override fun onError(error: Int) {
                            Log.w(TAG, "SpeechRecognizer Code: $error")
                            isListening = false
                            if (shouldKeepListening && !isSpeaking) {
                                val delay = if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) 800L else 300L
                                restartListeningWithDelay(delay)
                            }
                        }

                        override fun onResults(results: Bundle?) {
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                val userText = matches[0]
                                Log.d(TAG, "Transcription utilisateur: $userText")
                                onLiveTranscription("« $userText »")
                                
                                brain.getAnswerAsync(userText) { reply ->
                                    mainHandler.post {
                                        speak(reply)
                                    }
                                }
                            } else {
                                if (shouldKeepListening && !isSpeaking) {
                                    restartListeningWithDelay(300)
                                }
                            }
                        }

                        override fun onPartialResults(partialResults: Bundle?) {
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty() && !isSpeaking) {
                                val partial = matches[0]
                                onLiveTranscription("« $partial... »")
                            }
                        }

                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })

                    recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "fr-FR")
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "fr-FR")
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                    }
                    Log.d(TAG, "✅ SpeechRecognizer prêt.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erreur SpeechRecognizer: ${e.message}")
            }
        }
    }

    public fun startContinuousListening() {
        shouldKeepListening = true
        mainHandler.post {
            if (isSpeaking) return@post
            try {
                speechRecognizer?.cancel()
                recognizerIntent?.let {
                    speechRecognizer?.startListening(it)
                    isListening = true
                    onStatusUpdate("🎙️ Sarah vous écoute...")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erreur startListening: ${e.message}")
                restartListeningWithDelay(1000)
            }
        }
    }

    public fun stopListening() {
        shouldKeepListening = false
        mainHandler.post {
            try {
                isListening = false
                speechRecognizer?.stopListening()
                speechRecognizer?.cancel()
            } catch (e: Exception) {}
        }
    }

    public fun speak(text: String) {
        val cleanText = text.trim()
        if (cleanText.isEmpty()) return

        mainHandler.post {
            try {
                // 1. Stopper l'écoute pour éviter que le micro n'entende les haut-parleurs
                isListening = false
                try {
                    speechRecognizer?.cancel()
                } catch (e: Exception) {}

                // 2. Réappliquer systématiquement la voix féminine jeune et le pitch cristallin
                applyYoungFemaleVoice()

                val utteranceId = "sarah_${System.currentTimeMillis()}"
                val params = Bundle().apply {
                    putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
                    putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                    putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_MUSIC)
                }

                isSpeaking = true
                onSpeakingStateChanged(true)
                onStatusUpdate("🗣️ Sarah parle...")

                tts?.speak(cleanText, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
                Log.d(TAG, "TTS en cours: $cleanText")
            } catch (e: Exception) {
                Log.e(TAG, "Erreur speak: ${e.message}")
                isSpeaking = false
                onSpeakingStateChanged(false)
                if (shouldKeepListening) {
                    startContinuousListening()
                }
            }
        }
    }

    public fun stopSpeaking() {
        mainHandler.post {
            try {
                if (isSpeaking) {
                    tts?.stop()
                    isSpeaking = false
                    onSpeakingStateChanged(false)
                    onStatusUpdate("Sarah vous écoute en continu")
                    if (shouldKeepListening) {
                        restartListeningWithDelay(300)
                    }
                }
            } catch (e: Exception) {}
        }
    }

    private fun restartListeningWithDelay(delayMs: Long) {
        if (!shouldKeepListening) return
        mainHandler.postDelayed({
            if (shouldKeepListening && !isSpeaking) {
                startContinuousListening()
            }
        }, delayMs)
    }

    public fun destroy() {
        shouldKeepListening = false
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
            tts?.stop()
            tts?.shutdown()
            tts = null
        } catch (e: Exception) {}
    }
}
