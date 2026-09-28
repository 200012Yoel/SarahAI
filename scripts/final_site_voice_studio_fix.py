from pathlib import Path

# ---------------- ChatViewModel ----------------
vm_path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
vm = vm_path.read_text()

# More natural barge-in: explicit corrections interrupt immediately, while ordinary
# speech interrupts only when it does not look like an echo of Sarah's current TTS.
start = vm.find('''            if self.voiceManager.isSpeaking, !cleanedPartial.isEmpty {''')
end_marker = '''        }\n\n        AppleSpeechRecognizer.shared.onFinalTranscription'''
end = vm.find(end_marker, start)
if start == -1 or end == -1:
    raise SystemExit('voice partial block not found')
new_partial = r'''            if self.voiceManager.isSpeaking, !cleanedPartial.isEmpty {
                let normalized = cleanedPartial.lowercased()
                    .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
                    .replacingOccurrences(of: "’", with: " ")
                    .replacingOccurrences(of: "'", with: " ")

                let explicitInterrupt = normalized == "non" || normalized.hasPrefix("non ") ||
                    normalized.hasPrefix("attends") || normalized.hasPrefix("attend") ||
                    normalized.hasPrefix("stop") || normalized.hasPrefix("coupe") ||
                    normalized.hasPrefix("arrete") || normalized.hasPrefix("pardon") ||
                    normalized.hasPrefix("sarah") || normalized.contains("c est pas ca") ||
                    normalized.contains("ce n est pas ca") || normalized.contains("pas celui la") ||
                    normalized.contains("autre chose") || normalized.contains("laisse moi parler") ||
                    normalized.contains("laisse moi") || normalized.contains("pas ca") ||
                    normalized.contains("je veux autre")

                let spoken = self.voiceManager.currentSpokenText.lowercased()
                    .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
                    .replacingOccurrences(of: "’", with: " ")
                    .replacingOccurrences(of: "'", with: " ")

                let partialWords = Set(normalized.split(separator: " ").map(String.init).filter { $0.count > 1 })
                let spokenWords = Set(spoken.split(separator: " ").map(String.init).filter { $0.count > 1 })
                let overlapCount = partialWords.intersection(spokenWords).count
                let overlapRatio = partialWords.isEmpty ? 1.0 : Double(overlapCount) / Double(partialWords.count)

                // Deux mots réellement nouveaux suffisent pour prendre la parole,
                // mais une transcription qui ressemble fortement à la voix du haut-parleur
                // est ignorée pour éviter les auto-interruptions.
                let naturalBargeIn = partialWords.count >= 2 && overlapRatio < 0.45

                if explicitInterrupt || naturalBargeIn {
                    self.interruptVoiceResponse()
                    self.liveTranscriptionText = partial
                }
            }
'''
vm = vm[:start] + new_partial + vm[end:]

vm = vm.replace(
    '"💻 **Raphaël** — Parfait. Je vais te poser quelques questions rapides, puis je génère une première maquette de site que tu pourras améliorer."',
    '"💻 **Raphaël** — Parfait. Je vais te poser quelques questions rapides, puis je génère le site à partir de tes réponses. Aucun site par défaut ne sera utilisé."'
)

# Replace deterministic brief renderer with genuine model output only.
start = vm.find('''    /// Construit le site à partir du brief validé puis vérifie le rendu WebKit.''')
end = vm.find('''    private func appendMessage(_ msg: Message) {''', start)
if start == -1 or end == -1:
    raise SystemExit('completeWebsiteBrief block not found')
