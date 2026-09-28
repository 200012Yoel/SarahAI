from pathlib import Path

# ---------------- AppleSpeechRecognizer ----------------
path = Path('SarahIA/SarahIA/Services/AppleSpeechRecognizer.swift')
text = path.read_text()

text = text.replace(
    '    private let silenceThreshold: TimeInterval = 1.0\n',
    '    private let silenceThreshold: TimeInterval = 0.82\n',
    1
)

old_sig = '    public func startListening(autoFinalizeOnSilence: Bool = true) {\n'
new_sig = '    public func startListening(autoFinalizeOnSilence: Bool = true, preserveActiveSpeech: Bool = false) {\n'
if old_sig not in text and new_sig not in text:
    raise SystemExit('AppleSpeechRecognizer startListening signature not found')
text = text.replace(old_sig, new_sig, 1)

text = text.replace(
    '                self.startListening(autoFinalizeOnSilence: autoFinalizeOnSilence)\n',
    '                self.startListening(autoFinalizeOnSilence: autoFinalizeOnSilence, preserveActiveSpeech: preserveActiveSpeech)\n',
    1
)

old_stop = '''        // Une seule source audio doit être active à la fois. On coupe les lecteurs
        // réellement actifs, sans réveiller l'ancien moteur audio juste pour appeler stop().
        MultiAgentVoiceManager.shared.stop()
        if SpeechManager.shared.isSpeaking {
            SpeechManager.shared.stopSpeaking()
        }
        if #available(iOS 13.0, *) {
            let legacyTTS = TTSService.shared
            if legacyTTS.isSpeaking {
                legacyTTS.stopSpeaking()
            }
        }
'''
new_stop = '''        // En conversation normale, une seule source vocale est active. En mode
        // barge-in, on garde volontairement la synthèse en cours : le micro écoute
        // pendant que Sarah parle afin que l'utilisateur puisse l'interrompre.
        if !preserveActiveSpeech {
            MultiAgentVoiceManager.shared.stop()
            if SpeechManager.shared.isSpeaking {
                SpeechManager.shared.stopSpeaking()
            }
            if #available(iOS 13.0, *) {
                let legacyTTS = TTSService.shared
                if legacyTTS.isSpeaking {
                    legacyTTS.stopSpeaking()
                }
            }
        }
'''
if old_stop not in text and new_stop not in text:
    raise SystemExit('AppleSpeechRecognizer active speech block not found')
text = text.replace(old_stop, new_stop, 1)

old_device = '''        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }
'''
new_device = '''        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            // Équivalent local à un petit Whisper pour le français quand iOS le
            // permet : aucune requête serveur n'est nécessaire sur les appareils
            // qui exposent la reconnaissance Speech hors-ligne.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
'''
if old_device not in text and new_device not in text:
    raise SystemExit('AppleSpeechRecognizer on-device block not found')
text = text.replace(old_device, new_device, 1)
path.write_text(text)

# ---------------- ChatViewModel ----------------
path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
text = path.read_text()

marker = '    private var websiteGenerationID = UUID()\n'
if 'private var isBargeInMonitorActive' not in text:
    if marker not in text:
        raise SystemExit('ChatViewModel private state marker not found')
    text = text.replace(
        marker,
        marker + '    private var isBargeInMonitorActive = false\n',
        1
    )

old_barge = '''                // Deux mots réellement nouveaux suffisent pour prendre la parole,
                // mais une transcription qui ressemble fortement à la voix du haut-parleur
                // est ignorée pour éviter les auto-interruptions.
                let naturalBargeIn = partialWords.count >= 2 && overlapRatio < 0.45

                if explicitInterrupt || naturalBargeIn {
                    self.interruptVoiceResponse()
                    self.liveTranscriptionText = partial
                }
'''
new_barge = '''                // Barge-in conversationnel : un mot net qui n'appartient pas à la
                // phrase de Sarah, ou deux mots faiblement ressemblants, suffisent pour
                // couper la synthèse. Le mode voiceChat de la session audio réduit l'écho.
                let hasStrongNovelWord = partialWords.contains { word in
                    word.count >= 3 && !spokenWords.contains(word)
                }
                let naturalBargeIn =
                    (hasStrongNovelWord && overlapRatio < 0.34) ||
                    (partialWords.count >= 2 && overlapRatio < 0.58)

                if explicitInterrupt || naturalBargeIn {
                    self.isBargeInMonitorActive = false
                    self.interruptVoiceResponse()
                    self.liveTranscriptionText = partial
                }
'''
if old_barge not in text and new_barge not in text:
    raise SystemExit('ChatViewModel barge-in block not found')
