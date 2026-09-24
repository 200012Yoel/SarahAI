import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Gestionnaire Audio & Synthèse Vocale Apple Multi-Agents
///
/// Les agents utilisent volontairement la voix système Apple correspondant à leur
/// langue. Une application tierce ne peut pas lire ni réutiliser de façon fiable
/// l'identifiant interne de la voix actuellement choisie pour l'assistant Siri.
/// En laissant AVSpeechSynthesisVoice résoudre la langue, Sarah suit le choix TTS
/// standard disponible sur l'iPhone au lieu d'imposer des timbres personnalisés.
public final class AgentVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AgentVoiceManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingSpeechBlock: (() -> Void)?

    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Conservé pour compatibilité avec l'ancienne implémentation.
    /// Il n'y a plus de cache de voix à reconstruire : la voix système est
    /// résolue au moment où chaque phrase est prononcée.
    @objc public func refreshSystemVoiceSelection() {
        // Intentionnellement vide.
    }

    /// Retourne la voix TTS Apple par défaut pour la langue de l'agent.
    /// Le nom historique de la méthode est conservé pour ne pas casser les appels.
    public func getSiriVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice? {
        return AVSpeechSynthesisVoice(language: agent.localeCode)
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    public func getVoice(for agent: AgentPersona) -> AVSpeechSynthesisVoice {
        return getSiriVoice(for: agent)
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
            ?? AVSpeechSynthesisVoice()
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
    /// noms propres portent une notation IPA afin d'éviter les prononciations
    /// incorrectes tout en gardant l'orthographe normale à l'écran.
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

    private func prepareAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("⚠️ [AgentVoiceManager] Erreur configuration AVAudioSession: \(error.localizedDescription)")
        }
    }

    /// Prononce avec les réglages Apple standards : aucune hauteur de voix ou
    /// vitesse propre à un agent n'est imposée.
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
        let resolvedVoice = getSiriVoice(for: agent)
        utterance.voice = resolvedVoice
        utterance.pitchMultiplier = 1.0
        utterance.rate = rate

        print(
            "🔊 [AgentVoiceManager] Synthèse vocale [\(agent.rawValue)] via voix système Apple \(resolvedVoice?.name ?? \"fr-FR\")"
        )
        synthesizer.speak(utterance)
    }

    /// Compatibilité speak(text:for:)
    public func speak(text: String, for agent: AgentType) {
        speak(text: text, as: agent)
    }

    /// Passation vocale séquentielle entre deux agents, toujours avec les
    /// réglages de voix système Apple standards.
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
            let agentUtterance = self.makeUtterance(text: cleanAgent)
            agentUtterance.voice = self.getSiriVoice(for: targetAgent)
            agentUtterance.pitchMultiplier = 1.0
            agentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
            self.synthesizer.speak(agentUtterance)
        }

        let sourceUtterance = makeUtterance(text: cleanTransition)
        sourceUtterance.voice = getSiriVoice(for: sourceAgent)
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

    public var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        onSpeechStarted?()
    }

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        if let next = pendingSpeechBlock {
            pendingSpeechBlock = nil
            next()
        } else {
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
}

/// Alias MultiAgentVoiceManager pour compatibilité globale avec les ViewModels et Services.
public typealias MultiAgentVoiceManager = AgentVoiceManager
