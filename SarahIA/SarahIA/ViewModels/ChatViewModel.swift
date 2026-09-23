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
    @Published public var vaiCurrentCode: String? = nil
    @Published public var websiteDraft: WebsiteBrief? = nil
    @Published public var websiteRevisionCount: Int = 0
    @Published public var agentTransitionBanner: String? = nil
    
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
    private var cancelledImagePrompts = Set<String>()

    private enum DeveloperSkillStep {
        case projectType
        case websiteCategory
        case websiteName
        case websitePurpose
        case websiteAudience
        case websiteStyle
        case websiteAccent
        case websiteSections
    }

    private struct DeveloperSkillSession {
        var step: DeveloperSkillStep = .projectType
        var category = ""
        var name = ""
        var purpose = ""
        var audience = ""
        var visualStyle = ""
        var accent = "Bleu"
        var sections: [String] = ["Accueil", "À propos", "Contact"]
    }

    private var developerSkillSession: DeveloperSkillSession?

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

        if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {
            isShowingVoiceOrbModal = true
        }
    }
    
    public func appendVisionAnalysis(
        image: UIImage,
        result: LocalVisionEngine.VisionAnalysisResult
    ) {
        let imageData = image.jpegData(compressionQuality: 0.88)
        let textSuffix = result.detectedText.isEmpty
            ? ""
            : "\n\n📝 **Texte détecté** : \(result.detectedText)"

        appendMessage(
            Message(
                content: "👁️ **Vision locale**\n\n\(result.naturalSpokenResponse)\(textSuffix)",
                isFromUser: false,
                imageData: imageData
            )
        )
    }

    public func appendEditedVideo(url: URL, title: String, vertical: Bool) {
        appendMessage(
            Message(
                content: "✂️ **Montage Nathan exporté**\n\n\(title)",
                isFromUser: false,
                generatedVideoURL: url.absoluteString,
                videoGenerationPrompt: "Montage vidéo local Nathan",
                videoIsVertical: vertical,
                isGeneratingVideo: false
            )
        )
    }

    // MARK: - Liaison des Services

    private func normalizedMediaPrompt(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func imagePlaceholderIndex(matching prompt: String?) -> Int? {
        let normalized = prompt.map(normalizedMediaPrompt)
        return messages.lastIndex(where: { message in
            guard message.isImageGenerationPlaceholder else { return false }
            guard let normalized else { return true }
            return normalizedMediaPrompt(message.imageGenerationPrompt ?? "") == normalized
        })
    }

    private func musicPlaceholderIndex(matching prompt: String?) -> Int? {
        let normalized = prompt.map(normalizedMediaPrompt)
        return messages.lastIndex(where: { message in
            guard message.isMusicGenerationPlaceholder else { return false }
            guard let normalized else { return true }
            return normalizedMediaPrompt(message.generatedMusicStyle ?? "") == normalized
        })
    }

    private func videoPlaceholderIndex(matching prompt: String?) -> Int? {
        let normalized = prompt.map(normalizedMediaPrompt)
        return messages.lastIndex(where: { message in
            guard message.isVideoGenerationPlaceholder else { return false }
            guard let normalized else { return true }
            return normalizedMediaPrompt(message.videoGenerationPrompt ?? "") == normalized
        })
    }

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

        // Le placeholder image devient le rendu final dans le même emplacement.
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedImageReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let image = notif.userInfo?["image"] as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.94) else { return }

                let prompt = (notif.userInfo?["prompt"] as? String) ?? "Image générée"
                let fileURL = (notif.userInfo?["fileURL"] as? URL)?.absoluteString
                let normalizedPrompt = self.normalizedMediaPrompt(prompt)

                if self.cancelledImagePrompts.remove(normalizedPrompt) != nil {
                    return
                }

                if let index = self.imagePlaceholderIndex(matching: prompt) {
                    let old = self.messages[index]
                    self.messages[index] = Message(
                        id: old.id,
                        content: "🎨 **Image générée**",
                        isFromUser: false,
                        timestamp: old.timestamp,
                        imageData: data,
                        generatedImageURL: fileURL,
                        isGeneratingImage: false,
                        imageGenerationPrompt: prompt
                    )
                    self.persistCurrentState()
                } else {
                    self.appendMessage(
                        Message(
                            content: "🎨 **Image générée**",
                            isFromUser: false,
                            imageData: data,
                            generatedImageURL: fileURL,
                            isGeneratingImage: false,
                            imageGenerationPrompt: prompt
                        )
                    )
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SarahImageGenerationFailed"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }

                let prompt = notif.userInfo?["prompt"] as? String
                guard let index = self.imagePlaceholderIndex(matching: prompt) else {
                    return
                }

                let old = self.messages[index]
                let error = (notif.userInfo?["error"] as? String)
                    ?? "La génération d'image a échoué."

                self.messages[index] = Message(
                    id: old.id,
                    content: "🎨 **Génération d’image interrompue**\n\(error)",
                    isFromUser: false,
                    timestamp: old.timestamp
                )
                self.persistCurrentState()
            }
            .store(in: &cancellables)

        // Le fichier WAV final remplace la carte de génération sans créer une
        // seconde "fausse" piste. L'URL locale reste persistée dans le fil.
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedMusicReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self,
                      let url = notif.object as? URL else {
                    return
                }

                let prompt = notif.userInfo?["prompt"] as? String
                guard let index = self.musicPlaceholderIndex(matching: prompt) else {
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
                guard let self = self else { return }

                let prompt = notif.userInfo?["prompt"] as? String
                guard let index = self.musicPlaceholderIndex(matching: prompt) else {
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
                      let url = notif.object as? URL else {
                    return
                }

                let prompt = notif.userInfo?["prompt"] as? String
                guard let index = self.videoPlaceholderIndex(matching: prompt) else {
                    return
                }

                let old = self.messages[index]
                let duration = (notif.userInfo?["duration"] as? Double)
                    ?? old.audioDuration
                    ?? 6
                let isVertical = (notif.userInfo?["vertical"] as? Bool)
                    ?? old.videoIsVertical
                    ?? false

                self.messages[index] = Message(
                    id: old.id,
                    content: "🎬 **Vidéo générée.**",
                    isFromUser: false,
                    timestamp: old.timestamp,
                    audioDuration: duration,
                    generatedVideoURL: url.absoluteString,
                    videoGenerationPrompt: old.videoGenerationPrompt,
                    videoIsVertical: isVertical,
                    isGeneratingVideo: false
                )
                self.persistCurrentState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SarahVideoGenerationFailed"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }

                let prompt = notif.userInfo?["prompt"] as? String
                guard let index = self.videoPlaceholderIndex(matching: prompt) else {
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

        NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerStateChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                switch AppleSpeechRecognizer.shared.state {
                case .idle:
                    if self.isContinuousConversationActive,
                       !self.isVoiceMicrophoneMuted,
                       !self.voiceManager.isSpeaking,
                       !AppleSpeechRecognizer.shared.isListening {
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
        developerSkillSession = nil
        agentTransitionBanner = nil
        isTyping = false
        voiceStatus = .idle
        if #available(iOS 27.0, *) {
            SarahLocalMusicGenEngine.shared.cancelCurrentGeneration()
        }
        SarahLocalVideoGenEngine.shared.cancelCurrentGeneration()
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
        developerSkillSession = nil
        agentTransitionBanner = nil
        isTyping = false
        voiceStatus = .idle
        if #available(iOS 27.0, *) {
            SarahLocalMusicGenEngine.shared.cancelCurrentGeneration()
        }
        SarahLocalVideoGenEngine.shared.cancelCurrentGeneration()
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
    
    // MARK: - Transition d'agents & Skill développeur

    private func normalizedIntent(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func transitionToAgent(_ agent: AgentType, source: AgentType? = nil) {
        let previous = source ?? activeAgent
        guard previous != agent else {
            activeAgent = agent
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            activeAgent = agent
            agentTransitionBanner = "\(previous.displayName) → \(agent.displayName)"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self.agentTransitionBanner = nil
            }
        }
    }

    public func selectAgent(_ agent: AgentType) {
        haptics.buttonTap()
        let previous = activeAgent
        transitionToAgent(agent, source: previous)

        if isContinuousConversationActive, previous != agent {
            ensureVoicePipelinePrepared()
            voiceManager.speak(
                text: "\(agent.displayName) est prêt. Que veux-tu faire ?",
                for: agent
            )
        }
    }

    private func looksLikeDeveloperHandoff(_ text: String) -> Bool {
        let n = normalizedIntent(text)
        let names = ["agent developpeur", "developpeur", "raphael", "rafael", "agent code", "agent de code"]
        let switches = ["donne moi", "passe moi", "je veux", "parler a", "parler avec", "mets moi", "bascule", "ouvre"]
        return names.contains(where: { n.contains($0) })
            && switches.contains(where: { n.contains($0) })
    }

    private func developerQuestion(_ text: String, spoken: String? = nil) {
        appendMessage(Message(content: "💻 **Raphaël**\n\n\(text)", isFromUser: false))
        if isContinuousConversationActive {
            ensureVoicePipelinePrepared()
            voiceManager.speak(text: spoken ?? text, for: .esther)
        }
    }

    private func beginDeveloperSkill() {
        let sourceAgent = activeAgent
        transitionToAgent(.esther, source: sourceAgent)
        developerSkillSession = DeveloperSkillSession()

        let question = "Tu veux développer quoi ?\n\n**Site internet**, **app iPhone**, **raccourci Apple**, **script** ou **autre projet** ?"
        appendMessage(
            Message(
                content: "💻 **Raphaël**\n\n\(question)",
                isFromUser: false
            )
        )

        if isContinuousConversationActive {
            ensureVoicePipelinePrepared()
            voiceManager.speakHandoff(
                transitionText: "Je te passe Raphaël.",
                sourceAgent: sourceAgent,
                agentGreeting: "Bonjour, je suis Raphaël. Tu veux développer quoi ? Un site internet, une application iPhone, un raccourci Apple, un script, ou un autre projet ?",
                targetAgent: .esther
            )
        }
    }

    /// Retourne true lorsque le message a été consommé par le parcours guidé de Raphaël.
    private func handleDeveloperSkillAnswer(_ text: String) -> Bool {
        guard var session = developerSkillSession else { return false }
        let n = normalizedIntent(text)

        switch session.step {
        case .projectType:
            if n.contains("site") || n.contains("web") || n.contains("e commerce") || n.contains("ecommerce") {
                if n.contains("e commerce") || n.contains("ecommerce") {
                    session.category = "E-commerce"
                    session.step = .websiteName
                    developerSkillSession = session
                    developerQuestion("Parfait, un **site e-commerce**. Quel est le **nom de la boutique ou de la marque** ?")
                } else {
                    session.step = .websiteCategory
                    developerSkillSession = session
                    developerQuestion(
                        "Quel type de site veux-tu ?\n\n**E-commerce**, **portfolio**, **voyage**, **restaurant**, **entreprise** ou **événement** ?",
                        spoken: "Quel type de site veux-tu ? E-commerce, portfolio, voyage, restaurant, entreprise ou événement ?"
                    )
                }
                return true
            }

            developerSkillSession = nil
            transitionToAgent(.esther)
            if n.contains("app") || n.contains("iphone") || n.contains("ios") {
                developerQuestion("Très bien. Décris-moi l’**application iPhone** que tu veux créer et ses fonctions principales.")
            } else if n.contains("raccourci") || n.contains("shortcut") {
                developerQuestion("Très bien. Dis-moi ce que le **Raccourci Apple** doit faire, étape par étape.")
            } else if n.contains("script") || n.contains("python") {
                developerQuestion("Très bien. Dis-moi ce que le **script** doit automatiser et sur quelle plateforme il doit tourner.")
            } else {
                developerQuestion("Décris-moi ton projet. Je choisirai ensuite le meilleur format technique.")
            }
            return true

        case .websiteCategory:
            let mapping: [(String, String)] = [
                ("e commerce", "E-commerce"),
                ("ecommerce", "E-commerce"),
                ("portfolio", "Portfolio"),
                ("voyage", "Voyage"),
                ("restaurant", "Restaurant"),
                ("entreprise", "Entreprise"),
                ("evenement", "Événement")
            ]
            session.category = mapping.first(where: { n.contains($0.0) })?.1 ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.step = .websiteName
            developerSkillSession = session
            developerQuestion("Quel est le **nom du site, de la marque ou du projet** ?")
            return true

        case .websiteName:
            session.name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.step = .websitePurpose
            developerSkillSession = session
            developerQuestion("Quel est son **objectif principal** ? Par exemple vendre, présenter un projet, prendre des réservations ou informer.")
            return true

        case .websitePurpose:
            session.purpose = text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.step = .websiteAudience
            developerSkillSession = session
            developerQuestion("À qui s’adresse le site ? **Grand public**, **professionnels**, **familles**, **jeunes**, **clients locaux** ou **international** ?")
            return true

        case .websiteAudience:
            session.audience = text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.step = .websiteStyle
            developerSkillSession = session
            developerQuestion(
                "Quel style veux-tu ?\n\n**Apple / Liquid Glass**, **minimaliste**, **élégant**, **luxe**, **tech**, **naturel** ou **énergique** ?",
                spoken: "Quel style veux-tu ? Apple Liquid Glass, minimaliste, élégant, luxe, tech, naturel ou énergique ?"
            )
            return true

        case .websiteStyle:
            if n.contains("apple") || n.contains("liquid") {
                session.visualStyle = "Apple / Liquid Glass"
            } else {
                session.visualStyle = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            session.step = .websiteAccent
            developerSkillSession = session
            developerQuestion("Quelle **couleur principale** veux-tu ? Bleu, violet, rose, orange, vert ou noir et blanc ?")
            return true

        case .websiteAccent:
            session.accent = text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.step = .websiteSections
            developerSkillSession = session
            developerQuestion(
                "Quelles sections veux-tu ? Tu peux dire par exemple : **Accueil, Produits, À propos, Galerie, Avis, FAQ, Contact**.",
                spoken: "Quelles sections veux-tu ? Par exemple accueil, produits, à propos, galerie, avis, FAQ et contact."
            )
            return true

        case .websiteSections:
            let choices: [(String, String)] = [
                ("accueil", "Accueil"),
                ("a propos", "À propos"),
                ("produit", "Produits / services"),
                ("service", "Produits / services"),
                ("galerie", "Galerie"),
                ("avis", "Avis clients"),
                ("faq", "FAQ"),
                ("contact", "Contact")
            ]
            var selected = choices.compactMap { n.contains($0.0) ? $0.1 : nil }
            if selected.count < 3 {
                selected = ["Accueil", "Produits / services", "À propos", "Contact"]
            }
            session.sections = Array(Set(selected)).sorted()
            developerSkillSession = nil

            let brief = WebsiteBrief(
                category: session.category.isEmpty ? "Site web" : session.category,
                name: session.name.isEmpty ? "Nouveau projet" : session.name,
                purpose: session.purpose,
                audience: session.audience.isEmpty ? "Grand public" : session.audience,
                visualStyle: session.visualStyle.isEmpty ? "Apple / Liquid Glass" : session.visualStyle,
                accent: session.accent.isEmpty ? "Bleu" : session.accent,
                sections: session.sections
            )
            completeWebsiteBrief(brief)
            return true
        }
    }

    // MARK: - Pipeline Vocale Apple Speech & Multi-Agents
    
    private func setupVoicePipeline() {
        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            DispatchQueue.main.async {
                self?.liveTranscriptionText = partial
            }
        }
        
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    self.voiceStatus = .idle
                    return
                }
                self.liveTranscriptionText = ""
                self.sendMessage(cleaned)
            }
        }
        
        voiceManager.onSpeechStarted = { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeaking = true
                self?.voiceStatus = .speaking
                self?.haptics.speechStarted()
            }
        }
        
        voiceManager.onSpeechFinished = { [weak self] in
            DispatchQueue.main.async {
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
    }
    
    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if isContinuousConversationActive {
            if isVoiceMicrophoneMuted {
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

        voiceStatus = .starting
        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        if isMicRunning {
            voiceStatus = .listening(level: 0.0)
        }
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

        voiceStatus = .starting
        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        if isMicRunning {
            voiceStatus = .listening(level: 0.0)
        }
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
        // Les résultats image arrivés trop tard sont également ignorés.
        let imagePromptsToIgnore = messages.compactMap { message -> String? in
            guard message.isImageGenerationPlaceholder,
                  let prompt = message.imageGenerationPrompt else { return nil }
            return normalizedMediaPrompt(prompt)
        }
        cancelledImagePrompts.formUnion(imagePromptsToIgnore)

        if messages.contains(where: {
            $0.isMusicGenerationPlaceholder
            || $0.isVideoGenerationPlaceholder
            || $0.isImageGenerationPlaceholder
        }) {
            messages.removeAll(where: {
                $0.isMusicGenerationPlaceholder
                || $0.isVideoGenerationPlaceholder
                || $0.isImageGenerationPlaceholder
            })
            persistCurrentState()
        }

        if #available(iOS 27.0, *) {
            SarahLocalMusicGenEngine.shared.cancelCurrentGeneration()
        }
        SarahLocalVideoGenEngine.shared.cancelCurrentGeneration()
    }

    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Le handoff Raphaël et son questionnaire sont entièrement locaux.
        // Ils doivent répondre immédiatement, sans réveiller AIService avant même
        // que le premier message ait pu être affiché (ce qui gelait le smoke test
        // et pouvait donner l'impression que le changement d'agent ne marchait pas).
        if developerSkillSession != nil || looksLikeDeveloperHandoff(text) {
            let userMessage = Message(content: text, isFromUser: true)
            appendMessage(userMessage)
            inputText = ""

            if handleDeveloperSkillAnswer(text) {
                isTyping = false
                voiceStatus = isContinuousConversationActive ? voiceStatus : .idle
                return
            }

            if looksLikeDeveloperHandoff(text) {
                beginDeveloperSkill()
                isTyping = false
                return
            }
        }

        aiService.syncHistoryFromMessages(messages)
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""

        // Une demande de suivi peut arriver après un changement d'agent,
        // un retour dans la discussion ou une relance de l'app. On restaure
        // d'abord le contexte web de CETTE conversation avant de décider quoi faire.
        if WebsiteBrief.looksLikeWebsiteFollowUp(text),
           (vaiCurrentCode == nil || vaiCurrentCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) {
            restoreWebsiteContext(for: currentConversationId)
        }

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

        if (WebsiteBrief.isRefinementRequest(text)
            || (vaiCurrentCode != nil && WebsiteBrief.isContextualRefinementRequest(text))),
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

        let imageIntent = OpenSourceImageGenerationService.shared.isImageGenerationIntent(routedText)
        if imageIntent.isIntent {
            cancelledImagePrompts.remove(normalizedMediaPrompt(imageIntent.cleanedPrompt))
            appendMessage(
                Message(
                    content: "🎨 **Génération d’image en cours**",
                    isFromUser: false,
                    isGeneratingImage: true,
                    imageGenerationPrompt: imageIntent.cleanedPrompt
                )
            )
        }

        let videoIntent = SarahLocalVideoGenEngine.shared.detectVideoIntent(routedText)
        if videoIntent.isIntent {
            appendMessage(
                Message(
                    content: "🎬 **Génération vidéo en cours**",
                    isFromUser: false,
                    audioDuration: videoIntent.duration,
                    videoGenerationPrompt: videoIntent.prompt,
                    videoIsVertical: videoIntent.isVertical,
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

                self.transitionToAgent(
                    response.agent,
                    source: self.activeAgent
                )

                let rawText = response.text.isEmpty ? "Sarah n’a pas pu produire de réponse. Réessaie dans un instant." : response.text
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
                    self.captureWebsiteContextIfNeeded(
                        generatedCode: code,
                        userRequest: text
                    )
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

    /// Enregistre aussi les sites produits par la voie générale de Raphaël.
    /// Avant, seuls les sites créés par le questionnaire étaient persistés, ce
    /// qui expliquait qu'un « améliore le site que tu as créé » puisse perdre le fil.
    private func captureWebsiteContextIfNeeded(
        generatedCode: String,
        userRequest: String
    ) {
        let lower = generatedCode.lowercased()
        let looksLikeWebsite =
            lower.contains("<!doctype html")
            || (lower.contains("<html") && lower.contains("</html>"))
            || (lower.contains("<body") && lower.contains("</body>"))

        guard looksLikeWebsite else { return }

        if websiteDraft == nil {
            websiteDraft = WebsiteBrief.inferred(from: userRequest)
        }

        vaiCurrentCode = generatedCode
        _ = VAICodeEngine.shared.saveFile(
            filename: "index.html",
            content: generatedCode
        )
        saveWebsiteContext()
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
        if isContinuousConversationActive {
            ensureVoicePipelinePrepared()
            voiceManager.speak(
                text: "La première version de \(brief.name) est prête. Dis-moi ensuite ce que tu veux améliorer.",
                for: .esther
            )
        }
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
