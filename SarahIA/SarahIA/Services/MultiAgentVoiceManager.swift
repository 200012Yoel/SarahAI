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
        
        // 1. Recherche prioritaire par identifiant Siri exact Apple TTS
        if let directIdVoice = AVSpeechSynthesisVoice(identifier: agent.speechIdentifier) {
            return directIdVoice
        }
        
        // 2. Recherche par variantes enhanced / premium
        let enhancedId = agent.speechIdentifier.replacingOccurrences(of: "compact", with: "enhanced")
        if let enhancedVoice = AVSpeechSynthesisVoice(identifier: enhancedId) {
            return enhancedVoice
        }
        
        // 3. Filtrer les voix de la région cible (fr-FR ou fr-CA)
        let localeVoices = allVoices.filter { 
            $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix(agent.localeCode) 
        }
        
        // 4. Recherche ciblée par nom de timbre Apple Siri
        let targetNames: [String]
        switch agent {
        case .sarah:  targetNames = ["amélie", "amelie", "marie", "audrey", "celine", "hortense"]
        case .nathan: targetNames = ["thomas", "nicolas", "lucas", "paul"]
        case .esther: targetNames = ["audrey", "celine", "céline", "aurelie", "aurélie", "claire"]
        case .tom:    targetNames = ["rémi", "remi", "alain", "pierre", "antoine"]
        case .yohan:  targetNames = ["jean", "felix", "félix", "nicolas", "carmit"]
        case .ethel:  targetNames = ["chantal", "juliette", "amelie", "marie"]
        }
        
        for name in targetNames {
            if let matched = localeVoices.first(where: {
                $0.name.localizedCaseInsensitiveContains(name) ||
                $0.identifier.localizedCaseInsensitiveContains(name)
            }) {
                return matched
            }
        }
        
        // 5. Recherche par genre et qualité
        let isFemale = (agent == .sarah || agent == .esther || agent == .ethel)
        let filteredByGender = localeVoices.filter { voice in
            let lower = voice.name.lowercased()
            let maleList = ["thomas", "nicolas", "paul", "antoine", "remi", "alain", "jean", "felix"]
            let isNameMale = maleList.contains(where: { lower.contains($0) })
            return isFemale ? !isNameMale : isNameMale
        }
        
        if let genderMatch = filteredByGender.first {
            return genderMatch
        }
        
        return AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }
    
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        if let v = getSiriVoice(for: agent) { return v }
        if let v = AVSpeechSynthesisVoice(language: agent.localeCode) { return v }
        if let v = AVSpeechSynthesisVoice(language: "fr-FR") { return v }
        return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice()
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
        
        // Timbres, vitesses et hauteurs de tonalité authentiques pour chaque personnalité
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
        
        if resolvedVoice == nil {
            print("⚠️ [AgentVoiceManager] Échec d'initialisation de la voix AVSpeechSynthesisVoice(fr-FR)")
        } else {
            print("🔊 [AgentVoiceManager] Synthèse vocale [\(agent.rawValue)] via \(resolvedVoice?.name ?? "fr-FR") | ID: \(resolvedVoice?.identifier ?? "")")
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
