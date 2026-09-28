from pathlib import Path

# ---------------- ChatViewModel ----------------
vm_path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
vm = vm_path.read_text()

# Track real website generation requests so stale completions cannot overwrite a newer site.
old = '''    private var isVoicePipelinePrepared = false
    private var shouldResumeVoiceAfterSystemInterruption = false
'''
new = '''    private var isVoicePipelinePrepared = false
    private var shouldResumeVoiceAfterSystemInterruption = false
    private var websiteGenerationID = UUID()
'''
if old not in vm:
    raise SystemExit('ChatViewModel generation token target missing')
vm = vm.replace(old, new, 1)

# Do not treat arbitrary 3-word speaker echo as an interruption. Real barge-in stays immediate
# for explicit natural phrases such as "non", "attends", "stop", "coupe", etc.
old = '''                let words = normalized.split(separator: " ")
                let explicitInterrupt = normalized == "non" || normalized.hasPrefix("non ") ||
                    normalized.hasPrefix("attends") || normalized.hasPrefix("attend") ||
                    normalized.hasPrefix("stop") || normalized.hasPrefix("pardon") ||
                    normalized.hasPrefix("sarah") || normalized.contains("c est pas ca") ||
                    normalized.contains("ce n est pas ca") || words.count >= 3
'''
new = '''                let explicitInterrupt = normalized == "non" || normalized.hasPrefix("non ") ||
                    normalized.hasPrefix("attends") || normalized.hasPrefix("attend") ||
                    normalized.hasPrefix("stop") || normalized.hasPrefix("coupe") ||
                    normalized.hasPrefix("arrete") || normalized.hasPrefix("pardon") ||
                    normalized.hasPrefix("sarah") || normalized.contains("c est pas ca") ||
                    normalized.contains("ce n est pas ca") || normalized.contains("pas celui la") ||
                    normalized.contains("autre chose")
'''
if old not in vm:
    raise SystemExit('ChatViewModel barge-in target missing')
vm = vm.replace(old, new, 1)

# Add sequence-based site guide speech. Card changes are now driven by actual TTS completion,
# never by guessed timers.
old = '''    public func speakWebsiteGuide(_ text: String) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speak(text: text, for: .esther)
    }
'''
new = '''    public func speakWebsiteGuide(_ text: String) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speak(text: text, for: .esther)
    }

    /// Lit une suite de cartes sans minuterie artificielle. La carte suivante ne
    /// démarre qu'après la fin réelle de l'énoncé précédent.
    public func speakWebsiteGuideSequence(
        _ texts: [String],
        onItemStart: @escaping (Int) -> Void,
        completion: @escaping () -> Void
    ) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speakSequence(
            texts: texts,
            for: .esther,
            onItemStart: onItemStart,
            completion: completion
        )
    }
'''
if old not in vm:
    raise SystemExit('ChatViewModel speakWebsiteGuide target missing')
vm = vm.replace(old, new, 1)

# Cancellation now invalidates any in-flight website generation result too.
old = '''    public func cancelCurrentGeneration() {
        haptics.buttonTap()
        isTyping = false
        voiceStatus = .idle
        AIProgressiveScheduler.shared.cancelAllTasks()
    }
'''
new = '''    public func cancelCurrentGeneration() {
        haptics.buttonTap()
        websiteGenerationID = UUID()
        isTyping = false
        voiceStatus = .idle
        AIProgressiveScheduler.shared.cancelAllTasks()
    }
'''
if old not in vm:
    raise SystemExit('ChatViewModel cancel target missing')
vm = vm.replace(old, new, 1)

# Replace the static template generator with actual model-generated HTML.
start = vm.find('''    /// Construit une première version HTML locale depuis le brief rempli avec Raphaël.''')
end = vm.find('''    private func appendMessage(_ msg: Message) {''', start)
if start == -1 or end == -1:
    raise SystemExit('ChatViewModel completeWebsiteBrief block missing')