text = text.replace(old_barge, new_barge, 1)

old_final_guard = '''            // Tant que la synthèse parle encore, un résultat final peut être l'écho
            // du haut-parleur. Un vrai barge-in coupe la synthèse dès le partiel,
            // donc son résultat final arrive ensuite avec isSpeaking == false.
            guard !self.voiceManager.isSpeaking else {
                self.liveTranscriptionText = ""
                return
            }
'''
new_final_guard = '''            // Tant que Sarah parle encore, un résultat final peut être un reste
            // d'écho. On le jette puis on réarme immédiatement l'écoute barge-in
            // au lieu de laisser le micro muet jusqu'à la fin de la réponse.
            guard !self.voiceManager.isSpeaking else {
                self.liveTranscriptionText = ""
                self.isBargeInMonitorActive = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    guard self.isContinuousConversationActive,
                          self.voiceManager.isSpeaking,
                          !self.isVoiceMicrophoneMuted,
                          !AppleSpeechRecognizer.shared.isListening else { return }
                    self.isBargeInMonitorActive = true
                    AppleSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true,
                        preserveActiveSpeech: true
                    )
                    self.isMicRunning = AppleSpeechRecognizer.shared.isListening
                    self.voiceStatus = .speaking
                }
                return
            }
'''
if old_final_guard not in text and new_final_guard not in text:
    raise SystemExit('ChatViewModel final-transcription guard not found')
text = text.replace(old_final_guard, new_final_guard, 1)

old_started = '''        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.isMicRunning = AppleSpeechRecognizer.shared.isListening
            self.voiceStatus = .speaking
            self.haptics.speechStarted()
        }
'''
new_started = '''        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.voiceStatus = .speaking
            self.haptics.speechStarted()

            // Le micro reste en veille pendant la synthèse. C'est le vrai barge-in :
            // parler pendant la réponse déclenche onPartialTranscription puis coupe Sarah.
            if self.isContinuousConversationActive,
               !self.isVoiceMicrophoneMuted {
                self.isBargeInMonitorActive = true
                AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
                if !AppleSpeechRecognizer.shared.isListening {
                    AppleSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true,
                        preserveActiveSpeech: true
                    )
                }
            }
            self.isMicRunning = AppleSpeechRecognizer.shared.isListening
        }
'''
if old_started not in text and new_started not in text:
    raise SystemExit('ChatViewModel onSpeechStarted block not found')
text = text.replace(old_started, new_started, 1)

old_finished = '''        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            guard self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal,
                  !self.isVoiceMicrophoneMuted,
                  !self.shouldResumeVoiceAfterSystemInterruption else {
                self.voiceStatus = .idle
                return
            }

            self.voiceStatus = .starting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard self.isContinuousConversationActive,
                      self.isShowingVoiceOrbModal,
                      !self.isVoiceMicrophoneMuted,
                      !self.shouldResumeVoiceAfterSystemInterruption,
                      !self.voiceManager.isSpeaking else { return }
                if AppleSpeechRecognizer.shared.isListening {
                    self.isMicRunning = true
                    self.voiceStatus = .listening(level: self.micInputLevel)
                    return
                }
                self.resumeVoiceMicrophone()
            }
        }
'''
new_finished = '''        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            guard self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal,
                  !self.isVoiceMicrophoneMuted,
                  !self.shouldResumeVoiceAfterSystemInterruption else {
                self.isBargeInMonitorActive = false
                self.voiceStatus = .idle
                return
            }

            // Si l'écoute en cours servait uniquement à détecter une interruption,
            // on la recrée proprement pour effacer tout éventuel écho de la phrase
            // de Sarah avant d'attendre la prochaine vraie demande utilisateur.
            if self.isBargeInMonitorActive {
                self.isBargeInMonitorActive = false
                AppleSpeechRecognizer.shared.stopListening()
            }

            self.voiceStatus = .starting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                guard self.isContinuousConversationActive,
                      self.isShowingVoiceOrbModal,
                      !self.isVoiceMicrophoneMuted,
                      !self.shouldResumeVoiceAfterSystemInterruption,
                      !self.voiceManager.isSpeaking else { return }
                if AppleSpeechRecognizer.shared.isListening {
                    self.isMicRunning = true
                    self.voiceStatus = .listening(level: self.micInputLevel)
                    return
                }
                self.resumeVoiceMicrophone()
            }
        }
'''
if old_finished not in text and new_finished not in text:
    raise SystemExit('ChatViewModel onSpeechFinished block not found')
