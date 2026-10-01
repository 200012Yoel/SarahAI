from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing expected block: {label}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# Agent voices: use Apple's public gender metadata, keep Sarah female and the
# three principal specialist agents male, and never rely on unstable list order.
# -----------------------------------------------------------------------------
voice_path = Path("SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift")
voice = voice_path.read_text()
voice = voice.replace("import Foundation\nimport Foundation\n", "import Foundation\n", 1)

voice = replace_once(
    voice,
    '''                case .esther: targetNames = ["audrey", "celine", "céline", "aurelie", "aurélie", "claire"]
''',
    '''                case .esther: targetNames = ["nicolas", "thomas", "rémi", "remi", "alain", "pierre", "antoine"]
''',
    "Raphael male target names"
)

voice = replace_once(
    voice,
    '''                let isFemale = (agent == .sarah || agent == .esther || agent == .ethel)
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
''',
    '''                let wantsFemale = (agent == .sarah || agent == .ethel)
                let wantsMale = (agent == .nathan || agent == .esther || agent == .tom || agent == .yohan)

                let freeVoices = frenchVoices.filter { !usedIdentifiers.contains($0.identifier) }
                if let matchGender = freeVoices.first(where: { voice in
                    if wantsFemale { return voice.gender == .female }
                    if wantsMale { return voice.gender == .male }
                    return true
                }) {
                    selectedVoice = matchGender
                } else if let anyFree = freeVoices.first {
                    selectedVoice = anyFree
                }
''',
    "public voice gender matching"
)
voice_path.write_text(voice)

agent_path = Path("SarahIA/SarahIA/Models/AgentType.swift")
agent = agent_path.read_text()
agent = replace_once(
    agent,
    '''        case .esther:
            // Esther (affichée comme Raphaël) est fixée à France — Voix 3.
            return [
                "com.apple.ttsbundle.Audrey-compact",
                speechIdentifier
            ]
''',
    '''        case .esther:
            // Raphaël doit rester masculin. Aucun identifiant Siri privé ou
            // supposé n'est forcé ici : AgentVoiceManager choisit une voix
            // française masculine disponible via l'API publique iOS.
            return []
''',
    "Raphael public voice selection"
)
agent = agent.replace(
    'case .esther: return "Développeur : sites, apps iOS & code (Bleu ciel)"',
    'case .esther: return "Développeur : sites, apps iOS & code · voix masculine (Bleu ciel)"',
    1,
)
agent_path.write_text(agent)


# -----------------------------------------------------------------------------
# Real website generation: demand production-ready behavior rather than merely
# visually plausible HTML, and strengthen the static audit before persistence.
# -----------------------------------------------------------------------------
web_path = Path("SarahIA/SarahIA/Services/VAICodeEngine.swift")
web = web_path.read_text()

old_impl = '''        Tu es Raphaël Code Worker. Écris réellement le site demandé. Retourne UNIQUEMENT un document HTML5 autonome complet avec CSS et JavaScript intégrés. Chaque texte, section, composant, disposition et interaction doit découler du brief et du plan. Interdiction d'utiliser un dashboard de secours, du lorem ipsum, « Produit 01 », des blocs préfabriqués, des URLs d'images factices, un CDN, une police distante, un logo de marque ou un asset propriétaire. Les références de style sont des principes visuels, jamais des copies. Le résultat doit être responsive, accessible, utilisable hors ligne et les interactions demandées doivent fonctionner réellement en JavaScript local.
'''
new_impl = '''        Tu es Raphaël Code Worker. Écris réellement le site demandé. Retourne UNIQUEMENT un document HTML5 autonome complet avec CSS et JavaScript intégrés. Chaque texte, section, composant, disposition et interaction doit découler du brief et du plan. Interdiction d'utiliser un dashboard de secours, du lorem ipsum, « Produit 01 », des blocs préfabriqués, des URLs d'images factices, un CDN, une police distante, un logo de marque ou un asset propriétaire. Les références de style sont des principes visuels, jamais des copies. Le résultat doit être responsive, accessible, utilisable hors ligne et les interactions demandées doivent fonctionner réellement en JavaScript local. Tous les boutons doivent avoir une action utile, tous les liens internes doivent pointer vers une cible existante, tous les formulaires doivent valider leurs champs et afficher un résultat compréhensible, et aucun élément interactif ne doit être purement décoratif. Utilise HTML sémantique, un attribut lang, un title spécifique, une structure main/header/footer pertinente et des libellés accessibles. Ne renvoie jamais un prototype vide : livre une page cohérente, complète et directement ouvrable dans Safari mobile.
'''
web = replace_once(web, old_impl, new_impl, "production web implementer prompt")

