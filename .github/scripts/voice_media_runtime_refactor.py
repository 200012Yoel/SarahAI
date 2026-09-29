from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing expected block: {label}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# ChatViewModel: true barge-in lifecycle for continuous voice mode
# -----------------------------------------------------------------------------
vm_path = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
vm = vm_path.read_text()

vm = replace_once(
    vm,
    '''        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            self?.liveTranscriptionText = partial
        }
''',
    '''        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            guard let self = self else { return }
            self.liveTranscriptionText = partial

            guard self.isContinuousConversationActive,
                  self.voiceManager.isSpeaking,
                  self.shouldInterruptCurrentSpeech(with: partial) else { return }

            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.voiceManager.stop()
            self.isSpeaking = false
            self.voiceStatus = .listening(level: self.micInputLevel)
        }
''',
    "voice partial barge-in"
)

vm = replace_once(
    vm,
    '''            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)
''',
    '''            self.liveTranscriptionText = ""
            if self.voiceManager.isSpeaking {
                self.voiceManager.stop()
                self.isSpeaking = false
            }
            self.sendMessage(cleaned)
''',
    "final transcription interrupts speech"
)

vm = replace_once(
    vm,
    '''        voiceManager.onSpeechStarted = { [weak self] in
            self?.isSpeaking = true
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
''',
    '''        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.voiceStatus = .speaking
            self.haptics.speechStarted()

            // Full-duplex voice: keep the microphone listening while Sarah speaks.
            // The partial-transcription echo guard above decides whether the sound
            // is Sarah's own playback or a genuine user interruption.
            if self.isContinuousConversationActive,
               !self.isVoiceMicrophoneMuted,
               !AppleSpeechRecognizer.shared.isListening {
                AppleSpeechRecognizer.shared.startListening(
                    autoFinalizeOnSilence: true,
                    preserveActiveSpeech: true
                )
            }
        }
''',
    "speech started full duplex"
)

old_finish = '''        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.voiceStatus = .idle
            self.haptics.speechFinished()
            
            if self.isContinuousConversationActive && self.isShowingVoiceOrbModal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard self.isContinuousConversationActive,
                          self.isShowingVoiceOrbModal,
                          !self.voiceManager.isSpeaking else { return }
                    AppleSpeechRecognizer.shared.startListening()
                    self.isMicRunning = AppleSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning ? .listening(level: 0.0) : .idle
                }
            }
        }
'''
new_finish = '''        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            guard self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal,
                  !self.isVoiceMicrophoneMuted else {
                self.voiceStatus = .idle
                return
            }

            if !AppleSpeechRecognizer.shared.isListening {
                AppleSpeechRecognizer.shared.startListening(
                    autoFinalizeOnSilence: true,
                    preserveActiveSpeech: true
                )
            }
            self.isMicRunning = AppleSpeechRecognizer.shared.isListening
            self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .idle
        }
'''
vm = replace_once(vm, old_finish, new_finish, "speech finished resume")

old_start = '''    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()
        voiceManager.stop()
        isContinuousConversationActive = true

        guard !AppleSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
    }
'''
new_start = '''    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()
        voiceManager.stop()
        AudioSessionManager.shared.beginContinuousVoiceSession()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        guard !AppleSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        AppleSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: true
        )
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
    }
'''
vm = replace_once(vm, old_start, new_start, "start continuous voice")

vm = replace_once(
    vm,
    '''        AppleSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.deactivateSession()

        isMicRunning = false
''',
    '''        AppleSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.endContinuousVoiceSession()

        isMicRunning = false
''',
    "end continuous voice"
)

