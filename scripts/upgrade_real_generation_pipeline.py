from pathlib import Path

ROOT = Path("SarahIA/SarahIA")


def insert_before_once(text: str, marker: str, insertion: str, label: str) -> str:
    if insertion.strip() in text:
        return text
    idx = text.find(marker)
    if idx < 0:
        raise SystemExit(f"Missing marker: {label}")
    return text[:idx] + insertion + text[idx:]


def replace_function(text: str, signature_token: str, replacement: str, label: str) -> str:
    idx = text.find(signature_token)
    if idx < 0:
        raise SystemExit(f"Missing function: {label}")
    start = text.rfind("\n", 0, idx) + 1
    # Include immediately preceding comments for a clean replacement.
    scan = start
    while scan > 0:
        end_prev = scan - 1
        prev = text.rfind("\n", 0, end_prev) + 1
        line = text[prev:end_prev].strip()
        if line.startswith("///") or line.startswith("//") or not line:
            start = prev
            scan = prev
        else:
            break
    brace = text.find("{", idx)
    if brace < 0:
        raise SystemExit(f"Opening brace missing: {label}")
    depth = 0
    in_string = False
    triple = False
    escape = False
    i = brace
    end = None
    while i < len(text):
        if text.startswith('"""', i):
            triple = not triple
            i += 3
            continue
        ch = text[i]
        if triple:
            i += 1
            continue
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    if end is None:
        raise SystemExit(f"Closing brace missing: {label}")
    while end < len(text) and text[end] in " \t\n":
        end += 1
    return text[:start] + replacement.rstrip() + "\n\n" + text[end:]


# -----------------------------------------------------------------------------
# AIService: dedicated local code generation, bypassing conversational intents.
# -----------------------------------------------------------------------------
ai_path = ROOT / "Services/AIService.swift"
ai = ai_path.read_text()
local_code_method = r'''    /// Génération de code brute, réellement issue du moteur IA local.
    /// Cette entrée contourne le routage conversationnel afin qu'un prompt HTML
    /// ne soit jamais transformé en réponse de chat ou en template codé en dur.
    public func generateLocalCodeDocument(
        prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(NSError(
                domain: "SarahLocalCodeGeneration",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Prompt de code vide"]
            )))
            return
        }

        let system = """
        Tu es Raphaël, moteur de génération de code web. Tu dois écrire un vrai document HTML5 complet, spécifique au brief fourni. Tout CSS et JavaScript doit être intégré au même fichier. N'utilise aucun template pré-écrit, aucune page de secours, aucun lorem ipsum et aucun asset propriétaire. Retourne uniquement le document HTML final, sans commentaire avant ou après.
        """

        if ModelSelectionEngine.shared.isLocalGGUFAllowed(),
           BackgroundModelDownloader.isModelDownloaded,
           BackgroundModelDownloader.localModelURL != nil {
            let formatted = ModelSelectionEngine.shared.formatChatMLPrompt(
                system: system,
                user: clean
            )
            SarahBrainEngine.shared.generateStreamingResponse(prompt: formatted) { raw in
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    completion(.failure(NSError(
                        domain: "SarahLocalCodeGeneration",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Le modèle local n'a produit aucun code"]
                    )))
                    return
                }
                completion(.success(value))
            }
            return
        }

        // Le petit moteur neuronal est une vraie inférence locale lui aussi. Il sert
        // pendant que le GGUF Qwen recommandé se prépare, sans fabriquer de HTML fixe.
        BackgroundModelDownloader.shared.startQwenModelDownload()
        LocalNeuralIntelligenceEngine.shared.generateLocalResponse(
            prompt: system + "\n\nBRIEF :\n" + clean,
            contextHistory: []
        ) { result in
            let value = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                completion(.failure(NSError(
                    domain: "SarahLocalCodeGeneration",
                    code: 501,
                    userInfo: [NSLocalizedDescriptionKey: "Le moteur neuronal local n'a produit aucun code"]
                )))
                return
            }
            completion(.success(value))
        }
    }

'''
ai = insert_before_once(
    ai,
    "    /// Génère une réponse IA synchrone immédiate",
    local_code_method,
    "AIService synchronous response marker"
)
ai_path.write_text(ai)


