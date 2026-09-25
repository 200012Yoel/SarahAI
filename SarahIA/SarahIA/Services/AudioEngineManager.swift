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
///
/// IMPORTANT : ce composant ne possède plus AVAudioSession. Toute la configuration
/// de catégorie, mode, activation et route passe par AudioSessionManager afin
/// d'éviter que plusieurs services se battent pour la sortie audio de l'iPhone.
@available(iOS 13.0, *)
public final class AudioEngineManager: NSObject, ObservableObject {
    
    public static let shared = AudioEngineManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentInputLevel: Float = 0.0
    @Published public private(set) var isUserSpeaking: Bool = false
    @Published public private(set) var hasMicrophonePermission: Bool = false
    
    // MARK: - Configuration & Thresholds
    public var vadEnergyThreshold: Float = 0.040
    public var silenceDurationThreshold: TimeInterval = 1.2
    public var isTTSCurrentlyActive: Bool = false
    
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
    private let requiredConsecutiveFramesForOnset: Int = 2
    
    private var lastLevelUpdateTime: TimeInterval = 0
    private let audioProcessingQueue = DispatchQueue(label: "com.sarahia.audioprocessing", qos: .userInteractive)
    
    private override init() {
        super.init()
        checkInitialPermission()
        setupNotifications()
    }
    
    deinit {
        stopAudioEngine()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkInitialPermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        self.hasMicrophonePermission = (status == .granted)
    }
    
    // MARK: - Session Audio centralisée
    
    /// Ne configure jamais AVAudioSession directement. En mode vocal continu,
    /// on conserve exactement la même session écouter -> répondre -> écouter.
    /// Hors mode vocal, on demande simplement une session d'enregistrement.
    public func setupAudioSession() {
        if AudioSessionManager.shared.isContinuousVoiceSessionActive {
            AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
        } else {
            AudioSessionManager.shared.configureRecordingSession()
        }
    }
    
    // MARK: - Gestion des Permissions & Démarrage
    
    public func requestPermissionAndStart(completion: ((Bool) -> Void)? = nil) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            self.hasMicrophonePermission = true
            self.startAudioEngine()
            completion?(true)
        case .denied:
            self.hasMicrophonePermission = false
            print("⚠️ [AudioEngineManager] Permission microphone refusée par l'utilisateur.")
            completion?(false)
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                    if granted {
                        self?.startAudioEngine()
                    }
                    completion?(granted)
                }
            }
        @unknown default:
            completion?(false)
        }
    }
    
    /// Démarre la capture micro et l'analyse VAD en temps réel.
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
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.audioProcessingQueue.async {
                self?.processAudioBuffer(buffer)
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRunning = true
            }
            print("🎙️ [AudioEngineManager] Moteur audio démarré avec la session centralisée.")
        } catch {
            inputNode.removeTap(onBus: 0)
            print("❌ [AudioEngineManager] Erreur démarrage AVAudioEngine: \(error.localizedDescription)")
        }
    }
    
    /// Arrête uniquement le moteur de capture. La session audio appartient à
    /// AudioSessionManager et n'est donc jamais désactivée ici.
    public func stopAudioEngine() {
        if audioEngine.isRunning {
            inputNode?.removeTap(onBus: 0)
            audioEngine.stop()
        }
        DispatchQueue.main.async {
            self.isRunning = false
            self.currentInputLevel = 0.0
            self.isUserSpeaking = false
        }
    }
    
    public func toggleAudioEngine() {
        if isRunning {
            stopAudioEngine()
        } else {
            requestPermissionAndStart()
        }
    }
    
    // MARK: - Traitement du Signal Audio & VAD
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        var sumSquares: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameLength))
        let normalizedLevel = min(1.0, max(0.0, rms * 9.0))
        
        let now = CACurrentMediaTime()
        if now - lastLevelUpdateTime > 0.033 {
            lastLevelUpdateTime = now
            DispatchQueue.main.async {
                self.currentInputLevel = normalizedLevel
            }
        }
        
        onAudioBufferCaptured?(buffer)
        
        let isVoiceDetected = rms > vadEnergyThreshold
        
        if isVoiceDetected {
            consecutiveVoiceFrames += 1
            lastSpeechTime = Date()
            
            if consecutiveVoiceFrames >= requiredConsecutiveFramesForOnset {
                if !isUserSpeaking {
                    speechStartTime = Date()
                    DispatchQueue.main.async {
                        self.isUserSpeaking = true
                    }
                    
                    if isTTSCurrentlyActive {
                        print("⚡ [AudioEngineManager] BARGE-IN utilisateur détecté.")
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
                if let lastTime = lastSpeechTime,
                   Date().timeIntervalSince(lastTime) > silenceDurationThreshold {
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
    
    // MARK: - Interruptions système
    
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
            print("ℹ️ [AudioEngineManager] Interruption audio réelle commencée.")
            stopAudioEngine()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard options.contains(.shouldResume) else { return }
            print("ℹ️ [AudioEngineManager] Interruption terminée, restauration centralisée.")
            if AudioSessionManager.shared.isContinuousVoiceSessionActive {
                AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
            }
            startAudioEngine()
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        // Un changement de route (haut-parleur, Bluetooth, écouteurs) ne doit plus
        // recréer la catégorie audio. On laisse le gestionnaire central restaurer
        // la session uniquement si le vocal continu est réellement actif.
        guard AudioSessionManager.shared.isContinuousVoiceSessionActive else { return }
        AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
    }
}
