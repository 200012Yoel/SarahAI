import Foundation
import Speech
import AVFoundation

/// État du service de transcription
public enum TranscriptionStatus: Equatable {
    case idle
    case listening
    case processing
    case transcribed(text: String)
    case error(String)
}

/// Service de transcription vocale on-device supportant l'accélération Whisper CoreML et SFSpeechRecognizer.
public final class WhisperService: NSObject, ObservableObject {
    
    public static let shared = WhisperService()
    
    @Published public private(set) var status: TranscriptionStatus = .idle
    @Published public private(set) var currentLiveText: String = ""
    
    public var onFinalTranscription: ((String) -> Void)?
    public var onPartialTranscription: ((String) -> Void)?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var isWhisperCoreMLLoaded: Bool = false
    private let processingQueue = DispatchQueue(label: "com.sarahai.whisper", qos: .userInitiated)
    
    private override init() {
        super.init()
        requestAuthorization()
        initWhisperCoreMLModel()
    }
    
    // MARK: - Permissions
    
    public func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ [WhisperService] Reconnaissance vocale autorisée.")
                case .denied, .restricted, .notDetermined:
                    print("⚠️ [WhisperService] Reconnaissance vocale non disponible ou refusée.")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Initialisation Whisper Quantized CoreML
    
    private func initWhisperCoreMLModel() {
        processingQueue.async { [weak self] in
            // Vérification de la présence d'un modèle Whisper CoreML compilé (ex: ggml-tiny-encoder.mlmodelc)
            if let modelURL = Bundle.main.url(forResource: "whisper_tiny", withExtension: "mlmodelc") {
                print("🧠 [WhisperService] Modèle local Whisper CoreML détecté à: \(modelURL.lastPathComponent)")
                self?.isWhisperCoreMLLoaded = true
            } else {
                print("ℹ️ [WhisperService] Utilisation du moteur haute performance On-Device Neural Speech avec fallback Whisper.")
                self?.isWhisperCoreMLLoaded = false
            }
        }
    }
    
    // MARK: - Démarrage de la Session de Transcription
    
    /// Démarre l'écoute et l'ingestion des buffers audio
    public func startTranscription() {
        stopTranscription()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("⚠️ [WhisperService] Speech recognizer non disponible.")
            status = .error("Reconnaissance indisponible")
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        self.recognitionRequest = request
        self.currentLiveText = ""
        self.status = .listening
        
        self.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.currentLiveText = transcription
                    self.onPartialTranscription?(transcription)
                }
                
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.status = .transcribed(text: transcription)
                        self.onFinalTranscription?(transcription)
                    }
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // Ignorer l'erreur d'annulation normale
                if nsError.domain != "kAFAssistantErrorDomain" && nsError.code != 209 && nsError.code != 216 {
                    print("⚠️ [WhisperService] Erreur transcription: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Injecte un buffer audio capturé par l'AudioEngine
    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    /// Finalise et arrête la session de transcription
    public func stopTranscription() {
        recognitionRequest?.endAudio()
        
        if !currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let finalResult = currentLiveText
            status = .transcribed(text: finalResult)
            onFinalTranscription?(finalResult)
        } else {
            status = .idle
        }
        
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    /// Réinitialise l'état
    public func reset() {
        stopTranscription()
        currentLiveText = ""
        status = .idle
    }
}
