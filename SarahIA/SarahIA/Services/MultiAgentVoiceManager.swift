import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Multi-Agents
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil
    
    // Cache de voix Apple résolues par agent.
    private var agentVoices: [AgentType: AVSpeechSynthesisVoice] = [:]
    /// Les agents présents ici partagent temporairement une voix, car aucune
    /// voix Apple distincte du genre demandé n'est téléchargée sur l'iPhone.
    public private(set) var agentsNeedingAnotherSystemVoice = Set<AgentType>()
    
    public override init() {
        super.init()
        synthesizer.delegate = self
        resolveAllDistinctVoices()

        #if canImport(UIKit)
        // La voix peut être modifiée dans Réglages pendant que Sarah est en
        // arrière-plan. Au retour dans l'app, on relit la sélection système
        // pour les prochaines réponses.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshSystemVoiceSelection),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Vide le cache afin de relire les voix actuellement disponibles sur l'iPhone.
    @objc public func refreshSystemVoiceSelection() {
        agentVoices.removeAll()
        agentsNeedingAnotherSystemVoice.removeAll()
        resolveAllDistinctVoices()
    }
    
    /// Associe les voix Apple réellement disponibles aux quatre agents actifs.
    /// Siri ne donne pas accès à ses choix « Voix 1 », « Voix 2 », etc. aux
    /// apps tierces : on sélectionne donc une voix Apple installée de même
    /// région et de même genre, sans dépendre de noms internes instables.
    private func resolveAllDistinctVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        var usedIdentifiers = Set<String>()
        
        // Liste ordonnée des agents visibles pour l'attribution.
        let orderedAgents = AgentType.activeAgents
        
        // Voix francophones disponibles sur le système (France, Canada, Belgique, Suisse).
        let frenchVoices = allVoices.filter {
            $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix("fr")
        }
        
        for agent in orderedAgents {
            let matchingVoices = rankedVoices(for: agent, from: frenchVoices)
            let selectedVoice: AVSpeechSynthesisVoice
            if let distinctVoice = matchingVoices.first(where: { !usedIdentifiers.contains($0.identifier) }) {
                selectedVoice = distinctVoice
            } else if let reusableVoice = matchingVoices.first {
                // Ne mélange pas les genres à cause d'une voix manquante : on
                // conserve la voix correcte et on signale qu'il faut en
                // télécharger une autre dans Réglages iPhone.
                selectedVoice = reusableVoice
                agentsNeedingAnotherSystemVoice.insert(agent)
            } else {
                selectedVoice = AVSpeechSynthesisVoice(language: agent.localeCode)
                    ?? AVSpeechSynthesisVoice(language: "fr-FR")
                    ?? AVSpeechSynthesisVoice()
                agentsNeedingAnotherSystemVoice.insert(agent)
            }

            let finalVoice = selectedVoice
            agentVoices[agent] = finalVoice
            usedIdentifiers.insert(finalVoice.identifier)
        }
    }

    private func rankedVoices(for agent: AgentType, from voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        let preferredLocale = normalizedLanguageCode(agent.localeCode)
        return voices
            .filter { $0.gender == agent.preferredVoiceGender }
            .sorted { lhs, rhs in
                let lhsRank = normalizedLanguageCode(lhs.language) == preferredLocale ? 0 : 1
                let rhsRank = normalizedLanguageCode(rhs.language) == preferredLocale ? 0 : 1
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func normalizedLanguageCode(_ language: String) -> String {
        language
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }
    
    /// Résout la voix de synthèse Apple associée à l'agent.
    /// Le nom historique est conservé pour compatibilité ; une app tierce n'a pas
    /// d'API publique pour lire l'identifiant interne de la voix de l'assistant Siri.
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        let selectedAgent = agent.activeAgent
        if let cached = agentVoices[selectedAgent] {
            return cached
        }
        resolveAllDistinctVoices()
        return agentVoices[selectedAgent] ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }
    
    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
    }

    /// Nettoyage du texte sans modifier les noms visibles dans l'interface.
    public func cleanTextForSpeech(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Crée une énonciation Apple dont le texte reste inchangé, mais dont les
    /// noms propres portent une notation IPA. Cela évite que le synthétiseur
    /// écorche les noms sans afficher une orthographe phonétique à l'utilisateur.
    public func makeUtterance(text: String) -> AVSpeechUtterance {
        let cleaned = cleanTextForSpeech(text)
        let attributedText = NSMutableAttributedString(string: cleaned)

        let pronunciations: [(spellings: [String], ipa: String)] = [
            (["Sarah", "Sara"], "sa.ʁa"),
            (["Nathan"], "na.tan"),
            (["Raphaël", "Raphael"], "ʁa.fa.ɛl"),
            (["Esther"], "ɛs.tɛʁ"),
            (["Tom"], "tɔm"),
            (["Yoann", "Yohan", "Yoan", "Yohann"], "jo.an"),
            (["Ethel"], "e.tɛl")
        ]

        for pronunciation in pronunciations {
            for spelling in pronunciation.spellings {
                let pattern = "(?<![\\p{L}\\p{N}])" +
                    NSRegularExpression.escapedPattern(for: spelling) +
                    "(?![\\p{L}\\p{N}])"
                guard let expression = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                ) else { continue }

                let range = NSRange(cleaned.startIndex..., in: cleaned)
                for match in expression.matches(in: cleaned, range: range) {
                    attributedText.addAttribute(
                        NSAttributedString.Key(AVSpeechSynthesisIPANotationAttribute),
                        value: pronunciation.ipa,
                        range: match.range
                    )
                }
            }
        }

        return AVSpeechUtterance(attributedString: attributedText)
    }
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec une voix système Apple.
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
        
        let utterance = makeUtterance(text: cleaned)
        let activeAgent = agent.activeAgent
        let resolvedVoice = getSiriVoice(for: activeAgent) ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.voice = resolvedVoice
        
        // La hauteur ajuste le rendu sans remplacer un timbre manquant.
        switch activeAgent {
        case .sarah:
            utterance.pitchMultiplier = 1.05
            utterance.rate = 0.51
        case .nathan:
            utterance.pitchMultiplier = 0.95
            utterance.rate = 0.53
        case .esther:
            utterance.pitchMultiplier = 0.94
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
            let agentUtterance = self.makeUtterance(text: cleanAgent)
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
        
        let sourceUtterance = makeUtterance(text: cleanTransition)
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
