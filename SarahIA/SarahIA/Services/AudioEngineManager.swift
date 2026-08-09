import Foundation
import AVFoundation
import Combine

/// Événements d'activité vocale émis par l'AudioEngineManager
public enum VoiceActivityState: Equatable {
    case idle
    case listening(amplitude: Float)
    case userSpeaking(amplitude: Float)
    case bargeInDetected
    case silenceDetected
}

/// Gestionnaire audio temps réel pour capture micro, VAD et barge-in interruption.
public final class AudioEngineManager: NSObject, ObservableObject {
    
    public static let shared = AudioEngineManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentInputLevel: Float = 0.0
    @Published public private(set) var isUserSpeaking: Bool = false
    
    // MARK: - Configuration & Thresholds
    public var vadEnergyThreshold: Float = 0.045 // Seuil RMS de détection de voix
    public var silenceDurationThreshold: TimeInterval = 1.4 // Secondes de silence pour fin de phrase
    public var isTTSCurrentlyActive: Bool = false // Marqueur quand Sarah parle
    
    // MARK: - Callbacks
    public var onVoiceActivityChanged: ((VoiceActivityState) -> Void)?
    public var onBargeInTriggered: (() -> Void)?
    public var onSpeechEnded: (([Float]) -> Void)?
    public var onAudioBufferCaptured: ((AVAudioPCMBuffer) -> Void)?
    
    // MARK: - Internal Audio Components
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    private var accumulatedAudioSamples: [Float] = []
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private var consecutiveVoiceFrames: Int = 0
    private let requiredConsecutiveFramesForOnset: Int = 3
    
    private override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        stopAudioEngine()
    }
    
    // MARK: - Configuration de la Session Audio
    
    /// Configure la session audio pour lecture/enregistrement simultané avec support arrière-plan
    public func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .allowAirPlay
                ]
            )
            try session.setPreferredIOBufferDuration(0.02) // 20ms basse latence
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [AudioEngineManager] Erreur configuration AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Démarrage et Arrêt du Moteur Audio
    
    /// Démarre la capture micro et l'analyse VAD en temps réel
    public func startAudioEngine() {
        guard !audioEngine.isRunning else { return }
        
        setupAudioSession()
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            print("❌ [AudioEngineManager] Impossible d'accéder au nœud d'entrée audio.")
            return
        }
        
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            if let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                recordingFormat = fallbackFormat
            }
        }
        self.audioFormat = recordingFormat
        
        // Installer le Tap audio (buffer size 1024 frames = ~23ms à 44.1kHz)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRunning = true
            }
            print("🎙️ [AudioEngineManager] Moteur audio démarré avec succès.")
        } catch {
            print("❌ [AudioEngineManager] Erreur démarrage AVAudioEngine: \(error.localizedDescription)")
        }
    }
    
    /// Arrête le moteur audio
    public func stopAudioEngine() {
        if audioEngine.isRunning {
            inputNode?.removeTap(onBus: 0)
            audioEngine.stop()
            DispatchQueue.main.async {
                self.isRunning = false
                self.currentInputLevel = 0.0
                self.isUserSpeaking = false
            }
        }
    }
    
    // MARK: - Traitement du Signal Audio & VAD
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        // Calcul du RMS (Root Mean Square) pour l'énergie sonore
        var sumSquares: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameLength))
        let normalizedLevel = min(1.0, max(0.0, rms * 8.0))
        
        DispatchQueue.main.async {
            self.currentInputLevel = normalizedLevel
        }
        
        // Transmettre le buffer brut pour le streaming Whisper
        onAudioBufferCaptured?(buffer)
        
        // Évaluation VAD
        let isVoiceDetected = rms > vadEnergyThreshold
        
        if isVoiceDetected {
            consecutiveVoiceFrames += 1
            lastSpeechTime = Date()
            
            if consecutiveVoiceFrames >= requiredConsecutiveFramesForOnset {
                if !isUserSpeaking {
                    // Début de prise de parole détectée
                    speechStartTime = Date()
                    DispatchQueue.main.async {
                        self.isUserSpeaking = true
                    }
                    
                    // --- BARGE-IN INTERRUPTION ---
                    // Si l'utilisateur parle pendant que Sarah est en train de parler
                    if isTTSCurrentlyActive {
                        print("⚡ [AudioEngineManager] BARGE-IN! L'utilisateur a interrompu Sarah.")
                        DispatchQueue.main.async {
                            self.onBargeInTriggered?()
                            self.onVoiceActivityChanged?(.bargeInDetected)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.onVoiceActivityChanged?(.userSpeaking(amplitude: normalizedLevel))
                }
            }
        } else {
            consecutiveVoiceFrames = max(0, consecutiveVoiceFrames - 1)
            
            if isUserSpeaking {
                if let lastTime = lastSpeechTime, Date().timeIntervalSince(lastTime) > silenceDurationThreshold {
                    // Fin de parole / Silence détecté après une prise de parole
                    DispatchQueue.main.async {
                        self.isUserSpeaking = false
                        self.onVoiceActivityChanged?(.silenceDetected)
                    }
                    consecutiveVoiceFrames = 0
                } else {
                    DispatchQueue.main.async {
                        self.onVoiceActivityChanged?(.listening(amplitude: normalizedLevel))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.onVoiceActivityChanged?(.listening(amplitude: normalizedLevel))
                }
            }
        }
    }
    
    // MARK: - Gestion des Interruptions Système
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("ℹ️ [AudioEngineManager] Interruption audio commencée.")
            stopAudioEngine()
        case .ended:
            print("ℹ️ [AudioEngineManager] Interruption audio terminée. Redémarrage.")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    startAudioEngine()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        setupAudioSession()
    }
}
