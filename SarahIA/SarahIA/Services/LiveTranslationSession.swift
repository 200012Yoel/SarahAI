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
    @Published public private(set) var isUsingWatchMicrophone = false
    @Published public private(set) var isAwaitingWatchMicrophone = false

    /// Une notification acceptée affiche l'écran, sans déclencher le micro
    /// de l'iPhone avant la connexion du microphone Apple Watch.
    public func prepareForWatchCall() {
        isAwaitingWatchMicrophone = true
    }
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
        // Conserve la paire choisie même après fermeture de Sarah IA.
        if let source = UserDefaults.standard.string(forKey: "sarah.live.sourceLanguage"),
           let target = UserDefaults.standard.string(forKey: "sarah.live.targetLanguage"),
           LiveLanguagePair.supportedLanguageCodes.contains(source),
           LiveLanguagePair.supportedLanguageCodes.contains(target),
           source != target {
            languagePair = LiveLanguagePair(sourceLanguage: source, targetLanguage: target)
        }
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
        isAwaitingWatchMicrophone = false
        isUsingWatchMicrophone = false
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

    /// Démarré depuis la montre : aucun micro iPhone ne doit être ouvert.
    public func startFromWatch() {
        isAwaitingWatchMicrophone = false
        if isActive && isUsingWatchMicrophone { return }
        if isActive { stop() }

        startupEpoch &+= 1
        isStarting = false
        lastError = nil
        MultiAgentVoiceManager.shared.stop()
        WhisperSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.endContinuousVoiceSession()

        isMuted = false
        muteLock.lock()
        audioThreadMuted = false
        muteLock.unlock()

        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .default, options: [])
            try audio.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Haut-parleur iPhone indisponible : \(error.localizedDescription)"
        }

        // Respecter exactement les langues déjà choisies dans la vue iPhone.
        // La Watch fournit le micro, elle ne force plus hébreu -> français.
        isUsingWatchMicrophone = true
        isActive = true
        pipeline.startPipeline(with: languagePair)
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    /// Buffers Int16 mono / 16 kHz reçus de l'Apple Watch via WatchConnectivity.
    /// On recycle exactement le pipeline Whisper/Apple/Google/voix déjà présent.
    public func receiveWatchPCM(_ data: Data) {
        guard isActive, isUsingWatchMicrophone, !isMuted,
              !data.isEmpty, data.count.isMultiple(of: 2),
              data.count <= 16_000 else { return }

        let count = data.count / 2
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: 16_000,
                                          channels: 1,
                                          interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(count)),
              let channel = buffer.floatChannelData?[0] else { return }

        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for i in 0..<count {
                let low = UInt16(bytes[2 * i])
                let high = UInt16(bytes[2 * i + 1]) << 8
                channel[i] = Float(Int16(bitPattern: low | high)) / 32768.0
            }
        }
        buffer.frameLength = AVAudioFrameCount(count)
        pipeline.processMicrophoneBuffer(buffer)
    }

    public func stop() {
        isAwaitingWatchMicrophone = false
        startupEpoch &+= 1
        isStarting = false
        guard isActive else { return }
        let wasWatch = isUsingWatchMicrophone
        isUsingWatchMicrophone = false
        if wasWatch { WatchAudioBridge.shared.sendStop() }
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
        guard pair.sourceLanguage != pair.targetLanguage,
              LiveLanguagePair.supportedLanguageCodes.contains(pair.sourceLanguage),
              LiveLanguagePair.supportedLanguageCodes.contains(pair.targetLanguage) else { return }
        languagePair = pair
        UserDefaults.standard.set(pair.sourceLanguage, forKey: "sarah.live.sourceLanguage")
        UserDefaults.standard.set(pair.targetLanguage, forKey: "sarah.live.targetLanguage")
        if isActive {
            pipeline.updateLanguagePair(pair)
        }
        // La même paire reste visible sur la Watch, même si le micro Watch est arrêté.
        WatchAudioBridge.shared.sendLanguagePair(pair)
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
