import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Siri Multi-Agents
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    public private(set) var currentSpokenText: String = ""
    
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil
    
    // Cache de voix résolues et garanties 100% uniques et distinctes par agent
    private var agentVoices: [AgentType: AVSpeechSynthesisVoice] = [:]
    
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
        resolveAllDistinctVoices()
    }
    
    /// Résolution et assignation stricte d'une voix iOS francophone unique pour chaque agent (zéro doublon).
    /// Les voix désignées par l'utilisateur sont recherchées par identifiant
    /// disponible sur l'iPhone, jamais par position dans une liste mutable.
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

            // Sarah est résolue d'abord par timbre féminin explicite. On évite
            // ainsi qu'un fallback `fr-FR` choisisse une voix masculine.
            if agent == .sarah {
                selectedVoice = bestSarahFemaleVoice(from: allVoices)
            }

            // 1. Voix Apple demandée pour cet agent. Sarah et Nathan ont chacun
            // leur propre identifiant : ils ne dépendent donc pas du réglage
            // global actuellement affiché dans Siri.
            for identifier in agent.preferredSpeechVoiceIdentifiers where selectedVoice == nil {
                if let directVoice = AVSpeechSynthesisVoice(identifier: identifier),
                   !usedIdentifiers.contains(directVoice.identifier) {
                    selectedVoice = directVoice
                }
            }
            
            // 2. Essai par version enhanced
            if selectedVoice == nil {
                for identifier in agent.preferredSpeechVoiceIdentifiers {
                    let enhancedId = identifier.replacingOccurrences(of: "compact", with: "enhanced")
                    if let enhancedVoice = AVSpeechSynthesisVoice(identifier: enhancedId),
                       !usedIdentifiers.contains(enhancedVoice.identifier) {
                        selectedVoice = enhancedVoice
                        break
                    }
                }
            }

            // Si la voix demandée n'est pas encore téléchargée, iOS fournit une
            // voix France par défaut pour que Sarah reste utilisable. L'écran
            // À propos indique comment télécharger les voix souhaitées.
            if selectedVoice == nil,
               agent == .nathan,
               let systemFrenchVoice = AVSpeechSynthesisVoice(language: agent.localeCode),
               normalizedLanguageCode(systemFrenchVoice.language) == "fr-fr",
               !usedIdentifiers.contains(systemFrenchVoice.identifier) {
                selectedVoice = systemFrenchVoice
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
            
            // 5. Fallback garanti. Sarah réessaie explicitement une voix
            // féminine avant le fallback de langue générique.
            let finalVoice: AVSpeechSynthesisVoice
            if agent == .sarah {
                finalVoice = selectedVoice
                    ?? bestSarahFemaleVoice(from: allVoices)
                    ?? AVSpeechSynthesisVoice(identifier: agent.speechIdentifier)
                    ?? AVSpeechSynthesisVoice(language: "fr-FR")
                    ?? AVSpeechSynthesisVoice()
            } else {
                finalVoice = selectedVoice
                    ?? AVSpeechSynthesisVoice(language: agent.localeCode)
                    ?? AVSpeechSynthesisVoice(language: "fr-FR")
                    ?? AVSpeechSynthesisVoice()
            }
            agentVoices[agent] = finalVoice
            usedIdentifiers.insert(finalVoice.identifier)
        }
    }

    private func normalizedLanguageCode(_ language: String) -> String {
        language
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    /// Choisit une voix française explicitement féminine pour Sarah.
    /// `AVSpeechSynthesisVoice(language:)` n'est jamais utilisé en premier pour
    /// Sarah car iOS peut retourner une voix masculine selon les voix installées.
    private func bestSarahFemaleVoice(from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        let femaleTokens = [
            "amelie", "amélie", "audrey", "marie", "celine", "céline",
            "aurelie", "aurélie", "julie", "virginie", "chantal", "female"
        ]
        let maleTokens = [
            "thomas", "nicolas", "paul", "antoine", "remi", "rémi",
            "alain", "jean", "felix", "félix", "male"
        ]

        let french = voices.filter {
            normalizedLanguageCode($0.language).hasPrefix("fr-") ||
            normalizedLanguageCode($0.language) == "fr"
        }

        let candidates = french.filter { voice in
            let fingerprint = (voice.name + " " + voice.identifier).lowercased()
            let isExplicitMale = maleTokens.contains { fingerprint.contains($0) }
            let isExplicitFemale = femaleTokens.contains { fingerprint.contains($0) }
            return !isExplicitMale && isExplicitFemale
        }

        return candidates.max { lhs, rhs in
            func score(_ voice: AVSpeechSynthesisVoice) -> Int {
                let fingerprint = (voice.name + " " + voice.identifier).lowercased()
                var value = Int(voice.quality.rawValue) * 100
                if normalizedLanguageCode(voice.language) == "fr-fr" { value += 80 }
                if fingerprint.contains("amelie") || fingerprint.contains("amélie") { value += 60 }
                if fingerprint.contains("siri") { value += 20 }
                if fingerprint.contains("premium") { value += 30 }
                if fingerprint.contains("enhanced") { value += 20 }
                return value
            }
            return score(lhs) < score(rhs)
        }
    }

    /// Exposé pour les anciens écrans TTS : ils doivent utiliser exactement le
    /// même timbre féminin que le mode vocal principal.
    public func getSarahVoice() -> AVSpeechSynthesisVoice {
        if let cached = agentVoices[.sarah] { return cached }
        if let female = bestSarahFemaleVoice(from: AVSpeechSynthesisVoice.speechVoices()) {
            agentVoices[.sarah] = female
            return female
        }
        if let amelie = AVSpeechSynthesisVoice(identifier: AgentType.sarah.speechIdentifier) {
            agentVoices[.sarah] = amelie
            return amelie
        }
        // Ultime secours uniquement si aucune voix féminine française n'est
        // installée sur l'appareil. Le cache sera recalculé au retour dans l'app.
        return AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
    }
    
    /// Résout la voix de synthèse Apple associée à l'agent.
    /// Le nom historique est conservé pour compatibilité ; une app tierce n'a pas
    /// d'API publique pour lire l'identifiant interne de la voix de l'assistant Siri.
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        if let cached = agentVoices[agent] {
            return cached
        }
        resolveAllDistinctVoices()
        if agent == .sarah { return getSarahVoice() }
        return agentVoices[agent] ?? AVSpeechSynthesisVoice(language: "fr-FR")
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
    
    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri personnalisé
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        // Hors mode vocal continu, on conserve le comportement mono-source.
        // En mode vocal continu, Whisper reste volontairement en écoute afin que
        // l'utilisateur puisse interrompre Sarah à n'importe quel moment.
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
        stop()
        pendingSpeechBlock = nil
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        AudioSessionManager.shared.configurePlaybackSession()
        
        let utterance = makeUtterance(text: cleaned)
        let resolvedVoice = getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.voice = resolvedVoice
        
        // Timbres, vitesses et hauteurs de tonalité authentiques et distincts pour chaque agent
        switch agent {
        case .sarah:
            utterance.pitchMultiplier = 1.00
            utterance.rate = 0.48
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
        
        utterance.volume = 1.0
        if agent == .sarah {
            utterance.preUtteranceDelay = 0.02
            utterance.postUtteranceDelay = 0.04
        }

        currentSpokenText = cleaned
        print("🔊 [AgentVoiceManager] Synthèse vocale [\(agent.rawValue)] via \(resolvedVoice?.name ?? "fr-FR") | ID: \(resolvedVoice?.identifier ?? "")")
        synthesizer.speak(utterance)
    }
    
    /// Compatibilité speak(text:for:)
    public func speak(text: String, for agent: AgentType) {
        speak(text: text, as: agent)
    }
    
    /// Passation vocale séquentielle fluide entre deux agents
    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
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
            case .sarah:  agentUtterance.pitchMultiplier = 1.00; agentUtterance.rate = 0.48
            case .nathan: agentUtterance.pitchMultiplier = 0.96
            case .esther: agentUtterance.pitchMultiplier = 1.05
            case .tom:    agentUtterance.pitchMultiplier = 0.92
            case .yohan:  agentUtterance.pitchMultiplier = 0.90
            case .ethel:  agentUtterance.pitchMultiplier = 1.03
            }
            self.currentSpokenText = cleanAgent
            self.synthesizer.speak(agentUtterance)
        }
        
        let sourceUtterance = makeUtterance(text: cleanTransition)
        sourceUtterance.voice = getSiriVoice(for: sourceAgent)
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        switch sourceAgent {
        case .sarah:  sourceUtterance.pitchMultiplier = 1.00; sourceUtterance.rate = 0.48
        case .nathan: sourceUtterance.pitchMultiplier = 0.96
        case .esther: sourceUtterance.pitchMultiplier = 1.05
        case .tom:    sourceUtterance.pitchMultiplier = 0.92
        case .yohan:  sourceUtterance.pitchMultiplier = 0.90
        case .ethel:  sourceUtterance.pitchMultiplier = 1.03
        }
        currentSpokenText = cleanTransition
        synthesizer.speak(sourceUtterance)
    }
    
    public func stop() {
        pendingSpeechBlock = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentSpokenText = ""

        // Ne jamais conserver la route .playAndRecord une fois la voix coupée.
        if !WhisperSpeechRecognizer.shared.isListening {
            AudioSessionManager.shared.deactivateSession()
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
            currentSpokenText = ""
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentSpokenText = ""
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
}

/// Alias MultiAgentVoiceManager pour compatibilité globale avec les ViewModels et Services
public typealias MultiAgentVoiceManager = AgentVoiceManager
