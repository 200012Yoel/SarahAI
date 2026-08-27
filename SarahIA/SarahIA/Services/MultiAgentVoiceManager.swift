import Foundation
import AVFoundation

/// Gestionnaire de Voix Siri et Synthèse Vocale 100% Native Apple pour les 4 Agents :
/// 1. Sarah : Voix système principale féminine
/// 2. Tom : Voix conversationnelle masculine
/// 3. Raphaël : Voix technique dynamique
/// 4. Yohan : Voix polyglotte (fr-FR / he-IL)
/// Supporte la passation vocale séquentielle (Sarah parle d'abord avec sa voix puis l'agent cible prend le relais avec sa propre voix).
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
    
    private var pendingSpeechBlock: (() -> Void)? = nil
    
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
            tomVoice = frenchVoices.first(where: { voice in
                maleNames.contains(where: { name in
                    voice.name.lowercased().contains(name.lowercased())
                })
            })
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
    
    /// Synthétise la voix d'un agent unique
    public func speak(text: String, for agent: AgentType) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        let utterance = makeUtterance(cleaned: cleaned, for: agent)
        synthesizer.speak(utterance)
    }
    
    /// Exécute une passation vocale naturelle : Sarah parle d'abord ("Attends, ne quitte pas, je te le passe"), puis l'agent prend le relais avec sa voix
    public func speakHandoff(sarahTransition: String, agentGreeting: String, targetAgent: AgentType) {
        stop()
        
        let cleanSarah = cleanTextForSpeech(sarahTransition)
        let cleanAgent = cleanTextForSpeech(agentGreeting)
        
        guard !cleanSarah.isEmpty else {
            speak(text: cleanAgent, for: targetAgent)
            return
        }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        // Préparer la suite pour quand Sarah a fini sa phrase
        self.pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            let agentUtterance = self.makeUtterance(cleaned: cleanAgent, for: targetAgent)
            self.synthesizer.speak(agentUtterance)
        }
        
        let sarahUtterance = makeUtterance(cleaned: cleanSarah, for: .sarah)
        synthesizer.speak(sarahUtterance)
    }
    
    private func makeUtterance(cleaned: String, for agent: AgentType) -> AVSpeechUtterance {
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
        return utterance
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func stop() {
        pendingSpeechBlock = nil
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
        if let next = pendingSpeechBlock {
            pendingSpeechBlock = nil
            next()
        } else {
            onSpeechFinished?()
        }
    }
}