# -----------------------------------------------------------------------------
# VAICodeEngine: use real local inference when no OpenAI-compatible endpoint exists.
# -----------------------------------------------------------------------------
engine_path = ROOT / "Services/VAICodeEngine.swift"
engine = engine_path.read_text()
local_pipeline = r'''    private func localAgenticBuild(
        prompt: String,
        completion: @escaping (SarahAgenticWebBuildResult?) -> Void
    ) {
        let existing = loadAgenticProject()
        var fullPrompt = implementerSystemPrompt() + "\n\nDEMANDE :\n" + prompt
        if let existing {
            fullPrompt += "\n\nPROJET EXISTANT À AMÉLIORER, RÉVISION \(existing.revision) :\n" + existing.html
        }

        AIService.shared.generateLocalCodeDocument(prompt: fullPrompt) { result in
            guard case .success(let raw) = result,
                  var html = self.extractHTMLDocument(raw) else {
                completion(nil)
                return
            }
            html = self.stabilizeHTML(html)
            completion(SarahAgenticWebBuildResult(
                html: html,
                revision: (existing?.revision ?? 0) + 1,
                wasRefinement: existing != nil,
                architectModel: SarahCodingModelCatalog.architect,
                implementerModel: SarahCodingModelCatalog.implementer,
                staticAudit: self.auditWebHTML(html),
                browserAudit: nil,
                usedRemoteModels: false
            ))
        }
    }

    private func repairLocalBuild(
        _ build: SarahAgenticWebBuildResult,
        report: SarahBrowserSmokeReport,
        completion: @escaping (SarahAgenticWebBuildResult) -> Void
    ) {
        let prompt = repairSystemPrompt()
            + "\n\nHTML À CORRIGER :\n" + build.html
            + "\n\nRAPPORT WEBKIT :\n" + report.details
            + "\nErreurs JavaScript : " + report.javascriptErrors.joined(separator: " | ")

        AIService.shared.generateLocalCodeDocument(prompt: prompt) { result in
            guard case .success(let raw) = result,
                  var html = self.extractHTMLDocument(raw) else {
                completion(build)
                return
            }
            html = self.stabilizeHTML(html)
            var updated = build
            updated.html = html
            updated.staticAudit = self.auditWebHTML(html)
            completion(updated)
        }
    }

'''
engine = insert_before_once(
    engine,
    "    public func runBrowserSmokeTest",
    local_pipeline,
    "browser smoke test marker"
)

new_build_function = r'''    /// Génère et teste un vrai site. Si un endpoint de code est configuré il est
    /// utilisé, sinon Raphaël passe au moteur IA local. Dans les deux cas, le HTML
    /// vient d'une inférence de modèle puis passe un audit statique et WebKit.
    public func buildAndTestWebsite(
        prompt: String,
        completion: @escaping (Result<SarahAgenticWebBuildResult, Error>) -> Void
    ) {
        let previousProject = loadAgenticProject()
        let usesRemoteRuntime = SarahCodingRuntime.shared.isConfigured

        let persistPassing: (SarahAgenticWebBuildResult) -> Void = { build in
            let project = SarahPersistentWebProject(
                rootRequest: previousProject?.rootRequest ?? prompt,
                latestInstruction: prompt,
                html: build.html,
                revision: build.revision,
                updatedAt: Date()
            )
            self.persistAgenticProject(project)
            completion(.success(build))
        }

        let inspectCandidate: (SarahAgenticWebBuildResult?) -> Void = { candidate in
            guard let candidate else {
                completion(.failure(SarahRealWebsiteGenerationError.modelGenerationFailed))
                return
            }

            self.runBrowserSmokeTest(html: candidate.html) { firstReport in
                if firstReport.passed && candidate.staticAudit.isPassing {
                    var final = candidate
                    final.browserAudit = firstReport
                    persistPassing(final)
                    return
                }

                let finishRepair: (SarahAgenticWebBuildResult) -> Void = { repaired in
                    let stabilized = self.stabilizeHTML(repaired.html)
                    self.runBrowserSmokeTest(html: stabilized) { secondReport in
                        var final = repaired
                        final.html = stabilized
                        final.staticAudit = self.auditWebHTML(stabilized)
                        final.browserAudit = secondReport

                        guard secondReport.passed, final.staticAudit.isPassing else {
                            completion(.failure(
                                SarahRealWebsiteGenerationError.invalidRender(secondReport.details)
                            ))
                            return
                        }
                        persistPassing(final)
                    }
                }

                if usesRemoteRuntime {
                    self.repairRemoteBuild(candidate, report: firstReport, completion: finishRepair)
                } else {
                    self.repairLocalBuild(candidate, report: firstReport, completion: finishRepair)
                }
            }
        }

        if usesRemoteRuntime {
            remoteAgenticBuild(prompt: prompt, completion: inspectCandidate)
        } else {
            localAgenticBuild(prompt: prompt, completion: inspectCandidate)
        }
    }'''
engine = replace_function(
    engine,
    "public func buildAndTestWebsite(\n",
    new_build_function,
    "buildAndTestWebsite"
)
engine_path.write_text(engine)


