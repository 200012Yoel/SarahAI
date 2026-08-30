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
        
        // Priorité aux voix Siri Premium / Enhanced avec le numéro demandé
        if let premiumSiriVoice = localeVoices.first(where: { voice in
            let id = voice.identifier.lowercased()
            let name = voice.name.lowercased()
            let num = agent.siriVoiceNumber
            
            let isSiri = id.contains("siri") || name.contains("siri")
            let hasNumber = id.contains("voice\(num)") || id.contains("_\(num)") || name.contains("voix \(num)") || name.contains("voice \(num)")
            
            return isSiri && hasNumber
        }) {
            return premiumSiriVoice
        }
        
        // 2. Recherche parmi toutes les voix de haute qualité installées
        if #available(iOS 13.0, *) {
            let highQualityVoices = localeVoices.filter { $0.quality == .premium || $0.quality == .enhanced }
            if !highQualityVoices.isEmpty {
                let index = (Int(agent.siriVoiceNumber) ?? 1) - 1
                if highQualityVoices.indices.contains(index) {
                    return highQualityVoices[index]
                }
            }
        }
        
        // 3. Fallback index direct sur les voix disponibles
        let targetIndex = (Int(agent.siriVoiceNumber) ?? 1) - 1
        if localeVoices.indices.contains(targetIndex) {
            return localeVoices[targetIndex]
        }
        
        return AVSpeechSynthesisVoice(language: agent.localeCode)
    }
    
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")!
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri
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
        utterance.pitchMultiplier = 1.0
        
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
            agentUtterance.pitchMultiplier = 1.0
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = AVSpeechUtterance(string: cleanTransition)
        sourceUtterance.voice = getSiriVoice(for: sourceAgent)
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        sourceUtterance.pitchMultiplier = 1.0
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