text = text.replace(old_finished, new_finished, 1)

# Ensure state is reset when a voice session starts/stops or is explicitly interrupted.
text = text.replace(
    '        isContinuousConversationActive = true\n        isVoiceMicrophoneMuted = false\n',
    '        isContinuousConversationActive = true\n        isVoiceMicrophoneMuted = false\n        isBargeInMonitorActive = false\n',
    1
)
text = text.replace(
    '    public func interruptVoiceResponse() {\n        ensureVoicePipelinePrepared()\n        voiceManager.stop()\n',
    '    public func interruptVoiceResponse() {\n        ensureVoicePipelinePrepared()\n        isBargeInMonitorActive = false\n        voiceManager.stop()\n',
    1
)
text = text.replace(
    '        isContinuousConversationActive = false\n        isVoiceMicrophoneMuted = true\n',
    '        isContinuousConversationActive = false\n        isVoiceMicrophoneMuted = true\n        isBargeInMonitorActive = false\n',
    1
)

# Helper used by the website-builder UI before any explicit navigation.
helper_marker = '''    public func speakWebsiteGuide(_ text: String) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speak(text: text, for: .esther)
    }
'''
helper_new = helper_marker + '''
    public func cancelWebsiteGuideSpeech() {
        guard isContinuousConversationActive else { return }
        interruptVoiceResponse()
    }
'''
if 'public func cancelWebsiteGuideSpeech()' not in text:
    if helper_marker not in text:
        raise SystemExit('speakWebsiteGuide helper marker not found')
    text = text.replace(helper_marker, helper_new, 1)

path.write_text(text)

# ---------------- WebsiteBuilderFlowView ----------------
path = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
text = path.read_text()

# Manual navigation must stop any old spoken menu before changing the visible page.
text = text.replace(
'''                Button("Retour") {
                    HapticService.shared.buttonTap()
                    voiceGuideGeneration = UUID()
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                    announceCurrentStepAfterManualNavigation()
                }
''',
'''                Button("Retour") {
                    HapticService.shared.buttonTap()
                    voiceGuideGeneration = UUID()
                    if viewModel.isContinuousConversationActive {
                        viewModel.cancelWebsiteGuideSpeech()
                    }
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                    announceCurrentStepAfterManualNavigation()
                }
''', 1)

text = text.replace(
'''            Button(step == 4 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                voiceGuideGeneration = UUID()
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    announceCurrentStepAfterManualNavigation()
                }
            }
''',
'''            Button(step == 4 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                voiceGuideGeneration = UUID()
                if viewModel.isContinuousConversationActive {
                    viewModel.cancelWebsiteGuideSpeech()
                }
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    announceCurrentStepAfterManualNavigation()
                }
            }
''', 1)

