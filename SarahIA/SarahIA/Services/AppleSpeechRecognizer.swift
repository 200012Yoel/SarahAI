import Foundation
import Speech
import AVFoundation
import Combine

/// État de la reconnaissance vocale Apple native
public enum SpeechRecognizerState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
}

/// Gestionnaire de Reconnaissance Vocale 100% Gratuit, Local et Continu basé sur Apple Speech.framework (`SFSpeechRecognizer`).
@available(iOS 13.0, *)
public final class AppleSpeechRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    
    public static let shared = AppleSpeechRecognizer()
    
    @Published public private(set) var state: SpeechRecognizerState = .idle
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var currentLiveText: String = ""
    @Published public private(set) var micEnergyLevel: Float = 0.0
    
    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Détection automatique de silence pour valider la fin de la phrase
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.3 // Secondes de pause pour valider la question
    private var hasDetectedSpeechInCurrentSession: Bool = false
    
    private override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    public func requestPermissions(completion: ((Bool) -> Void)? = nil) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    let isReady = (authStatus == .authorized && micGranted)
                    completion?(isReady)
                }
            }
        }
    }
    
    // MARK: - Démarrage de l'Écoute Vocale Continue
    
    /// Démarre l'écoute microphone et la transcription en direct
    public func startListening() {
        guard !isListening else { return }
        
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        
        if authStatus != .authorized || micStatus != .granted {
            requestPermissions { [weak self] ready in
                if ready {
                    self?.startListening()
                } else {
                    self?.state = .error("Permissions microphone ou vocale non accordées")
                }
            }
            return
        }
        
        stopListening()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("⚠️ [AppleSpeechRecognizer] SFSpeechRecognizer non disponible.")
            self.state = .error("Reconnaissance vocale indisponible")
            return
        }
        
        // 1. Configurer la session audio pour enregistrement
        AudioSessionManager.shared.configureRecordingSession()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        self.currentLiveText = ""
        self.hasDetectedSpeechInCurrentSession = false
        
        audioEngine.reset()
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        var recordingFormat = inputNode.inputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            recordingFormat = inputNode.outputFormat(forBus: 0)
        }
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? recordingFormat
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)
            self?.calculateAudioLevel(buffer: buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isListening = true
                self.state = .listening
            }
            
            self.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] (result, error) in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.currentLiveText = text
                        self.onPartialTranscription?(text)
                        self.hasDetectedSpeechInCurrentSession = true
                        
                        // Réinitialiser le timer de silence à chaque mot détecté
                        self.resetSilenceTimer()
                    }
                    
                    if result.isFinal {
                        self.finalizeSpeech(text: text)
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code != 209 && nsError.code != 216 && nsError.domain != "kAFAssistantErrorDomain" {
                        print("ℹ️ [AppleSpeechRecognizer] Fin session: \(error.localizedDescription)")
                    }
                }
            }
            
            print("🎙️ [AppleSpeechRecognizer] Écoute active démarrée.")
        } catch {
            print("❌ [AppleSpeechRecognizer] Erreur AVAudioEngine: \(error.localizedDescription)")
            self.state = .error(error.localizedDescription)
        }
    }
    
    /// Calcule l'énergie sonore pour animation des ondes
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let length = Int(buffer.frameLength)
        guard length > 0 else { return }
        
        var sum: Float = 0
        for i in 0..<length {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(length))
        DispatchQueue.main.async {
            self.micEnergyLevel = min(1.0, rms * 8.0)
        }
    }
    
    // MARK: - Détection Automatique de Silence (Fin de Question)
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening, self.hasDetectedSpeechInCurrentSession else { return }
            let text = self.currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                print("⏳ [AppleSpeechRecognizer] Silence détecté -> Validation automatique de la question.")
                self.finalizeSpeech(text: text)
            }
        }
    }
    
    private func finalizeSpeech(text: String) {
        stopListening()
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            DispatchQueue.main.async {
                self.onFinalTranscription?(cleaned)
            }
        }
    }
    
    // MARK: - Arrêt de l'Écoute
    
    /// Arrête l'écoute microphone
    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.micEnergyLevel = 0.0
            if self.state == .listening {
                self.state = .idle
            }
        }
    }
}
