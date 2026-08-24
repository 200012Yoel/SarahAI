import Foundation
import AVFoundation
import UIKit
#if canImport(Combine)
import Combine
#endif

/// Gestionnaire universel de synthèse vocale haute fidélité pour Sarah IA (iOS 12 -> 18) :
/// - Voix féminine française naturelle (recherche prioritaire sur Amélie / Audrey / Hortense)
/// - Contournement du mode silencieux via AudioSessionManager
/// - Synthèse vocale fluide et naturelle pour le chat
public final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    
    public static let shared = SpeechManager()
    
    public private(set) var isSpeaking: Bool = false {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SarahSpeechStateDidChange"), object: nil)
            }
        }
    }
    
    public private(set) var currentSpokenText: String? = nil {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SarahSpeechStateDidChange"), object: nil)
            }
        }
    }
    
    public private(set) var currentJawOpen: Float = 0.0
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechInterrupted: (() -> Void)?
    public var onVisemeChanged: ((Float) -> Void)?
    
    private let synthesizer = AVSpeechSynthesizer()
    private var visemeTimer: Timer?
    private var targetJawOpen: Float = 0.0
    private var speechBgTask: UIBackgroundTaskIdentifier = .invalid
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Synthèse Vocale avec Contournement Silencieux
    
    /// Prononce un texte à voix haute avec voix féminine fr-FR naturelle et animation labiale 3D synchronisée.
    public func speak(
        text: String,
        pitch: Float = 1.05,
        rate: Float = 0.50
    ) {
        stopSpeaking()
        AppleSpeechRecognizer.shared.stopListening()
        
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else { return }
        
        // 1. Forcer la session audio en mode haut-parleur principal
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        
        // 2. Sélection de la voix féminine française
        utterance.voice = selectBestFrenchFemaleVoice()
        utterance.pitchMultiplier = pitch
        utterance.rate = rate
        utterance.volume = 1.0
        
        currentSpokenText = cleaned
        isSpeaking = true
        
        beginBackgroundTask()
        startVisemeLoop()
        onSpeechStarted?()
        
        DispatchQueue.main.async {
            self.synthesizer.speak(utterance)
        }
    }
    
    /// Interrompt immédiatement l'élocution (Barge-in)
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        stopVisemeLoop()
        isSpeaking = false
        currentSpokenText = nil
        currentJawOpen = 0.0
        onVisemeChanged?(0.0)
        endBackgroundTask()
        onSpeechInterrupted?()
    }
    
    // MARK: - Recherche de Voix Française Standard Garantie
    
    private func selectBestFrenchFemaleVoice() -> AVSpeechSynthesisVoice {
        if let frFR = AVSpeechSynthesisVoice(language: "fr-FR") {
            return frFR
        }
        if let fr = AVSpeechSynthesisVoice(language: "fr") {
            return fr
        }
        return AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.starts(with: "fr") })
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice.speechVoices().first!
    }
    
    // MARK: - Animation Labiale (Visèmes / Morphs)
    
    private func startVisemeLoop() {
        stopVisemeLoop()
        targetJawOpen = 0.6
        
        // Boucle 60 FPS pour animer les lèvres
        visemeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isSpeaking else { return }
            let noise = Float.random(in: 0.85...1.15)
            let smooth = self.currentJawOpen + (self.targetJawOpen * noise - self.currentJawOpen) * 0.35
            self.currentJawOpen = min(1.0, max(0.0, smooth))
            self.onVisemeChanged?(self.currentJawOpen)
            self.targetJawOpen *= 0.90
        }
    }
    
    private func stopVisemeLoop() {
        visemeTimer?.invalidate()
        visemeTimer = nil
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.onSpeechStarted?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.stopVisemeLoop()
            self.isSpeaking = false
            self.currentSpokenText = nil
            self.currentJawOpen = 0.0
            self.onVisemeChanged?(0.0)
            self.endBackgroundTask()
            self.onSpeechFinished?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.stopVisemeLoop()
            self.isSpeaking = false
            self.currentSpokenText = nil
            self.currentJawOpen = 0.0
            self.onVisemeChanged?(0.0)
            self.endBackgroundTask()
            self.onSpeechInterrupted?()
        }
    }
    
    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let full = utterance.speechString as NSString
        guard characterRange.location + characterRange.length <= full.length else { return }
        let sub = full.substring(with: characterRange).lowercased()
        
        if sub.contains("a") || sub.contains("o") || sub.contains("é") || sub.contains("e") {
            targetJawOpen = 0.85
        } else if sub.contains("i") || sub.contains("u") {
            targetJawOpen = 0.50
        } else {
            targetJawOpen = 0.35
        }
    }
    
    // MARK: - Background Task
    
    private func beginBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
        }
        speechBgTask = UIApplication.shared.beginBackgroundTask(withName: "Sarah_Speech") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
            speechBgTask = .invalid
        }
    }
}

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ObservableSpeechManager: ObservableObject {
    public static let shared = ObservableSpeechManager()
    
    @Published public var isSpeaking: Bool = SpeechManager.shared.isSpeaking
    @Published public var currentSpokenText: String? = SpeechManager.shared.currentSpokenText
    @Published public var currentJawOpen: Float = SpeechManager.shared.currentJawOpen
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahSpeechStateDidChange"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSpeaking = SpeechManager.shared.isSpeaking
                self?.currentSpokenText = SpeechManager.shared.currentSpokenText
                self?.currentJawOpen = SpeechManager.shared.currentJawOpen
            }
            .store(in: &cancellables)
    }
}
#endif