old_repair = '''        Tu es le relecteur final du Code Worker. Retourne uniquement le HTML complet corrigé. Corrige les erreurs WebKit, le débordement horizontal, les erreurs JavaScript et les balises incomplètes sans supprimer les fonctions valides du site.
'''
new_repair = '''        Tu es le relecteur final du Code Worker. Retourne uniquement le HTML complet corrigé. Corrige toutes les erreurs WebKit, le débordement horizontal, les erreurs JavaScript, les balises incomplètes, les liens internes cassés, les boutons sans action, les formulaires non fonctionnels et les problèmes d'accessibilité évidents sans supprimer les fonctions valides du site. Le site corrigé doit rester autonome, responsive, hors ligne et directement ouvrable dans Safari mobile.
'''
web = replace_once(web, old_repair, new_repair, "production web repair prompt")

old_audit_tail = '''        if lower.contains("@media") || lower.contains("clamp(") || lower.contains("min(") { passed.append("Responsive CSS") } else { warnings.append("Peu de règles responsive détectées") }
        if lower.contains("document.write(") { warnings.append("document.write() détecté") }
        if html.count > 750_000 { warnings.append("Document très volumineux") }

        return SarahWebAuditReport(errors: errors, warnings: warnings, passedChecks: passed)
'''
new_audit_tail = '''        if lower.contains("@media") || lower.contains("clamp(") || lower.contains("min(") { passed.append("Responsive CSS") } else { warnings.append("Peu de règles responsive détectées") }
        if lower.contains("<title>") && lower.contains("</title>") { passed.append("Titre de page") } else { errors.append("Titre de page manquant") }
        if lower.contains("<html lang=") { passed.append("Langue du document") } else { errors.append("Attribut lang manquant") }
        if lower.contains("<main") { passed.append("Structure sémantique") } else { warnings.append("Balise main absente") }
        if lower.contains("document.write(") { warnings.append("document.write() détecté") }
        if lower.contains("href=\\\"#\\\"") || lower.contains("href='#'") { warnings.append("Lien # sans destination détecté") }
        if lower.contains("javascript:void") { warnings.append("Lien javascript:void détecté") }
        if lower.contains("<button") && !lower.contains("<script") { errors.append("Boutons présents sans JavaScript") }
        if lower.contains("<form") && !lower.contains("onsubmit") && !lower.contains("addeventlistener('submit") && !lower.contains("addeventlistener(\\\"submit") { warnings.append("Formulaire sans gestion de soumission détectée") }
        if html.count > 750_000 { warnings.append("Document très volumineux") }

        return SarahWebAuditReport(errors: errors, warnings: warnings, passedChecks: passed)
'''
web = replace_once(web, old_audit_tail, new_audit_tail, "stronger static web audit")

old_local_repair = '''        let prompt = repairSystemPrompt()
            + "\\n\\nHTML À CORRIGER :\\n" + build.html
            + "\\n\\nRAPPORT WEBKIT :\\n" + report.details
            + "\\nErreurs JavaScript : " + report.javascriptErrors.joined(separator: " | ")
'''
new_local_repair = '''        let prompt = repairSystemPrompt()
            + "\\n\\nHTML À CORRIGER :\\n" + build.html
            + "\\n\\nRAPPORT WEBKIT :\\n" + report.details
            + "\\nErreurs JavaScript : " + report.javascriptErrors.joined(separator: " | ")
            + "\\nErreurs statiques : " + build.staticAudit.errors.joined(separator: " | ")
            + "\\nAvertissements statiques : " + build.staticAudit.warnings.joined(separator: " | ")
'''
web = replace_once(web, old_local_repair, new_local_repair, "local repair audit context")
web_path.write_text(web)


# -----------------------------------------------------------------------------
# Deep UI interaction hardening.
# -----------------------------------------------------------------------------
content_path = Path("SarahIA/SarahIA/ContentView.swift")
content = content_path.read_text()
content = content.replace(
    '''                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(
                    !viewModel.isDrawerOpen && !viewModel.isShowingVoiceOrbModal
                )
''',
    '''                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)
'''
)
content_path.write_text(content)

