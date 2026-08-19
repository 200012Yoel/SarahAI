import Foundation
import SwiftUI
import Combine
import AVFoundation

/// Mode d'affichage actif de l'application Sarah AI
public enum AppMode: String, Codable {
    case avatar
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

/// ViewModel principal orchestrant le mode Avatar 3D, le mode Texte, le tiroir de discussions multiples, le Whisper VAD, le TTS et la persistance.
@MainActor
public final class ChatViewModel: ObservableObject {
    
    // MARK: - Published UI State
    @Published public var appMode: AppMode = .avatar
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
    
    // MARK: - Navigation Tiroir & Recherche
    @Published public var isDrawerOpen: Bool = false
    @Published public var drawerProgress: CGFloat = 0.0 // 0.0 à 1.0 pour animation fluide au geste
    @Published public var searchQuery: String = ""
    @Published public var isSearchActive: Bool = false
    
    // MARK: - Services
    private let aiService = AIService.shared
    private let notificationService = NotificationService.shared
    private let storageService = StorageService.shared
    private let audioEngine = AudioEngineManager.shared
    private let whisperService = WhisperService.shared
    private let ttsService = TTSService.shared
    private let haptics = HapticService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var stateSaveDebounceTimer: Timer?
    
    public init() {
        restorePersistedState()
        setupVoicePipeline()
        setupModeObserver()
        bindServices()
    }
    
    // MARK: - Liaison des Services
    
    private func bindServices() {
        SpeechManager.shared.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                self?.isSpeaking = speaking
                if speaking {
                    self?.voiceStatus = .speaking
                } else if self?.voiceStatus == .speaking {
                    self?.voiceStatus = .idle
                }
            }
            .store(in: &cancellables)
            
        SpeechManager.shared.$currentSpokenText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.currentSpeakingText = text
            }
            .store(in: &cancellables)
            
