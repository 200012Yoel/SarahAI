import Foundation
import AVFoundation
import UIKit

/// Gestionnaire de Synthèse Vocale Multi-Personnages (Sarah & Tom)
/// - Sarah : Voix féminine naturelle française (Siri / Amélie / Audrey)
/// - Tom : Voix masculine française pour le mode Caméra & Vision (Siri Male / Thomas / Nicolas)
/// - Transition fluide par handoff : "Ah, tu utilises la caméra, je te laisse avec Tom"
public final class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    
    public static let shared = TTSManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var isPlayingSequence = false
    private var sequenceQueue: [() -> Void] = []
    
    // Voix Mémorisées
    private var sarahVoice: AVSpeechSynthesisVoice?
    private var tomVoice: AVSpeechSynthesisVoice?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        setupVoiceProfiles()
    }
    
    // MARK: - Initialisation des Profils Vocaux
    
    private func setupVoiceProfiles() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let frenchVoices = allVoices.filter { $0.language.starts(with: "fr") }
        let maleNames = ["thomas", "nicolas", "paul", "aurelien", "aurélien", "antoine", "remi", "alain", "pierre"]
        
        // 1. Profil Tom (Masculin)
        let maleFrenchVoices = frenchVoices.filter { voice in
            let lower = voice.name.lowercased()
            if #available(iOS 13.0, *) {
                return maleNames.contains(where: { lower.contains($0) }) || voice.gender == .male
            }
            return maleNames.contains(where: { lower.contains($0) })
        }
        
        if #available(iOS 16.0, *) {
            tomVoice = maleFrenchVoices.first(where: { $0.quality == .premium && $0.gender == .male })
                ?? maleFrenchVoices.first(where: { $0.quality == .enhanced && $0.gender == .male })
                ?? maleFrenchVoices.first(where: { $0.name.contains("Thomas") || $0.name.contains("Nicolas") })
                ?? maleFrenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        } else if #available(iOS 13.0, *) {
            tomVoice = maleFrenchVoices.first(where: { $0.gender == .male })
                ?? maleFrenchVoices.first(where: { $0.name.contains("Thomas") || $0.name.contains("Nicolas") })
                ?? maleFrenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        } else {
            tomVoice = maleFrenchVoices.first(where: { $0.name.contains("Thomas") || $0.name.contains("Nicolas") })
                ?? maleFrenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        }
        
        // 2. Profil Sarah (Féminin)
        let femaleFrenchVoices = frenchVoices.filter { voice in
            let lower = voice.name.lowercased()
            if #available(iOS 13.0, *) {
                return !maleNames.contains(where: { lower.contains($0) }) && voice.gender != .male
            }
            return !maleNames.contains(where: { lower.contains($0) })
        }
        
        if #available(iOS 16.0, *) {
            sarahVoice = femaleFrenchVoices.first(where: { $0.quality == .premium && ($0.name.contains("Amélie") || $0.name.contains("Audrey")) })
                ?? femaleFrenchVoices.first(where: { $0.quality == .enhanced && ($0.name.contains("Amélie") || $0.name.contains("Audrey")) })
                ?? femaleFrenchVoices.first(where: { $0.gender == .female })
                ?? femaleFrenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        } else if #available(iOS 13.0, *) {
            sarahVoice = femaleFrenchVoices.first(where: { $0.gender == .female })
                ?? femaleFrenchVoices.first(where: { $0.name.contains("Amélie") || $0.name.contains("Audrey") })
                ?? femaleFrenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        } else {
            sarahVoice = femaleFrenchVoices.first(where: { $0.name.contains("Amélie") || $0.name.contains("Audrey") })
                ?? femaleFrenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        }
    }
    
    // MARK: - Passage de Témoin / Accueil Caméra Instantané
    
    /// Accueil vocal instantané en mode Caméra sans attente ni retard
    public func handOffToTom(
        sarahTransitionPhrase: String = "Je regarde ce que tu me montres.",
        tomGreeting: String = "",
        onCompleted: (() -> Void)? = nil
    ) {
        stop()
        
        // Configuration immédiate de la session audio
        AudioSessionManager.shared.configurePlaybackSession()
        
        let phrase = sarahTransitionPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phrase.isEmpty {
            speak(text: phrase, voice: sarahVoice, pitch: 1.12, rate: 0.53)
        }
        
        if !tomGreeting.isEmpty {
            sequenceQueue.append { [weak self] in
                guard let self = self else { return }
                self.speak(text: tomGreeting, voice: self.tomVoice, pitch: 0.95, rate: 0.52)
                if let completion = onCompleted {
                    self.sequenceQueue.append(completion)
                }
            }
        } else if let completion = onCompleted {
            sequenceQueue.append(completion)
        }
    }
    
    // MARK: - Énonciation Dédiée
    
    public func speakAsSarah(_ text: String) {
        stop()
        AudioSessionManager.shared.configurePlaybackSession()
        speak(text: text, voice: sarahVoice, pitch: 1.12, rate: 0.53)
    }
    
    public func speakAsTom(_ text: String) {
        stop()
        AudioSessionManager.shared.configurePlaybackSession()
        speak(text: text, voice: tomVoice, pitch: 0.95, rate: 0.52)
    }
    
    private func speak(text: String, voice: AVSpeechSynthesisVoice?, pitch: Float, rate: Float) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = voice ?? selectBestFemaleVoice()
        utterance.pitchMultiplier = pitch
        utterance.rate = rate
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.05
        
        synthesizer.speak(utterance)
    }
    
    private func selectBestFemaleVoice() -> AVSpeechSynthesisVoice {
        return sarahVoice ?? AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice(language: "en-US")!
    }
    
    public func stop() {
        sequenceQueue.removeAll()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !sequenceQueue.isEmpty {
            let nextAction = sequenceQueue.removeFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nextAction()
            }
        }
    }
}
