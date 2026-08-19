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
        ttsService.$isSpeaking
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
            
        ttsService.$currentSpokenText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.currentSpeakingText = text
            }
            .store(in: &cancellables)
            
        audioEngine.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isMicRunning = running
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
    
    // MARK: - Pipeline Vocal Full-Duplex & Barge-In
    
    private func setupVoicePipeline() {
        audioEngine.onAudioBufferCaptured = { [weak self] buffer in
            self?.whisperService.appendAudioBuffer(buffer)
        }
        
        audioEngine.onVoiceActivityChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .idle:
                self.voiceStatus = .idle
                self.micInputLevel = 0.0
            case .listening(let amplitude):
                self.micInputLevel = amplitude
                if !self.ttsService.isSpeaking && self.voiceStatus != .processing {
                    self.voiceStatus = .listening(level: amplitude)
                }
            case .userSpeaking(let amplitude):
                self.micInputLevel = amplitude
                if self.voiceStatus != .processing {
                    self.voiceStatus = .listening(level: amplitude)
                }
            case .bargeInDetected:
                print("⚡ [ChatViewModel] Interruption détectée! Arrêt immédiat de la parole de Sarah.")
                self.haptics.bargeIn()
                self.ttsService.stopSpeaking()
                self.whisperService.startTranscription()
                self.voiceStatus = .listening(level: self.micInputLevel)
            case .silenceDetected:
                if self.whisperService.status == .listening {
                    self.whisperService.stopTranscription()
                }
            }
        }
        
        whisperService.onPartialTranscription = { [weak self] partial in
            self?.liveTranscriptionText = partial
        }
        
        whisperService.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self else { return }
            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                return
            }
            
            self.liveTranscriptionText = ""
            self.handleUserSpeechInput(cleaned)
        }
        
        ttsService.onSpeechStarted = { [weak self] in
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
        
        ttsService.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.voiceStatus = .idle
            self.haptics.speechFinished()
            if self.appMode == .avatar {
                self.whisperService.startTranscription()
            }
        }
        
        ttsService.onSpeechInterrupted = { [weak self] in
            self?.voiceStatus = .idle
        }
    }
    
    public func toggleMicrophone() {
        haptics.buttonTap()
        if audioEngine.isRunning {
            audioEngine.stopAudioEngine()
            whisperService.stopTranscription()
            voiceStatus = .idle
        } else {
            audioEngine.requestPermissionAndStart { [weak self] granted in
                guard let self = self, granted else { return }
                self.whisperService.startTranscription()
                self.voiceStatus = .listening(level: 0.0)
            }
        }
    }
    
    public func startFullDuplexVoiceMode() {
        audioEngine.requestPermissionAndStart { [weak self] granted in
            guard let self = self, granted else { return }
            self.whisperService.startTranscription()
            self.voiceStatus = .listening(level: 0.0)
        }
    }
    
    public func stopVoiceMode() {
        whisperService.stopTranscription()
        audioEngine.stopAudioEngine()
        ttsService.stopSpeaking()
        voiceStatus = .idle
    }
    
    // MARK: - Écoute et Lecture Vocale des Messages (TTS)
    
    public func speakMessage(_ text: String) {
        haptics.buttonTap()
        ttsService.speak(text: text)
    }
    
    public func toggleSpeechForMessage(_ text: String) {
        haptics.buttonTap()
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        if ttsService.isSpeaking && ttsService.currentSpokenText == cleaned {
            ttsService.stopSpeaking()
        } else {
            ttsService.speak(text: text)
        }
    }
    
    public func introduceSarah() {
        haptics.buttonTap()
        let introText = "Bonjour ! 👋 Je m'appelle Sarah, votre assistante IA 3D en temps réel. Je suis conçue pour converser avec vous par la voix ou par écrit, répondre à vos questions, et mémoriser nos échanges. N'hésitez pas à me parler librement !"
        let aiMessage = Message(content: introText, isFromUser: false)
        appendMessage(aiMessage)
        ttsService.speak(text: introText)
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
            self.ttsService.speak(text: response)
            self.endAIBgTask()
        }
    }
    
    public func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
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
            self.ttsService.speak(text: response)
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
