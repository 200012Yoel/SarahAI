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
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // 1. Filtrer les voix de la locale ciblée (fr-FR ou fr-CA)
        let localeVoices = allVoices.filter { $0.language == agent.localeCode }
        
        // 2. Extraire les voix contenant "Siri" pour cette locale
        let siriVoices = localeVoices.filter {
            $0.identifier.localizedCaseInsensitiveContains("siri") ||
            $0.name.localizedCaseInsensitiveContains("siri")
        }
        
        // 3. Recherche directe par numéro/index de voix Siri ("Voix 1", "Voix 2", "Voice 1", "_1", etc.)
        let indexStr = agent.voiceIndex
        let targetIndexInt = Int(indexStr) ?? 1
        
        // 3a. Recherche dans les voix Siri nommées
        if let directSiri = siriVoices.first(where: {
            $0.name.localizedCaseInsensitiveContains("Voix \(indexStr)") ||
            $0.name.localizedCaseInsensitiveContains("Voice \(indexStr)") ||
            $0.name.localizedCaseInsensitiveContains(indexStr) ||
            $0.identifier.localizedCaseInsensitiveContains("siri_\(indexStr)") ||
            $0.identifier.localizedCaseInsensitiveContains("voice\(indexStr)") ||
            $0.identifier.localizedCaseInsensitiveContains("_\(indexStr)")
        }) {
            return directSiri
        }
        
        // 3b. Si plusieurs voix Siri existent pour la locale, utiliser l'index ordonné (1-based)
        if !siriVoices.isEmpty {
            let zeroIndex = targetIndexInt - 1
            if zeroIndex >= 0 && zeroIndex < siriVoices.count {
                return siriVoices[zeroIndex]
            }
        }
        
        // 4. Recherche par identifiant système Apple TTS bundle Siri connu
        let knownSiriIds = [
            "com.apple.ttsbundle.siri_\(agent.localeCode)_compact_\(indexStr)",
            "com.apple.ttsbundle.siri_\(agent.localeCode)_\(indexStr)",
            "com.apple.ttsbundle.siri_\(agent.localeCode)_\(indexStr)_compact",
            "com.apple.voice.compact.\(agent.localeCode).Siri\(indexStr)",
            "com.apple.voice.premium.\(agent.localeCode).Siri\(indexStr)",
            "com.apple.ttsbundle.siri_\(agent.localeCode)_female",
            "com.apple.ttsbundle.siri_\(agent.localeCode)_male"
        ]
        for siriId in knownSiriIds {
            if let v = AVSpeechSynthesisVoice(identifier: siriId) {
                return v
            }
        }
        
        // 5. Mapping précis sur les voix Apple Siri Premium / Compact emblématiques
        let targetNames: [String]
        switch agent {
        case .sarah:
            // Siri France Voix 1 (Féminine)
            targetNames = ["audrey", "marie", "amélie", "amelie", "celine"]
        case .nathan:
            // Siri France Voix 2 (Masculine)
            targetNames = ["thomas", "nicolas", "lucas", "paul"]
        case .esther:
            // Siri France Voix 3 (Féminine / Tech)
            targetNames = ["aurélien", "aurelien", "paul", "claire", "audrey"]
        case .tom:
            // Siri France Voix 4 (Masculine)
            targetNames = ["rémi", "remi", "pierre", "alain", "thomas"]
        case .yohan:
            // Siri Canada Voix 1 (Masculine — Siri Canadien)
            targetNames = ["antoine", "alain", "nicolas", "thomas"]
        case .ethel:
            // Siri Canada Voix 2 (Féminine — Siri Canadien)
            targetNames = ["chantal", "amelie", "amélie", "audrey"]
        }
        
        // Recherche dans localeVoices par nom de timbre
        for name in targetNames {
            if let matched = localeVoices.first(where: {
                $0.name.localizedCaseInsensitiveContains(name) ||
                $0.identifier.localizedCaseInsensitiveContains(name)
            }) {
                return matched
            }
        }
        
        // 6. Filtrage par genre si disponible sous iOS 13+
        if #available(iOS 13.0, *) {
            let wantsFemale = (agent == .sarah || agent == .esther || agent == .ethel)
            let desiredGender: AVSpeechSynthesisVoiceGender = wantsFemale ? .female : .male
            if let genderVoice = localeVoices.first(where: { $0.gender == desiredGender }) {
                return genderVoice
            }
        }
        
        // 7. Fallback par défaut selon la région
        return AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")!
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = getVoice(for: agent)
        utterance.rate = rate
        
        // Pitch personnalisé pour différencier les personnalités
        switch agent {
        case .sarah:  utterance.pitchMultiplier = 1.08
        case .nathan: utterance.pitchMultiplier = 0.98
        case .esther: utterance.pitchMultiplier = 1.05
        case .tom:    utterance.pitchMultiplier = 0.95
        case .yohan:  utterance.pitchMultiplier = 0.90
        case .ethel:  utterance.pitchMultiplier = 1.02
        }
        
        synthesizer.speak(utterance)
    }
    
    /// Compatibilité speak(text:for:)
    public func speak(text: String, for agent: AgentType) {
        speak(text: text, as: agent)
    }
    
    /// Exécute une passation vocale naturelle (ex: Sarah passe la main à Esther / Tom / Nathan / Yoann / Ethel)
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
            switch targetAgent {
            case .sarah:  agentUtterance.pitchMultiplier = 1.08
            case .nathan: agentUtterance.pitchMultiplier = 0.98
            case .esther: agentUtterance.pitchMultiplier = 1.05
            case .tom:    agentUtterance.pitchMultiplier = 0.95
            case .yohan:  agentUtterance.pitchMultiplier = 0.90
            case .ethel:  agentUtterance.pitchMultiplier = 1.02
            }
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = AVSpeechUtterance(string: cleanTransition)
        sourceUtterance.voice = getVoice(for: sourceAgent)
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        switch sourceAgent {
        case .sarah:  sourceUtterance.pitchMultiplier = 1.08
        case .nathan: sourceUtterance.pitchMultiplier = 0.98
        case .esther: sourceUtterance.pitchMultiplier = 1.05
        case .tom:    sourceUtterance.pitchMultiplier = 0.95
        case .yohan:  sourceUtterance.pitchMultiplier = 0.90
        case .ethel:  sourceUtterance.pitchMultiplier = 1.02
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
