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
    
    /// Résout la voix Siri exacte selon l'ordre des voix système installées
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Liste des voix françaises de France et du Canada installées
        let franceVoices = allVoices.filter { $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix("fr-FR") }
        let canadaVoices = allVoices.filter { $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix("fr-CA") }
        
        switch agent {
        case .sarah:
            // Sarah = Voix 1 France
            return franceVoices.indices.contains(0) ? franceVoices[0] : AVSpeechSynthesisVoice(language: "fr-FR")
            
        case .nathan:
            // Nathan = Voix 2 France
            return franceVoices.indices.contains(1) ? franceVoices[1] : AVSpeechSynthesisVoice(language: "fr-FR")
            
        case .esther:
            // Esther = Voix 3 France
            return franceVoices.indices.contains(2) ? franceVoices[2] : AVSpeechSynthesisVoice(language: "fr-FR")
            
        case .tom:
            // Tom = Voix 4 France
            return franceVoices.indices.contains(3) ? franceVoices[3] : AVSpeechSynthesisVoice(language: "fr-FR")
            
        case .yohan:
            // Yohan = Voix 1 Canada
            return canadaVoices.indices.contains(0) ? canadaVoices[0] : AVSpeechSynthesisVoice(language: "fr-CA")
            
        case .ethel:
            // Ethel = Voix 2 Canada (Féminine canadienne)
            return canadaVoices.indices.contains(1) ? canadaVoices[1] : AVSpeechSynthesisVoice(language: "fr-CA")
        }
    }
    
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        let selectedVoice = getSiriVoice(for: agent)
        utterance.voice = selectedVoice
        utterance.rate = rate
        
        if let v = selectedVoice {
            print("🗣️ Agent: \(agent.rawValue) | Voix: \(v.name) | Langue: \(v.language) | ID: \(v.identifier)")
        }
        
        synthesizer.speak(utterance)
    }
    
    /// Compatibilité speak(text:for:)
    public func speak(text: String, for agent: AgentType) {
        speak(text: text, as: agent)
    }
    
    /// Passation vocale séquentielle fluide entre deux agents
    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        stop()
        
        let cleanTransition = cleanTextForSpeech(transitionText)
        let cleanAgent = cleanTextForSpeech(agentGreeting)
        
        guard !cleanTransition.isEmpty else {
            speak(text: cleanAgent, as: targetAgent)
            return
        }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        self.pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            let agentUtterance = AVSpeechUtterance(string: cleanAgent)
            agentUtterance.voice = self.getSiriVoice(for: targetAgent)
            agentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = AVSpeechUtterance(string: cleanTransition)
        sourceUtterance.voice = getSiriVoice(for: sourceAgent)
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
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
