import Foundation
import AVFoundation
import Speech

/// Pipeline de Traduction Vocale & Synthèse Temps Réel en Appel (Full Duplex)
public final class LiveSpeechTranslationPipeline: NSObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    
    public static let shared = LiveSpeechTranslationPipeline()
    
    // Callbacks pour l'UI et le moteur WebRTC
    public var onTranscriptItemUpdated: ((CallTranscriptItem) -> Void)?
    public var onSynthesizedAudioReady: ((Data, String) -> Void)?
    public var onAudioEnergyLevel: ((Float) -> Void)?
    
    private var localSpeechRecognizer: SFSpeechRecognizer?
    private var localRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var localRecognitionTask: SFSpeechRecognitionTask?
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentLanguagePair = CallLanguagePair()
    private var isPipelineRunning = false
    
    // Suivi du segment en cours
    private var currentLocalSegmentId: String = UUID().uuidString
    private var lastRecognizedText: String = ""
    private var silenceDebounceTimer: Timer?
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    // MARK: - Démarrage / Arrêt du Pipeline
    
    public func startPipeline(with languagePair: CallLanguagePair) {
        stopPipeline()
        self.currentLanguagePair = languagePair
        self.isPipelineRunning = true
        
        let localeId = localeIdentifier(for: languagePair.localLanguage)
        localSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        localSpeechRecognizer?.delegate = self
        
        startRecognitionSession()
    }
    
    public func updateLanguagePair(_ newPair: CallLanguagePair) {
        let needsRestart = newPair.localLanguage != currentLanguagePair.localLanguage
        self.currentLanguagePair = newPair
        if needsRestart && isPipelineRunning {
            startPipeline(with: newPair)
        }
    }
    
    public func stopPipeline() {
        isPipelineRunning = false
        silenceDebounceTimer?.invalidate()
        silenceDebounceTimer = nil
        
        localRecognitionRequest?.endAudio()
        localRecognitionRequest = nil
        
        localRecognitionTask?.cancel()
        localRecognitionTask = nil
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - Ingestion des Buffers PCM Micro
    
    public func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isPipelineRunning, let request = localRecognitionRequest else { return }
        request.append(buffer)
        
        // Calcul du niveau d'énergie audio RMS pour l'animation visuelle
        calculateAudioEnergy(buffer: buffer)
    }
    
    private func calculateAudioEnergy(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return }
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrtf(sum / Float(frameLength))
        let normalized = min(max(rms * 10.0, 0.0), 1.0)
        
        DispatchQueue.main.async { [weak self] in
            self?.onAudioEnergyLevel?(normalized)
        }
    }
    
    // MARK: - Session de Reconnaissance Vocale Continue
    
    private func startRecognitionSession() {
        guard let recognizer = localSpeechRecognizer, recognizer.isAvailable else {
            print("⚠️ [SpeechPipeline] SFSpeechRecognizer non disponible")
            return
        }
        
        localRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = localRecognitionRequest else { return }
        
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        
        currentLocalSegmentId = UUID().uuidString
        lastRecognizedText = ""
        
        localRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcription.isEmpty && transcription != self.lastRecognizedText {
                    self.lastRecognizedText = transcription
                    self.handleLocalTranscription(text: transcription, isFinal: result.isFinal)
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                // Recommencer une session propre si le pipeline est toujours actif
                if self.isPipelineRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.startRecognitionSession()
                    }
                }
            }
        }
    }
    
    // MARK: - Traitement & Traduction en Direct
    
    private func handleLocalTranscription(text: String, isFinal: Bool) {
        silenceDebounceTimer?.invalidate()
        
        // Traduction instantanée locale
        let targetLang = currentLanguagePair.remoteLanguage
        let sourceLang = currentLanguagePair.localLanguage
        
        // Traduction ultra-rapide (dictionnaire local + fallback)
        let targetEnum: TranslationEngine.TargetLanguage = {
            switch targetLang {
            case "en": return .english
            case "he": return .hebrew
            default: return .french
            }
        }()
        
        TranslationEngine.shared.translate(text: text, sourceLang: sourceLang, targetLang: targetEnum) { [weak self] (translatedText) in
            guard let self = self else { return }
            
            let item = CallTranscriptItem(
                id: self.currentLocalSegmentId,
                isLocalSpeaker: true,
                originalText: text,
                originalLanguage: sourceLang,
                translatedText: translatedText,
                targetLanguage: targetLang,
                isFinal: isFinal
            )
            
            DispatchQueue.main.async {
                self.onTranscriptItemUpdated?(item)
            }
            
            // Si la phrase est validée ou après un court silence, on synthétise la voix traduite
            self.silenceDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) { [weak self] _ in
                guard let self = self, self.currentLanguagePair.isVoiceTranslationEnabled else { return }
                self.synthesizeAndInjectTranslatedVoice(text: translatedText, language: targetLang)
                // Nouveau segment pour la phrase suivante
                self.currentLocalSegmentId = UUID().uuidString
                self.lastRecognizedText = ""
            }
        }
    }
    
    // MARK: - Synthèse Vocale & Injection WebRTC
    
    private func synthesizeAndInjectTranslatedVoice(text: String, language: String) {
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        let localeCode = localeIdentifier(for: language)
        utterance.voice = AVSpeechSynthesisVoice(language: localeCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        
        // Stopper toute synthèse précédente
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        speechSynthesizer.speak(utterance)
        
        // Émission de l'événement de voix synthétisée pour la couche WebRTC
        let utf8Data = Data(text.utf8)
        self.onSynthesizedAudioReady?(utf8Data, language)
    }
    
    // MARK: - Traitement de l'Audio Distant (Correspondant -> Utilisateur iPhone)
    
    public func handleRemoteIncomingText(_ remoteText: String) {
        let sourceLang = currentLanguagePair.remoteLanguage
        let targetLang = currentLanguagePair.localLanguage
        
        let targetEnum: TranslationEngine.TargetLanguage = {
            switch targetLang {
            case "he": return .hebrew
            case "en": return .english
            default: return .french
            }
        }()
        
        TranslationEngine.shared.translate(text: remoteText, sourceLang: sourceLang, targetLang: targetEnum) { [weak self] (translatedText) in
            guard let self = self else { return }
            
            let item = CallTranscriptItem(
                id: UUID().uuidString,
                isLocalSpeaker: false,
                originalText: remoteText,
                originalLanguage: sourceLang,
                translatedText: translatedText,
                targetLanguage: targetLang,
                isFinal: true
            )
            
            DispatchQueue.main.async {
                self.onTranscriptItemUpdated?(item)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func localeIdentifier(for langCode: String) -> String {
        switch langCode {
        case "en": return "en-US"
        case "he": return "he-IL"
        case "fr": return "fr-FR"
        default: return "fr-FR"
        }
    }
}