real_generation = r'''    /// Génère réellement le site avec le moteur IA local à partir du brief.
    /// Aucun template HTML prédéfini n'est utilisé et aucun faux résultat de secours
    /// n'est injecté si le modèle ne renvoie pas un document valide.
    public func completeWebsiteBrief(_ brief: WebsiteBrief) {
        activeAgent = .esther
        websiteDraft = brief
        isShowingWebsiteBuilder = false
        isTyping = true
        voiceStatus = .processing

        let generationID = UUID()
        websiteGenerationID = generationID

        appendMessage(Message(
            content: "💻 **Raphaël — génération réelle en cours**\n\nJe construis maintenant **\(brief.name)** à partir de ton brief. Le HTML, le CSS, les interactions et la mise en page vont être générés pour ce projet, sans maquette prédéfinie.",
            isFromUser: false
        ))

        if isContinuousConversationActive {
            speakWebsiteGuide("J'ai le brief. Je génère maintenant le vrai site, sans modèle prédéfini.")
        }

        requestGeneratedWebsite(brief, generationID: generationID, attempt: 0)
    }

    private func requestGeneratedWebsite(_ brief: WebsiteBrief, generationID: UUID, attempt: Int) {
        let prompt = websiteGenerationPrompt(for: brief, retry: attempt > 0)

        aiService.processQuery(prompt) { [weak self] rawResult in
            DispatchQueue.main.async {
                guard let self = self, self.websiteGenerationID == generationID else { return }

                if let html = self.extractGeneratedWebsiteHTML(rawResult) {
                    _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
                    self.vaiCurrentCode = html
                    self.websiteDraft = brief
                    self.isTyping = false
                    self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle

                    let ready = "💻 **Raphaël — site généré**\n\nLe site **\(brief.name)** a été généré depuis zéro à partir de tes choix. Le fichier `index.html` contient le HTML, le CSS et le JavaScript créés pour ce brief.\n\n🧩 Ouvrir le Studio"
                    self.appendMessage(Message(content: ready, isFromUser: false))
                    self.aiService.recordExchange(userText: prompt, assistantResponse: "Site HTML généré et validé localement.")

                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "Le site \(brief.name) est généré. Tu peux ouvrir le rendu ou me demander de le modifier.",
                            for: .esther
                        )
                    }
                    return
                }

                if attempt == 0 {
                    self.requestGeneratedWebsite(brief, generationID: generationID, attempt: 1)
                    return
                }

                self.isTyping = false
                self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle
                let failure = "💻 **Raphaël — génération à reprendre**\n\nLe moteur n'a pas renvoyé un document HTML complet et valide. Je n'ai pas remplacé le résultat par un template générique. Relance la génération ou précise le contenu du site."
                self.appendMessage(Message(content: failure, isFromUser: false))
                if self.isContinuousConversationActive {
                    self.voiceManager.speak(
                        text: "La génération n'a pas produit un site HTML valide. Je n'ai pas mis de faux template à la place.",
                        for: .esther
                    )
                }
            }
        }
    }

    private func websiteGenerationPrompt(for brief: WebsiteBrief, retry: Bool) -> String {
        let sectionList = brief.sections.joined(separator: ", ")
        let retryInstruction = retry
            ? "La réponse précédente n'était pas un document HTML valide. Cette fois, respecte strictement le format demandé."
            : ""

        return """
        Tu es Raphaël, agent développeur. Génère réellement un site web complet et unique pour ce brief.
        \(retryInstruction)

        BRIEF
        - Type : \(brief.category)
        - Nom : \(brief.name)
        - Objectif : \(brief.purpose.isEmpty ? "à déduire intelligemment du type et du nom" : brief.purpose)
        - Public : \(brief.audience)
        - Direction graphique : \(brief.visualStyle)
        - Couleur d'accent : \(brief.accent)
        - Sections demandées : \(sectionList)

        CONTRAT DE GÉNÉRATION
        1. Réponds UNIQUEMENT avec un document HTML5 complet, de <!doctype html> jusqu'à </html>. Aucun Markdown, aucune explication.
        2. Tout le CSS et tout le JavaScript doivent être intégrés dans ce seul fichier HTML.
        3. Ne réutilise aucun template, aucune maquette par défaut, aucun bloc générique pré-écrit et aucun asset externe.
        4. N'utilise aucune URL d'image, CDN, police distante, logo de marque ou ressource réseau. Crée l'identité visuelle avec HTML/CSS, gradients, formes, typographie système et composants générés pour ce projet.
        5. La direction graphique nommée dans le brief est une inspiration de langage visuel. Ne copie pas de page, logo, texte ou ressource propriétaire.
        6. Le contenu doit être cohérent avec le nom, le type, l'objectif et le public. Évite les placeholders comme « Offre 01 », « Produit phare », « Lorem ipsum » ou « À personnaliser ».
        7. Toutes les sections demandées doivent exister réellement dans la page et avoir une navigation fonctionnelle.
        8. Ajoute des interactions JavaScript utiles au type de site. Pour une boutique : catalogue, panier local, quantité et total. Pour un restaurant : menu et réservation locale. Pour un voyage : recherche/filtre de destinations. Pour un portfolio : filtres de projets. Adapte la logique au brief.
        9. Le site doit être responsive iPhone, tablette et ordinateur, accessible, rapide et utilisable hors ligne.
        10. Le résultat doit avoir une vraie hiérarchie visuelle et ne doit pas ressembler au dashboard générique de Raphaël.
        """
    }

    private func extractGeneratedWebsiteHTML(_ raw: String) -> String? {
        var candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate = candidate
            .replacingOccurrences(of: "```html", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = candidate.lowercased()
        let startIndex: String.Index?
        if let doctype = lower.range(of: "<!doctype html>") {
            startIndex = doctype.lowerBound
        } else if let html = lower.range(of: "<html") {
            startIndex = html.lowerBound
        } else {
            startIndex = nil
        }

        guard let startIndex else { return nil }
        let sliced = String(candidate[startIndex...])
        guard let endRange = sliced.lowercased().range(of: "</html>", options: .backwards) else { return nil }
        let end = sliced.index(endRange.upperBound, offsetBy: 0)
        let html = String(sliced[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        let htmlLower = html.lowercased()

        guard html.count >= 1500,
              htmlLower.contains("<body"),
              htmlLower.contains("<style"),
              htmlLower.contains("</html>") else { return nil }
        return html
    }

'''
vm = vm[:start] + real_generation + vm[end:]
vm_path.write_text(vm)

