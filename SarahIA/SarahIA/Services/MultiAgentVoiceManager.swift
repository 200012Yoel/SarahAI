import Foundation
import AVFoundation

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Multi-Agents
/// Chaque agent reçoit un profil vocal Apple distinct. iOS ne donne pas aux apps
/// tierces l'identifiant privé des voix numérotées de Siri ; on reproduit donc
/// l'idée « Voix 1 à 5 » avec cinq voix Apple installées, choisies de façon stable.
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingSpeechBlock: (() -> Void)?
    private var cachedFrenchVoices: [AVSpeechSynthesisVoice] = []

    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
        refreshSystemVoiceSelection()
    }

    /// Recharge les voix installées. Les voix Premium/Enhanced passent avant les
    /// voix compactes, puis le tri par identifiant garde un ordre stable.
    @objc public func refreshSystemVoiceSelection() {
        var seen = Set<String>()
        cachedFrenchVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("fr") }
            .sorted { lhs, rhs in
                let left = qualityScore(lhs)
                let right = qualityScore(rhs)
                if left != right { return left > right }
                if lhs.language != rhs.language { return lhs.language < rhs.language }
                return lhs.identifier < rhs.identifier
            }
            .filter { voice in
                guard !seen.contains(voice.identifier) else { return false }
                seen.insert(voice.identifier)
                return true
            }
    }

    /// Profil vocal 1...5 demandé pour les agents principaux.
    /// Ethel partage le profil 5 afin de conserver cinq profils au total.
    private func voiceSlot(for agent: AgentPersona) -> Int {
        switch agent {
        case .sarah:  return 0 // Voix 1
        case .esther: return 1 // Voix 2 - Raphaël
        case .tom:    return 2 // Voix 3
        case .yohan:  return 3 // Voix 4
        case .nathan: return 4 // Voix 5
        case .ethel:  return 4 // partage Voix 5
        }
    }

    private func qualityScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        if #available(iOS 16.0, *), voice.quality == .premium { return 3 }
        if voice.quality == .enhanced { return 2 }
        return 1
    }

    /// Retourne le profil vocal Apple de l'agent. Si l'iPhone possède moins de
    /// cinq voix françaises, on retombe proprement sur la voix de langue système.
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        if cachedFrenchVoices.isEmpty {
            refreshSystemVoiceSelection()
        }

        let slot = voiceSlot(for: agent)
        if cachedFrenchVoices.indices.contains(slot) {
            return cachedFrenchVoices[slot]
        }

        // Les anciens identifiants restent d'excellents replis quand la voix est
        // effectivement installée sur l'appareil.
        for identifier in agent.preferredSpeechVoiceIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: agent.localeCode)
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent)
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
            ?? AVSpeechSynthesisVoice()
    }

    /// Nettoyage du texte pour éviter de lire les marqueurs Markdown.
    public func cleanTextForSpeech(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "•", with: " ")
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
                let pattern = "(?<![\\p{L}\\p{N}])"
                    + NSRegularExpression.escapedPattern(for: spelling)
                    + "(?![\\p{L}\\p{N}])"
                guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
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

    private func containsHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0590...0x05FF).contains(Int(scalar.value))
        }
    }

    private func resolvedVoice(for agent: AgentPersona, text: String) -> AVSpeechSynthesisVoice? {
        // Yohan peut lire correctement une réponse réellement en hébreu sans
        // sacrifier son profil Voix 4 pour les phrases françaises.
        if containsHebrew(text), let hebrew = AVSpeechSynthesisVoice(language: "he-IL") {
            return hebrew
        }
        return getSiriVoice(for: agent)
    }

    private func prepareAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("⚠️ [AgentVoiceManager] AVAudioSession: \(error.localizedDescription)")
        }
    }

    public func speak(
        text: String,
        as agent: AgentPersona,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate
    ) {
        AppleSpeechRecognizer.shared.stopListening()
        stop()
        pendingSpeechBlock = nil

        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }

        prepareAudioSession()

        let utterance = makeUtterance(text: cleaned)
        let voice = resolvedVoice(for: agent, text: cleaned)
        utterance.voice = voice
        utterance.pitchMultiplier = 1.0
        utterance.rate = rate

        let voiceName = voice?.name ?? "fr-FR"
        print("🔊 [AgentVoiceManager] \(agent.displayName) · Voix \(voiceSlot(for: agent) + 1) · \(voiceName)")
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

        prepareAudioSession()

        pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            let utterance = self.makeUtterance(text: cleanAgent)
            utterance.voice = self.resolvedVoice(for: targetAgent, text: cleanAgent)
            utterance.pitchMultiplier = 1.0
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            self.synthesizer.speak(utterance)
        }

        let sourceUtterance = makeUtterance(text: cleanTransition)
        sourceUtterance.voice = resolvedVoice(for: sourceAgent, text: cleanTransition)
        sourceUtterance.pitchMultiplier = 1.0
        sourceUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
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

    public var isSpeaking: Bool { synthesizer.isSpeaking }

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