real_block = r'''    /// Génère le site à partir d'un vrai moteur de génération de code.
    /// Si aucun moteur capable de produire du HTML n'est disponible, Sarah échoue
    /// explicitement au lieu d'injecter un template ou des assets prédéfinis.
    public func completeWebsiteBrief(_ brief: WebsiteBrief) {
        activeAgent = .esther
        websiteDraft = brief
        isShowingWebsiteBuilder = false
        isTyping = true
        voiceStatus = .processing

        let generationID = UUID()
        websiteGenerationID = generationID
        let prompt = websiteGenerationPrompt(for: brief)

        appendMessage(Message(
            content: "💻 **Raphaël · génération réelle**\n\nJe génère maintenant **\(brief.name)** à partir de ton brief. Je n'utiliserai aucun site par défaut si le moteur de code ne répond pas.",
            isFromUser: false
        ))

        if isContinuousConversationActive {
            speakWebsiteGuide("J'ai le brief. Je lance maintenant la génération réelle du code du site.")
        }

        // Priorité au moteur de code OpenAI-compatible configuré dans Sarah.
        if SarahCodingRuntime.shared.isConfigured {
            let system = """
            Tu es Raphaël, générateur de sites web. Retourne uniquement un document HTML5 complet.
            Tout le CSS et le JavaScript doivent être intégrés au même fichier.
            N'utilise aucun template prédéfini, aucun asset externe, aucune URL d'image, aucun CDN et aucun placeholder générique.
            Le contenu, la structure, les interactions et le style doivent être générés spécifiquement à partir du brief utilisateur.
            """
            SarahCodingRuntime.shared.generate(
                model: SarahCodingModelCatalog.implementer,
                system: system,
                user: prompt
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let raw):
                    self.acceptGeneratedWebsite(raw, brief: brief, generationID: generationID)
                case .failure(let error):
                    self.failWebsiteGeneration(
                        "Le moteur de code connecté a échoué : \(error.localizedDescription)",
                        generationID: generationID
                    )
                }
            }
            return
        }

        // Le moteur local n'est essayé que si ses poids sont réellement présents.
        // On ne remplace jamais son absence par un générateur déterministe.
        if BackgroundModelDownloader.isModelDownloaded {
            aiService.processQuery(prompt) { [weak self] raw in
                self?.acceptGeneratedWebsite(raw, brief: brief, generationID: generationID)
            }
            return
        }

        BackgroundModelDownloader.shared.startQwenModelDownload()
        isTyping = false
        voiceStatus = isContinuousConversationActive ? .processing : .idle
        appendMessage(Message(
            content: "💻 **Raphaël · moteur de code non prêt**\n\nLe modèle local nécessaire à une vraie génération n'est pas encore installé. Sarah a lancé sa préparation en arrière-plan. Je n'ai créé aucun faux site à la place.",
            isFromUser: false
        ))
        if isContinuousConversationActive {
            voiceManager.speak(
                text: "Le moteur local de code n'est pas encore installé. Je lance sa préparation et je ne mets aucun faux site à la place.",
                for: .esther
            )
        }
    }

    private func acceptGeneratedWebsite(_ raw: String, brief: WebsiteBrief, generationID: UUID) {
        DispatchQueue.main.async {
            guard self.websiteGenerationID == generationID else { return }
            guard let html = self.extractGeneratedWebsiteHTML(raw) else {
                self.failWebsiteGeneration(
                    "Le moteur n'a pas renvoyé un document HTML complet. Aucun rendu par défaut n'a été créé.",
                    generationID: generationID
                )
                return
            }

            VAICodeEngine.shared.runBrowserSmokeTest(html: html) { [weak self] report in
                DispatchQueue.main.async {
                    guard let self = self, self.websiteGenerationID == generationID else { return }
                    guard report.passed else {
                        self.failWebsiteGeneration(
                            "Le HTML a été généré mais le test WebKit a échoué : \(report.details)",
                            generationID: generationID
                        )
                        return
                    }

                    _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
                    self.vaiCurrentCode = html
                    self.websiteDraft = brief
                    self.isTyping = false
                    self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle

                    self.appendMessage(Message(
                        content: "💻 **Raphaël · site généré**\n\n**\(brief.name)** a été généré par le moteur de code puis testé dans WebKit. Ouvre le Studio : **Code** contient le fichier produit et **Vision** affiche exactement son rendu.",
                        isFromUser: false
                    ))

                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "Le site \(brief.name) est généré et son rendu a passé le test. Dans le Studio, tu as seulement Code et Vision.",
                            for: .esther
                        )
                    }
                }
            }
        }
    }

    private func failWebsiteGeneration(_ reason: String, generationID: UUID) {
        DispatchQueue.main.async {
            guard self.websiteGenerationID == generationID else { return }
            self.isTyping = false
            self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle
            self.appendMessage(Message(
                content: "💻 **Raphaël · génération arrêtée**\n\n\(reason)",
                isFromUser: false
            ))
            if self.isContinuousConversationActive {
                self.voiceManager.speak(
                    text: "La génération s'est arrêtée. Je n'ai pas remplacé le résultat par un site par défaut.",
                    for: .esther
                )
            }
        }
    }

    private func websiteGenerationPrompt(for brief: WebsiteBrief) -> String {
        let sectionList = brief.sections.joined(separator: ", ")
        return """
        Génère un site web complet et unique à partir de ce brief.

        TYPE : \(brief.category)
        NOM : \(brief.name)
        OBJECTIF : \(brief.purpose.isEmpty ? "déduis un objectif cohérent du brief" : brief.purpose)
        PUBLIC : \(brief.audience)
        DIRECTION GRAPHIQUE : \(brief.visualStyle)
        ACCENT : \(brief.accent)
        SECTIONS : \(sectionList)

        CONTRAT STRICT :
        - Retourne uniquement le document HTML, de <!doctype html> jusqu'à </html>.
        - CSS et JavaScript dans ce fichier unique.
        - Aucun template pré-écrit, aucun dashboard générique, aucun asset externe, aucun CDN.
        - Aucun Lorem ipsum, Produit 01, Offre 01, À personnaliser ou autre placeholder générique.
        - Le texte, la navigation, les composants et les interactions doivent être spécifiques au brief.
        - Le site doit être responsive sur iPhone et fonctionner hors ligne une fois généré.
        - Pour un e-commerce, crée un vrai panier local et des produits cohérents avec le projet.
        - Pour un voyage, crée recherche et filtres pertinents.
        - Pour un restaurant, crée menu et parcours de réservation local.
        - Pour un portfolio, crée filtres et projets cohérents.
        - La direction graphique peut s'inspirer d'un langage visuel connu sans copier logo, texte ou page propriétaire.
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
        if let range = lower.range(of: "<!doctype html>") {
            startIndex = range.lowerBound
        } else if let range = lower.range(of: "<html") {
            startIndex = range.lowerBound
        } else {
            startIndex = nil
        }
        guard let startIndex else { return nil }

        let sliced = String(candidate[startIndex...])
        guard let close = sliced.lowercased().range(of: "</html>", options: .backwards) else { return nil }
        let html = String(sliced[..<close.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let htmlLower = html.lowercased()

        guard html.count >= 1200,
              htmlLower.contains("<body"),
              htmlLower.contains("<style"),
              htmlLower.contains("</html>") else { return nil }
        return html
    }

'''
vm = vm[:start] + real_block + vm[end:]
vm_path.write_text(vm)

