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

/// ViewModel principal orchestrant le mode Avatar 3D, le mode Texte, le Whisper VAD, le TTS et la persistance.
@MainActor
public final class ChatViewModel: ObservableObject {
    
    // MARK: - Published UI State
    @Published public var appMode: AppMode = .avatar
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
    
    /// Restaure la conversation et le mode actif depuis le stockage local
    private func restorePersistedState() {
        let savedState = storageService.loadState()
        
        self.learnedMemories = savedState.learnedMemories
        
        if let mode = AppMode(rawValue: savedState.activeMode) {
            self.appMode = mode
        } else {
            self.appMode = .avatar
        }
        
        if !savedState.messages.isEmpty {
            self.messages = savedState.messages
        } else {
            // Premier lancement : message de bienvenue de Sarah
            let welcome = Message(
                content: "Bonjour ! 👋 Je suis Sarah, votre assistante IA 3D en temps réel. Parlez-moi ou écrivez-moi !",
                isFromUser: false
            )
            self.messages = [welcome]
            persistCurrentState()
        }
    }
    
    /// Sauvegarde l'état courant de l'application
    public func persistCurrentState() {
        let existing = storageService.loadState()
        let state = AppPersistedState(
            activeMode: appMode.rawValue,
            messages: messages,
            lastActiveTimestamp: Date(),
            voiceSettings: existing.voiceSettings,
            learnedMemories: self.learnedMemories,
            pendingLearningTrigger: existing.pendingLearningTrigger
        )
        storageService.saveState(state)
    }
    
    /// Efface l'historique et réinitialise la conversation
    public func resetConversation() {
        ttsService.stopSpeaking()
        whisperService.reset()
        messages = [
            Message(
                content: "Bonjour ! Je suis Sarah. Comment puis-je vous aider ?",
                isFromUser: false
            )
        ]
        persistCurrentState()
        haptics.memoryDeleted()
    }
    
    // MARK: - Gestion des Modes d'Affichage
    
