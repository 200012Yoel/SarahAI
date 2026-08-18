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
import android.util.Log
import java.util.Locale

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

    init {
        initTTS()
        initSpeechRecognizer()
    }

    private fun initTTS() {
        try {
            tts = TextToSpeech(context) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val result = tts?.setLanguage(Locale.FRENCH)
                    if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                        tts?.setLanguage(Locale.getDefault())
                    }
                    tts?.setSpeechRate(1.02f)
                    tts?.setPitch(1.06f)

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
                                if (shouldKeepListening) {
                                    startContinuousListening()
                                }
                            }
                        }

                        override fun onError(utteranceId: String?) {
                            mainHandler.post {
                                isSpeaking = false
                                onSpeakingStateChanged(false)
                                onStatusUpdate("Sarah vous écoute en continu")
                                if (shouldKeepListening) {
                                    startContinuousListening()
                                }
                            }
                        }
                    })

                    Log.d(TAG, "✅ TTS initialisé.")
                    mainHandler.postDelayed({
                        speak("Bonjour ! Je m'appelle Sarah. Je vous écoute !")
                    }, 500)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Erreur initialisation TTS: ${e.message}")
        }
    }

    private fun initSpeechRecognizer() {
        mainHandler.post {
            try {
                if (SpeechRecognizer.isRecognitionAvailable(context)) {
                    speechRecognizer?.destroy()
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                    
                    speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            onStatusUpdate("🎙️ Sarah vous écoute...")
                        }

                        override fun onBeginningOfSpeech() {
                            triggerBargeIn()
                            onStatusUpdate("🎙️ Écoute de votre voix...")
                        }

                        override fun onRmsChanged(rmsdB: Float) {
                            if (rmsdB > 2.0f && isSpeaking) {
                                triggerBargeIn()
                            }
                        }

                        override fun onBufferReceived(buffer: ByteArray?) {}

                        override fun onEndOfSpeech() {
                            onStatusUpdate("🧠 Traitement...")
                        }

                        override fun onError(error: Int) {
                            Log.w(TAG, "SpeechRecognizer Code: $error")
                            isListening = false
                            if (shouldKeepListening && !isSpeaking) {
                                restartListeningWithDelay(400)
                            }
                        }

                        override fun onResults(results: Bundle?) {
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                val userText = matches[0]
                                Log.d(TAG, "Transcription: $userText")
                                onLiveTranscription("« $userText »")
                                
                                val reply = generateAnswer(userText)
                                mainHandler.postDelayed({
                                    speak(reply)
                                }, 200)
                            } else {
                                restartListeningWithDelay(300)
                            }
                        }

                        override fun onPartialResults(partialResults: Bundle?) {
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                val partial = matches[0]
                                triggerBargeIn()
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
                    Log.d(TAG, "✅ SpeechRecognizer configuré.")
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
            } catch (e: Exception) {
                Log.e(TAG, "Erreur stopListening: ${e.message}")
            }
        }
    }

    public fun speak(text: String) {
        mainHandler.post {
            try {
                if (isListening) {
                    speechRecognizer?.cancel()
                    isListening = false
                }
                val params = Bundle().apply {
                    putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "sarah_${System.currentTimeMillis()}")
                }
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "sarah_utterance")
            } catch (e: Exception) {
                Log.e(TAG, "Erreur speak: ${e.message}")
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
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erreur stopSpeaking: ${e.message}")
            }
        }
    }

    // --- BARGE-IN INTERRUPTION ---
    private fun triggerBargeIn() {
        if (isSpeaking) {
            Log.d(TAG, "⚡ [Barge-In] Interruption immédiate de Sarah !")
            stopSpeaking()
            onStatusUpdate("🎙️ Sarah vous écoute...")
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

    // MARK: - Cerveau Conversationnel de Sarah IA
    private fun generateAnswer(input: String): String {
        val lower = input.lowercase().trim()

        return when {
            lower.contains("bonjour") || lower.contains("salut") || lower.contains("coucou") || lower.contains("hello") ->
                "Bonjour ! Je suis ravie de vous parler. Comment puis-je vous aider aujourd'hui ?"

            lower.contains("qui es-tu") || lower.contains("qui es tu") || lower.contains("présente-toi") || lower.contains("ton nom") ->
                "Je m'appelle Sarah ! Je suis votre assistante virtuelle 3D intelligente. Je vous écoute en direct et je réponds à toutes vos questions."

            lower.contains("heure") || lower.contains("quelle heure") -> {
                val cal = java.util.Calendar.getInstance()
                "Il est actuellement ${cal.get(java.util.Calendar.HOUR_OF_DAY)} heures et ${cal.get(java.util.Calendar.MINUTE)} minutes."
            }

            lower.contains("date") || lower.contains("quel jour") -> {
                val sdf = java.text.SimpleDateFormat("EEEE d MMMM yyyy", Locale.FRENCH)
                "Nous sommes le ${sdf.format(java.util.Date())}."
            }

            lower.contains("blague") || lower.contains("raconte une blague") || lower.contains("fais-moi rire") ->
                "Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? Parce que sinon ils tombent dans le bateau !"

            lower.contains("merci") ->
                "Je vous en prie ! C'est toujours un plaisir d'échanger avec vous."

            lower.contains("comment vas-tu") || lower.contains("ça va") ->
                "Je vais merveilleusement bien, merci ! Et vous, comment se passe votre journée ?"

            else ->
                "J'ai bien compris : $input. Je suis à votre écoute !"
        }
    }

    public fun destroy() {
        shouldKeepListening = false
        speechRecognizer?.destroy()
        speechRecognizer = null
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