# ---------------- MultiAgentVoiceManager ----------------
voice_path = Path('SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift')
voice = voice_path.read_text()

old = '''    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil
'''
new = '''    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil

    private var sequenceTexts: [String] = []
    private var sequenceAgent: AgentType? = nil
    private var sequenceIndex: Int = 0
    private var sequenceItemStarted: ((Int) -> Void)? = nil
    private var sequenceCompletion: (() -> Void)? = nil
    private var isSequenceActive = false
    private var suppressNextCancelCallback = false
'''
if old not in voice:
    raise SystemExit('VoiceManager state target missing')
voice = voice.replace(old, new, 1)

# Helper inserted before ordinary speak.
marker = '''    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
'''
helper = '''    private func clearSpeechSequence() {
        sequenceTexts = []
        sequenceAgent = nil
        sequenceIndex = 0
        sequenceItemStarted = nil
        sequenceCompletion = nil
        isSequenceActive = false
    }

    private func stopForReplacement() {
        pendingSpeechBlock = nil
        clearSpeechSequence()
        if synthesizer.isSpeaking {
            suppressNextCancelCallback = true
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func speakNextSequenceItem() {
        guard isSequenceActive,
              let agent = sequenceAgent,
              sequenceIndex < sequenceTexts.count else { return }

        let currentIndex = sequenceIndex
        sequenceItemStarted?(currentIndex)
        let utterance = makeUtterance(text: sequenceTexts[currentIndex])
        configureUtterance(utterance, for: agent)
        synthesizer.speak(utterance)
    }

    /// Lit une liste d'énoncés l'un après l'autre en attendant la fin réelle de
    /// chaque synthèse. Ceci remplace les délais estimés qui coupaient les cartes.
    public func speakSequence(
        texts: [String],
        for agent: AgentType,
        onItemStart: @escaping (Int) -> Void,
        completion: @escaping () -> Void
    ) {
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            AppleSpeechRecognizer.shared.stopListening()
        }

        stopForReplacement()
        let cleaned = texts.map(cleanTextForSpeech).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            completion()
            return
        }

        sequenceTexts = cleaned
        sequenceAgent = agent
        sequenceIndex = 0
        sequenceItemStarted = onItemStart
        sequenceCompletion = completion
        isSequenceActive = true

        AudioSessionManager.shared.configurePlaybackSession()
        speakNextSequenceItem()
    }

'''
if marker not in voice:
    raise SystemExit('VoiceManager speak marker missing')