marker = '''    public func toggleMicrophone() {
'''
helper = '''    private func normalizedVoiceComparisonText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func shouldInterruptCurrentSpeech(with partial: String) -> Bool {
        let heard = normalizedVoiceComparisonText(partial)
        guard !heard.isEmpty else { return false }

        let explicitInterruptions = [
            "stop", "coupe", "attend", "attends", "non", "pause", "pardon",
            "c est pas ca", "ce n est pas ca", "laisse moi parler"
        ]
        if explicitInterruptions.contains(where: { heard == $0 || heard.hasPrefix($0 + " ") }) {
            return true
        }

        let heardWords = heard.split(separator: " ").map(String.init)
        guard heardWords.count >= 2 else { return false }

        let spoken = normalizedVoiceComparisonText(voiceManager.currentSpokenText)
        guard !spoken.isEmpty else { return true }
        let spokenWords = Set(spoken.split(separator: " ").map(String.init))
        let overlap = heardWords.filter { spokenWords.contains($0) }.count
        let ratio = Double(overlap) / Double(max(1, heardWords.count))

        // If most recognized words are already in Sarah's sentence, it is likely
        // speaker echo. A genuinely different two-word phrase interrupts at once.
        return ratio < 0.62
    }

'''
if helper.strip() not in vm:
    if marker not in vm:
        raise SystemExit("Missing toggleMicrophone marker")
    vm = vm.replace(marker, helper + marker, 1)

vm_path.write_text(vm)


# -----------------------------------------------------------------------------
# MultiAgentVoiceManager: do not kill the recognizer in continuous voice mode
# -----------------------------------------------------------------------------
voice_path = Path("SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift")
voice = voice_path.read_text()

if "public private(set) var currentSpokenText" not in voice:
    voice = replace_once(
        voice,
        '''    private let synthesizer = AVSpeechSynthesizer()
    
    public var onSpeechStarted: (() -> Void)?
''',
        '''    private let synthesizer = AVSpeechSynthesizer()
    public private(set) var currentSpokenText: String = ""
    
    public var onSpeechStarted: (() -> Void)?
''',
        "current spoken text"
    )

voice = replace_once(
    voice,
    '''        // Ne jamais laisser reconnaissance + synthèse tourner en même temps.
        // Deux AVAudioEngine concurrents peuvent provoquer du routage audio instable
        // et des ralentissements à l'échelle du téléphone.
        AppleSpeechRecognizer.shared.stopListening()
        stop()
''',
    '''        // In continuous voice mode the microphone intentionally remains active
        // so the user can interrupt Sarah. Outside that mode we keep the historical
        // single-source behaviour for ordinary message playback.
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            AppleSpeechRecognizer.shared.stopListening()
        }
        stop()
''',
    "voice manager preserve recognizer"
)

old_session = '''        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("⚠️ [AgentVoiceManager] Erreur configuration AVAudioSession: \\(error.localizedDescription)")
        }
'''
if old_session in voice:
    voice = voice.replace(old_session, '''        AudioSessionManager.shared.configurePlaybackSession()
''', 1)

voice = replace_once(
    voice,
    '''        print("🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? "fr-FR") | ID: \\(resolvedVoice?.identifier ?? "")")
        synthesizer.speak(utterance)
''',
    '''        currentSpokenText = cleaned
        print("🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? "fr-FR") | ID: \\(resolvedVoice?.identifier ?? "")")
        synthesizer.speak(utterance)
''',
    "track current speech"
)

voice = replace_once(
    voice,
    '''    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        AppleSpeechRecognizer.shared.stopListening()
        stop()
''',
    '''    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            AppleSpeechRecognizer.shared.stopListening()
        }
        stop()
''',
    "handoff preserve recognizer"
)

voice = replace_once(
    voice,
    '''            self.synthesizer.speak(agentUtterance)
''',
    '''            self.currentSpokenText = cleanAgent
            self.synthesizer.speak(agentUtterance)
''',
    "handoff target speech text"
)

voice = replace_once(
    voice,
    '''        synthesizer.speak(sourceUtterance)
    }
    
    public func stop() {
''',
    '''        currentSpokenText = cleanTransition
        synthesizer.speak(sourceUtterance)
    }
    
    public func stop() {
''',
    "handoff source speech text"
)

