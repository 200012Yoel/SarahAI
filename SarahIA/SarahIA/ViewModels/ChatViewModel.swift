import Foundation
import SwiftUI
import Combine
import AVFoundation

/// Mode d'affichage actif de l'application Sarah AI
public enum AppMode: String, Codable {
    case text
}

/// État de la boucle vocale en direct
public enum VoiceInteractionStatus: Equatable {
    case idle
    case listening(level: Float)
    case processing
    case speaking
    case error(String)
}

/// ViewModel principal orchestrant l'écosystème à 4 agents (Sarah, Tom, Raphaël, Yohan),
/// le Voice Orb, le studio VAI Coding, la reconnaissance vocale Apple Speech et la synthèse vocale multi-voix.
@available(iOS 14.0, *)
@MainActor
public final class ChatViewModel: ObservableObject {
    
    // MARK: - Published UI State
    @Published public var activeAgent: AgentType = .sarah
    @Published public var appMode: AppMode = .text
    @Published public var conversations: [Conversation] = []
    @Published public var currentConversationId: UUID? = nil
    @Published public var messages: [Message] = []
    @Published public var inputText: String = ""
    @Published public var isTyping: Bool = false
    @Published public var voiceStatus: VoiceInteractionStatus = .idle
    @Published public var liveTranscriptionText: String = ""
    @Published public var micInputLevel: Float = 0.0
    @Published public var learnedMemories: [String: String] = [:]
    @Published public var isSpeaking: Bool = false
    @Published public var currentSpeakingText: String? = nil
    @Published public var isMicRunning: Bool = false
    @Published public var isComposerDictating: Bool = false
    @Published public var isContinuousConversationActive: Bool = false
    @Published public var pendingVoiceConfirmation: String? = nil
    @Published public var isVoiceBubbleVisible: Bool = false
    
    // MARK: - Navigation, Studio VAI Coding & Voice Orb
    @Published public var isDrawerOpen: Bool = false
    @Published public var drawerProgress: CGFloat = 0.0
    @Published public var searchQuery: String = ""
    @Published public var isSearchActive: Bool = false
    @Published public var isShowingVoiceOrbModal: Bool = false
    @Published public var isShowingVAICodingStudio: Bool = false
    @Published public var isShowingWebsiteBuilder: Bool = false
    @Published public var vaiCurrentCode: String? = nil
    @Published public var websiteDraft: WebsiteBrief? = nil
    
    public var isGeneratingResponse: Bool {
        get { isTyping }
        set { isTyping = newValue }
    }
    
    // MARK: - Services
    // Les services lourds sont résolus à la demande. Sur certaines bêtas iOS,
    // initialiser Speech/AVAudioEngine/AVSpeechSynthesizer avant le premier frame
    // peut faire tomber le processus. Le chat peut donc toujours démarrer seul.
    private var aiService: AIService { AIService.shared }
    private var notificationService: NotificationService { NotificationService.shared }
    private var storageService: StorageService { StorageService.shared }
    private var multiAgentCoordinator: MultiAgentCoordinator { MultiAgentCoordinator.shared }
    private var voiceManager: MultiAgentVoiceManager { MultiAgentVoiceManager.shared }
    private var haptics: HapticService { HapticService.shared }

    private var cancellables = Set<AnyCancellable>()
    private var isVoicePipelinePrepared = false
    private var pendingVoiceActionText: String? = nil
    private var shouldResumeVoiceAfterInterruption = false
    private var composerDictationBaseText: String = ""
    private var isVoiceTurnInFlight = false
    private var lastSubmittedVoiceTranscript = ""
    private var lastSubmittedVoiceTranscriptAt = Date.distantPast
    
    public init() {
        restorePersistedState()
        setupModeObserver()
        bindCoreServices()
    }
    
    // MARK: - Liaison des Services