voice = voice.replace(marker, helper + marker, 1)

# Ordinary speech should replace current speech without producing a false "finished" callback.
old = '''        stop()
        pendingSpeechBlock = nil

        let cleaned = cleanTextForSpeech(text)
'''
new = '''        stopForReplacement()
        pendingSpeechBlock = nil

        let cleaned = cleanTextForSpeech(text)
'''
if old not in voice:
    raise SystemExit('VoiceManager ordinary replacement target missing')
voice = voice.replace(old, new, 1)

old = '''        stop()

        let cleanTransition = cleanTextForSpeech(transitionText)
'''
new = '''        stopForReplacement()

        let cleanTransition = cleanTextForSpeech(transitionText)
'''
if old not in voice:
    raise SystemExit('VoiceManager handoff replacement target missing')
voice = voice.replace(old, new, 1)

# Explicit stop clears a sequence, and its cancel callback remains meaningful for mic resume.
old = '''    public func stop() {
        pendingSpeechBlock = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        if !AppleSpeechRecognizer.shared.isListening {
            AudioSessionManager.shared.deactivateSession()
        }
    }
'''
new = '''    public func stop() {
        pendingSpeechBlock = nil
        clearSpeechSequence()
        suppressNextCancelCallback = false
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        if !AppleSpeechRecognizer.shared.isListening {
            AudioSessionManager.shared.deactivateSession()
        }
    }
'''
if old not in voice:
    raise SystemExit('VoiceManager stop target missing')
voice = voice.replace(old, new, 1)

old = '''    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
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
'''
new = '''    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if isSequenceActive {
            sequenceIndex += 1
            if sequenceIndex < sequenceTexts.count {
                speakNextSequenceItem()
                return
            }

            let completion = sequenceCompletion
            clearSpeechSequence()
            completion?()
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
            return
        }

        if let next = pendingSpeechBlock {
            pendingSpeechBlock = nil
            next()
        } else {
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if suppressNextCancelCallback {
            suppressNextCancelCallback = false
            return
        }
        clearSpeechSequence()
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
'''
if old not in voice:
    raise SystemExit('VoiceManager delegate target missing')
voice = voice.replace(old, new, 1)
voice_path.write_text(voice)

# ---------------- ChatScreen website flow ----------------
view_path = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
view = view_path.read_text()

# Timed speech estimator is removed entirely.
start = view.find('''    private func estimatedSpeechDuration(_ text: String) -> Double {''')
end = view.find('''    private func readCurrentVoiceOptions() {''', start)
if start == -1 or end == -1:
    raise SystemExit('Website speech estimator block missing')
view = view[:start] + view[end:]

