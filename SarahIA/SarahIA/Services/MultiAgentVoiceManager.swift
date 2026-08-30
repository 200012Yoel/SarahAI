import Foundation
import AVFoundation

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Siri Multi-Agents
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil
    
    public override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Résout et retourne la voix Siri exacte pour l'agent selon la locale (fr-FR / fr-CA) et l'index (1, 2, 3, 4)
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // 1. Filtrer par locale (fr-FR ou fr-CA)
        let localeVoices = allVoices.filter { $0.language == agent.localeCode }
        
        // 2. Trouver la voix Siri correspondant à l'index (ex: "Voice 3", "voix 3", etc.)
        if let matchedVoice = localeVoices.first(where: { voice in
            voice.name.localizedCaseInsensitiveContains(agent.voiceIndex) ||
            voice.identifier.localizedCaseInsensitiveContains("voice\(agent.voiceIndex)") ||
            voice.identifier.localizedCaseInsensitiveContains("_\(agent.voiceIndex)")
        }) {
            return matchedVoice
        }
        
        // 3. Fallback direct par recherche d'identifiant Siri compact/premium
        let potentialId = "com.apple.ttsbundle.siri_\(agent.localeCode)_compact_\(agent.voiceIndex)"
        if let directVoice = AVSpeechSynthesisVoice(identifier: potentialId) {
            return directVoice
        }
        
        // 4. Fallback par recherche de genre ou nom
        if agent.localeCode == "fr-CA" {
            if agent == .yohan {
                if let maleCA = localeVoices.first(where: { $0.gender == .male }) ?? allVoices.first(where: { $0.language.starts(with: "fr") && $0.gender == .male }) {
                    return maleCA
                }
            } else if agent == .ethel {
                if let femaleCA = localeVoices.first(where: { $0.gender == .female }) ?? allVoices.first(where: { $0.language.starts(with: "fr") && $0.gender == .female }) {
                    return femaleCA
                }
            }
        }
        
        // 5. Fallback par défaut selon la région
        return AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")!
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = getVoice(for: agent)
        utterance.rate = rate
        utterance.pitchMultiplier = (agent == .yohan ? 0.90 : (agent == .sarah ? 1.08 : 1.0))
        
        synthesizer.speak(utterance)
    }
    
    /// Compatibilité speak(text:for:)
    public func speak(text: String, for agent: AgentType) {
        speak(text: text, as: agent)
    }
    
    /// Exécute une passation vocale naturelle (ex: Sarah passe la main à Esther / Tom / Nathan / Yohan / Ethel)
    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        stop()
        
        let cleanTransition = cleanTextForSpeech(transitionText)
        let cleanAgent = cleanTextForSpeech(agentGreeting)
        
        guard !cleanTransition.isEmpty else {
            speak(text: cleanAgent, as: targetAgent)
            return
        }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        // Préparer la suite pour quand l'agent source a fini sa phrase de passage
        self.pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            let agentUtterance = AVSpeechUtterance(string: cleanAgent)
            agentUtterance.voice = self.getVoice(for: targetAgent)
            agentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
            agentUtterance.pitchMultiplier = (targetAgent == .yohan ? 0.90 : 1.0)
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = AVSpeechUtterance(string: cleanTransition)
        sourceUtterance.voice = getVoice(for: sourceAgent)
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        sourceUtterance.pitchMultiplier = (sourceAgent == .sarah ? 1.08 : 1.0)
        synthesizer.speak(sourceUtterance)
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
    
    private func cleanTextForSpeech(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

/// Alias MultiAgentVoiceManager pour compatibilité globale avec les ViewModels et Services
public typealias MultiAgentVoiceManager = AgentVoiceManager