    private func setupModeObserver() {
        $appMode
            .sink { [weak self] newMode in
                guard let self = self else { return }
                self.persistCurrentState()
                self.haptics.modeToggled()
                
                if newMode == .avatar {
                    // Démarrage doux de l'audio si permission déjà accordée
                    self.audioEngine.requestPermissionAndStart { granted in
                        if granted {
                            self.whisperService.startTranscription()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Bascule entre le mode Avatar plein écran et le mode Texte
    public func toggleMode() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            appMode = (appMode == .avatar) ? .text : .avatar
        }
    }
    
    // MARK: - Pipeline Vocal Full-Duplex & Barge-In
    
    private func setupVoicePipeline() {
        // 1. Liaison des buffers audio du micro vers Whisper
        audioEngine.onAudioBufferCaptured = { [weak self] buffer in
            self?.whisperService.appendAudioBuffer(buffer)
        }
        
        // 2. Gestion des événements VAD (Voice Activity Detection)
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
                // --- BARGE-IN INTERRUPTION ---
                print("⚡ [ChatViewModel] Interruption détectée! Arrêt immédiat de la parole de Sarah.")
                self.haptics.bargeIn()
                self.ttsService.stopSpeaking()
                self.whisperService.startTranscription()
                self.voiceStatus = .listening(level: self.micInputLevel)
            case .silenceDetected:
                // Fin de prise de parole -> Finaliser la transcription
                if self.whisperService.status == .listening {
                    self.whisperService.stopTranscription()
                }
            }
        }
        
        // 3. Transcription partielle en direct pour affichage dans la vue Avatar
        whisperService.onPartialTranscription = { [weak self] partial in
            self?.liveTranscriptionText = partial
        }
        
        // 4. Transcription finale terminée -> Envoyer au modèle d'IA
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
        
        // 5. Événements TTS
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
    
    /// Démarre ou bascule l'écoute vocale
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
    
    /// Démarre l'écoute vocale continue pour le mode Avatar
    public func startFullDuplexVoiceMode() {
        audioEngine.requestPermissionAndStart { [weak self] granted in
            guard let self = self, granted else { return }
            self.whisperService.startTranscription()
            self.voiceStatus = .listening(level: 0.0)
        }
    }
    
    /// Arrête l'écoute vocale
    public func stopVoiceMode() {
        whisperService.stopTranscription()
        audioEngine.stopAudioEngine()
        ttsService.stopSpeaking()
        voiceStatus = .idle
    }
    
    // MARK: - Écoute et Lecture Vocale des Messages (TTS)
    
    /// Lit un message spécifique à voix haute
    public func speakMessage(_ text: String) {
        haptics.buttonTap()
        ttsService.speak(text: text)
    }
    
    /// Bascule la lecture d'un message spécifique (lecture ou arrêt)
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
    
    /// Présentation complète et chaleureuse de Sarah (Voix + Texte)
    public func introduceSarah() {
        haptics.buttonTap()
        let introText = "Bonjour ! 👋 Je m'appelle Sarah, votre assistante IA 3D en temps réel. Je suis conçue pour converser avec vous par la voix ou par écrit, répondre à vos questions, et mémoriser nos échanges. N'hésitez pas à me parler librement !"
        let aiMessage = Message(content: introText, isFromUser: false)
        messages.append(aiMessage)
        persistCurrentState()
        ttsService.speak(text: introText)
    }
    
    // MARK: - Traitement des Messages (Texte & Voix)
    
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
    
    /// Traite une entrée vocale transcrite par Whisper
    private func handleUserSpeechInput(_ transcription: String) {
        let userMessage = Message(content: transcription, isFromUser: true)
        messages.append(userMessage)
        persistCurrentState()
        
        voiceStatus = .processing
        isTyping = true
        beginAIBgTask()
        
        Task {
            let response = await aiService.generateResponse(for: transcription)
            self.refreshLearnedMemories()
            
            let aiMessage = Message(content: response, isFromUser: false)
            self.messages.append(aiMessage)
            self.isTyping = false
            self.persistCurrentState()
            
            // Envoyer une notification locale si l'app est en arrière-plan
            self.sendNotificationIfNeeded(message: response)
            
            // Prononcer la réponse à voix haute et animer l'avatar 3D
            self.ttsService.speak(text: response)
            self.endAIBgTask()
        }
    }
    
    /// Envoie un message saisi manuellement au clavier
    public func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = Message(content: text, isFromUser: true)
        messages.append(userMessage)
        inputText = ""
        persistCurrentState()
        
        isTyping = true
        beginAIBgTask()
        
        Task {
            let response = await aiService.generateResponse(for: text)
            self.refreshLearnedMemories()
            
            let aiMessage = Message(content: response, isFromUser: false)
            self.messages.append(aiMessage)
            self.isTyping = false
            self.persistCurrentState()
            
            // Envoyer une notification locale si l'app est en arrière-plan
            self.sendNotificationIfNeeded(message: response)
            
            // Synthèse vocale fluide et synchronisée à voix haute
            self.ttsService.speak(text: response)
            self.endAIBgTask()
        }
    }
    
    /// Envoie une suggestion rapide (chips)
    public func sendQuickSuggestion(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "Présente-toi" || trimmed == "Qui es-tu ?" || trimmed.contains("présentation") {
            introduceSarah()
        } else {
            inputText = text
            sendMessage()
        }
    }
    
    // MARK: - Gestion de la Mémoire Apprise ("Brain Vault")
    
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
    
    /// Test de notification locale en arrière-plan
    public func sendBackgroundTest() {
        let testMessage = Message(
            content: "🔔 Test en arrière-plan lancé ! Minimisez l'app maintenant pour tester la voix et les notifications.",
            isFromUser: false
        )
        messages.append(testMessage)
        persistCurrentState()
        
        isTyping = true
        
        Task {
            let response = await aiService.generateBackgroundTestResponse()
            let aiMessage = Message(content: response, isFromUser: false)
            self.messages.append(aiMessage)
            self.isTyping = false
            self.persistCurrentState()
            
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
