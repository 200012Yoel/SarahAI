import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit

/// Mode d'affichage actif de l'application Sarah AI
public enum AppMode: String, Codable {
    case text
}

/// État de la boucle vocale en direct
public enum VoiceInteractionStatus: Equatable {
    case idle
    case starting
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
    @Published public var websiteVoiceCommand: String = ""
    @Published public var websiteVoiceCommandSequence: Int = 0
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
    private var shouldResumeVoiceAfterSystemInterruption = false
    private var websiteGenerationID = UUID()
    private var isBargeInMonitorActive = false
    
    public init() {
        restorePersistedState()
        setupModeObserver()
        bindCoreServices()
    }


    public func appendVisionAnalysis(image: UIImage, result: LocalVisionEngine.VisionAnalysisResult) {
        let imageData = image.jpegData(compressionQuality: 0.88)
        let textSuffix = result.detectedText.isEmpty ? "" : "\n\n📝 **Texte détecté** : \(result.detectedText)"
        appendMessage(
            Message(
                content: "👁️ **Vision locale**\n\n\(result.naturalSpokenResponse)\(textSuffix)",
                isFromUser: false,
                imageData: imageData
            )
        )
    }

    public func appendImportedFile(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent.isEmpty ? "Fichier" : url.lastPathComponent
        do {
            let data = try Data(contentsOf: url)
            let previewData = data.prefix(24_000)
            let preview = String(data: previewData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var content = "📎 **Fichier ajouté : \(name)**"
            if let preview, !preview.isEmpty {
                content += "\n\n```\n\(String(preview.prefix(8_000)))\n```"
            }
            appendMessage(Message(content: content, isFromUser: true))
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = "Analyse le fichier \(name)"
            }
        } catch {
            inputText = "Impossible d'ouvrir \(name) : \(error.localizedDescription)"
        }
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


        NotificationCenter.default.publisher(for: NSNotification.Name("WhisperSpeechRecognizerStateChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                switch WhisperSpeechRecognizer.shared.state {
                case .idle:
                    if self.isTyping {
                        self.voiceStatus = .processing
                    } else if self.isContinuousConversationActive,
                       !self.isVoiceMicrophoneMuted,
                       !self.voiceManager.isSpeaking,
                       !WhisperSpeechRecognizer.shared.isListening {
                        self.voiceStatus = .idle
                    }
                case .listening:
                    self.isMicRunning = true
                    self.voiceStatus = .listening(level: self.micInputLevel)
                case .processing:
                    self.voiceStatus = .processing
                case .error(let message):
                    self.isMicRunning = false
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
        voiceManager.stop()
        AIProgressiveScheduler.shared.cancelAllTasks()
        let newSessionId = UUID()
        currentConversationId = newSessionId
        messages = []
        inputText = ""
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
    
    // MARK: - Pipeline Vocale Whisper & Multi-Agents
    
    private func setupVoicePipeline() {
        WhisperSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            self?.liveTranscriptionText = partial
        }
        
        WhisperSpeechRecognizer.shared.onVoiceActivity = { [weak self] in
            guard let self = self,
                  self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted,
                  self.isBargeInMonitorActive,
                  self.voiceManager.isSpeaking else { return }

            // AVAudioSession .voiceChat fournit l'annulation d'écho. Dès qu'une
            // vraie voix traverse le VAD Whisper, Sarah s'arrête immédiatement,
            // mais Whisper continue d'enregistrer la nouvelle phrase utilisateur.
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.isBargeInMonitorActive = false
            self.voiceManager.stop()
            self.isSpeaking = false
            self.voiceStatus = .listening(level: self.micInputLevel)
        }

        WhisperSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self else { return }
            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                return
            }
            self.liveTranscriptionText = ""
            if self.voiceManager.isSpeaking {
                self.isBargeInMonitorActive = false
                self.voiceManager.stop()
                self.isSpeaking = false
            }
            self.sendMessage(cleaned)
        }
        
        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.voiceStatus = .speaking
            self.haptics.speechStarted()

            guard self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted else {
                self.isBargeInMonitorActive = false
                self.isMicRunning = false
                return
            }

            self.isBargeInMonitorActive = true
            AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
            if !WhisperSpeechRecognizer.shared.isListening {
                WhisperSpeechRecognizer.shared.startListening(
                    autoFinalizeOnSilence: true,
                    preserveActiveSpeech: true
                )
            }
            self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
        }
        
        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            let finishedWithoutBargeIn = self.isBargeInMonitorActive
            self.isBargeInMonitorActive = false

            guard self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted else {
                self.voiceStatus = .idle
                return
            }

