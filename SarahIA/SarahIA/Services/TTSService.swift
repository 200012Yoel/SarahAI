import Foundation
import AVFoundation
import UIKit
import Combine

/// Événement de visème émis pour animer le morphing facial 3D
public struct VisemeFrame {
    public let jawOpen: Float      // 0.0 à 1.0 (ouverture mâchoire - voyelles ouvertes A/O)
    public let mouthPucker: Float  // 0.0 à 1.0 (lèvres serrées vers l'avant - U/OU/W)
    public let mouthFunnel: Float  // 0.0 à 1.0 (lèvres projetées en rond - O/CH)
    public let mouthSmile: Float   // 0.0 à 1.0 (sourire / étirement - I/E)
    public let amplitude: Float    // Niveau global d'énergie
    
    public static let zero = VisemeFrame(jawOpen: 0, mouthPucker: 0, mouthFunnel: 0, mouthSmile: 0, amplitude: 0)
}

/// Service de synthèse vocale temps réel avec générateur de visèmes et support d'interruption instantanée.
@available(iOS 13.0, *)
public final class TTSService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    public static let shared = TTSService()
    
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var currentSpokenText: String? = nil
    @Published public private(set) var currentViseme: VisemeFrame = .zero
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechInterrupted: (() -> Void)?
    public var onVisemeUpdated: ((VisemeFrame) -> Void)?
    
    private let synthesizer = AVSpeechSynthesizer()
    private var visemeTimer: Timer?
    private var currentUtteranceWords: [String] = []
    private var currentWordIndex: Int = 0
    private var targetJawOpen: Float = 0.0
    private var targetPucker: Float = 0.0
    private var targetFunnel: Float = 0.0
    private var targetSmile: Float = 0.0
    private var speechBgTask: UIBackgroundTaskIdentifier = .invalid
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Synthèse Vocale
    
    /// Synthétise et prononce un texte avec animation de morphing synchronisée
    public func speak(
        text: String,
        language: String = "fr-FR",
        rate: Float = 0.53,
        pitch: Float = 1.15
    ) {
        // Stopper toute lecture en cours
        stopSpeaking()
        
        let cleanedText = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedText.isEmpty else { return }
        
        // 1. Activer la session audio .playback pour contourner le commutateur silencieux de l'iPhone
        AudioSessionManager.shared.configurePlaybackSession()
        
        currentUtteranceWords = cleanedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        
        // 🎙️ SÉLECTION D'UNE VOIX FÉMININE JEUNE ET NATURELLE (100% SANS VOIX D'HOMME)
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let frenchVoices = allVoices.filter { $0.language.starts(with: "fr") }
        
        let maleNames = ["thomas", "nicolas", "paul", "aurelien", "aurélien", "antoine", "remi", "alain"]
        let femaleFrenchVoices = frenchVoices.filter { voice in
            let lower = voice.name.lowercased()
            return !maleNames.contains(where: { lower.contains($0) })
        }
        
        var selectedVoice: AVSpeechSynthesisVoice?
        
        if #available(iOS 16.0, *) {
            selectedVoice = femaleFrenchVoices.first(where: { $0.quality == .premium && ($0.name.contains("Amélie") || $0.name.contains("Amelie") || $0.name.contains("Audrey") || $0.name.contains("Hortense") || $0.name.contains("Chantal")) })
                ?? femaleFrenchVoices.first(where: { $0.quality == .enhanced && ($0.name.contains("Amélie") || $0.name.contains("Amelie") || $0.name.contains("Audrey") || $0.name.contains("Hortense") || $0.name.contains("Chantal")) })
                ?? femaleFrenchVoices.first(where: { $0.quality == .premium && $0.gender == .female })
                ?? femaleFrenchVoices.first(where: { $0.quality == .enhanced && $0.gender == .female })
        } else {
            selectedVoice = femaleFrenchVoices.first(where: { $0.quality == .enhanced && ($0.name.contains("Amélie") || $0.name.contains("Amelie") || $0.name.contains("Audrey") || $0.name.contains("Hortense")) })
                ?? femaleFrenchVoices.first(where: { $0.quality == .enhanced && $0.gender == .female })
        }
        
        let bestVoice = selectedVoice
            ?? femaleFrenchVoices.first(where: { $0.name.contains("Amélie") || $0.name.contains("Amelie") || $0.name.contains("Audrey") || $0.name.contains("Hortense") })
            ?? femaleFrenchVoices.first(where: { $0.gender == .female })
            ?? femaleFrenchVoices.first
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
            ?? AVSpeechSynthesisVoice(language: language)
        
        utterance.voice = bestVoice
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.1 // Rendu chaleureux et féminin
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0
        
        isSpeaking = true
        currentSpokenText = cleanedText
        AudioEngineManager.shared.isTTSCurrentlyActive = true
        
        // Démarrer une assertion de tâche d'arrière-plan pour garantir la parole même écran verrouillé
        beginSpeechBackgroundTask()
        
        startVisemeAnimationLoop()
        onSpeechStarted?()
        
        synthesizer.speak(utterance)
    }
    
    /// Interrompt immédiatement la parole (BARGE-IN / INTERRUPTION INSTANTANÉE)
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        stopVisemeAnimationLoop()
        isSpeaking = false
        currentSpokenText = nil
        AudioEngineManager.shared.isTTSCurrentlyActive = false
        currentViseme = .zero
        onVisemeUpdated?(.zero)
        endSpeechBackgroundTask()
        onSpeechInterrupted?()
    }
    
    // MARK: - Gestion des Tâches d'Arrière-Plan
    
    private func beginSpeechBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
        }
        speechBgTask = UIApplication.shared.beginBackgroundTask(withName: "SarahAI_TTS") { [weak self] in
            self?.endSpeechBackgroundTask()
        }
    }
    
    private func endSpeechBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
            speechBgTask = .invalid
        }
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
            self.stopVisemeAnimationLoop()
            self.isSpeaking = false
            self.currentSpokenText = nil
            AudioEngineManager.shared.isTTSCurrentlyActive = false
            self.currentViseme = .zero
            self.onVisemeUpdated?(.zero)
            self.endSpeechBackgroundTask()
            self.onSpeechFinished?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.stopVisemeAnimationLoop()
            self.isSpeaking = false
            self.currentSpokenText = nil
            AudioEngineManager.shared.isTTSCurrentlyActive = false
            self.currentViseme = .zero
            self.onVisemeUpdated?(.zero)
            self.endSpeechBackgroundTask()
            self.onSpeechInterrupted?()
        }
    }
    
    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let fullString = utterance.speechString as NSString
        guard characterRange.location + characterRange.length <= fullString.length else { return }
        let currentSub = fullString.substring(with: characterRange).lowercased()
        
        // Analyse phonétique simplifiée pour mapping de visèmes
        mapPhonemesToVisemes(currentSub)
    }
    
    // MARK: - Modélisation Phonétique & Moteur de Visèmes
    
    private func mapPhonemesToVisemes(_ token: String) {
        var jaw: Float = 0.3
        var pucker: Float = 0.0
        var funnel: Float = 0.0
        var smile: Float = 0.1
        
        if token.contains("a") || token.contains("à") || token.contains("â") {
            jaw = 0.85
            smile = 0.2
        } else if token.contains("o") || token.contains("ô") || token.contains("au") || token.contains("eau") {
            jaw = 0.65
            funnel = 0.75
            pucker = 0.35
        } else if token.contains("u") || token.contains("ou") || token.contains("w") {
            jaw = 0.35
            pucker = 0.90
            funnel = 0.40
        } else if token.contains("i") || token.contains("y") || token.contains("é") || token.contains("è") {
            jaw = 0.45
            smile = 0.85
            pucker = 0.0
        } else if token.contains("e") || token.contains("eu") {
            jaw = 0.45
            funnel = 0.30
        }
        
        targetJawOpen = jaw
        targetPucker = pucker
        targetFunnel = funnel
        targetSmile = smile
    }
    
    private func startVisemeAnimationLoop() {
        stopVisemeAnimationLoop()
        
        // Boucle d'interpolation 60 Hz pour des mouvements faciaux organiques
        visemeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isSpeaking else { return }
            
            // Modulation d'amplitude avec micro-bruit organique
            let randomFlutter = Float.random(in: 0.85...1.15)
            let currentAmp = self.targetJawOpen * randomFlutter
            
            // Interpolation lisse (LERP) vers les cibles
            let smoothJaw = self.lerp(start: self.currentViseme.jawOpen, end: self.targetJawOpen * randomFlutter, factor: 0.35)
            let smoothPucker = self.lerp(start: self.currentViseme.mouthPucker, end: self.targetPucker, factor: 0.30)
            let smoothFunnel = self.lerp(start: self.currentViseme.mouthFunnel, end: self.targetFunnel, factor: 0.30)
            let smoothSmile = self.lerp(start: self.currentViseme.mouthSmile, end: self.targetSmile, factor: 0.25)
            
            let frame = VisemeFrame(
                jawOpen: min(1.0, max(0.0, smoothJaw)),
                mouthPucker: min(1.0, max(0.0, smoothPucker)),
                mouthFunnel: min(1.0, max(0.0, smoothFunnel)),
                mouthSmile: min(1.0, max(0.0, smoothSmile)),
                amplitude: currentAmp
            )
            
            self.currentViseme = frame
            self.onVisemeUpdated?(frame)
            
            // Décroissance naturelle de la mâchoire entre les syllabes
            self.targetJawOpen *= 0.88
            self.targetPucker *= 0.90
            self.targetFunnel *= 0.90
            self.targetSmile *= 0.92
        }
    }
    
    private func stopVisemeAnimationLoop() {
        visemeTimer?.invalidate()
        visemeTimer = nil
    }
    
    private func lerp(start: Float, end: Float, factor: Float) -> Float {
        return start + (end - start) * factor
    }
}