old_confirm = '''    private func confirmVoiceChoiceAndAdvance(_ text: String, to nextStep: Int) {
        let generation = UUID()
        voiceGuideGeneration = generation
        viewModel.speakWebsiteGuideSequence(
            [text],
            onItemStart: { _ in },
            completion: {
                guard voiceGuideGeneration == generation,
                      viewModel.isShowingWebsiteBuilder else { return }
                withAnimation(.easeInOut(duration: 0.18)) { step = nextStep }
                readCurrentVoiceOptions()
            }
        )
    }
'''
new_confirm = '''    private func confirmVoiceChoiceWithoutAdvance(_ text: String) {
        voiceGuideGeneration = UUID()
        voiceFocusedOption = nil
        viewModel.speakWebsiteGuide(text + " Je reste sur cette question. Dis suivant quand tu veux continuer.")
    }
'''
if old_confirm not in text and new_confirm not in text:
    raise SystemExit('WebsiteBuilder confirmVoiceChoiceAndAdvance not found')
text = text.replace(old_confirm, new_confirm, 1)

text = text.replace(
    '            confirmVoiceChoiceAndAdvance("Très bien. \\(choice.title) est sélectionné.", to: 1)',
    '            confirmVoiceChoiceWithoutAdvance("Très bien. \\(choice.title) est sélectionné.")'
)
text = text.replace(
    '                confirmVoiceChoiceAndAdvance("Public \\(choice.title) sélectionné.", to: 2)',
    '                confirmVoiceChoiceWithoutAdvance("Public \\(choice.title) sélectionné.")'
)
text = text.replace(
    '            confirmVoiceChoiceAndAdvance("Ambiance \\(choice.title) sélectionnée.", to: 3)',
    '            confirmVoiceChoiceWithoutAdvance("Ambiance \\(choice.title) sélectionnée.")'
)
text = text.replace(
    '            confirmVoiceChoiceAndAdvance("Style \\(choice.title) sélectionné. Cette direction sera réellement utilisée dans le rendu.", to: 4)',
    '            confirmVoiceChoiceWithoutAdvance("Style \\(choice.title) sélectionné. Cette direction sera réellement utilisée dans le rendu.")'
)

old_free = '''                confirmVoiceChoiceAndAdvance(
                    "D'accord. Je retiens comme public : \\(freeAudience). On passe maintenant à l'ambiance graphique.",
                    to: 2
                )
'''
new_free = '''                confirmVoiceChoiceWithoutAdvance(
                    "D'accord. Je retiens comme public : \\(freeAudience)."
                )
'''
if old_free not in text and new_free not in text:
    raise SystemExit('WebsiteBuilder free audience advance block not found')
text = text.replace(old_free, new_free, 1)

# Explicit voice navigation is the only voice path allowed to change the page.
old_next = '''        if normalized == "suivant" || normalized.contains("continue") || normalized.contains("valide") || normalized.contains("c est bon") {
            if canContinue {
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    readCurrentVoiceOptions()
                }
            } else {
                viewModel.speakWebsiteGuide("Il me manque encore un choix avant de continuer.")
            }
            return
        }
'''
new_next = '''        if normalized == "suivant" || normalized.contains("continue") || normalized.contains("valide") || normalized.contains("c est bon") {
            if canContinue {
                viewModel.cancelWebsiteGuideSpeech()
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        guard viewModel.isShowingWebsiteBuilder else { return }
                        readCurrentVoiceOptions()
                    }
                }
            } else {
                viewModel.speakWebsiteGuide("Il me manque encore un choix avant de continuer.")
            }
            return
        }
'''
if old_next not in text and new_next not in text:
    raise SystemExit('WebsiteBuilder voice next block not found')
text = text.replace(old_next, new_next, 1)

# Back by voice also cancels old menu audio before page change.
old_back = '''        if normalized.contains("retour") || normalized.contains("precedent") || normalized.contains("reviens") {
            if step > 0 {
                withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                readCurrentVoiceOptions()
            }
            return
        }
'''
new_back = '''        if normalized.contains("retour") || normalized.contains("precedent") || normalized.contains("reviens") {
            if step > 0 {
                viewModel.cancelWebsiteGuideSpeech()
                withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    guard viewModel.isShowingWebsiteBuilder else { return }
                    readCurrentVoiceOptions()
                }
            }
            return
        }
'''
if old_back not in text and new_back not in text:
    raise SystemExit('WebsiteBuilder voice back block not found')
text = text.replace(old_back, new_back, 1)

path.write_text(text)
