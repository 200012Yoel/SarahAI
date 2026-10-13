import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit
import PDFKit

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
    
    /// Repair dead hardware input after the system has had time to settle.
    /// Don't interfere with Sarah's current spoken answer or revive a
    /// microphone the user deliberately muted.
    private func recoverVoiceInputAfterRouteChange() {
        let token = voiceSessionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self, self.voiceSessionGeneration == token,
                  self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted,
                  !self.voiceManager.isSpeaking,
                  !self.isTyping,
                  !WhisperService.shared.isMicrophoneEngineRunning else { return }
            self.rearmMicrophoneAfterSilence(delay: 0.10)
        }
    }

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
    @Published public var voicePlaybackError: String? = nil
    @Published public var isPreparingVoiceReply = false
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
    @Published public var isShowingTranslateLive: Bool = false
    @Published public var translateLiveSource: String = "he"
    @Published public var translateLiveTarget: String = "fr"
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
    // A cancelled or superseded request must never publish a late reply.
    private var messageGenerationID = UUID()
    private var isBargeInMonitorActive = false
    private var voicePlaybackStartedAt = Date.distantPast
    private var voiceSessionGeneration = UUID()

    /// One rearm path for silence, failed/empty transcription and TTS end.
    /// No late callback is allowed to reopen a microphone after Stop / Close.
    private func rearmMicrophoneAfterSilence(delay: TimeInterval = 0.25) {
        let generation = voiceSessionGeneration
        guard isContinuousConversationActive, !isVoiceMicrophoneMuted else { return }
        isMicRunning = false
        voiceStatus = .starting
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.voiceSessionGeneration == generation,
                  self.isContinuousConversationActive, !self.isVoiceMicrophoneMuted,
                  !self.voiceManager.isSpeaking,
                  !self.voiceManager.isPreparingSpeech, !self.isTyping else { return }
            self.voiceStatus = .starting
            WhisperSpeechRecognizer.shared.startListening(
                autoFinalizeOnSilence: true,
                preserveActiveSpeech: true
            )
            self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
            if self.isMicRunning {
                self.voiceStatus = .listening(level: self.micInputLevel)
            } else if case .error(let reason) = WhisperSpeechRecognizer.shared.state {
                self.voiceStatus = .error(reason)
            }
        }
    }
    
    /// Some iOS betas silently stop AVAudioEngine without an interruption
    /// notification. This low-frequency watchdog repairs the hardware input
    /// while preserving the existing Voice Orb UI and explicit Stop semantics.
    private func watchVoiceMicrophone(generation: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self,
                  self.voiceSessionGeneration == generation,
                  self.isContinuousConversationActive else { return }
            if !self.isVoiceMicrophoneMuted,
               !self.voiceManager.isSpeaking,
               !self.voiceManager.isPreparingSpeech,
               !self.isTyping,
               !WhisperService.shared.isTranscribing,
               !WhisperService.shared.isModelLoading,
               !WhisperService.shared.isMicrophoneEngineRunning {
                self.rearmMicrophoneAfterSilence(delay: 0.12)
            }
            self.watchVoiceMicrophone(generation: generation)
        }
    }

    public init() {
        restorePersistedState()
        setupModeObserver()
        bindCoreServices()
    }


    public func appendVisionAnalysis(image: UIImage, result: LocalVisionEngine.VisionAnalysisResult) {
        // Limit persisted camera images to prevent memory pressure or a large
        // conversation archive from repeatedly crashing older iPhones.
        let imageData = LocalVisionEngine.prepareImageForAnalysis(
            image, maxDimension: 1080, quality: 0.76
        )?.data
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
            // Read only a bounded preview from Files/iCloud. Never load
            // large documents completely into the application's RAM.
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard size <= 20 * 1024 * 1024 else {
                inputText = "Le fichier \(name) dépasse 20 Mo. Sélectionne une version plus petite."
                return
            }
            let ext = url.pathExtension.lowercased()
            let plainText = ["txt", "md", "csv", "json", "xml", "html", "log", "swift", "py", "js"]
                .contains(ext)
            let preview: String?
            if plainText {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                preview = String(data: handle.readData(ofLength: 24_000), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if ext == "pdf" {
                let pdf = PDFDocument(url: url)
                let firstPages = (0..<min(3, pdf?.pageCount ?? 0))
                    .compactMap { pdf?.page(at: $0)?.string }
                    .joined(separator: "\n")
                preview = String(firstPages.prefix(8_000))
            } else {
                preview = nil
            }
            var content = "📎 **Fichier ajouté : \(name)**"
            if let preview, !preview.isEmpty {
                content += "\n\n```\n\(String(preview.prefix(8_000)))\n```"
            }
            if !plainText && ext != "pdf" {
                content += "\n\nCe type de fichier n'a pas encore de lecteur de contenu intégré."
            }
            appendMessage(Message(content: content, isFromUser: true))
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = preview?.isEmpty == false
                    ? "Analyse le contenu du fichier \(name) ci-dessus."
                    : "J'ai sélectionné le fichier \(name)."
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
                    self?.activeAgent = agent.currentAgent
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

        // iOS can interrupt AVAudioEngine for a phone call, Bluetooth route
        // switch or Siri, leaving the Voice Orb on "Je t'écoute" while the
        // audio input has actually stopped. Recover once after iOS resumes,
        // using the existing session-generation guard so Stop stays final.
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began:
                    self.shouldResumeVoiceAfterSystemInterruption =
                        self.isContinuousConversationActive && !self.isVoiceMicrophoneMuted
                case .ended:
                    guard self.shouldResumeVoiceAfterSystemInterruption else { return }
                    self.shouldResumeVoiceAfterSystemInterruption = false
                    self.recoverVoiceInputAfterRouteChange()
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recoverVoiceInputAfterRouteChange()
            }
            .store(in: &cancellables)

        ObservableSpeechRecognizer.shared.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isMicRunning = listening
                if listening, let self,
                   self.isContinuousConversationActive,
                   !self.voiceManager.isSpeaking,
                   !self.isPreparingVoiceReply,
                   !self.isTyping {
                    self.voiceStatus = .listening(level: self.micInputLevel)
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
                // The microphone also listens during interruption monitoring.
                // Its state must never overwrite a speaking agent's visible state.
                if self.isContinuousConversationActive && self.voiceManager.isSpeaking {
                    self.voiceStatus = .speaking
                    return
                }
                if self.isContinuousConversationActive &&
                   (self.isTyping || self.isPreparingVoiceReply) {
                    self.voiceStatus = .processing
                    return
                }
                switch WhisperSpeechRecognizer.shared.state {
                case .idle:
                    if self.isTyping {
                        self.voiceStatus = .processing
                    } else if self.isContinuousConversationActive,
                       !self.isVoiceMicrophoneMuted,
                       !self.voiceManager.isSpeaking,
                       !WhisperSpeechRecognizer.shared.isListening {
                        self.voiceStatus = .starting
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
        messageGenerationID = UUID()
        websiteGenerationID = UUID()
        isTyping = false
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
        messageGenerationID = UUID()
        websiteGenerationID = UUID()
        isTyping = false
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
                  self.voiceManager.isSpeaking,
                  Date().timeIntervalSince(self.voicePlaybackStartedAt) > 0.28 else { return }

            // AVAudioSession .voiceChat fournit l'annulation d'écho. Dès qu'une
            // vraie voix traverse le VAD Whisper, Sarah s'arrête immédiatement,
            // mais Whisper continue d'enregistrer la nouvelle phrase utilisateur.
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.isBargeInMonitorActive = false
            WhisperService.shared.voiceReplyPlayingOnSpeaker = false
            // The microphone heard Sarah before the interruption; keep only
            // recent audio near the human voice, then stop the TTS at once.
            WhisperService.shared.keepOnlyRecentBargeInAudio()
            self.voiceManager.stop()
            self.isSpeaking = false
            self.voiceStatus = .listening(level: self.micInputLevel)
        }

        WhisperSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self else { return }
            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.isContinuousConversationActive, !self.isVoiceMicrophoneMuted else {
                // A voice recognition finishing after Close must not create a
                // surprise chat message in an unrelated conversation.
                return
            }
            guard !cleaned.isEmpty else {
                self.liveTranscriptionText = ""
                self.rearmMicrophoneAfterSilence()
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
        
        voiceManager.onSpeechPreparationStarted = { [weak self] in
            guard let self else { return }
            self.isPreparingVoiceReply = true
            self.voicePlaybackError = nil
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            if self.isContinuousConversationActive { self.voiceStatus = .processing }
        }

        voiceManager.onSpeechError = { [weak self] message in
            guard let self else { return }
            self.isPreparingVoiceReply = false
            self.voicePlaybackError = message
        }

        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.voicePlaybackError = nil
            self.isPreparingVoiceReply = false
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

            self.voicePlaybackStartedAt = Date()
            // Full-duplex turn taking: the input tap must stay alive even
            // while playing from the built-in speaker. The previous headset-
            // only condition made "interrupt Sarah" completely impossible
            // without headphones. Voice processing applies iOS echo
            // cancellation, and Whisper uses stricter sustained VAD for the
            // phone speaker to reduce self-interruptions.
            let outputTypes = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
            let isolatedOutput = outputTypes.contains {
                [.headphones, .bluetoothHFP, .bluetoothA2DP, .bluetoothLE].contains($0)
            }
            WhisperService.shared.voiceReplyPlayingOnSpeaker = !isolatedOutput
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
            self.isPreparingVoiceReply = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            let finishedWithoutBargeIn = self.isBargeInMonitorActive
            self.isBargeInMonitorActive = false
            WhisperService.shared.voiceReplyPlayingOnSpeaker = false

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
                self.rearmMicrophoneAfterSilence(delay: 0.10)
            } else if WhisperSpeechRecognizer.shared.isListening {
                // Genuine barge-in: preserve the user's already active utterance.
                self.isMicRunning = true
                self.voiceStatus = .listening(level: self.micInputLevel)
            } else {
                // TTS generation may fail *before* onSpeechStarted. In that case
                // there was never a barge-in tap to keep alive: rearm explicitly.
                self.rearmMicrophoneAfterSilence(delay: 0.12)
            }
        }
    }
    
    /// Read a contextual instruction without stopping the live microphone session.
    public func speakWebsiteGuide(_ text: String) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speak(text: text, for: .esther)
    }

    /// Highlight builder cards as their own audio finishes rather than using timers.
    public func speakWebsiteGuideSequence(
        _ texts: [String],
        onItemStart: @escaping (Int) -> Void,
        completion: @escaping () -> Void
    ) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else {
            completion()
            return
        }
        activeAgent = .esther
        voiceManager.speakSequence(
            texts: texts,
            for: .esther,
            onItemStart: onItemStart,
            completion: completion
        )
    }

    /// Cancel narration only; keep the user's voice conversation alive.
    public func cancelWebsiteGuideSpeech() {
        guard isContinuousConversationActive else { return }
        voiceManager.stop()
        currentSpeakingText = nil
        isSpeaking = false
        if !isVoiceMicrophoneMuted && !WhisperSpeechRecognizer.shared.isListening {
            WhisperSpeechRecognizer.shared.startListening(
                autoFinalizeOnSilence: true,
                preserveActiveSpeech: true
            )
        }
    }

    /// Select the voice agent immediately without waiting for an LLM reply.
    public func selectVoiceAgent(_ agent: AgentType) {
        let selected = agent.currentAgent
        guard activeAgent != selected else { return }
        messageGenerationID = UUID()
        isTyping = false
        isPreparingVoiceReply = false
        voiceManager.stop()
        activeAgent = selected
        currentSpeakingText = nil
        liveTranscriptionText = ""
        if isContinuousConversationActive && !isVoiceMicrophoneMuted {
            if WhisperSpeechRecognizer.shared.isListening {
                voiceStatus = .listening(level: micInputLevel)
            } else {
                rearmMicrophoneAfterSilence(delay: 0.08)
            }
        } else {
            voiceStatus = .idle
        }
    }

    public func activateTranslateLive(from source: String = "he", to target: String = "fr") {
        // A dedicated mode: dismiss all competing audio and present after any
        // full-screen voice sheet has finished its dismissal animation.
        let dismissingVoiceSheet = isShowingVoiceOrbModal
        stopVoiceConversation()
        WebRTCVoiceCallManager.shared.endCall(reason: "Translate Live")
        activeAgent = .yohan
        translateLiveSource = source
        translateLiveTarget = target
        isShowingVoiceOrbModal = false
        isDrawerOpen = false
        if dismissingVoiceSheet {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.isShowingTranslateLive = true
            }
        } else {
            isShowingTranslateLive = true
        }
    }

    public func retryVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        guard AVAudioSession.sharedInstance().recordPermission != .denied else {
            isMicRunning = false
            voiceStatus = .error("Micro refusé par iOS. Ouvre Réglages → Sarah IA → Microphone.")
            return
        }

        // Clear an error from an old attempt and start a fresh microphone
        // generation. The view can retry without reinstalling the whole app.
        voiceSessionGeneration = UUID()
        watchVoiceMicrophone(generation: voiceSessionGeneration)
        WhisperSpeechRecognizer.shared.stopListening()
        WhisperService.shared.reset()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
        AudioSessionManager.shared.beginContinuousVoiceSession()
        voiceStatus = .starting
        WhisperSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: true
        )
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        if isMicRunning { voiceStatus = .listening(level: micInputLevel) }
    }

    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if case .error = voiceStatus {
            retryVoiceMicrophone()
            return
        }

        if isContinuousConversationActive && !isVoiceMicrophoneMuted {
            // Also applies while Whisper is loading its model: a tap on the
            // microphone MUST mute rather than submit another start request.
            isVoiceMicrophoneMuted = true
            WhisperSpeechRecognizer.shared.stopListening()
            isMicRunning = false
            micInputLevel = 0
            voiceStatus = .idle
            return
        }

        isVoiceMicrophoneMuted = false
        isContinuousConversationActive = true
        voiceSessionGeneration = UUID()
        watchVoiceMicrophone(generation: voiceSessionGeneration)
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
        voiceSessionGeneration = UUID()
        watchVoiceMicrophone(generation: voiceSessionGeneration)
        voiceManager.stop()
        AudioSessionManager.shared.beginContinuousVoiceSession()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
        isBargeInMonitorActive = false
        WhisperService.shared.voiceReplyPlayingOnSpeaker = false
        voicePlaybackError = nil

        // Do not block first microphone activation with Supertonic startup.
        // Preload on its background queue once the voice conversation is up.
        let session = voiceSessionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self,
                  self.voiceSessionGeneration == session,
                  self.isContinuousConversationActive else { return }
            NeuralVoiceService.shared.prepareForVoiceConversation()
        }

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
        voiceSessionGeneration = UUID()
        isPreparingVoiceReply = false
        isContinuousConversationActive = false
        isVoiceMicrophoneMuted = false
        isBargeInMonitorActive = false
        WhisperService.shared.voiceReplyPlayingOnSpeaker = false

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
        voicePlaybackError = nil
        voiceStatus = .idle
    }
    
    /// Test one of the six distinct bundled Supertonic voices without
    /// starting microphone capture. Install the same voice callbacks as the
    /// real conversation so any missing model/audio failure is visible.
    public func previewAgentVoice(_ agent: AgentType) {
        ensureVoicePipelinePrepared()
        voicePlaybackError = nil
        voiceManager.speak(
            text: "Bonjour. Je suis \(agent.displayName). Écoute ma voix, différente des autres agents.",
            for: agent
        )
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
        messageGenerationID = UUID()
        websiteGenerationID = UUID()
        isTyping = false
        isPreparingVoiceReply = false
        voiceStatus = .idle
        AIProgressiveScheduler.shared.cancelAllTasks()
        voiceManager.stop()
    }

    // MARK: - Envoi de Message & Orchestration Multi-Agents
    
    /// Recognize explicit short commands, never random agent names in TV audio.
    private static func voiceAgentSwitchTarget(_ text: String) -> AgentType? {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "fr_FR")
        ).lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let words = normalized.split(whereSeparator: { $0.isWhitespace })
        guard words.count <= 12 else { return nil }
        let explicit = [
            "passe moi", "passe a", "passe au", "passe avec",
            "je veux parler", "je voudrais parler", "parler avec",
            "parler a", "mets moi", "mets", "choisis",
            "bascule", "active l'agent", "change pour",
            "je veux yoann", "je veux sarah", "ouvre yoann",
            "ouvre sarah"
        ].contains(where: { normalized.contains($0) })
        func named(_ variants: [String]) -> Bool {
            variants.contains { words.contains(Substring($0)) }
        }
        if named(["yoann", "yohan", "yoan", "johan"]) &&
            (explicit || words.count == 1) { return .yohan }
        if named(["sarah", "sara"]) &&
            (explicit || words.count == 1) { return .sarah }
        if named(["ethel", "etel", "tom"]) &&
            (explicit || words.count == 1) { return .ethel }
        if named(["raphael", "esther", "ester"]) &&
            (explicit || words.count == 1) { return .esther }
        return nil
    }

    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // "Active Translate Live hébreu-français" opens Yoann's dedicated
        // microphone interpreter instead of treating the command as chat text.
        if let pair = YoannTranslateLiveService.commandPair(text) {
            inputText = ""
            activateTranslateLive(from: pair.from, to: pair.to)
            return
        }
        if isContinuousConversationActive,
           let agent = Self.voiceAgentSwitchTarget(text) {
            inputText = ""
            selectVoiceAgent(agent)
            return
        }
        let generationID = UUID()
        messageGenerationID = generationID

        aiService.syncHistoryFromMessages(messages)
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""

        // A genuine geocoded world-map card, with live OSM businesses, is
        // part of the conversation, not a fabricated AI location answer.
        if SarahMapIntent.wantsMap(text) {
            appendMessage(Message(
                content: SarahMapIntent.payload(text),
                isFromUser: false,
                agentID: AgentType.sarah.rawValue
            ))
            isTyping = false
            if isContinuousConversationActive {
                voiceManager.speak(text: "J'ouvre la carte du monde en trois dimensions. Je cherche le lieu demandé.", for: .sarah)
            }
            return
        }

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
        multiAgentCoordinator.routeAndProcess(
            query: text, currentAgent: currentSelectedAgent,
            preferFastVoice: isContinuousConversationActive
        ) { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Une réponse calculée pour une ancienne discussion ne doit jamais réapparaître
                // dans un nouveau chat après un redémarrage, un archivage ou un changement de fil.
                guard self.currentConversationId == responseConversationID,
                      self.messageGenerationID == generationID else { return }
                // Basculer l'agent actif selon la décision de routage / passation de main
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.activeAgent = response.agent
                }
                
                let rawText = response.text
                var responseContent = SarahResponseCleaner.clean(rawText.decodingHTMLEntities())
                if responseContent.isEmpty {
                    responseContent = "Je n'ai pas obtenu de réponse finale lisible. Réessaie, s'il te plaît."
                }
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
                        let candidate = (response.spokenText.isEmpty ? responseContent : response.spokenText)
                            .decodingHTMLEntities()
                        let spoken = SarahResponseCleaner.clean(candidate)
                        self.voiceManager.speak(text: spoken.isEmpty ? responseContent : spoken, for: response.agent)
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
                    let passedChecks = build.staticAudit.passedChecks.joined(separator: " · ")
                    let warnings = build.staticAudit.warnings.isEmpty
                        ? "aucun avertissement"
                        : build.staticAudit.warnings.joined(separator: " · ")
                    let runtime = build.usedRemoteModels ? "moteur de code configuré" : "moteur IA local"
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · site généré et contrôlé**\n\n**\(brief.name)** est prêt. Pipeline : architecture → code → relecture qualité → WebKit → réparations automatiques si nécessaire.\n\nMoteur : \(runtime)\nContrôle navigateur : \(audit)\nContrôles statiques : \(passedChecks)\nAvertissements : \(warnings)\nRévision : #\(build.revision)\n\n🧩 Ouvrir le Studio",
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
                        content: "💻 **Raphaël · contrôle qualité non validé**\n\n\(error.localizedDescription)\n\nAucun faux site n'a été créé à la place.",
                        isFromUser: false
                    ))
                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "La génération ou son contrôle qualité n'a pas abouti. Je n'ai pas remplacé le résultat par un faux site. Tu peux réessayer ou préciser le brief.",
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
            ? "MODIFICATION : repars du projet existant, conserve les fonctions valides et applique ce nouveau brief sans régression."
            : "NOUVEAU PROJET : conçois le produit, son contenu et son interface depuis zéro."

        let domainRequirements: String
        switch brief.category {
        case "E-commerce":
            domainRequirements = "Catalogue crédible, filtres/recherche utiles, fiche produit ou détail, panier local réellement interactif avec localStorage. Aucun faux paiement ni faux stock serveur."
        case "Restaurant":
            domainRequirements = "Menu réellement lisible avec catégories/prix, informations pratiques et réservation locale avec validation. Ne prétends pas confirmer une table sur un serveur."
        case "Voyage":
            domainRequirements = "Destinations/contenus crédibles, recherche ou filtres locaux si pertinents, itinéraires ou cartes éditoriales. Aucune fausse disponibilité temps réel."
        case "Portfolio":
            domainRequirements = "Projets détaillés, navigation vers les réalisations, filtres ou modales si utiles, présentation personnelle crédible et contact local."
        case "Entreprise":
            domainRequirements = "Proposition de valeur claire, services, preuves/confiance honnêtes, équipe ou méthode si pertinent, contact avec validation locale."
        case "Événement":
            domainRequirements = "Programme, horaires, intervenants ou lieux, inscription locale avec états clairs. Aucun faux billet ou paiement serveur."
        case "SaaS / App":
            domainRequirements = "Hero produit, fonctionnalités concrètes, démonstration interactive locale si possible, tarifs si demandés, FAQ et CTA cohérents. Aucun faux compte cloud."
        case "Blog / média":
            domainRequirements = "Accueil éditorial, cartes d'articles crédibles, catégories/tags, recherche locale et lecture structurée. Aucun faux flux d'actualité temps réel."
        case "Association":
            domainRequirements = "Mission, actions, événements/projets, équipe ou bénévolat, contact/adhésion locale. Ne simule pas de don ou paiement réel."
        default:
            domainRequirements = "Choisis les interactions et composants qui servent réellement l'objectif, sans ajouter de fonctions décoratives inutiles."
        }

        return """
        \(operation)

        BRIEF PRODUIT
        Type : \(brief.category)
        Nom : \(brief.name)
        Objectif : \(brief.purpose)
        Public : \(brief.audience)
        Direction graphique : \(brief.visualStyle)
        Accent : \(brief.accent)
        Sections demandées : \(sectionList)
        Exigences métier : \(domainRequirements)

        CONTRAT DE LIVRAISON
        - Produis un vrai site spécifique au brief, avec une identité visuelle cohérente et du contenu rédigé pour ce public.
        - Retourne un seul index.html autonome avec HTML, CSS et JavaScript intégrés.
        - Mobile-first : 320/390 px, tablette et desktop. Aucun débordement horizontal.
        - Structure sémantique, un seul H1, navigation claire, sections demandées réellement remplies et footer utile.
        - Tous les boutons, menus, filtres, formulaires, accordéons, onglets, modales et liens visibles doivent avoir un comportement réel.
        - Les formulaires valident localement et montrent les états erreur/succès. N'invente jamais un backend.
        - Utilise localStorage pour les fonctions locales persistantes lorsque c'est pertinent.
        - Aucun lorem ipsum, Produit 01, Offre 01, TODO, bouton mort, faux lien ou contenu placeholder.
        - Aucun CDN, police distante, script distant, image distante, logo de marque, asset propriétaire ou URL d'image factice.
        - Les styles nommés sont des inspirations de principes graphiques, jamais des copies de marques.
        - Accessibilité réelle : contrastes, focus visible, labels de formulaires, alt, aria quand nécessaire, reduced motion.
        - Le rendu doit fonctionner hors ligne dans WKWebView.
        - Avant livraison, relis le contenu, vérifie toutes les interactions et corrige les incohérences.
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
        let introText = "Bonjour ! 👋 Je suis Sarah, votre agent pilote. À mes côtés se trouvent Ethel (Création & Design), Raphaël (Développeur & Code) et Yoann (Traducteur Français ⇄ Hébreu). Que pouvons-nous faire pour vous ?"
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