# ---------------- MultiAgentVoiceManager ----------------
voice_path = Path('SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift')
voice = voice_path.read_text()

needle = '    private let synthesizer = AVSpeechSynthesizer()\n'
if 'public private(set) var currentSpokenText' not in voice:
    if needle not in voice:
        raise SystemExit('voice synthesizer marker not found')
    voice = voice.replace(needle, needle + '    public private(set) var currentSpokenText: String = ""\n', 1)

voice = voice.replace(
'''        let currentIndex = sequenceIndex
        sequenceItemStarted?(currentIndex)
        let utterance = makeUtterance(text: sequenceTexts[currentIndex])
''',
'''        let currentIndex = sequenceIndex
        sequenceItemStarted?(currentIndex)
        currentSpokenText = sequenceTexts[currentIndex]
        let utterance = makeUtterance(text: sequenceTexts[currentIndex])
''', 1)

voice = voice.replace(
'''        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }

        AudioSessionManager.shared.configurePlaybackSession()
''',
'''        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        currentSpokenText = cleaned

        AudioSessionManager.shared.configurePlaybackSession()
''', 1)

voice = voice.replace(
'''        pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            let agentUtterance = self.makeUtterance(text: cleanAgent)
''',
'''        pendingSpeechBlock = { [weak self] in
            guard let self = self, !cleanAgent.isEmpty else { return }
            self.currentSpokenText = cleanAgent
            let agentUtterance = self.makeUtterance(text: cleanAgent)
''', 1)

voice = voice.replace(
'''        let sourceUtterance = makeUtterance(text: cleanTransition)
        configureUtterance(sourceUtterance, for: sourceAgent)
''',
'''        currentSpokenText = cleanTransition
        let sourceUtterance = makeUtterance(text: cleanTransition)
        configureUtterance(sourceUtterance, for: sourceAgent)
''', 1)

voice = voice.replace(
'''    public func stop() {
        pendingSpeechBlock = nil
        clearSpeechSequence()
''',
'''    public func stop() {
        pendingSpeechBlock = nil
        currentSpokenText = ""
        clearSpeechSequence()
''', 1)

voice = voice.replace(
'''            let completion = sequenceCompletion
            clearSpeechSequence()
            completion?()
''',
'''            let completion = sequenceCompletion
            currentSpokenText = ""
            clearSpeechSequence()
            completion?()
''', 1)

voice = voice.replace(
'''        } else {
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
''',
'''        } else {
            currentSpokenText = ""
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
''', 1)

voice = voice.replace(
'''        clearSpeechSequence()
        AudioSessionManager.shared.deactivateSession()
''',
'''        currentSpokenText = ""
        clearSpeechSequence()
        AudioSessionManager.shared.deactivateSession()
''', 1)

voice_path.write_text(voice)
print('real site generation + natural voice barge-in applied')
