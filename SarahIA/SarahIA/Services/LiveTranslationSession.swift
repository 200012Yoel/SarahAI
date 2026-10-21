import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Session de traduction en direct : micro → reconnaissance → traduction → voix.
/// Aucune notion d'appel : on ouvre l'écran, on parle, Sarah traduit.
public final class LiveTranslationSession: ObservableObject {

    public static let shared = LiveTranslationSession()

    @Published public private(set) var isActive = false
    @Published public private(set) var languagePair = LiveLanguagePair()
    @Published public private(set) var items: [LiveTranscriptItem] = []
    @Published public private(set) var micEnergy: Float = 0
    @Published public private(set) var isMuted = false
    @Published public private(set) var lastError: String?

    private let audioEngine = AVAudioEngine()
    private let pipeline = LiveSpeechTranslationPipeline.shared
    private let maxItems = 30
    // Invalide une autorisation micro qui arrive après la fermeture de la vue.
    private var startupEpoch = 0
    private var isStarting = false

    /// Lu depuis le thread audio.
    private let muteLock = NSLock()
    private var audioThreadMuted = false

    private init() {
        pipeline.onTranscriptItemUpdated = { [weak self] item in
            self?.upsert(item)
        }
        pipeline.onAudioEnergyLevel = { [weak self] level in
            self?.micEnergy = level
        }
    }

    /// Moteur de reconnaissance actuellement utilisé (« Apple » ou « Whisper (hors ligne) »).
    public var recognitionModeLabel: String {
        pipeline.currentRecognitionMode.rawValue
    }

    // MARK: - Démarrage / arrêt

    public func start() {
        guard !isActive && !isStarting else { return }
        isStarting = true
        startupEpoch &+= 1
        let epoch = startupEpoch
        lastError = nil

        // Ferme le micro du chat avant d'ouvrir celui de la traduction.
        // Deux AVAudioEngine actifs étaient susceptibles de monopoliser l'entrée audio.
        MultiAgentVoiceManager.shared.stop()
        WhisperSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.endContinuousVoiceSession()
        isMuted = false
        muteLock.lock()
        audioThreadMuted = false
        muteLock.unlock()

        requestMicrophonePermission { [weak self] granted in
            guard let self = self, self.startupEpoch == epoch else { return }
            self.isStarting = false
            guard granted else {
                self.lastError = "Autorise le micro dans Réglages > Sarah IA pour utiliser la traduction en direct."
                return
            }
            self.configureAudioSession()
            guard self.startAudioEngine() else { return }
            self.pipeline.startPipeline(with: self.languagePair)
            self.isActive = true
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
    }

    public func stop() {
        startupEpoch &+= 1
        isStarting = false
        guard isActive else { return }
        pipeline.stopPipeline()
        stopAudioEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isActive = false
        micEnergy = 0
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    public func clearTranscript() {
        items.removeAll()
    }

    // MARK: - Contrôles

    public func toggleMute() {
        HapticService.shared.buttonTap()
        isMuted.toggle()
        muteLock.lock()
        audioThreadMuted = isMuted
        muteLock.unlock()
        if isMuted { micEnergy = 0 }
    }

    public func toggleVoice() {
        HapticService.shared.buttonTap()
        languagePair.isVoiceEnabled.toggle()
        pipeline.updateLanguagePair(languagePair)
    }

    /// Inverse les langues (hébreu → français ⇄ français → hébreu).
    public func swapLanguages() {
        HapticService.shared.buttonTap()
        setLanguages(languagePair.swapped)
    }

    public func setLanguages(_ pair: LiveLanguagePair) {
        languagePair = pair
        if isActive {
            pipeline.startPipeline(with: pair)
        }
    }

    // MARK: - Transcription

    private func upsert(_ item: LiveTranscriptItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
            if items.count > maxItems {
                items.removeFirst(items.count - maxItems)
            }
        }
    }

    // MARK: - Audio

    private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        default:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // HFP permet le micro des écouteurs ; A2DP permet la lecture de la
            // traduction dans les écouteurs avec le micro de l'iPhone.
            // Ce sont des routes iOS standards, pas une API AirPods privée.
            let hasAirPods = AirPodsTranslationSupport.connectedName != nil
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            // 20 ms : limite les réveils CPU et la chauffe sans dégrader les voix parlées.
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            if hasAirPods,
               let phoneMicrophone = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                // Une personne près de l'iPhone doit être entendue, même si
                // l'utilisateur reçoit la traduction dans ses AirPods.
                do { try session.setPreferredInput(phoneMicrophone) }
                catch { print("⚠️ [Traduction] Micro iPhone indisponible : \(error.localizedDescription)") }
            }
        } catch {
            print("⚠️ [Traduction] Session audio : \(error.localizedDescription)")
        }
    }

    private func startAudioEngine() -> Bool {
        if audioEngine.isRunning { return true }

        let inputNode = audioEngine.inputNode

        // Annulation d'écho et réduction de bruit d'iOS (à activer avant de lire le format)
        do {
            try inputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("⚠️ [Traduction] Annulation d'écho indisponible : \(error.localizedDescription)")
        }

        // L'annulation d'écho d'iOS baisse fortement le volume des autres sons, y compris la voix
        // de Sarah : on désactive cette atténuation pour que la traduction reste bien audible.
        if #available(iOS 17.0, *) {
            inputNode.voiceProcessingOtherAudioDuckingConfiguration =
                AVAudioVoiceProcessingOtherAudioDuckingConfiguration(enableAdvancedDucking: false, duckingLevel: .min)
        }

        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            lastError = "Micro indisponible."
            return false
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.muteLock.lock()
            let muted = self.audioThreadMuted
            self.muteLock.unlock()
            guard !muted else { return }
            self.pipeline.processMicrophoneBuffer(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            return true
        } catch {
            inputNode.removeTap(onBus: 0)
            lastError = "Impossible de démarrer le micro : \(error.localizedDescription)"
            return false
        }
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