            if finishedWithoutBargeIn {
                // Sarah a fini normalement. On jette le tampon utilisé uniquement
                // pour surveiller une interruption afin qu'aucun résidu d'écho ne
                // devienne un faux message, puis on repart sur une capture propre.
                WhisperSpeechRecognizer.shared.stopListening()
                self.isMicRunning = false
                self.voiceStatus = .starting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard self.isContinuousConversationActive,
                          !self.isVoiceMicrophoneMuted,
                          !self.voiceManager.isSpeaking else { return }
                    WhisperSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true,
                        preserveActiveSpeech: true
                    )
                    self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .starting
                }
            } else {
                // Barge-in : Whisper est déjà en train d'enregistrer l'utilisateur.
                self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
                self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .starting
            }
        }
    }
    
    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if isMicRunning || WhisperSpeechRecognizer.shared.isListening {
            isVoiceMicrophoneMuted = true
            WhisperSpeechRecognizer.shared.stopListening()
            isMicRunning = false
            micInputLevel = 0
            voiceStatus = .idle
            return
        }

        isVoiceMicrophoneMuted = false
        isContinuousConversationActive = true
        AudioSessionManager.shared.beginContinuousVoiceSession()
        WhisperSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: true
        )
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = voiceManager.isSpeaking
            ? .speaking
            : (isMicRunning ? .listening(level: micInputLevel) : .starting)
    }

    /// Démarre explicitement une session vocale continue.
    /// Utilisé par le plein écran vocal pour éviter les doubles démarrages.
    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()
        voiceManager.stop()
        AudioSessionManager.shared.beginContinuousVoiceSession()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
        isBargeInMonitorActive = false

        guard !WhisperSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        WhisperSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: true
        )
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: 0.0) : .starting
    }

    /// Coupe complètement le mode vocal et rend la session audio à iOS.
    /// Cette méthode doit être appelée à chaque fermeture de l'écran vocal,
    /// même si Sarah est en train de parler et que le micro est déjà arrêté.
    public func stopVoiceConversation(stopSpeech: Bool = true) {
        isContinuousConversationActive = false
        isVoiceMicrophoneMuted = false
        isBargeInMonitorActive = false
        isBargeInMonitorActive = false

        // Couper d'abord la synthèse, puis la capture micro. Dans l'ordre inverse,
        // la session AVAudioSession pouvait rester active si Sarah parlait encore.
        if stopSpeech {
            voiceManager.stop()
        }

        WhisperSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.endContinuousVoiceSession()

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
    
    public func cancelCurrentGeneration() {
        haptics.buttonTap()
        isTyping = false
        voiceStatus = .idle
        AIProgressiveScheduler.shared.cancelAllTasks()
    }

    // MARK: - Envoi de Message & Orchestration Multi-Agents
    
    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        aiService.syncHistoryFromMessages(messages)
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
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
                : "💻 **Raphaël** — Parfait. Je vais te poser quelques questions rapides, puis je génère le site à partir de tes réponses. Aucun site par défaut ne sera utilisé."
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
                
                let rawText = response.text.isEmpty ? "[DEBUG] Le bouton fonctionne, mais le moteur IA n'a pas démarré." : response.text
                var responseContent = rawText.decodingHTMLEntities()
                if response.openStudio, response.generatedCode != nil {
                    responseContent += "\n\n🧩 La prévisualisation est prête. Ouvrir le Studio"
                }
                let aiMessage = Message(content: responseContent, isFromUser: false)
                self.appendMessage(aiMessage)
                self.isTyping = false
                self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle
                
                // Enregistrer l'échange pour maintenir le fil contextuel (mémoire court terme)
                self.aiService.recordExchange(userText: text, assistantResponse: responseContent)
                SemanticMemoryIndex.shared.indexExchange(userText: text, assistantText: responseContent, topicType: response.agent.rawValue)
                
                // Si Raphaël a généré du code, il prépare le studio mais ne l'ouvre jamais
                // de force. L'utilisateur reste dans le chat et choisit lui-même d'ouvrir le rendu.
                if let code = response.generatedCode {
                    self.vaiCurrentCode = code
                }
                
                let shouldSpeakAutomatically = self.isContinuousConversationActive
                if shouldSpeakAutomatically {
                    if let transitionPart = response.handoffSarahTransition,
                       let agentPart = response.handoffAgentGreeting {
                        let src = response.handoffSourceAgent ?? .sarah
                        self.voiceManager.speakHandoff(
                            transitionText: transitionPart.decodingHTMLEntities(),
                            sourceAgent: src,
                            agentGreeting: agentPart.decodingHTMLEntities(),
                            targetAgent: response.agent
                        )
                    } else {
                        let spoken = (response.spokenText.isEmpty ? responseContent : response.spokenText)
                            .decodingHTMLEntities()
                        self.voiceManager.speak(text: spoken, for: response.agent)
                    }
                }
            }
        }
    }

    /// Génère le site uniquement avec le véritable pipeline de modèles de code.
    /// L'ancien faux chemin « modèle local téléchargé -> réponse déterministe » est supprimé.
    public func completeWebsiteBrief(_ brief: WebsiteBrief) {
        let isRefinement = websiteDraft != nil && vaiCurrentCode != nil
        activeAgent = .esther
        websiteDraft = brief
        isShowingWebsiteBuilder = false
        isTyping = true
        voiceStatus = .processing

        if !isRefinement {
            vaiCurrentCode = nil
            VAICodeEngine.shared.resetCurrentWebProject()
        }

        let generationID = UUID()
        websiteGenerationID = generationID
        let prompt = realWebsitePrompt(for: brief, isRefinement: isRefinement)

        appendMessage(Message(
            content: "💻 **Raphaël · génération réelle en cours**\n\nJe transmets ton brief au moteur de code. Aucun dashboard, aucune page type et aucun asset de secours ne seront utilisés.",
            isFromUser: false
        ))

        if isContinuousConversationActive {
            speakWebsiteGuide("J'ai tout le brief. Je lance le vrai moteur de code. Tu peux continuer à me parler et m'interrompre.")
        }

        VAICodeEngine.shared.buildAndTestWebsite(prompt: prompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.websiteGenerationID == generationID else { return }
                self.isTyping = false
                self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle

                switch result {
                case .success(let build):
                    self.vaiCurrentCode = build.html
                    self.websiteDraft = brief
                    _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: build.html)

                    let audit = build.browserAudit?.details ?? "WebKit validé"
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · site réellement généré**\n\n**\(brief.name)** a été écrit par le moteur de code à partir de ton brief, puis contrôlé dans WebKit.\n\nContrôle : \(audit)\nRévision : #\(build.revision)\n\n🧩 Ouvrir le Studio",
                        isFromUser: false
                    ))

                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "Le site \(brief.name) est réellement généré et vérifié. Tu peux ouvrir le Studio ou me demander de le modifier.",
                            for: .esther
                        )
                    }

                case .failure(let error):
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · génération réelle indisponible**\n\n\(error.localizedDescription)\n\nAucun faux site n'a été créé à la place.",
                        isFromUser: false
                    ))
                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "La vraie génération n'a pas pu démarrer. Je n'ai créé aucun faux site. Vérifie le moteur de code dans les réglages Sarah Engine.",
                            for: .esther
                        )
                    }
                }
            }
        }
    }

    private func realWebsitePrompt(for brief: WebsiteBrief, isRefinement: Bool) -> String {
        let sectionList = brief.sections.joined(separator: ", ")
        let operation = isRefinement
            ? "MODIFICATION : repars du projet existant et applique ce nouveau brief sans casser les fonctions valides."
            : "NOUVEAU PROJET : conçois et écris le site depuis zéro."

        return """
        \(operation)

        BRIEF
        Type : \(brief.category)
        Nom : \(brief.name)
        Objectif : \(brief.purpose)
        Public : \(brief.audience)
        Direction graphique : \(brief.visualStyle)
        Accent : \(brief.accent)
        Sections : \(sectionList)

        CONTRAT STRICT
        - Écris un site réellement spécifique à ce brief, pas une variante de template.
        - Retourne uniquement un document HTML5 complet avec CSS et JavaScript intégrés.
        - Aucun dashboard générique, lorem ipsum, Produit 01, Offre 01 ou bloc préfabriqué.
        - Aucun CDN, police distante, logo de marque, asset propriétaire ou URL d'image factice.
        - Le style nommé est une inspiration de principes graphiques, pas une copie de la marque.
        - Les interactions utiles au type de site doivent fonctionner réellement côté navigateur.
        - N'invente pas de backend, paiement ou publication serveur si cela n'existe pas.
        - Responsive iPhone/tablette/ordinateur, accessible et utilisable hors ligne dans WKWebView.
        """
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
        let introText = "Bonjour ! 👋 Je suis Sarah, votre agent pilote. À mes côtés se trouvent Tom (Histoire & Géopolitique), Raphaël (Développeur & Code) et Yohan (Traducteur Français ⇄ Hébreu). Que pouvons-nous faire pour vous ?"
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
