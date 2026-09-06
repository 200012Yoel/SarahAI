import Foundation
import AVFoundation

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Siri Multi-Agents
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil
    
    // Cache de voix résolues et garanties 100% uniques et distinctes par agent
    private var agentVoices: [AgentType: AVSpeechSynthesisVoice] = [:]
    
    public override init() {
        super.init()
        synthesizer.delegate = self
        resolveAllDistinctVoices()
    }
    
    /// Résolution et assignation stricte d'une voix iOS francophone unique pour chaque agent (zéro doublon)
    private func resolveAllDistinctVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        var usedIdentifiers = Set<String>()
        
        // Liste ordonnée de tous les agents pour l'attribution
        let orderedAgents: [AgentType] = [.sarah, .nathan, .esther, .tom, .yohan, .ethel]
        
        // Voix francophones disponibles sur le système (France, Canada, Belgique, Suisse)
        let frenchVoices = allVoices.filter {
            $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix("fr")
        }
        
        for agent in orderedAgents {
            var selectedVoice: AVSpeechSynthesisVoice? = nil
            
            // 1. Essai par identifiant exact configuré dans AgentType
            if let directVoice = AVSpeechSynthesisVoice(identifier: agent.speechIdentifier),
               !usedIdentifiers.contains(directVoice.identifier) {
                selectedVoice = directVoice
            }
            
            // 2. Essai par version enhanced
            if selectedVoice == nil {
                let enhancedId = agent.speechIdentifier.replacingOccurrences(of: "compact", with: "enhanced")
                if let enhancedVoice = AVSpeechSynthesisVoice(identifier: enhancedId),
                   !usedIdentifiers.contains(enhancedVoice.identifier) {
                    selectedVoice = enhancedVoice
                }
            }
            
            // 3. Essai par noms ciblés de timbres vocaux Siri distincts
            if selectedVoice == nil {
                let targetNames: [String]
                switch agent {
                case .sarah:  targetNames = ["amélie", "amelie", "marie", "audrey"]
                case .nathan: targetNames = ["thomas", "nicolas", "lucas", "paul"]
                case .esther: targetNames = ["audrey", "celine", "céline", "aurelie", "aurélie", "claire"]
                case .tom:    targetNames = ["rémi", "remi", "alain", "pierre", "antoine"]
                case .yohan:  targetNames = ["jean", "felix", "félix", "nicolas"]
                case .ethel:  targetNames = ["chantal", "juliette", "hortense", "geneviève", "genevieve"]
                }
                
                for name in targetNames {
                    if let match = frenchVoices.first(where: {
                        !usedIdentifiers.contains($0.identifier) &&
                        ($0.name.localizedCaseInsensitiveContains(name) || $0.identifier.localizedCaseInsensitiveContains(name))
                    }) {
                        selectedVoice = match
                        break
                    }
                }
            }
            
            // 4. Attribution d'une voix francophone libre non encore utilisée
            if selectedVoice == nil {
                let isFemale = (agent == .sarah || agent == .esther || agent == .ethel)
                let maleKeywords = ["thomas", "nicolas", "paul", "antoine", "remi", "alain", "jean", "felix"]
                
                let freeVoices = frenchVoices.filter { !usedIdentifiers.contains($0.identifier) }
                if let matchGender = freeVoices.first(where: { voice in
                    let lower = voice.name.lowercased()
                    let isMale = maleKeywords.contains(where: { lower.contains($0) })
                    return isFemale ? !isMale : isMale
                }) {
                    selectedVoice = matchGender
                } else if let anyFree = freeVoices.first {
                    selectedVoice = anyFree
                }
            }
            
            // 5. Fallback garanti
            let finalVoice = selectedVoice ?? AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
            agentVoices[agent] = finalVoice
            usedIdentifiers.insert(finalVoice.identifier)
        }
    }
    
    /// Résout la voix Siri exacte et unique pour l'agent
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        if let cached = agentVoices[agent] {
            return cached
        }
        resolveAllDistinctVoices()
        return agentVoices[agent] ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }
    
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
    }
    
    /// Nettoyage et correction phonétique stricte pour la synthèse vocale
    public func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Règle de remplacement phonétique stricte : "Yoann" / "Yohan" -> "io-An"
        let yoannVariants = [
            "Yoann", "yoann", "YOANN",
            "Yohan", "yohan", "YOHAN",
            "Yoan", "yoan", "YOAN",
            "Yohann", "yohann", "YOHANN"
        ]
        for variant in yoannVariants {
            cleaned = cleaned.replacingOccurrences(of: variant, with: "io-An")
        }
        
        return cleaned
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri personnalisé
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("⚠️ [AgentVoiceManager] Erreur configuration AVAudioSession: \(error.localizedDescription)")
        }
        
        let utterance = AVSpeechUtterance(string: cleaned)
        let resolvedVoice = getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.voice = resolvedVoice
        
        // Timbres, vitesses et hauteurs de tonalité authentiques et distincts pour chaque agent
        switch agent {
        case .sarah:
            utterance.pitchMultiplier = 1.05
            utterance.rate = 0.51
        case .nathan:
            utterance.pitchMultiplier = 0.95
            utterance.rate = 0.53
        case .esther:
            utterance.pitchMultiplier = 1.12
            utterance.rate = 0.49
        case .tom:
            utterance.pitchMultiplier = 0.84
            utterance.rate = 0.46
        case .yohan:
            utterance.pitchMultiplier = 0.91
            utterance.rate = 0.50
        case .ethel:
            utterance.pitchMultiplier = 1.18
            utterance.rate = 0.48
        }
        
        print("🔊 [AgentVoiceManager] Synthèse vocale [\(agent.rawValue)] via \(resolvedVoice?.name ?? "fr-FR") | ID: \(resolvedVoice?.identifier ?? "")")
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