# Replace timer-based card narration with TTS delegate sequencing.
start = view.find('''    private func readCurrentVoiceOptions() {''')
end = view.find('''    private func currentStepStatusText() -> String {''', start)
if start == -1 or end == -1:
    raise SystemExit('Website readCurrentVoiceOptions block missing')
sequence_reader = r'''    private func readCurrentVoiceOptions() {
        guard viewModel.isContinuousConversationActive else { return }
        let generation = UUID()
        voiceGuideGeneration = generation

        if step == 1 {
            voiceFocusedOption = nil
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Tu es à la question du nom. Dis-moi librement le nom du site. Par exemple : le site s'appelle Horizon.")
            } else if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Le site s'appelle \(name). Dis-moi maintenant à qui il s'adresse. Tu peux choisir une carte ou répondre librement avec tes propres mots.")
            } else {
                viewModel.speakWebsiteGuide("Le site s'appelle \(name) et le public choisi est \(audience). Tu peux dire suivant pour passer à l'ambiance graphique.")
            }
            return
        }

        let choices = currentVoiceChoices
        guard !choices.isEmpty else { return }
        let spokenItems = choices.enumerated().map { index, choice in
            "Option \(index + 1). \(choice.title). \(choice.detail)."
        } + ["Tu peux me dire le nom de l'option, son numéro, ou dire celui-là pendant qu'une carte est éclairée."]

        viewModel.speakWebsiteGuideSequence(
            spokenItems,
            onItemStart: { index in
                guard voiceGuideGeneration == generation,
                      viewModel.isShowingWebsiteBuilder else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    voiceFocusedOption = index < choices.count ? choices[index].title : nil
                }
            },
            completion: {
                guard voiceGuideGeneration == generation else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    voiceFocusedOption = nil
                }
            }
        )
    }

'''
view = view[:start] + sequence_reader + view[end:]

# Completion now delegates only to the real AI generator.
old = '''        // On conserve le flux existant de Raphaël (historique, message et voix),
        // puis on remplace le HTML par la variante réellement stylée choisie ici.
        viewModel.completeWebsiteBrief(brief)
        let styledHTML = generateStyledWebsiteHTML(brief)
        _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: styledHTML)
        viewModel.vaiCurrentCode = styledHTML
        viewModel.websiteDraft = brief
        dismiss()
'''
new = '''        viewModel.completeWebsiteBrief(brief)
        dismiss()
'''
if old not in view:
    raise SystemExit('Website completeBrief static overwrite target missing')
view = view.replace(old, new, 1)

# Delete the entire hard-coded styled website generator and its helper assets.
static_start = view.find('''    private func generateStyledWebsiteHTML(_ brief: WebsiteBrief) -> String {''')
struct_marker = '''
}

@available(iOS 15.0, *)
private struct WebsiteChoice'''
static_end = view.find(struct_marker, static_start)
if static_start == -1 or static_end == -1:
    raise SystemExit('Static styled website generator region missing')
view = view[:static_start] + view[static_end:]
view_path.write_text(view)

# ---------------- VAICodeEngine ----------------
engine_path = Path('SarahIA/SarahIA/Services/VAICodeEngine.swift')
engine = engine_path.read_text()

# Remove the older generic WebsiteBrief template as well. htmlEscaped is preserved because
# the coding studio's other generators still use it.
static_start = engine.find('''    /// Génère une première maquette de site à partir du questionnaire de Raphaël.''')
html_escape_marker = '''    private func htmlEscaped(_ value: String) -> String {'''
static_end = engine.find(html_escape_marker, static_start)
if static_start == -1 or static_end == -1:
    raise SystemExit('VAICodeEngine static website generator region missing')
engine = engine[:static_start] + '''    // Les anciens templates WebsiteBrief ont été supprimés. Le créateur de site
    // utilise maintenant l'inférence réelle pilotée par ChatViewModel.

''' + engine[static_end:]
engine_path.write_text(engine)

print('Real website generation and voice rework applied')
