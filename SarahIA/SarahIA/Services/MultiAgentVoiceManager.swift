import Foundation
import AVFoundation

/// Gestionnaire de Voix Siri et Synthèse Vocale 100% Native Apple pour les 4 Agents :
/// 1. Sarah : Voix système principale féminine
/// 2. Tom : Voix conversationnelle masculine
/// 3. Raphaël : Voix de notification & build
/// 4. Yohan : Voix de restitution polyglotte (fr-FR / he-IL)
public final class MultiAgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    
    public static let shared = MultiAgentVoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // Voix Mémorisées par Agent
    private var sarahVoice: AVSpeechSynthesisVoice?
    private var tomVoice: AVSpeechSynthesisVoice?
    private var raphaelVoice: AVSpeechSynthesisVoice?
    private var yohanFrVoice: AVSpeechSynthesisVoice?
    private var yohanHeVoice: AVSpeechSynthesisVoice?
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        setupVoices()
    }
    
    private func setupVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let frenchVoices = allVoices.filter { $0.language.starts(with: "fr") }
        let hebrewVoices = allVoices.filter { $0.language.starts(with: "he") }
        
        let maleNames = ["thomas", "nicolas", "paul", "aurelien", "antoine", "remi", "alain", "pierre"]
        
        // 1. Sarah (Féminine principale)
        if #available(iOS 13.0, *) {
            sarahVoice = frenchVoices.first(where: { $0.gender == .female && ($0.name.contains("Amélie") || $0.name.contains("Audrey")) })
                ?? frenchVoices.first(where: { $0.gender == .female })
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        } else {
            sarahVoice = frenchVoices.first(where: { $0.name.contains("Amélie") || $0.name.contains("Audrey") })
                ?? frenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        }
        
        // 2. Tom (Masculine conversationnelle)
        if #available(iOS 13.0, *) {
            tomVoice = frenchVoices.first(where: { $0.gender == .male && ($0.name.contains("Thomas") || $0.name.contains("Nicolas")) })
                ?? frenchVoices.first(where: { $0.gender == .male })
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        } else {
            tomVoice = frenchVoices.first(where: { maleNames.contains(where: { name in $0.name.lowercased().contains(name) }) })
                ?? frenchVoices.first
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
        }
        
        // 3. Raphaël (Masculine technique / dynamique)
        raphaelVoice = frenchVoices.first(where: { $0.name.contains("Paul") || $0.name.contains("Aurélien") || $0.name.contains("Thomas") })
            ?? tomVoice
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
        
        // 4. Yohan (Français & Hébreu)
        yohanFrVoice = sarahVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
        yohanHeVoice = hebrewVoices.first ?? AVSpeechSynthesisVoice(language: "he-IL")
    }
    
    public func speak(text: String, for agent: AgentType) {
        stop()
        
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        
        switch agent {
        case .sarah:
            utterance.voice = sarahVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
            utterance.pitchMultiplier = 1.12
            utterance.rate = 0.52
            
        case .tom:
            utterance.voice = tomVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
            utterance.pitchMultiplier = 0.95
            utterance.rate = 0.52
            
        case .raphael:
            utterance.voice = raphaelVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
            utterance.pitchMultiplier = 1.05
            utterance.rate = 0.54
            
        case .yohan:
            if YohanLexiconEngine.shared.isHebrew(cleaned) {
                utterance.voice = yohanHeVoice ?? AVSpeechSynthesisVoice(language: "he-IL")
                utterance.pitchMultiplier = 1.0
                utterance.rate = 0.48
            } else {
                utterance.voice = yohanFrVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
                utterance.pitchMultiplier = 1.05
                utterance.rate = 0.50
            }
        }
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    public var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeechStarted?()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeechFinished?()
    }
}