chat_path = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
chat = chat_path.read_text()
chat = chat.replace(
    '''                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { keyboard.dismiss() }
''',
    '''                .frame(maxWidth: .infinity, maxHeight: .infinity)
'''
)
chat = chat.replace(
    '''        .ignoresSafeArea()
    }

    private var composerDock: some View {
''',
    '''        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var composerDock: some View {
''',
    1
)
chat_path.write_text(chat)

message_list_path = Path("SarahIA/SarahIA/Views/MessageList.swift")
message_list = message_list_path.read_text()
message_list = message_list.replace(
    '''            // Fermeture du clavier au glissement vers le bas
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 15 && isKeyboardVisible {
                            onDismissKeyboard?()
                        }
                    }
            )
''',
    '''            .scrollDismissesKeyboard(.interactively)
'''
)
message_list_path.write_text(message_list)

# Keep the native composer editable even while an answer is being generated.
# The stop button remains available, but stale generation state cannot disable
# the UITextField or steal focus from the user.
bar_path = Path("SarahIA/SarahIA/Views/MessageBar.swift")
bar = bar_path.read_text()
bar = bar.replace("                    isEnabled: !isProcessing,", "                    isEnabled: true,", 1)
bar_path.write_text(bar)

# A microphone permission alert also sends willResignActive. Stopping voice mode
# on that notification killed the very first launch of the microphone. Only stop
# the conversation when the app really enters the background.
voice_orb_path = Path("SarahIA/SarahIA/Views/VoiceOrbModalView.swift")
voice_orb = voice_orb_path.read_text()
voice_orb = voice_orb.replace(
    "UIApplication.willResignActiveNotification",
    "UIApplication.didEnterBackgroundNotification",
    1,
)
voice_orb = voice_orb.replace(
    '''        case .processing:
            return "Je réfléchis…"
''',
    '''        case .starting:
            return "Préparation du micro…"
        case .processing:
            return "Je réfléchis…"
''',
    1,
)
voice_orb = voice_orb.replace(
    '''        case .error:
            return "Touchez le micro pour réessayer"
        case .processing:
            return "Un instant…"
''',
    '''        case .error:
            return "Touchez le micro pour réessayer"
        case .starting:
            return "Whisper se prépare en local"
        case .processing:
            return "Un instant…"
''',
    1,
)
voice_orb_path.write_text(voice_orb)

# -----------------------------------------------------------------------------
# Main-thread freeze removal.
#
# Loading a large history or image-rich conversation must never happen on the
# main actor. Storage keeps its synchronous API for maintenance callers, while
# ChatViewModel uses the asynchronous API and all chat saves are merged on the
# storage queue before being written.
# -----------------------------------------------------------------------------
storage_path = Path("SarahIA/SarahIA/Services/StorageService.swift")
storage = storage_path.read_text()
old_load = '''    /// Charge l'état persisté depuis le stockage local avec restauration automatique de secours.
    public func loadState() -> AppPersistedState {
        return ioQueue.sync {
            if fileManager.fileExists(atPath: stateFileURL.path) {
                do {
                    let data = try Data(contentsOf: stateFileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(AppPersistedState.self, from: data)
                } catch {
                    print("⚠️ [StorageService] Fichier principal corrompu, essai du secours: \\(error.localizedDescription)")
                }
            }

            if fileManager.fileExists(atPath: backupFileURL.path) {
                do {
                    let data = try Data(contentsOf: backupFileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let state = try decoder.decode(AppPersistedState.self, from: data)
                    print("✅ [StorageService] État restauré depuis la sauvegarde de secours")
                    return state
                } catch {
                    print("⚠️ [StorageService] Échec du secours: \\(error.localizedDescription)")
                }
            }

            return AppPersistedState()
        }
    }
'''
new_load = '''    /// Charge l'état persisté depuis le stockage local avec restauration automatique de secours.
    public func loadState() -> AppPersistedState {
        ioQueue.sync { loadStateUnlocked() }
    }

    /// Charge l'historique sans jamais bloquer le MainActor. La completion est
    /// toujours rappelée sur le main thread, prête à mettre à jour SwiftUI.
    public func loadStateAsync(completion: @escaping (AppPersistedState) -> Void) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let state = self.loadStateUnlocked()
            DispatchQueue.main.async {
                completion(state)
            }
        }
    }

    /// Fusionne une capture du chat avec les réglages persistés existants sans
    /// relire le JSON sur le thread appelant.
    public func saveChatState(
        conversations: [Conversation],
        currentConversationId: UUID?,
        messages: [Message],
        learnedMemories: [String: String]
    ) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            var state = self.loadStateUnlocked()
            state.activeMode = "text"
            state.conversations = conversations
            state.currentConversationId = currentConversationId
            state.messages = messages
            state.learnedMemories = learnedMemories
            state.lastActiveTimestamp = Date()
            self.saveState(state)
        }
    }

    private func loadStateUnlocked() -> AppPersistedState {
        if fileManager.fileExists(atPath: stateFileURL.path) {
            do {
                let data = try Data(contentsOf: stateFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(AppPersistedState.self, from: data)
            } catch {
                print("⚠️ [StorageService] Fichier principal corrompu, essai du secours: \\(error.localizedDescription)")
            }
        }

        if fileManager.fileExists(atPath: backupFileURL.path) {
            do {
                let data = try Data(contentsOf: backupFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let state = try decoder.decode(AppPersistedState.self, from: data)
                print("✅ [StorageService] État restauré depuis la sauvegarde de secours")
                return state
            } catch {
                print("⚠️ [StorageService] Échec du secours: \\(error.localizedDescription)")
            }
        }

        return AppPersistedState()
    }
'''
storage = replace_once(storage, old_load, new_load, "nonblocking storage load")
storage_path.write_text(storage)

