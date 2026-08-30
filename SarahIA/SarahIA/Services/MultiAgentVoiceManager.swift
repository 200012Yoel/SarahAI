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
    
    /// Récupère la voix Siri exacte de l'agent (Sarah, Nathan, Esther, Tom, Yohan, Ethel)
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        // 1. Recherche prioritaire par l'identifiant système Apple TTS Bundle Siri exact
        if let directVoice = AVSpeechSynthesisVoice(identifier: agent.speechIdentifier) {
            return directVoice
        }
        
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // 2. Filtrer toutes les voix de la région cible (fr-FR ou fr-CA)
        let availableVoices = allVoices.filter {
            $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix(agent.localeCode)
        }
        
        // 3. Extraire les voix labellisées Siri
        let siriVoices = availableVoices.filter {
            $0.identifier.localizedCaseInsensitiveContains("siri") ||
            $0.name.localizedCaseInsensitiveContains("siri")
        }
        
        // 3a. Recherche par index dans les voix Siri réelles installées
        if agent.voiceIndexOrder < siriVoices.count {
            return siriVoices[agent.voiceIndexOrder]
        }
        
        // 3b. Recherche par index dans la liste ordonnée des voix de la région
        if agent.voiceIndexOrder < availableVoices.count {
            return availableVoices[agent.voiceIndexOrder]
        }
        
        // 4. Recherche par timbres nominatifs emblématiques Siri
        let targetNames: [String]
        switch agent {
        case .sarah:  targetNames = ["audrey", "marie", "amélie", "amelie", "celine"]
        case .nathan: targetNames = ["thomas", "nicolas", "lucas", "paul"]
        case .esther: targetNames = ["aurélien", "aurelien", "paul", "claire", "audrey"]
        case .tom:    targetNames = ["rémi", "remi", "pierre", "alain", "thomas"]
        case .yohan:  targetNames = ["antoine", "alain", "nicolas", "thomas"]
        case .ethel:  targetNames = ["chantal", "amelie", "amélie", "audrey"]
        }
        
        for name in targetNames {
            if let matched = availableVoices.first(where: {
                $0.name.localizedCaseInsensitiveContains(name) ||
                $0.identifier.localizedCaseInsensitiveContains(name)
            }) {
                return matched
            }
        }
        
        // 5. Filtrage par genre sous iOS 13+
        if #available(iOS 13.0, *) {
            let wantsFemale = (agent == .sarah || agent == .esther || agent == .ethel)
            let desiredGender: AVSpeechSynthesisVoiceGender = wantsFemale ? .female : .male
            if let genderVoice = availableVoices.first(where: { $0.gender == desiredGender }) {
                return genderVoice
            }
        }
        
        // 6. Fallback direct sur la première voix disponible de la région
        if let fallback = availableVoices.first {
            return fallback
        }
        
        return AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        let selectedVoice = getVoice(for: agent)
        utterance.voice = selectedVoice
        utterance.rate = rate
        
        // Affichage console pour vérification immédiate du timbre en direct
        print("🗣️ Agent: \(agent.rawValue) | Voix: \(selectedVoice.name) | Langue: \(selectedVoice.language) | ID: \(selectedVoice.identifier)")
        
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
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = AVSpeechUtterance(string: cleanTransition)
        sourceUtterance.voice = getVoice(for: sourceAgent)
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
    
    // MARK: - Validation & Inspection
    /// Liste toutes les voix Français/Hébreu installées sur l'appareil (pour vérification console)
    public func listAvailableFrenchVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.starts(with: "fr") || $0.language.starts(with: "he")
        }
        for (index, voice) in voices.enumerated() {
            print("[\(index)] Nom: \(voice.name) | Langue: \(voice.language) | ID: \(voice.identifier)")
        }
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
