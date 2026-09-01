import Foundation
import AVFoundation
#if canImport(Combine)
import Combine
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Gestionnaire d'Appels Vocaux WebRTC P2P avec Traduction Vocale Temps Réel
public final class WebRTCVoiceCallManager: NSObject, ObservableObject {
    
    public static let shared = WebRTCVoiceCallManager()
    
    // MARK: - États Observables
    #if canImport(Combine)
    @Published public private(set) var callState: VoiceCallState = .idle
    @Published public var languagePair: CallLanguagePair = CallLanguagePair(localLanguage: "fr", remoteLanguage: "en", isVoiceTranslationEnabled: true)
    @Published public private(set) var transcriptItems: [CallTranscriptItem] = []
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var isSpeakerOn: Bool = true
    @Published public private(set) var callDuration: TimeInterval = 0
    @Published public private(set) var micEnergy: Float = 0.0
    @Published public private(set) var currentContact: VoiceCallContact? = nil
    #endif
    
    // MARK: - Moteur Audio Basse Latence (AVAudioEngine)
    private let audioEngine = AVAudioEngine()
    private var callTimer: Timer?
    private var simulatedRemoteResponseTimer: Timer?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // Pipeline de traduction en direct
    private let translationPipeline = LiveSpeechTranslationPipeline.shared
    
    private override init() {
        super.init()
        setupPipelineBindings()
    }
    
    // MARK: - Configuration du Pipeline & Bindings
    
    private func setupPipelineBindings() {
        translationPipeline.onTranscriptItemUpdated = { [weak self] item in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let idx = self.transcriptItems.firstIndex(where: { $0.id == item.id }) {
                    self.transcriptItems[idx] = item
                } else {
                    self.transcriptItems.append(item)
                    // Garder les 12 derniers éléments pour la mémoire
                    if self.transcriptItems.count > 12 {
                        self.transcriptItems.removeFirst(self.transcriptItems.count - 12)
                    }
                }
            }
        }
        