# -----------------------------------------------------------------------------
# ChatViewModel: turn generated UIImage notifications into actual assistant images.
# -----------------------------------------------------------------------------
vm_path = ROOT / "ViewModels/ChatViewModel.swift"
vm = vm_path.read_text()
image_observer = r'''
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedImageReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let image = notification.userInfo?["image"] as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.94) else { return }
                let prompt = notification.userInfo?["prompt"] as? String ?? "Image générée"
                let model = notification.userInfo?["modelName"] as? String ?? "modèle image local"
                self.activeAgent = .ethel
                self.appendMessage(Message(
                    content: "🎨 **Image générée**\n\n\(prompt)\n\nModèle : \(model)",
                    isFromUser: false,
                    imageData: data
                ))
            }
            .store(in: &cancellables)
'''
if "SarahGeneratedImageReady" not in vm:
    anchor = '''        NotificationCenter.default.publisher(for: .sarahAgentSelected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                if let agent = notif.object as? AgentType {
                    self?.activeAgent = agent
                }
            }
            .store(in: &cancellables)
'''
    if anchor not in vm:
        raise SystemExit("ChatViewModel core-service anchor missing")
    vm = vm.replace(anchor, anchor + image_observer, 1)
vm_path.write_text(vm)


# -----------------------------------------------------------------------------
# Chat bubble: render assistant imageData directly, not only URL-based images.
# -----------------------------------------------------------------------------
bubble_path = ROOT / "Views/ChatBubbleView.swift"
bubble = bubble_path.read_text()
ai_image_view = r'''                if let data = message.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 290, maxHeight: 390)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)
                }

'''
if ai_image_view.strip() not in bubble:
    marker = "                if !message.isVisionReport {\n"
    if marker not in bubble:
        raise SystemExit("ChatBubble AI content marker missing")
    bubble = bubble.replace(marker, ai_image_view + marker, 1)
bubble_path.write_text(bubble)


# -----------------------------------------------------------------------------
# Ethel: wait for actual image pipeline result instead of returning "launched" text.
# -----------------------------------------------------------------------------
coord_path = ROOT / "Services/MultiAgentCoordinator.swift"
coord = coord_path.read_text()
new_ethel = r'''    // MARK: - Ethel (création visuelle réelle)

    private func processWithEthel(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi ethel", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let source = clean.isEmpty ? text : clean
        let imageService = OpenSourceImageGenerationService.shared
        let intent = imageService.isImageGenerationIntent(source)
        let normalized = normalize(source)

        var prompt = intent.cleanedPrompt
        if !intent.isIntent {
            let generationWords = ["genere", "génère", "cree", "crée", "dessine", "fabrique"]
            if generationWords.contains(where: { normalized.contains($0.folding(options: .diacriticInsensitive, locale: .current)) }) {
                prompt = source
                for word in generationWords {
                    prompt = prompt.replacingOccurrences(of: word, with: "", options: [.caseInsensitive, .diacriticInsensitive])
                }
                prompt = prompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":,-")))
            }
        }

        guard intent.isIntent || !prompt.isEmpty else {
            AIService.shared.processQuery(source) { response in
                completion(AgentResponse(
                    agent: .ethel,
                    text: response,
                    spokenText: response
                ))
            }
            return
        }

        let finalPrompt = prompt.isEmpty ? source : prompt
        let profile = SarahGenerativeModelCatalog.imageProfile()

        imageService.generateImage(prompt: finalPrompt) { result in
            if result.isSuccess {
                completion(AgentResponse(
                    agent: .ethel,
                    text: "✨ **Ethel [Studio Créatif]**\n\n🎨 Image réellement générée pour : « **\(finalPrompt)** »\nModèle : **\(result.modelName)**.",
                    spokenText: "C'est fait. L'image a réellement été générée et je l'affiche dans la discussion."
                ))
                return
            }

            let detail = result.errorMessage ?? "ressources locales indisponibles"
            if detail.localizedCaseInsensitiveContains("pas installé") ||
               detail.localizedCaseInsensitiveContains("not installed") {
                if #available(iOS 13.0, *) {
                    GenerativeModelDownloader.shared.startImageModelDownload()
                }
                completion(AgentResponse(
                    agent: .ethel,
                    text: "✨ **Ethel [Studio Créatif]**\n\nLe vrai modèle **\(profile.displayName)** n'est pas encore installé. Je lance sa préparation locale. Une fois l'installation terminée, relance la même demande.\n\nAucune fausse image n'a été créée.",
                    spokenText: "Le vrai modèle image doit d'abord être installé. Je lance sa préparation locale."
                ))
                return
            }

            completion(AgentResponse(
                agent: .ethel,
                text: "✨ **Ethel [Studio Créatif]**\n\nLa génération réelle a échoué : \(detail)\n\nAucune image fictive n'a été annoncée comme terminée.",
                spokenText: "La génération réelle a échoué. Je n'annonce plus une image tant qu'elle n'existe pas."
            ))
        }
    }'''
coord = replace_function(
    coord,
    "private func processWithEthel(text: String, completion: @escaping (AgentResponse) -> Void)",
    new_ethel,
    "processWithEthel"
)
coord_path.write_text(coord)

print("Real local website generation and actual image result pipeline applied")
