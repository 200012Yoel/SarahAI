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
    
    /// Résout la voix Siri exacte pour l'agent (Sarah, Nathan, Esther, Tom, Yohan, Ethel)
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // 1. Filtrer les voix de la bonne langue (fr-FR ou fr-CA)
        let localeVoices = allVoices.filter { 
            $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix(agent.localeCode) 
        }
        
        // 2. Recherche prioritaire par identifiant Siri exact (Apple TTS bundle)
        if let directIdVoice = AVSpeechSynthesisVoice(identifier: agent.speechIdentifier) {
            return directIdVoice
        }
        
        // 3. Recherche directe par timbre nominatif emblématique Apple Siri
        let targetNames: [String]
        switch agent {
        case .sarah:  targetNames = ["marie", "audrey", "amélie", "amelie", "celine"]
        case .nathan: targetNames = ["thomas", "nicolas", "lucas", "paul"]
        case .esther: targetNames = ["aurélien", "aurelien", "claire", "audrey"]
        case .tom:    targetNames = ["rémi", "remi", "pierre", "alain"]
        case .yohan:  targetNames = ["antoine", "alain", "nicolas"]
        case .ethel:  targetNames = ["chantal", "amelie", "amélie"]
        }
        
        for name in targetNames {
            if let matched = localeVoices.first(where: {
                $0.name.localizedCaseInsensitiveContains(name) ||
                $0.identifier.localizedCaseInsensitiveContains(name)
            }) {
                return matched
            }
        }
        
        // 4. Recherche Siri générique avec numéro de voix
        if let siriByNum = localeVoices.first(where: { v in
            let id = v.identifier.lowercased()
            let name = v.name.lowercased()
            let num = agent.siriVoiceNumber
            return (id.contains("siri") || name.contains("siri")) && (id.contains(num) || name.contains(num))
        }) {
            return siriByNum
        }
        
        // 5. Voix haute qualité par index
        let highQualityVoices: [AVSpeechSynthesisVoice]
        if #available(iOS 16.0, *) {
            highQualityVoices = localeVoices.filter { $0.quality == .premium || $0.quality == .enhanced }
        } else {
            highQualityVoices = localeVoices.filter { $0.quality == .enhanced }
        }
        let targetIdx = (Int(agent.siriVoiceNumber) ?? 1) - 1
        if !highQualityVoices.isEmpty && highQualityVoices.indices.contains(targetIdx) {
            return highQualityVoices[targetIdx]
        }
        
        // 6. Index direct dans les voix de la région
        if localeVoices.indices.contains(targetIdx) {
            return localeVoices[targetIdx]
        }
        
        return AVSpeechSynthesisVoice(language: agent.localeCode)
    }
    
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")!
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri personnalisé
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        let voice = getSiriVoice(for: agent)
        utterance.voice = voice
        utterance.rate = rate
        
        // Timbres et hauteurs de tonalité uniques pour chaque personnalité
        switch agent {
        case .sarah:  utterance.pitchMultiplier = 1.08
        case .nathan: utterance.pitchMultiplier = 0.96
        case .esther: utterance.pitchMultiplier = 1.05
        case .tom:    utterance.pitchMultiplier = 0.92
        case .yohan:  utterance.pitchMultiplier = 0.90
        case .ethel:  utterance.pitchMultiplier = 1.03
        }
        
        print("🔊 Lecture [\(agent.rawValue)] via Voix: \(voice?.name ?? "Inconnue") | ID: \(voice?.identifier ?? "")")
        
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
            switch targetAgent {
            case .sarah:  agentUtterance.pitchMultiplier = 1.08
            case .nathan: agentUtterance.pitchMultiplier = 0.96
            case .esther: agentUtterance.pitchMultiplier = 1.05
            case .tom:    agentUtterance.pitchMultiplier = 0.92
            case .yohan:  agentUtterance.pitchMultiplier = 0.90
            case .ethel:  agentUtterance.pitchMultiplier = 1.03
            }
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = AVSpeechUtterance(string: cleanTransition)
        sourceUtterance.voice = getSiriVoice(for: sourceAgent)
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        switch sourceAgent {
        case .sarah:  sourceUtterance.pitchMultiplier = 1.08
        case .nathan: sourceUtterance.pitchMultiplier = 0.96
        case .esther: sourceUtterance.pitchMultiplier = 1.05
        case .tom:    sourceUtterance.pitchMultiplier = 0.92
        case .yohan:  sourceUtterance.pitchMultiplier = 0.90
        case .ethel:  sourceUtterance.pitchMultiplier = 1.03
        }
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