voice = replace_once(
    voice,
    '''        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Ne jamais conserver la route .playAndRecord une fois la voix coupée.
''',
    '''        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentSpokenText = ""

        // Ne jamais conserver la route .playAndRecord une fois la voix coupée.
''',
    "clear speech text on stop"
)

voice = replace_once(
    voice,
    '''        } else {
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
''',
    '''        } else {
            currentSpokenText = ""
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
''',
    "clear speech text on finish"
)

voice = replace_once(
    voice,
    '''    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
''',
    '''    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentSpokenText = ""
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
''',
    "clear speech text on cancel"
)

voice_path.write_text(voice)


# -----------------------------------------------------------------------------
# WhisperService: stop pretending the Apple recognizer is Whisper
# -----------------------------------------------------------------------------
whisper_path = Path("SarahIA/SarahIA/Services/WhisperService.swift")
whisper = whisper_path.read_text()
whisper = whisper.replace(
    "/// Service de Reconnaissance Vocale Local et Gratuit (remplaçant Whisper)",
    "/// Façade de transcription vocale. Cette build utilise Apple Speech on-device quand disponible; le nom historique est conservé pour compatibilité."
)
whisper_path.write_text(whisper)


# -----------------------------------------------------------------------------
# Image routing: local-only by default, auto-prepare the Core ML model on request
# -----------------------------------------------------------------------------
ai_path = Path("SarahIA/SarahIA/Services/AIService.swift")
ai = ai_path.read_text()
image_anchor = '''        if imageCheck.isIntent {
            let prompt = imageCheck.cleanedPrompt
            let profile = SarahGenerativeModelCatalog.imageProfile()

            OpenSourceImageGenerationService.shared.generateImage(prompt: prompt) { [weak self] result in
'''
image_replacement = '''        if imageCheck.isIntent {
            let prompt = imageCheck.cleanedPrompt
            let profile = SarahGenerativeModelCatalog.imageProfile()

            // Commercial/local profile: never silently send the prompt to a third-party
            // image endpoint. If the Core ML weights are absent, prepare them on Wi-Fi.
            OpenSourceImageGenerationService.shared.cloudFallbackEnabled = false

            OpenSourceImageGenerationService.shared.generateImage(prompt: prompt) { [weak self] result in
'''
ai = replace_once(ai, image_anchor, image_replacement, "local-only image routing")

old_failure = '''                } else {
                    reply = """
                    🎨 **Création locale indisponible**

                    Sarah a sélectionné **\\(profile.displayName)** pour cet appareil, mais la génération n'a pas pu démarrer :
                    \\(result.errorMessage ?? "ressources locales indisponibles").

                    Le fallback réseau est \\(OpenSourceImageGenerationService.shared.cloudFallbackEnabled ? "activé" : "désactivé").
                    """
                }
'''
new_failure = '''                } else {
                    let detail = result.errorMessage ?? "ressources locales indisponibles"
                    if detail.localizedCaseInsensitiveContains("pas installé") ||
                       detail.localizedCaseInsensitiveContains("not installed") {
                        if #available(iOS 13.0, *) {
                            GenerativeModelDownloader.shared.startImageModelDownload()
                        }
                        reply = """
                        🎨 **Préparation du modèle image local**

                        Sarah prépare **\\(profile.displayName)** en Wi-Fi. Aucun prompt n'est envoyé à un service d'images tiers. Une fois l'installation terminée, relance simplement ta demande d'image.
                        """
                    } else {
                        reply = """
                        🎨 **Création locale indisponible**

                        Sarah a sélectionné **\\(profile.displayName)** pour cet appareil, mais la génération n'a pas pu démarrer :
                        \\(detail).

                        Le fallback réseau est désactivé pour garder ce chemin local.
                        """
                    }
                }
'''
ai = replace_once(ai, old_failure, new_failure, "image missing-model auto prepare")
ai_path.write_text(ai)

print("voice/media runtime refactor applied")