    private func bindCoreServices() {
        NotificationCenter.default.publisher(for: .sarahStartNewChat)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startNewChat()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .sarahClearCurrentChat)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startNewChat()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .sarahAgentSelected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                if let agent = notif.object as? AgentType {
                    self?.activeAgent = agent
                }
            }
            .store(in: &cancellables)
    }

    private func ensureVoicePipelinePrepared() {
        guard !isVoicePipelinePrepared else { return }
        isVoicePipelinePrepared = true

        setupVoicePipeline()

        // Relier réellement les interruptions système au mode vocal.
        // Avant ce correctif, AudioSessionManager détectait Siri/appels/alarmes
        // mais personne ne coupait puis ne restaurait la conversation vocale.
        AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
            guard let self = self else { return }
            let shouldResume = self.isContinuousConversationActive &&
                (self.isShowingVoiceOrbModal || self.isVoiceBubbleVisible)

            if shouldResume || AppleSpeechRecognizer.shared.isListening || self.voiceManager.isSpeaking {
                self.stopVoiceConversation()
            }

            self.shouldResumeVoiceAfterInterruption = shouldResume
        }

        AudioSessionManager.shared.onInterruptionEnded = { [weak self] in
            guard let self = self else { return }
            let shouldResume = self.shouldResumeVoiceAfterInterruption
            self.shouldResumeVoiceAfterInterruption = false

            guard shouldResume else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard self.isShowingVoiceOrbModal || self.isVoiceBubbleVisible else { return }

                if self.isVoiceBubbleVisible {
                    self.isContinuousConversationActive = true
                    AppleSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true
                    )
                    self.isMicRunning = AppleSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning
                        ? .listening(level: 0.0)
                        : .idle
                } else {
                    self.startVoiceConversation()
                }
            }
        }

        ObservableSpeechRecognizer.shared.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isMicRunning = listening
                if listening {
                    self?.voiceStatus = .listening(level: 0.5)
                }
            }
            .store(in: &cancellables)
            
        ObservableSpeechRecognizer.shared.$micEnergyLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.micInputLevel = level
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSNotification.Name("AppleSpeechRecognizerStateChanged")
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self = self else { return }
            if case .error(let message) = AppleSpeechRecognizer.shared.state {
                self.isMicRunning = false
                self.isVoiceTurnInFlight = false
                self.voiceStatus = .error(message)
            }
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Persistance des Données & Restauration
    
    public func restorePersistedState() {
        let savedState = storageService.loadState()
        self.learnedMemories = savedState.learnedMemories
        self.conversations = savedState.conversations
        
        if let currentId = savedState.currentConversationId,
           let existing = self.conversations.first(where: { $0.id == currentId }) {
            self.currentConversationId = existing.id
            self.messages = existing.messages
        } else if let first = self.conversations.first {
            self.currentConversationId = first.id
            self.messages = first.messages
        } else {
            self.conversations = []
            self.currentConversationId = nil
            self.messages = []
        }

        // Après une relance complète, ouvrir un chat vierge sans appeler startNewChat().
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
    }
    
    public func persistCurrentState() {
        if let currentId = currentConversationId,
           let index = conversations.firstIndex(where: { $0.id == currentId }) {
            conversations[index].messages = messages
            conversations[index].updatedAt = Date()
        }
        
        var state = storageService.loadState()
        state.conversations = self.conversations
        state.currentConversationId = self.currentConversationId
        state.learnedMemories = self.learnedMemories
        storageService.saveState(state)
    }
    
    // MARK: - Discussions & Tiroir Latéral
    
    public var filteredPinnedConversations: [Conversation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return conversations.filter { $0.isPinned && !$0.isArchived }
            .filter { query.isEmpty || $0.title.lowercased().contains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public var filteredRecentConversations: [Conversation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return conversations.filter { !$0.isPinned && !$0.isArchived }
            .filter { query.isEmpty || $0.title.lowercased().contains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public func startNewChat(silently: Bool = false) {
        if !silently { haptics.buttonTap() }

        if isVoicePipelinePrepared {
            stopVoiceConversation()
        } else {
            voiceManager.stop()
        }

        AIProgressiveScheduler.shared.cancelAllTasks()
        currentConversationId = nil
        messages = []
        inputText = ""
        isTyping = false
        isSpeaking = false
        voiceStatus = .idle
        appMode = .text
        isDrawerOpen = false
        drawerProgress = 0.0
        activeAgent = .sarah
        aiService.syncHistoryFromMessages([])
        SemanticMemoryIndex.shared.clearSessionContext()
        ConversationContext.shared.reset()
        SarahBrainEngine.shared.clearSessionHistory()
        persistCurrentState()
    }
    
    public func selectConversation(_ conv: Conversation) {
        haptics.buttonTap()

        if isVoicePipelinePrepared {
            stopVoiceConversation()
        } else {
            voiceManager.stop()
        }

        AIProgressiveScheduler.shared.cancelAllTasks()
        isTyping = false
        isSpeaking = false
        voiceStatus = .idle
        currentConversationId = conv.id
        messages = conv.messages
        appMode = .text
        isDrawerOpen = false
        drawerProgress = 0.0
        aiService.syncHistoryFromMessages(conv.messages)
        SemanticMemoryIndex.shared.clearSessionContext()
        ConversationContext.shared.reset()
        SarahBrainEngine.shared.clearSessionHistory()
        persistCurrentState()
    }
    
    public func togglePinConversation(_ conv: Conversation) {
        haptics.buttonTap()
        if let index = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[index].isPinned.toggle()
            persistCurrentState()
        }
    }
    
    public func renameConversation(_ conv: Conversation, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        haptics.buttonTap()
        if let index = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[index].title = trimmed
            persistCurrentState()
        }
    }
    
    public func deleteConversation(_ conv: Conversation) {
        haptics.memoryDeleted()
        AIProgressiveScheduler.shared.cancelAllTasks()
        conversations.removeAll(where: { $0.id == conv.id })
        
        let convUUID = conv.id.uuidString
        DispatchQueue.global(qos: .background).async {
            SQLiteChatDatabase.shared.deleteConversationByUUID(uuid: convUUID)
        }
        
        if currentConversationId == conv.id {
            if let next = conversations.first {
                selectConversation(next)
            } else {
                startNewChat()
            }
        }
        persistCurrentState()
    }
    
    public func deleteAllConversations() {
        haptics.memoryDeleted()

        if isVoicePipelinePrepared {
            stopVoiceConversation()
        } else {
            voiceManager.stop()
        }

        AIProgressiveScheduler.shared.cancelAllTasks()
        conversations.removeAll()
        messages.removeAll()
        currentConversationId = nil
        inputText = ""
        isTyping = false
        isSpeaking = false
        voiceStatus = .idle
        aiService.syncHistoryFromMessages([])
        SemanticMemoryIndex.shared.clearSessionContext()
        ConversationContext.shared.reset()
        SarahBrainEngine.shared.clearSessionHistory()
        SQLiteChatDatabase.shared.clearAllHistory()
        persistCurrentState()
    }
    
    public func archiveConversation(_ conv: Conversation) {
        haptics.buttonTap()
        if let index = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[index].isArchived = true
            if currentConversationId == conv.id {
                startNewChat()
            }
            persistCurrentState()
        }
    }

    public func unarchiveConversation(_ conv: Conversation) {
        haptics.buttonTap()
        if let index = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[index].isArchived = false
            persistCurrentState()
        }
    }

    public var filteredArchivedConversations: [Conversation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return conversations.filter { $0.isArchived }
            .filter { query.isEmpty || $0.title.lowercased().contains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public func openDrawer() {
        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)) {
            isDrawerOpen = true
            drawerProgress = 1.0
        }
    }
    
    public func closeDrawer() {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.90, blendDuration: 0.10)) {
            isDrawerOpen = false
            drawerProgress = 0.0
        }
    }
    
    public func switchToChat() {
        haptics.buttonTap()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            appMode = .text
            isDrawerOpen = false
            drawerProgress = 0.0
        }
    }
    
    private func setupModeObserver() {
        $appMode
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.persistCurrentState()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Pipeline Vocale Apple Speech & Multi-Agents
    
    private func setupVoicePipeline() {
        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            guard let self = self else { return }
            self.liveTranscriptionText = partial

            if self.isComposerDictating {
                self.inputText = self.composerText(with: partial)
            }
        }
        
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self else { return }

            let cleaned = self.sanitizeVoiceTranscript(finalTranscription)

            // Dictée de la barre de saisie : conserver le texte, ne jamais
            // l'envoyer automatiquement à Sarah.
            if self.isComposerDictating {
                if !cleaned.isEmpty {
                    self.inputText = self.composerText(with: cleaned)
                }
                self.isComposerDictating = false
                self.isMicRunning = false
                self.liveTranscriptionText = ""
                self.voiceStatus = .idle
                self.composerDictationBaseText = ""
                return
            }
            
            // Une seule phrase vocale à la fois. Le micro ne doit jamais
            // lancer une deuxième requête pendant le traitement ou pendant la voix de Sarah.
            guard !self.voiceManager.isSpeaking,
                  !self.isVoiceTurnInFlight,
                  !self.isTyping else {
                return
            }

            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                return
            }

            let normalizedTranscript = self.normalizeVoiceCommand(cleaned)
            let now = Date()
            if normalizedTranscript == self.lastSubmittedVoiceTranscript,
               now.timeIntervalSince(self.lastSubmittedVoiceTranscriptAt) < 2.5 {
                self.voiceStatus = .idle
                return
            }

            self.liveTranscriptionText = cleaned
            self.isMicRunning = false

            // Les actions qui ouvrent une app ou modifient l'iPhone ne partent
            // jamais directement depuis une transcription vocale.
            if self.handleVoiceActionSafety(cleaned) {
                return
            }

            self.lastSubmittedVoiceTranscript = normalizedTranscript
            self.lastSubmittedVoiceTranscriptAt = now
            self.isVoiceTurnInFlight = true
            self.voiceStatus = .processing
            self.sendMessage(cleaned)
        }
        
        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            AppleSpeechRecognizer.shared.stopListening()
            self.isMicRunning = false
            self.isSpeaking = true
            self.voiceStatus = .speaking
            self.haptics.speechStarted()
        }
        
        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.isVoiceTurnInFlight = false
            self.voiceStatus = .idle
            self.haptics.speechFinished()

            let voiceUIIsAvailable =
                self.isShowingVoiceOrbModal || self.isVoiceBubbleVisible

            if self.isContinuousConversationActive && voiceUIIsAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    guard self.isContinuousConversationActive,
                          (self.isShowingVoiceOrbModal || self.isVoiceBubbleVisible),
                          !self.voiceManager.isSpeaking,
                          !self.isTyping else { return }

                    if self.pendingVoiceActionText == nil {
                        self.liveTranscriptionText = ""
                    }

                    AppleSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true
                    )
                    self.isMicRunning = AppleSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning
                        ? .listening(level: 0.0)
                        : .idle
                }
            }
        }
    }
    
    private func sanitizeVoiceTranscript(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let normalized = trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        // Canoniser les salutations courtes, très fréquentes en vocal.
        switch normalized {
        case "bonjour", "bonjour sarah", "bon jour":
            return "bonjour"
        case "salut", "salut sarah", "coucou", "coucou sarah":
            return "salut"
        case "bonsoir", "bonsoir sarah":
            return "bonsoir"
        default:
            return trimmed
        }
    }
    
    private func normalizeVoiceCommand(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    /// Retourne true si la transcription a été consommée par le garde-fou vocal.
    private func handleVoiceActionSafety(_ text: String) -> Bool {
        let normalized = normalizeVoiceCommand(text)
        
        let confirmations: Set<String> = [
            "confirme", "je confirme", "oui confirme", "oui je confirme",
            "ok confirme", "vas y confirme"
        ]
        let cancellations: Set<String> = [
            "annule", "annuler", "non annule", "laisse tomber", "oublie"
        ]
        
        if let pending = pendingVoiceActionText {
            if confirmations.contains(normalized) {
                pendingVoiceActionText = nil
                pendingVoiceConfirmation = nil
                liveTranscriptionText = pending
                isVoiceTurnInFlight = true
                voiceStatus = .processing
                sendMessage(pending)
                return true
            }
            
            if cancellations.contains(normalized) {
                pendingVoiceActionText = nil
                pendingVoiceConfirmation = nil
                liveTranscriptionText = "Action annulée"
                voiceStatus = .speaking
                voiceManager.speak(
                    text: "D'accord, action annulée.",
                    for: activeAgent
                )
                return true
            }
            
            // Une nouvelle phrase remplace l'ancienne demande non confirmée.
            pendingVoiceActionText = nil
            pendingVoiceConfirmation = nil
        }
        
        guard requiresVoiceConfirmation(normalized) else {
            return false
        }
        
        pendingVoiceActionText = text
        pendingVoiceConfirmation = text
        liveTranscriptionText = text
        voiceStatus = .speaking
        
        voiceManager.speak(
            text: "J'ai compris : \(text). Dis confirme pour exécuter cette action, ou annule.",
            for: activeAgent
        )
        return true
    }
    
    private func requiresVoiceConfirmation(_ normalized: String) -> Bool {
        let actionVerbs = [
            "ouvre", "lance", "mets", "joue", "demarre", "active",
            "desactive", "allume", "eteins", "appelle", "telephone"
        ]
        
        let sideEffectTargets = [
            "apple music", "spotify", "musique", "radio", "podcast",
            "youtube", "camera", "appareil photo", "torche", "lampe",
            "flash", "appel", "telephone", "instagram", "tiktok",
            "whatsapp", "reglages"
        ]
        
        let hasActionVerb = actionVerbs.contains { verb in
            normalized == verb ||
            normalized.hasPrefix(verb + " ") ||
            normalized.contains(" " + verb + " ")
        }
        
        let hasTarget = sideEffectTargets.contains { normalized.contains($0) }
        return hasActionVerb && hasTarget
    }
    
    private func composerText(with transcript: String) -> String {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = composerDictationBaseText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !base.isEmpty else { return spoken }
        guard !spoken.isEmpty else { return base }
        return base + " " + spoken
    }

    public func toggleComposerDictation() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if isComposerDictating {
            finishComposerDictation()
        } else {
            startComposerDictation()
        }
    }

    public func startComposerDictation() {
        ensureVoicePipelinePrepared()

        // Les deux modes audio sont exclusifs.
        if isContinuousConversationActive {
            stopVoiceConversation()
        } else if voiceManager.isSpeaking {
            voiceManager.stop()
        }

        composerDictationBaseText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscriptionText = ""
        isComposerDictating = true
        voiceStatus = .listening(level: 0.0)

        AppleSpeechRecognizer.shared.startListening(autoFinalizeOnSilence: false)
        isMicRunning = AppleSpeechRecognizer.shared.isListening
    }

    public func finishComposerDictation() {
        guard isComposerDictating else { return }

        let live = AppleSpeechRecognizer.shared.currentLiveText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !live.isEmpty {
            inputText = composerText(with: live)
        }

        AppleSpeechRecognizer.shared.stopListening()
        isComposerDictating = false
        isMicRunning = false
        liveTranscriptionText = ""
        voiceStatus = .idle
        composerDictationBaseText = ""
    }

    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if isMicRunning || AppleSpeechRecognizer.shared.isListening {
            stopVoiceConversation(stopSpeech: false)
        } else {
            startVoiceConversation()
        }
    }

    /// Démarre explicitement une session vocale continue.
    /// Utilisé par le plein écran vocal pour éviter les doubles démarrages.
    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()

        if isComposerDictating {
            finishComposerDictation()
        }

        shouldResumeVoiceAfterInterruption = false
        isVoiceBubbleVisible = false
        if !isTyping && !voiceManager.isSpeaking {
            isVoiceTurnInFlight = false
        }

        // Réouverture depuis la bulle : conserver la réponse en cours au lieu
        // de redémarrer toute la pile audio.
        if isContinuousConversationActive {
            if !voiceManager.isSpeaking && !AppleSpeechRecognizer.shared.isListening {
                AppleSpeechRecognizer.shared.startListening()
                isMicRunning = AppleSpeechRecognizer.shared.isListening
                voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
            }
            return
        }

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

    /// Coupe complètement le mode vocal et rend la session audio à iOS.
    /// Cette méthode doit être appelée à chaque fermeture de l'écran vocal,
    /// même si Sarah est en train de parler et que le micro est déjà arrêté.
    public func stopVoiceConversation(stopSpeech: Bool = true) {
        shouldResumeVoiceAfterInterruption = false
        isVoiceBubbleVisible = false

        if isComposerDictating {
            let live = AppleSpeechRecognizer.shared.currentLiveText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !live.isEmpty {
                inputText = composerText(with: live)
            }
            isComposerDictating = false
            composerDictationBaseText = ""
        }
        isContinuousConversationActive = false
        isVoiceTurnInFlight = false
        pendingVoiceActionText = nil
        pendingVoiceConfirmation = nil

        // Couper d'abord la synthèse, puis la capture micro. Dans l'ordre inverse,
        // la session AVAudioSession pouvait rester active si Sarah parlait encore.
        if stopSpeech {
            voiceManager.stop()
        }

        AppleSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.deactivateSession()

        isMicRunning = false
        micInputLevel = 0.0
        liveTranscriptionText = ""
        voiceStatus = .idle
    }

    public func minimizeVoiceConversation() {
        guard isContinuousConversationActive else { return }
        isVoiceBubbleVisible = true
        isShowingVoiceOrbModal = false
    }

    public func restoreVoiceConversation() {
        isVoiceBubbleVisible = false
        isShowingVoiceOrbModal = true
    }
    
    public func speakMessage(_ text: String) {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        voiceManager.speak(text: sanitizeAssistantOutput(text), for: activeAgent)
    }
    
    public func toggleSpeechForMessage(_ text: String) {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if voiceManager.isSpeaking {
            voiceManager.stop()
        } else {
            voiceManager.speak(text: sanitizeAssistantOutput(text), for: activeAgent)
        }
    }
    
    private func sanitizeAssistantOutput(_ raw: String) -> String {
        var text = raw.decodingHTMLEntities()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let leakedPrompt =
            text.localizedCaseInsensitiveContains("<|im_start|>") ||
            text.localizedCaseInsensitiveContains("<|im_end|>") ||
            text.localizedCaseInsensitiveContains("RÈGLES ABSOLUES") ||
            text.localizedCaseInsensitiveContains("REGLES ABSOLUES") ||
            text.localizedCaseInsensitiveContains("Tu es Sarah, l'intelligence artificielle intégrée à Sarah Engine")
        
        if leakedPrompt {
            return "Je n’ai pas produit une réponse correcte. Réessaie ta demande."
        }
        
        if let regex = try? NSRegularExpression(pattern: "(?is)<think>.*?</think>") {
            text = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(location: 0, length: text.utf16.count),
                withTemplate: ""
            )
        }
        
        for token in [
            "<|assistant|>", "<|user|>", "<|system|>",
            "<|endoftext|>", "<|im_start|>", "<|im_end|>"
        ] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty
            ? "Je n’ai pas produit une réponse correcte. Réessaie ta demande."
            : result
    }
    
    // MARK: - Envoi de Message & Orchestration Multi-Agents

    public func retryUserMessage(_ message: Message) {
        guard message.isFromUser else { return }

        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isTyping else { return }

        haptics.buttonTap()
        sendMessage(text)
    }
    
    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        aiService.syncHistoryFromMessages(messages)

        if OpenSourceImageGenerationService.shared.isImageGenerationIntent(text).isIntent {
            notificationService.requestPermission()
        }

        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        WidgetDataBridge.shared.recordQuestion()
        WidgetDataBridge.shared.updateConversationCount(conversations.count)
        inputText = ""

        // Raphaël ouvre un vrai brief de création au lieu d'envoyer une réponse générique.
        // Le même parcours sert aussi à reprendre et améliorer la dernière maquette créée.
        if WebsiteBrief.shouldOpenBuilder(for: text) {
            let isRefinement = WebsiteBrief.isRefinementRequest(text) && websiteDraft != nil
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeAgent = .esther
            }
            let guidance = isRefinement
                ? "💻 **Raphaël** — On reprend ta maquette. Je vais te poser quelques questions pour préparer une version améliorée."
                : "💻 **Raphaël** — Parfait. Je vais te poser quelques questions rapides, puis je génère une première maquette de site que tu pourras améliorer."
            appendMessage(Message(content: guidance, isFromUser: false))
            voiceStatus = .idle
            isTyping = false
            isShowingWebsiteBuilder = true
            return
        }
        
        isTyping = true
        voiceStatus = .processing
        
        // Routage intelligent vers l'un des 4 agents (Sarah, Tom, Raphaël, Yohan) avec préservation du contexte
        let currentSelectedAgent = activeAgent
        let responseConversationID = currentConversationId
        multiAgentCoordinator.routeAndProcess(query: text, currentAgent: currentSelectedAgent) { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Une réponse calculée pour une ancienne discussion ne doit jamais réapparaître
                // dans un nouveau chat après un redémarrage, un archivage ou un changement de fil.
                guard self.currentConversationId == responseConversationID else { return }
                // Basculer l'agent actif selon la décision de routage / passation de main
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.activeAgent = response.agent
                }
                
                let rawText = response.text.isEmpty
                    ? "Je n’ai pas reçu de réponse du moteur."
                    : response.text
                var responseContent = self.sanitizeAssistantOutput(rawText)
                if response.openStudio, response.generatedCode != nil {
                    responseContent += "\n\n🧩 La prévisualisation est prête. Ouvrir le Studio"
                }
                let aiMessage = Message(
                    content: responseContent,
                    isFromUser: false,
                    imageData: response.generatedImageData,
                    generatedImageURL: response.generatedImageURL,
                    generatedAudioURL: response.generatedAudioURL,
                    generatedMusicStyle: response.generatedMusicStyle,
                    imageGenerationPrompt: response.imageGenerationPrompt
                )
                self.appendMessage(aiMessage)

                if response.generatedImageData != nil || response.generatedImageURL != nil {
                    if UIApplication.shared.applicationState != .active {
                        self.notificationService.sendResponseNotification(
                            message: "Votre image est prête."
                        )
                    }
                }

                if response.generatedAudioURL != nil,
                   UIApplication.shared.applicationState != .active {
                    self.notificationService.sendResponseNotification(
                        message: "Votre musique est prête."
                    )
                }

                self.isTyping = false
                self.voiceStatus = .idle
                
                // La mémoire courte AIService est resynchronisée depuis les messages au prochain envoi.
                // Ne pas réenregistrer ici, sinon chaque réponse de Sarah apparaît deux fois dans le contexte.
                SemanticMemoryIndex.shared.indexExchange(userText: text, assistantText: responseContent, topicType: response.agent.rawValue)
                
                // Si Raphaël a généré du code, il prépare le studio mais ne l'ouvre jamais
                // de force. L'utilisateur reste dans le chat et choisit lui-même d'ouvrir le rendu.
                if let code = response.generatedCode {
                    self.vaiCurrentCode = code
                }
                
                // En chat texte, Sarah reste silencieuse. La lecture automatique est
                // réservée au vrai mode vocal ; le bouton "Écouter" reste disponible
                // manuellement sur chaque réponse.
                if self.isContinuousConversationActive &&
                   (self.isShowingVoiceOrbModal || self.isVoiceBubbleVisible) {
                    if let transitionPart = response.handoffSarahTransition,
                       let agentPart = response.handoffAgentGreeting {
                        let src = response.handoffSourceAgent ?? .sarah
                        self.voiceManager.speakHandoff(
                            transitionText: self.sanitizeAssistantOutput(transitionPart),
                            sourceAgent: src,
                            agentGreeting: self.sanitizeAssistantOutput(agentPart),
                            targetAgent: response.agent
                        )
                    } else {
                        let spokenRaw = response.spokenText.isEmpty ? responseContent : response.spokenText
                        let spoken = self.sanitizeAssistantOutput(spokenRaw)
                        self.voiceManager.speak(text: spoken, for: response.agent)
                    }
                }
            }
        }
    }

    /// Construit une première version HTML locale depuis le brief rempli avec Raphaël.
    /// Elle est enregistrée dans l'espace de travail VAI ; l'ouverture du studio reste un choix explicite.
    public func completeWebsiteBrief(_ brief: WebsiteBrief) {
        activeAgent = .esther
        let html = VAICodeEngine.shared.generateWebsite(brief: brief)
        _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
        vaiCurrentCode = html
        websiteDraft = brief
        isShowingWebsiteBuilder = false

        let response = "💻 **Raphaël — première version prête**\n\nJ’ai créé la maquette locale de **\(brief.name)** : \(brief.category). Tu peux ensuite me dire ce que tu veux améliorer : les couleurs, les sections, les textes ou la mise en page.\n\n🧩 Ouvrir le Studio"
        appendMessage(Message(content: response, isFromUser: false))
        voiceManager.speak(text: "La première version de \(brief.name) est prête. Dis-moi ensuite ce que tu veux améliorer.", for: .esther)
    }
    
    private func appendMessage(_ msg: Message) {
        ensureConversation(withFirstMessage: msg.content)
        messages.append(msg)
        persistCurrentState()
        
        let convId = currentConversationId?.uuidString ?? UUID().uuidString
        let persisted = SQLiteChatDatabase.PersistedMessage(
            id: msg.id.uuidString,
            conversationId: convId,
            agentId: activeAgent.rawValue,
            sender: msg.isFromUser ? "user" : "assistant",
            content: msg.content,
            timestamp: Int64(msg.timestamp.timeIntervalSince1970 * 1000),
            isAudio: false
        )
        SQLiteChatDatabase.shared.insertMessage(persisted)
        WidgetDataBridge.shared.updateConversationCount(conversations.count)
    }
    
    private func ensureConversation(withFirstMessage text: String) {
        if currentConversationId == nil || !conversations.contains(where: { $0.id == currentConversationId }) {
            let title = aiService.generateSmartTitle(from: text)
            let newConv = Conversation(title: title)
            conversations.insert(newConv, at: 0)
            currentConversationId = newConv.id
        }
    }
    
    public func introduceSarah() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        let introText = "Bonjour ! 👋 Je suis Sarah, votre agent pilote. À mes côtés se trouvent Tom (Histoire & Géopolitique), Raphaël (Développeur & Raccourcis) et Yohan (Traducteur Français ⇄ Hébreu). Que pouvons-nous faire pour vous ?"
        let aiMessage = Message(content: introText, isFromUser: false)
        appendMessage(aiMessage)
        voiceManager.speak(text: introText, for: .sarah)
    }
    
    public func saveVoiceSettings(rate: Float, pitch: Float, vadSensitivity: Float) {
        var state = storageService.loadState()
        state.voiceSettings.speechRate = rate
        state.voiceSettings.speechPitch = pitch
        state.voiceSettings.vadSensitivity = vadSensitivity
        storageService.saveState(state)
    }
}

// MARK: - Gestion de Mémoire & Memory Vault
@available(iOS 14.0, *)
extension ChatViewModel {
    public func clearAllLearnedMemories() {
        storageService.clearAllMemories()
    }
    
    public func speakLearnedResponse(text: String) {
        TTSManager.shared.speak(text: text)
    }
    
    public func deleteLearnedMemory(trigger: String) {
        storageService.deleteMemory(forTrigger: trigger)
    }
    
    public func addLearnedMemory(trigger: String, response: String) {
        storageService.saveMemory(trigger: trigger, response: response)
    }
}