view_model_path = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
view_model = view_model_path.read_text()
view_model = view_model.replace(
    '''    public init() {
        restorePersistedState()
        setupModeObserver()
        bindCoreServices()
    }
''',
    '''    public init() {
        setupModeObserver()
        bindCoreServices()
        restorePersistedStateInBackground()
    }
''',
    1,
)
view_model = view_model.replace(
    '''    public func restorePersistedState() {
        let savedState = storageService.loadState()
''',
    '''    private func restorePersistedStateInBackground() {
        storageService.loadStateAsync { [weak self] savedState in
            guard let self = self else { return }
            // If the user already started interacting, never overwrite the live
            // conversation with a late disk restoration.
            guard self.currentConversationId == nil, self.messages.isEmpty else { return }
            self.applyPersistedState(savedState)
        }
    }

    public func restorePersistedState() {
        applyPersistedState(storageService.loadState())
    }

    private func applyPersistedState(_ savedState: AppPersistedState) {
''',
    1,
)
# Keep ChatGPT-like history across launches. New-build test resets remain handled
# by StorageService.resetUserStateForNewBuildIfNeeded, not by every cold launch.
view_model = view_model.replace(
    '''        // Après une relance complète, ouvrir un chat vierge sans appeler startNewChat().
        // startNewChat() initialise la voix, la mémoire sémantique et d'autres moteurs lourds ;
        // aucun de ces composants ne doit être touché pendant le démarrage du processus.
        if SessionTimeoutManager.shared.consumeColdLaunchFreshChatRequest() {
            currentConversationId = nil
            messages = []
            inputText = ""
            appMode = .text
            isDrawerOpen = false
            drawerProgress = 0
            activeAgent = .sarah
            return
        }
        // Le moteur IA est synchronisé au premier envoi, pas au lancement.
''',
    '''        // Le moteur IA est synchronisé au premier envoi, pas au lancement.
        // L'historique reste visible comme dans une application de chat normale.
''',
    1,
)
view_model = view_model.replace(
    '''        var state = storageService.loadState()
        state.conversations = self.conversations
        state.currentConversationId = self.currentConversationId
        state.learnedMemories = self.learnedMemories
        storageService.saveState(state)
''',
    '''        storageService.saveChatState(
            conversations: self.conversations,
            currentConversationId: self.currentConversationId,
            messages: self.messages,
            learnedMemories: self.learnedMemories
        )
''',
    1,
)
# Published appMode emits immediately. Do not persist during the first frame.
view_model = view_model.replace(
    '''        $appMode
            .sink { [weak self] _ in
''',
    '''        $appMode
            .dropFirst()
            .sink { [weak self] _ in
''',
    1,
)
view_model = view_model.replace(
    '''        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
    }
''',
    '''        voiceStatus = isMicRunning ? .listening(level: 0.0) : .starting
    }
''',
    1,
)
view_model_path.write_text(view_model)

print("Production stability pass applied: responsive composer, nonblocking history persistence, safe voice startup")
