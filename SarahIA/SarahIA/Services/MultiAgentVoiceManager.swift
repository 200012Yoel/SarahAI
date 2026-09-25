import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Siri Multi-Agents
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()

    private let synthesizer = AVSpeechSynthesizer()

    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil

    // Les voix sont résolues une fois puis conservées pendant la session.
    private var agentVoices: [AgentType: AVSpeechSynthesisVoice] = [:]

    public override init() {
        super.init()
        synthesizer.delegate = self
        resolveAllDistinctVoices()

        #if canImport(UIKit)
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

    /// Relit les voix système uniquement hors conversation vocale. Pendant un
    /// appel vocal Sarah, le timbre reste donc identique du début à la fin.
    @objc public func refreshSystemVoiceSelection() {
        guard !AudioSessionManager.shared.isContinuousVoiceSessionActive else { return }
        agentVoices.removeAll()
        resolveAllDistinctVoices()
    }

    private func resolveAllDistinctVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        var usedIdentifiers = Set<String>()
        let orderedAgents: [AgentType] = [.sarah, .nathan, .esther, .tom, .yohan, .ethel]
        let frenchVoices = allVoices.filter {
            $0.language.replacingOccurrences(of: "_", with: "-").hasPrefix("fr")
        }

        for agent in orderedAgents {
            var selectedVoice: AVSpeechSynthesisVoice? = nil

            for identifier in agent.preferredSpeechVoiceIdentifiers where selectedVoice == nil {
                if let directVoice = AVSpeechSynthesisVoice(identifier: identifier),
                   !usedIdentifiers.contains(directVoice.identifier) {
                    selectedVoice = directVoice
                }
            }

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

            if selectedVoice == nil,
               (agent == .sarah || agent == .nathan),
               let systemFrenchVoice = AVSpeechSynthesisVoice(language: agent.localeCode),
               normalizedLanguageCode(systemFrenchVoice.language) == "fr-fr",
               !usedIdentifiers.contains(systemFrenchVoice.identifier) {
                selectedVoice = systemFrenchVoice
            }

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
                        ($0.name.localizedCaseInsensitiveContains(name) ||
                         $0.identifier.localizedCaseInsensitiveContains(name))
                    }) {
                        selectedVoice = match
                        break
                    }
                }
            }

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

            let finalVoice = selectedVoice
                ?? AVSpeechSynthesisVoice(language: agent.localeCode)
                ?? AVSpeechSynthesisVoice(language: "fr-FR")
                ?? AVSpeechSynthesisVoice()

            agentVoices[agent] = finalVoice
            usedIdentifiers.insert(finalVoice.identifier)
        }
    }

    private func normalizedLanguageCode(_ language: String) -> String {
        language
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        if let cached = agentVoices[agent] {
            return cached
        }
        resolveAllDistinctVoices()
        return agentVoices[agent] ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        getSiriVoice(for: agent)
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
            ?? AVSpeechSynthesisVoice()
    }

    public func cleanTextForSpeech(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

    /// Applique exactement le même timbre et la même vitesse quel que soit le
    /// chemin de lecture (réponse simple ou passation entre agents).
    private func configureUtterance(_ utterance: AVSpeechUtterance, for agent: AgentType) {
        utterance.voice = getSiriVoice(for: agent) ?? AVSpeechSynthesisVoice(language: "fr-FR")
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
    }

    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        // Le micro est arrêté, mais la session AVAudioSession reste active quand
        // le mode vocal continu est ouvert.
        AppleSpeechRecognizer.shared.stopListening()
        stop()
        pendingSpeechBlock = nil

        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }

        AudioSessionManager.shared.configurePlaybackSession()

        let utterance = makeUtterance(text: cleaned)
        configureUtterance(utterance, for: agent)
        synthesizer.speak(utterance)
    }

    public func speak(text: String, for agent: AgentType) {
        speak(text: text, as: agent)
    }

    public func speakHandoff(
        transitionText: String,
        sourceAgent: AgentType,
        agentGreeting: String,
        targetAgent: AgentType
    ) {
        AppleSpeechRecognizer.shared.stopListening()
        stop()

        let cleanTransition = cleanTextForSpeech(transitionText)
        let cleanAgent = cleanTextForSpeech(agentGreeting)

        guard !cleanTransition.isEmpty else {
            speak(text: cleanAgent, as: targetAgent)
            return
        }

        AudioSessionManager.shared.configurePlaybackSession()

        pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            let agentUtterance = self.makeUtterance(text: cleanAgent)
            self.configureUtterance(agentUtterance, for: targetAgent)
            self.synthesizer.speak(agentUtterance)
        }

        let sourceUtterance = makeUtterance(text: cleanTransition)
        configureUtterance(sourceUtterance, for: sourceAgent)
        synthesizer.speak(sourceUtterance)
    }

    public func stop() {
        pendingSpeechBlock = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        if !AppleSpeechRecognizer.shared.isListening {
            AudioSessionManager.shared.deactivateSession()
        }
    }

    public var isSpeaking: Bool {
        synthesizer.isSpeaking
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
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
}

public typealias MultiAgentVoiceManager = AgentVoiceManager