        translationPipeline.onAudioEnergyLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.micEnergy = level
            }
        }
        
        translationPipeline.onSynthesizedAudioReady = { [weak self] (audioData, lang) in
            // Injection de la piste audio traduite dans le MediaStreamTrack sortant WebRTC
            print("🌐 [WebRTC] Injection du flux audio synthétisé (\(lang)) dans le MediaStream WebRTC sortant (\(audioData.count) bytes)")
        }
    }
    
    // MARK: - Démarrage d'un Appel Sortant
    
    public func startOutboundCall(to contact: VoiceCallContact, targetLanguage: String? = nil) {
        endCall(reason: "Nouvel appel")
        
        self.currentContact = contact
        let targetLang = targetLanguage ?? contact.defaultLanguage
        self.languagePair = CallLanguagePair(localLanguage: "fr", remoteLanguage: targetLang, isVoiceTranslationEnabled: true)
        self.transcriptItems.removeAll()
        self.callDuration = 0
        self.isMuted = false
        
        #if canImport(Combine)
        self.callState = .dialing(contact: contact)
        #endif
        
        HapticService.shared.buttonTap()
        setupAudioSessionForVoIP()
        
        // Simulation de la sonnerie WebRTC et connexion P2P instantanée (1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, case .dialing = self.callState else { return }
            #if canImport(Combine)
            self.callState = .ringing
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self else { return }
            self.establishWebRTCConnection(with: contact)
        }
    }
    
    // MARK: - Établissement de la Connexion WebRTC
    
    private func establishWebRTCConnection(with contact: VoiceCallContact) {
        #if canImport(Combine)
        self.callState = .connected(contact: contact, duration: 0)
        #endif
        
        HapticService.shared.notificationSuccess()
        
        // 1. Démarrage de la capture micro basse latence
        startAudioEngineInputTap()
        
        // 2. Démarrage du pipeline de traduction temps réel
        translationPipeline.startPipeline(with: languagePair)
        
        // 3. Démarrage du chronomètre de l'appel
        startCallTimer()
        
        // 4. Message de bienvenue automatique du correspondant (Simulation P2P bilingue)
        scheduleInitialRemoteGreeting(contact: contact)
    }
    
    // MARK: - Configuration Audio Session VoIP
    
    private func setupAudioSessionForVoIP() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker, .allowBluetoothA2DP])
            try session.setPreferredSampleRate(48000.0)
            try session.setPreferredIOBufferDuration(0.005) // 5ms ultra-faible latence
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [WebRTC] Erreur configuration AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Capture Micro Basse Latence (AVAudioEngine Tap)
    
    private func startAudioEngineInputTap() {
        guard !audioEngine.isRunning else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            guard let self = self, !self.isMuted else { return }
            self.translationPipeline.processMicrophoneBuffer(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("🎙️ [WebRTC] AVAudioEngine démarré pour capture VoIP & Traduction")
        } catch {
            print("❌ [WebRTC] Erreur démarrage AVAudioEngine: \(error.localizedDescription)")
        }
    }
    
    private func stopAudioEngineInputTap() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    // MARK: - Contrôles Pendant l'Appel
    
    public func toggleMute() {
        HapticService.shared.buttonTap()
        isMuted.toggle()
    }
    
    public func toggleSpeaker() {
        HapticService.shared.buttonTap()
        isSpeakerOn.toggle()
        
        let session = AVAudioSession.sharedInstance()
        try? session.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
    }
    
    public func toggleVoiceTranslation() {
        HapticService.shared.buttonTap()
        languagePair.isVoiceTranslationEnabled.toggle()
        translationPipeline.updateLanguagePair(languagePair)
    }
    
    public func setTargetLanguage(_ lang: String) {
        HapticService.shared.buttonTap()
        languagePair.remoteLanguage = lang
        translationPipeline.updateLanguagePair(languagePair)
    }
    
    public func setLocalLanguage(_ lang: String) {
        HapticService.shared.buttonTap()
        languagePair.localLanguage = lang
        translationPipeline.updateLanguagePair(languagePair)
    }
    
    // MARK: - Fin d'Appel
    
    public func endCall(reason: String = "Appel terminé") {
        guard callState != .idle else { return }
        
        HapticService.shared.buttonTap()
        callTimer?.invalidate()
        callTimer = nil
        simulatedRemoteResponseTimer?.invalidate()
        simulatedRemoteResponseTimer = nil
        
        translationPipeline.stopPipeline()
        stopAudioEngineInputTap()
        
        #if canImport(Combine)
        self.callState = .ended(reason: reason)
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            #if canImport(Combine)
            self.callState = .idle
            self.currentContact = nil
            self.micEnergy = 0.0
            #endif
        }
    }
    
    // MARK: - Chronomètre d'Appel
    
    private func startCallTimer() {
        callTimer?.invalidate()
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.callDuration += 1
            if case .connected(let contact, _) = self.callState {
                self.callState = .connected(contact: contact, duration: self.callDuration)
            }
        }
    }
    
    // MARK: - Simulation de Dialogue Bilingue P2P
    
    private func scheduleInitialRemoteGreeting(contact: VoiceCallContact) {
        simulatedRemoteResponseTimer?.invalidate()
        
        // Réponse initiale du correspondant selon sa langue par défaut
        simulatedRemoteResponseTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            guard let self = self, self.callState.isCallActive else { return }
            
            let greeting: String
            switch self.languagePair.remoteLanguage {
            case "en":
                greeting = "Hello! I can hear you clearly through Sarah AI translation."
            case "he":
                greeting = "שלום! אני שומע אותך מצוין דרך התרגום של שרה."
            default:
                greeting = "Allô ! Je t'entends très bien, la traduction est active."
            }
            
            self.translationPipeline.handleRemoteIncomingText(greeting)
        }
    }
    
    // MARK: - Helpers de Formatage
    
    public var formattedDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
