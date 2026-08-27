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
    
    // MARK: - Navigation, Studio VAI Coding & Voice Orb
    @Published public var isDrawerOpen: Bool = false
    @Published public var drawerProgress: CGFloat = 0.0
    @Published public var searchQuery: String = ""
    @Published public var isSearchActive: Bool = false
    @Published public var isShowingVoiceOrbModal: Bool = false
    @Published public var isShowingVAICodingStudio: Bool = false
    @Published public var vaiCurrentCode: String? = nil
    
    public var isGeneratingResponse: Bool {
        get { isTyping }
        set { isTyping = newValue }
    }
    
    // MARK: - Services
    private let aiService = AIService.shared
    private let notificationService = NotificationService.shared
    private let storageService = StorageService.shared
    private let multiAgentCoordinator = MultiAgentCoordinator.shared
    private let voiceManager = MultiAgentVoiceManager.shared
    private let haptics = HapticService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        restorePersistedState()
        setupVoicePipeline()
        setupModeObserver()
        bindServices()
    }
    
    // MARK: - Liaison des Services
    
    private func bindServices() {
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
        aiService.syncHistoryFromMessages(self.messages)
    }
    
    public func persistCurrentState() {
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
    }
    
    // MARK: - Discussions & Tiroir Latéral
    
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
        voiceManager.stop()
        AIProgressiveScheduler.shared.cancelAllTasks()
        currentConversationId = nil
        messages = []
        inputText = ""
        appMode = .text
        isDrawerOpen = false
        drawerProgress = 0.0
        activeAgent = .sarah
        aiService.syncHistoryFromMessages([])
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
            
            if self.isContinuousConversationActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if !self.voiceManager.isSpeaking {
                        AppleSpeechRecognizer.shared.startListening()
                        self.isMicRunning = true
                        self.voiceStatus = .listening(level: 0.0)
                    }
                }
            }
        }
    }
    
    public func toggleMicrophone() {
        haptics.buttonTap()
        if isMicRunning || AppleSpeechRecognizer.shared.isListening {
            isContinuousConversationActive = false
            AppleSpeechRecognizer.shared.stopListening()
            isMicRunning = false
            voiceStatus = .idle
        } else {
            voiceManager.stop()
            isContinuousConversationActive = true
            AppleSpeechRecognizer.shared.startListening()
            self.isMicRunning = true
            self.voiceStatus = .listening(level: 0.5)
            self.haptics.speechStarted()
        }
    }
    
    public func speakMessage(_ text: String) {
        haptics.buttonTap()
        voiceManager.speak(text: text, for: activeAgent)
    }
    
    public func toggleSpeechForMessage(_ text: String) {
        haptics.buttonTap()
        if voiceManager.isSpeaking {
            voiceManager.stop()
        } else {
            voiceManager.speak(text: text, for: activeAgent)
        }
    }
    
    // MARK: - Envoi de Message & Orchestration Multi-Agents
    
    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""
        
        isTyping = true
        voiceStatus = .processing
        
        // Routage intelligent vers l'un des 4 agents (Sarah, Tom, Raphaël, Yohan) avec préservation du contexte
        let currentSelectedAgent = activeAgent
        multiAgentCoordinator.routeAndProcess(query: text, currentAgent: currentSelectedAgent) { [weak self] response in
            guard let self = self else { return }
            
            // Basculer l'agent actif selon la décision de routage / passation de main
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self.activeAgent = response.agent
            }
            
            let aiMessage = Message(content: response.text, isFromUser: false)
            self.appendMessage(aiMessage)
            self.isTyping = false
            
            // Enregistrer l'échange pour maintenir le fil contextuel (mémoire court terme)
            self.aiService.recordExchange(userText: text, assistantResponse: response.text)
            SemanticMemoryIndex.shared.indexExchange(userText: text, assistantText: response.text, topicType: response.agent.rawValue)
            
            // Si Raphaël a généré du code -> préparer pour le studio
            if let code = response.generatedCode {
                self.vaiCurrentCode = code
                if response.openStudio {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.isShowingVAICodingStudio = true
                    }
                }
            }
            
            self.voiceManager.speak(text: response.spokenText, for: response.agent)
        }
    }
    
    private func appendMessage(_ msg: Message) {
        ensureConversation(withFirstMessage: msg.content)
        messages.append(msg)
        persistCurrentState()
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