        AppleSpeechRecognizer.shared.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isMicRunning = listening
                if listening {
                    self?.voiceStatus = .listening(level: 0.5)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistance des Données & Restauration
    
    /// Restaure l'ensemble des discussions et l'état depuis le stockage local
    private func restorePersistedState() {
        let savedState = storageService.loadState()
        
        self.learnedMemories = savedState.learnedMemories
        self.conversations = savedState.conversations
        
        if let mode = AppMode(rawValue: savedState.activeMode) {
            self.appMode = mode
        } else {
            self.appMode = .avatar
        }
        
        if let currentId = savedState.currentConversationId,
           let existing = self.conversations.first(where: { $0.id == currentId }) {
            self.currentConversationId = existing.id
            self.messages = existing.messages
        } else if let first = self.conversations.first {
            self.currentConversationId = first.id
            self.messages = first.messages
        } else if !savedState.messages.isEmpty {
            let initialConv = Conversation(title: "Nouvelle discussion", messages: savedState.messages)
            self.conversations = [initialConv]
            self.currentConversationId = initialConv.id
            self.messages = initialConv.messages
        } else {
            // Aucun message -> Liste vierge prête
            self.conversations = []
            self.currentConversationId = nil
            self.messages = []
        }
    }
    
    /// Sauvegarde l'état courant de l'application
    public func persistCurrentState() {
        // Mettre à jour la conversation active si existante
        if let currentId = currentConversationId,
           let index = conversations.firstIndex(where: { $0.id == currentId }) {
            conversations[index].messages = messages
            conversations[index].updatedAt = Date()
        }
        
        let existing = storageService.loadState()
        let state = AppPersistedState(
            activeMode: appMode.rawValue,
            conversations: conversations,
            currentConversationId: currentConversationId,
            messages: messages,
            lastActiveTimestamp: Date(),
            voiceSettings: existing.voiceSettings,
            learnedMemories: self.learnedMemories,
            pendingLearningTrigger: existing.pendingLearningTrigger
        )
        storageService.saveState(state)
        
        // Synchronisation en temps réel des statistiques vers les Widgets iOS
        let lastMemoryTuple: (trigger: String, response: String)? = self.learnedMemories.first.map { ($0.key, $0.value) }
        SarahWidgetBridge.shared.syncStats(
            conversationsCount: self.conversations.count,
            messagesCount: self.messages.count,
            memoriesCount: self.learnedMemories.count,
            lastMemory: lastMemoryTuple,
            lastMessage: self.messages.last?.content
        )
    }
    
    // MARK: - Gestion des Discussions (Sidebar)
    
    public var filteredPinnedConversations: [Conversation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return conversations.filter { $0.isPinned && !$0.isArchived }
            .filter { query.isEmpty || $0.title.lowercased().contains(query) }
    }
    
    public var filteredRecentConversations: [Conversation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return conversations.filter { !$0.isPinned && !$0.isArchived }
            .filter { query.isEmpty || $0.title.lowercased().contains(query) }
    }
    
    public func startNewChat() {
        haptics.buttonTap()
        ttsService.stopSpeaking()
        currentConversationId = nil
        messages = []
        inputText = ""
        appMode = .text
        isDrawerOpen = false
        drawerProgress = 0.0
    }
    
    public func selectConversation(_ conv: Conversation) {
        haptics.buttonTap()
        ttsService.stopSpeaking()
        currentConversationId = conv.id
        messages = conv.messages
        appMode = .text
        isDrawerOpen = false
        drawerProgress = 0.0
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
        conversations.removeAll(where: { $0.id == conv.id })
        if currentConversationId == conv.id {
            if let next = conversations.first {
                selectConversation(next)
            } else {
                startNewChat()
            }
        }
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
    
    // MARK: - Tiroir Latéral (Drawer)
    
    public func toggleDrawer() {
        haptics.buttonTap()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isDrawerOpen.toggle()
            drawerProgress = isDrawerOpen ? 1.0 : 0.0
        }
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
    
    // MARK: - Gestion des Modes d'Affichage
    
    private func setupModeObserver() {
        $appMode
            .sink { [weak self] newMode in
                guard let self = self else { return }
                self.persistCurrentState()
                self.haptics.modeToggled()
                
                if newMode == .avatar {
                    self.audioEngine.requestPermissionAndStart { granted in
                        if granted {
                            self.whisperService.startTranscription()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func switchToAvatar() {
        haptics.buttonTap()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            appMode = .avatar
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
    
    public func toggleMode() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            appMode = (appMode == .avatar) ? .text : .avatar
        }
    }
    
    // MARK: - Mode Conversationnel Continu (100% Gratuit & Local Apple Speech)
    
    private func setupVoicePipeline() {
        // 1. Liaison de la transcription en direct
        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            self?.liveTranscriptionText = partial
        }
        
        // 2. Validation automatique de la phrase par détection de silence
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self else { return }
            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                return
            }
            
            self.liveTranscriptionText = ""
            self.handleUserSpeechInput(cleaned)
        }
        
        // 3. Liaison de l'énergie micro pour ondelettes audio
        AppleSpeechRecognizer.shared.$micEnergyLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.micInputLevel = level
            }
            .store(in: &cancellables)
            
        AppleSpeechRecognizer.shared.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isMicRunning = listening
                if listening {
                    self?.voiceStatus = .listening(level: 0.5)
                } else if self?.voiceStatus != .speaking && self?.voiceStatus != .processing {
                    self?.voiceStatus = .idle
                }
            }
            .store(in: &cancellables)
        
        // 4. Événements SpeechManager (Synthèse Vocale Sarah)
        SpeechManager.shared.onSpeechStarted = { [weak self] in
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
        
        SpeechManager.shared.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.voiceStatus = .idle
            self.haptics.speechFinished()
            
            // 🔄 BOUCLE CONVERSATIONNELLE CONTINUE : Réactivation automatique du micro
            if self.isContinuousConversationActive || self.appMode == .avatar {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if !SpeechManager.shared.isSpeaking {
                        AppleSpeechRecognizer.shared.startListening()
                        self.isMicRunning = true
                        self.voiceStatus = .listening(level: 0.0)
                    }
                }
            }
        }
        
        SpeechManager.shared.onSpeechInterrupted = { [weak self] in
            self?.voiceStatus = .idle
        }
        
        // 5. Coupure automatique du micro et de la voix si Siri ou un appel se déclenche
        AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
            print("🔇 [ChatViewModel] Siri ou appel détecté : Coupure immédiate du micro et de la parole de Sarah.")
            self?.stopVoiceMode()
        }
    }
    
    /// Bascule le microphone / mode conversationnel continu (1 seul appui pour converser librement)
    public func toggleMicrophone() {
        haptics.buttonTap()
        if isMicRunning || AppleSpeechRecognizer.shared.isListening {
            isContinuousConversationActive = false
            AppleSpeechRecognizer.shared.stopListening()
            isMicRunning = false
            voiceStatus = .idle
        } else {
            SpeechManager.shared.stopSpeaking()
            isContinuousConversationActive = true
            AppleSpeechRecognizer.shared.requestPermissions { [weak self] ready in
                guard let self = self, ready else { return }
                AppleSpeechRecognizer.shared.startListening()
                self.isMicRunning = true
                self.voiceStatus = .listening(level: 0.5)
                self.haptics.speechStarted()
            }
        }
    }
    
    public func startFullDuplexVoiceMode() {
        isContinuousConversationActive = true
        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = true
        voiceStatus = .listening(level: 0.5)
    }
    
    public func stopVoiceMode() {
        isContinuousConversationActive = false
        AppleSpeechRecognizer.shared.stopListening()
        SpeechManager.shared.stopSpeaking()
        isMicRunning = false
        voiceStatus = .idle
    }
    
    // MARK: - Écoute et Lecture Vocale des Messages (TTS)
    
    public func speakMessage(_ text: String) {
        haptics.buttonTap()
        SpeechManager.shared.speak(text: text)
    }
    
    public func toggleSpeechForMessage(_ text: String) {
        haptics.buttonTap()
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        if SpeechManager.shared.isSpeaking && SpeechManager.shared.currentSpokenText == cleaned {
            SpeechManager.shared.stopSpeaking()
        } else {
            SpeechManager.shared.speak(text: text)
        }
    }
    
    public func introduceSarah() {
        haptics.buttonTap()
        let introText = "Bonjour ! 👋 Je m'appelle Sarah, votre assistante IA 3D en temps réel. Je suis conçue pour converser avec vous par la voix ou par écrit, répondre à vos questions, et mémoriser nos échanges. N'hésitez pas à me parler librement !"
        let aiMessage = Message(content: introText, isFromUser: false)
        appendMessage(aiMessage)
        SpeechManager.shared.speak(text: introText)
    }
    
    // MARK: - Traitement des Messages
    
    private func generateTitle(from text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 34 {
            return String(cleaned.prefix(34)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return cleaned.isEmpty ? "Nouvelle discussion" : cleaned
    }
    
    private func ensureConversation(withFirstMessage text: String) {
        if currentConversationId == nil || !conversations.contains(where: { $0.id == currentConversationId }) {
            let title = generateTitle(from: text)
            let newConv = Conversation(title: title)
            conversations.insert(newConv, at: 0)
            currentConversationId = newConv.id
        }
    }
    
    private func appendMessage(_ msg: Message) {
        ensureConversation(withFirstMessage: msg.content)
        messages.append(msg)
        persistCurrentState()
    }
    
    private var aiProcessingBgTask: UIBackgroundTaskIdentifier = .invalid
    
    private func beginAIBgTask() {
        if aiProcessingBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(aiProcessingBgTask)
        }
        aiProcessingBgTask = UIApplication.shared.beginBackgroundTask(withName: "SarahAI_Processing") { [weak self] in
            if let task = self?.aiProcessingBgTask, task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
                self?.aiProcessingBgTask = .invalid
            }
        }
    }
    
    private func endAIBgTask() {
        if aiProcessingBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(aiProcessingBgTask)
            aiProcessingBgTask = .invalid
        }
    }
    
    private func handleUserSpeechInput(_ transcription: String) {
        let userMessage = Message(content: transcription, isFromUser: true)
        appendMessage(userMessage)
        
        voiceStatus = .processing
        isTyping = true
        beginAIBgTask()
        
        Task {
            let response = await aiService.generateResponse(for: transcription)
            self.refreshLearnedMemories()
            
            let aiMessage = Message(content: response, isFromUser: false)
            self.appendMessage(aiMessage)
            self.isTyping = false
            
            self.sendNotificationIfNeeded(message: response)
            SpeechManager.shared.speak(text: response)
            self.endAIBgTask()
        }
    }
    
    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""
        
        isTyping = true
        beginAIBgTask()
        
        Task {
            let response = await aiService.generateResponse(for: text)
            self.refreshLearnedMemories()
            
            let aiMessage = Message(content: response, isFromUser: false)
            self.appendMessage(aiMessage)
            self.isTyping = false
            
            self.sendNotificationIfNeeded(message: response)
            SpeechManager.shared.speak(text: response)
            self.endAIBgTask()
        }
    }
    
    public func sendQuickSuggestion(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "Présente-toi" || trimmed == "Qui es-tu ?" || trimmed.contains("présentation") {
            introduceSarah()
        } else {
            inputText = text
        }
    }
    
    // MARK: - Mémoire Apprise
    
    public func refreshLearnedMemories() {
        self.learnedMemories = storageService.loadState().learnedMemories
    }
    
    public func addLearnedMemory(trigger: String, response: String) {
        var state = storageService.loadState()
        state.learnedMemories[trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] = response
        storageService.saveState(state)
        self.learnedMemories = state.learnedMemories
    }
    
    public func deleteLearnedMemory(trigger: String) {
        var state = storageService.loadState()
        state.learnedMemories.removeValue(forKey: trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        storageService.saveState(state)
        self.learnedMemories = state.learnedMemories
    }
    
    public func clearAllLearnedMemories() {
        var state = storageService.loadState()
        state.learnedMemories.removeAll()
        storageService.saveState(state)
        self.learnedMemories = [:]
    }
    
    public func speakLearnedResponse(text: String) {
        ttsService.speak(text: text)
    }
    
    // MARK: - Réglages Vocaux
    
    public func saveVoiceSettings(rate: Float, pitch: Float, vadSensitivity: Float) {
        var state = storageService.loadState()
        state.voiceSettings.speechRate = rate
        state.voiceSettings.speechPitch = pitch
        state.voiceSettings.vadSensitivity = vadSensitivity
        storageService.saveState(state)
    }
    
    public func testVoiceSettings(rate: Float, pitch: Float) {
        ttsService.speak(
            text: "Bonjour ! Ceci est un aperçu de mes réglages vocaux personnalisés.",
            rate: rate,
            pitch: pitch
        )
    }
    
    public func sendBackgroundTest() {
        let testMessage = Message(
            content: "🔔 Test en arrière-plan lancé ! Minimisez l'app maintenant pour tester la voix et les notifications.",
            isFromUser: false
        )
        appendMessage(testMessage)
        isTyping = true
        
        Task {
            let response = await aiService.generateBackgroundTestResponse()
            let aiMessage = Message(content: response, isFromUser: false)
            self.appendMessage(aiMessage)
            self.isTyping = false
            
            self.notificationService.sendResponseNotification(message: response)
            self.ttsService.speak(text: response)
        }
    }
    
    private func sendNotificationIfNeeded(message: String) {
        let state = UIApplication.shared.applicationState
        if state != .active {
            notificationService.sendResponseNotification(message: message)
        }
    }
}
