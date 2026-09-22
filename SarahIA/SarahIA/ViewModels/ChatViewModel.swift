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
    @Published public var isContinuousConversationActive: Bool = false
    @Published public var isVoiceMicrophoneMuted: Bool = false
    
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
    @Published public var websiteRevisionCount: Int = 0
    
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

    // Identifie la réponse encore autorisée à écrire dans le chat.
    // Changer cet UUID invalide proprement un callback tardif après Stop / Nouveau chat.
    private var responseGenerationID = UUID()
    private var pendingMusicPrompt: String? = nil

    private struct PersistedWebsiteContext: Codable {
        var brief: WebsiteBrief
        var html: String
        var revisionCount: Int
    }

    private let websiteContextDefaultsKey = "SarahIA.WebsiteContexts.v1"
    
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

        // Les moteurs d'image renvoient maintenant le vrai rendu au chat au lieu
        // de laisser seulement un texte "image générée".
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedImageReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let image = notif.userInfo?["image"] as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.94) else { return }

                let prompt = (notif.userInfo?["prompt"] as? String) ?? "Image générée"
                var mediaMessage = Message(
                    content: "🎨 Image générée",
                    isFromUser: false,
                    imageData: data,
                    imageGenerationPrompt: prompt
                )
                mediaMessage.generatedImageURL = (notif.userInfo?["fileURL"] as? URL)?.absoluteString
                self.appendMessage(mediaMessage)
            }
            .store(in: &cancellables)

        // Le fichier WAV final remplace la carte de génération sans créer une
        // seconde "fausse" piste. L'URL locale reste persistée dans le fil.
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedMusicReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let url = notif.object as? URL,
                      let index = self.messages.lastIndex(where: { $0.isMusicGenerationPlaceholder }) else {
                    return
                }

                let old = self.messages[index]
                let duration = (notif.userInfo?["duration"] as? Double)
                    ?? old.detectedMusicDuration
                    ?? 20

                self.messages[index] = Message(
                    id: old.id,
                    content: "🎵 **Musique générée localement.**",
                    isFromUser: false,
                    timestamp: old.timestamp,
                    audioDuration: duration,
                    generatedMusicStyle: old.generatedMusicStyle,
                    generatedAudioURL: url.absoluteString
                )
                self.persistCurrentState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SarahMusicGenerationFailed"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let index = self.messages.lastIndex(where: { $0.isMusicGenerationPlaceholder }) else {
                    return
                }

                let old = self.messages[index]
                let error = (notif.userInfo?["error"] as? String) ?? "La génération a échoué."
                self.messages[index] = Message(
                    id: old.id,
                    content: "🎵 **Génération musicale interrompue**\n\(error)",
                    isFromUser: false,
                    timestamp: old.timestamp
                )
                self.persistCurrentState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedVideoReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let url = notif.object as? URL,
                      let index = self.messages.lastIndex(where: { $0.isVideoGenerationPlaceholder }) else {
                    return
                }

                let old = self.messages[index]
                let duration = (notif.userInfo?["duration"] as? Double)
                    ?? old.audioDuration
                    ?? 6

                self.messages[index] = Message(
                    id: old.id,
                    content: "🎬 **Vidéo générée.**",
                    isFromUser: false,
                    timestamp: old.timestamp,
                    audioDuration: duration,
                    generatedVideoURL: url.absoluteString,
                    videoGenerationPrompt: old.videoGenerationPrompt,
                    isGeneratingVideo: false
                )
                self.persistCurrentState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SarahVideoGenerationFailed"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let index = self.messages.lastIndex(where: { $0.isVideoGenerationPlaceholder }) else {
                    return
                }

                let old = self.messages[index]
                let error = (notif.userInfo?["error"] as? String)
                    ?? "La génération vidéo a échoué."

                self.messages[index] = Message(
                    id: old.id,
                    content: "🎬 **Génération vidéo interrompue**\n\(error)",
                    isFromUser: false,
                    timestamp: old.timestamp
                )
                self.persistCurrentState()
            }
            .store(in: &cancellables)
    }

    private func ensureVoicePipelinePrepared() {
        guard !isVoicePipelinePrepared else { return }
        isVoicePipelinePrepared = true

        setupVoicePipeline()

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
        restoreWebsiteContext(for: currentConversationId)
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
        voiceManager.stop()
        AIProgressiveScheduler.shared.cancelAllTasks()
        responseGenerationID = UUID()
        pendingMusicPrompt = nil
        isTyping = false
        voiceStatus = .idle
        if #available(iOS 27.0, *) {
            SarahLocalMusicGenEngine.shared.cancelCurrentGeneration()
        }
        let newSessionId = UUID()
        currentConversationId = newSessionId
        messages = []
        inputText = ""
        websiteDraft = nil
        vaiCurrentCode = nil
        websiteRevisionCount = 0
        appMode = .text
        isDrawerOpen = false
        drawerProgress = 0.0
        activeAgent = .sarah
        aiService.syncHistoryFromMessages([])
        SemanticMemoryIndex.shared.clearSessionContext()
        ConversationContext.shared.reset()
        SarahBrainEngine.shared.clearSessionHistory()
        SessionTimeoutManager.shared.recordAppBackgroundTime()
        persistCurrentState()
    }
    
    public func selectConversation(_ conv: Conversation) {
        haptics.buttonTap()
        voiceManager.stop()
        AIProgressiveScheduler.shared.cancelAllTasks()
        responseGenerationID = UUID()
        pendingMusicPrompt = nil
        isTyping = false
        voiceStatus = .idle
        if #available(iOS 27.0, *) {
            SarahLocalMusicGenEngine.shared.cancelCurrentGeneration()
        }
        currentConversationId = conv.id
        messages = conv.messages
        restoreWebsiteContext(for: conv.id)
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
        voiceManager.stop()
        AIProgressiveScheduler.shared.cancelAllTasks()
        conversations.removeAll()
        messages.removeAll()
        currentConversationId = nil
        inputText = ""
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
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isDrawerOpen = true
            drawerProgress = 1.0
        }
    }
    
    public func closeDrawer() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
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
            self?.liveTranscriptionText = partial
        }
        
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self else { return }
            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                return
            }
            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)
        }
        
        voiceManager.onSpeechStarted = { [weak self] in
            self?.isSpeaking = true
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
        
        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.voiceStatus = .idle
            self.haptics.speechFinished()
            
            if self.isContinuousConversationActive && !self.isVoiceMicrophoneMuted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard self.isContinuousConversationActive,
                          !self.isVoiceMicrophoneMuted,
                          !self.voiceManager.isSpeaking else { return }
                    AppleSpeechRecognizer.shared.startListening()
                    self.isMicRunning = AppleSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning ? .listening(level: 0.0) : .idle
                }
            }
        }
    }
    
    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if isContinuousConversationActive {
            if isVoiceMicrophoneMuted || !AppleSpeechRecognizer.shared.isListening {
                resumeVoiceMicrophone()
            } else {
                pauseVoiceMicrophone()
            }
            return
        }

        startVoiceConversation()
    }

    /// Démarre une session vocale continue. La session appartient au chat,
    /// pas à la feuille visuelle : fermer l'interface vocale ne l'arrête donc plus.
    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        if voiceManager.isSpeaking {
            voiceStatus = .speaking
            return
        }

        guard !AppleSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
    }

    /// Coupe seulement le micro tout en gardant le mode vocal actif.
    public func pauseVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        isVoiceMicrophoneMuted = true
        AppleSpeechRecognizer.shared.stopListening()
        isMicRunning = false
        micInputLevel = 0
        liveTranscriptionText = ""

        if voiceManager.isSpeaking {
            voiceStatus = .speaking
        } else {
            voiceStatus = .idle
        }
    }

    /// Réactive le micro sans recréer la session vocale.
    public func resumeVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        guard !voiceManager.isSpeaking else {
            voiceStatus = .speaking
            return
        }

        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
    }

    /// Arrête réellement le mode vocal. C'est la seule action UI qui doit
    /// faire disparaître la mini-barre vocale du chat.
    public func endVoiceConversation() {
        stopVoiceConversation(stopSpeech: true)
        isShowingVoiceOrbModal = false
    }

    public func stopVoiceConversation(stopSpeech: Bool = true) {
        isContinuousConversationActive = false
        isVoiceMicrophoneMuted = false

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
    
    public func speakMessage(_ text: String) {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        voiceManager.speak(text: text, for: activeAgent)
    }
    
    public func toggleSpeechForMessage(_ text: String) {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if voiceManager.isSpeaking {
            voiceManager.stop()
        } else {
            voiceManager.speak(text: text, for: activeAgent)
        }
    }
    
    // MARK: - Envoi de Message & Orchestration Multi-Agents
    
    /// Arrête la réponse en cours, comme le bouton carré de ChatGPT.
    /// Les moteurs qui ne savent pas être interrompus n'ont plus le droit de réinjecter
    /// leur callback dans la conversation après cette action.
    public func cancelCurrentGeneration() {
        haptics.buttonTap()
        responseGenerationID = UUID()
        isTyping = false
        voiceStatus = .idle
        AIProgressiveScheduler.shared.cancelAllTasks()

        // Retire la carte provisoire si l'utilisateur touche le carré Stop.
        if messages.contains(where: { $0.isMusicGenerationPlaceholder || $0.isVideoGenerationPlaceholder }) {
            messages.removeAll(where: {
                $0.isMusicGenerationPlaceholder || $0.isVideoGenerationPlaceholder
            })
            persistCurrentState()
        }

        if #available(iOS 27.0, *) {
            SarahLocalMusicGenEngine.shared.cancelCurrentGeneration()
        }
    }

    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        aiService.syncHistoryFromMessages(messages)
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""

        // Compétence web de Raphaël : il garde le site courant comme contexte,
        // au lieu de repartir de zéro quand l'utilisateur dit simplement
        // « améliore le site que tu as créé ».
        if WebsiteBrief.isAppleInspiredCreationRequest(text) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeAgent = .esther
            }

            let brief = WebsiteBrief.appleInspired(from: text)
            let html = VAICodeEngine.shared.generateAppleInspiredWebsite(prompt: text)
            websiteDraft = brief
            vaiCurrentCode = html
            websiteRevisionCount = 0
            _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
            saveWebsiteContext()

            appendMessage(
                Message(
                    content: "💻 **Raphaël — site premium prêt**\n\nJ’ai créé une première version inspirée des principes visuels d’Apple : grande typographie, espaces nets, surfaces Liquid Glass et animations discrètes. Tu peux maintenant me dire simplement « améliore le site », « ajoute une section », « rends-le plus animé », etc.\n\n🧩 Ouvrir le Studio",
                    isFromUser: false
                )
            )
            voiceStatus = .idle
            isTyping = false
            return
        }

        if WebsiteBrief.isRefinementRequest(text),
           let currentHTML = vaiCurrentCode,
           !currentHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeAgent = .esther
            }

            let improved = VAICodeEngine.shared.refineWebsite(
                currentHTML: currentHTML,
                brief: websiteDraft,
                instruction: text
            )
            vaiCurrentCode = improved
            websiteRevisionCount += 1
            _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: improved)
            saveWebsiteContext()

            appendMessage(
                Message(
                    content: "💻 **Raphaël — site amélioré**\n\nJ’ai repris **le site de cette discussion**, sans repartir de zéro, et appliqué ta demande. Révision **#\(websiteRevisionCount)** prête.\n\n🧩 Ouvrir le Studio",
                    isFromUser: false
                )
            )
            voiceStatus = .idle
            isTyping = false
            return
        }

        if WebsiteBrief.shouldOpenBuilder(for: text) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeAgent = .esther
            }
            appendMessage(
                Message(
                    content: "💻 **Raphaël** — Parfait. Je vais te poser quelques questions rapides, puis je génère une première maquette que je garderai en mémoire dans cette discussion.",
                    isFromUser: false
                )
            )
            voiceStatus = .idle
            isTyping = false
            isShowingWebsiteBuilder = true
            return
        }

        var routedText = text

        // Conversation musicale en deux temps : "fais-moi une petite musique"
        // -> Sarah demande 20 s / 30 s / 1 min, puis la réponse courte de l'utilisateur
        // reprend automatiquement le prompt précédent.
        if #available(iOS 27.0, *) {
            let engine = SarahLocalMusicGenEngine.shared
            let initialMusic = engine.detectIntent(text)

            if let pending = pendingMusicPrompt,
               let seconds = engine.extractRequestedSeconds(from: text) {
                routedText = "Génère une musique \(pending) de \(Int(seconds)) secondes"
                pendingMusicPrompt = nil
            } else if initialMusic.isIntent && !initialMusic.wantsLyrics && initialMusic.requestedSeconds == nil {
                pendingMusicPrompt = initialMusic.prompt
                let question = """
                🎵 **Combien de temps pour la musique ?**

                Choisis **20 secondes**, **30 secondes** ou **1 minute**.
                Je garde ton style en mémoire pendant que tu choisis.
                """
                appendMessage(Message(content: question, isFromUser: false))
                isTyping = false
                voiceStatus = .idle
                return
            } else if pendingMusicPrompt != nil && !initialMusic.isIntent {
                // Un autre sujet annule silencieusement la question de durée précédente.
                pendingMusicPrompt = nil
            }

            let routedMusic = engine.detectIntent(routedText)
            if routedMusic.isIntent,
               !routedMusic.wantsLyrics,
               let seconds = routedMusic.requestedSeconds,
               engine.isInstrumentalModelInstalled {
                let durationText = seconds >= 60 ? "1 min" : "\(Int(seconds)) s"
                let style = routedMusic.prompt.isEmpty ? "Instrumental" : routedMusic.prompt
                appendMessage(
                    Message(
                        content: "🎵 **Génération musicale en cours**\nDurée : **\(durationText)**",
                        isFromUser: false,
                        audioDuration: TimeInterval(seconds),
                        generatedMusicStyle: style
                    )
                )
            }
        }

        let videoIntent = SarahLocalVideoGenEngine.shared.detectVideoIntent(routedText)
        if videoIntent.isIntent {
            appendMessage(
                Message(
                    content: "🎬 **Génération vidéo en cours**",
                    isFromUser: false,
                    audioDuration: videoIntent.duration,
                    videoGenerationPrompt: videoIntent.prompt,
                    isGeneratingVideo: true
                )
            )
        }

        isTyping = true
        voiceStatus = .processing

        let currentSelectedAgent = activeAgent
        let responseConversationID = currentConversationId
        let requestID = UUID()
        responseGenerationID = requestID

        multiAgentCoordinator.routeAndProcess(query: routedText, currentAgent: currentSelectedAgent) { [weak self] response in
            guard let self = self else { return }

            DispatchQueue.main.async {
                guard self.currentConversationId == responseConversationID,
                      self.responseGenerationID == requestID else { return }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.activeAgent = response.agent
                }

                let rawText = response.text.isEmpty ? "[DEBUG] Le bouton fonctionne, mais le moteur IA n'a pas démarré." : response.text
                var responseContent = rawText.decodingHTMLEntities()
                if response.openStudio, response.generatedCode != nil {
                    responseContent += "\n\n🧩 La prévisualisation est prête. Ouvrir le Studio"
                }

                let aiMessage = Message(content: responseContent, isFromUser: false)
                self.appendMessage(aiMessage)
                self.isTyping = false
                self.voiceStatus = .idle

                self.aiService.recordExchange(userText: text, assistantResponse: responseContent)
                SemanticMemoryIndex.shared.indexExchange(userText: text, assistantText: responseContent, topicType: response.agent.rawValue)

                if let code = response.generatedCode {
                    self.vaiCurrentCode = code
                }

                if let transitionPart = response.handoffSarahTransition, let agentPart = response.handoffAgentGreeting {
                    let src = response.handoffSourceAgent ?? .sarah
                    self.voiceManager.speakHandoff(
                        transitionText: transitionPart.decodingHTMLEntities(),
                        sourceAgent: src,
                        agentGreeting: agentPart.decodingHTMLEntities(),
                        targetAgent: response.agent
                    )
                } else {
                    let spoken = (response.spokenText.isEmpty ? responseContent : response.spokenText).decodingHTMLEntities()
                    self.voiceManager.speak(text: spoken, for: response.agent)
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
        websiteRevisionCount = 0
        saveWebsiteContext()
        isShowingWebsiteBuilder = false

        let response = "💻 **Raphaël — première version prête**\n\nJ’ai créé la maquette locale de **\(brief.name)** : \(brief.category). Tu peux ensuite me dire ce que tu veux améliorer : les couleurs, les sections, les textes ou la mise en page.\n\n🧩 Ouvrir le Studio"
        appendMessage(Message(content: response, isFromUser: false))
        voiceManager.speak(text: "La première version de \(brief.name) est prête. Dis-moi ensuite ce que tu veux améliorer.", for: .esther)
    }
    
    private func saveWebsiteContext() {
        guard let conversationID = currentConversationId,
              let brief = websiteDraft,
              let html = vaiCurrentCode,
              !html.isEmpty else { return }

        var contexts = loadWebsiteContexts()
        contexts[conversationID.uuidString] = PersistedWebsiteContext(
            brief: brief,
            html: html,
            revisionCount: websiteRevisionCount
        )

        if let data = try? JSONEncoder().encode(contexts) {
            UserDefaults.standard.set(data, forKey: websiteContextDefaultsKey)
        }
    }

    private func restoreWebsiteContext(for conversationID: UUID?) {
        guard let conversationID else {
            websiteDraft = nil
            vaiCurrentCode = nil
            websiteRevisionCount = 0
            return
        }

        let contexts = loadWebsiteContexts()
        if let context = contexts[conversationID.uuidString] {
            websiteDraft = context.brief
            vaiCurrentCode = context.html
            websiteRevisionCount = context.revisionCount
        } else {
            websiteDraft = nil
            vaiCurrentCode = nil
            websiteRevisionCount = 0
        }
    }

    private func loadWebsiteContexts() -> [String: PersistedWebsiteContext] {
        guard let data = UserDefaults.standard.data(forKey: websiteContextDefaultsKey),
              let contexts = try? JSONDecoder().decode(
                [String: PersistedWebsiteContext].self,
                from: data
              ) else {
            return [:]
        }
        return contexts
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
