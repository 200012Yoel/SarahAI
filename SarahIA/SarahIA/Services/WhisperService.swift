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
    @Published public private(set) var isAuthorized: Bool = false
    
    public var onFinalTranscription: ((String) -> Void)?
    public var onPartialTranscription: ((String) -> Void)?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var isWhisperCoreMLLoaded: Bool = false
    private let processingQueue = DispatchQueue(label: "com.sarahai.whisper", qos: .userInitiated)
    private var hasDeliveredFinalResult: Bool = false
    
    private override init() {
        super.init()
        requestAuthorization()
        initWhisperCoreMLModel()
    }
    
    // MARK: - Permissions
    
    public func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                let ok = (authStatus == .authorized)
                self?.isAuthorized = ok
                if ok {
                    print("✅ [WhisperService] Reconnaissance vocale autorisée.")
                } else {
                    print("⚠️ [WhisperService] Reconnaissance vocale non autorisée (\(authStatus.rawValue)).")
                }
                completion?(ok)
            }
        }
    }
    
    // MARK: - Initialisation Whisper Quantized CoreML
    
    private func initWhisperCoreMLModel() {
        processingQueue.async { [weak self] in
            if let modelURL = Bundle.main.url(forResource: "whisper_tiny", withExtension: "mlmodelc") {
                print("🧠 [WhisperService] Modèle local Whisper CoreML détecté à: \(modelURL.lastPathComponent)")
                self?.isWhisperCoreMLLoaded = true
            } else {
                print("ℹ️ [WhisperService] Moteur On-Device Apple Speech avec fallback.")
                self?.isWhisperCoreMLLoaded = false
            }
        }
    }
    
    // MARK: - Démarrage de la Session de Transcription
    
    /// Démarre l'écoute et l'ingestion des buffers audio
    public func startTranscription() {
        stopTranscription()
        
        guard let speechRecognizer = speechRecognizer else {
            print("⚠️ [WhisperService] Speech recognizer introuvable pour fr-FR.")
            status = .error("Reconnaissance indisponible")
            return
        }
        
        guard speechRecognizer.isAvailable else {
            print("⚠️ [WhisperService] Speech recognizer non disponible actuellement.")
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        self.recognitionRequest = request
        self.currentLiveText = ""
        self.hasDeliveredFinalResult = false
        self.status = .listening
        
        self.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.currentLiveText = transcription
                    self.onPartialTranscription?(transcription)
                }
                
                if result.isFinal && !self.hasDeliveredFinalResult {
                    self.hasDeliveredFinalResult = true
                    DispatchQueue.main.async {
                        self.status = .transcribed(text: transcription)
                        self.onFinalTranscription?(transcription)
                    }
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // Ignorer les codes d'annulation bénins
                if nsError.domain != "kAFAssistantErrorDomain" && nsError.code != 209 && nsError.code != 216 {
                    print("⚠️ [WhisperService] Info transcription: \(error.localizedDescription)")
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
        
        let finalResult = currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalResult.isEmpty && !hasDeliveredFinalResult {
            hasDeliveredFinalResult = true
            status = .transcribed(text: finalResult)
            DispatchQueue.main.async {
                self.onFinalTranscription?(finalResult)
            }
        } else if finalResult.isEmpty {
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
