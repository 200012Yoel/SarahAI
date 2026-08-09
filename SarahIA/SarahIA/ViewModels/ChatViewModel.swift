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
    
    // MARK: - Services
    private let aiService = AIService.shared
    private let notificationService = NotificationService.shared
    private let storageService = StorageService.shared
    private let audioEngine = AudioEngineManager.shared
    private let whisperService = WhisperService.shared
    private let ttsService = TTSService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var stateSaveDebounceTimer: Timer?
    
    public init() {
        restorePersistedState()
        setupVoicePipeline()
        setupModeObserver()
    }
    
    // MARK: - Persistance des Données & Restauration
    
    /// Restaure la conversation et le mode actif depuis le stockage local
    private func restorePersistedState() {
        let savedState = storageService.loadState()
        
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
                content: "Bonjour ! 👋 Je suis Sarah, votre assistante IA en temps réel. Parlez-moi ou écrivez-moi !",
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
            learnedMemories: existing.learnedMemories,
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
    }
    
    // MARK: - Gestion des Modes d'Affichage
    
    private func setupModeObserver() {
        $appMode
            .sink { [weak self] newMode in
                guard let self = self else { return }
                self.persistCurrentState()
                
                if newMode == .avatar {
                    self.startFullDuplexVoiceMode()
                } else {
                    // En mode texte, ne pas couper brutalement si Sarah parle, mais libérer le micro VAD continu
                    // si l'utilisateur souhaite taper du texte
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
                self.ttsService.stopSpeaking()
                self.whisperService.startTranscription()
                self.voiceStatus = .listening(level: self.micInputLevel)
            case .silenceDetected:
                // Fin de prise de parole -> Finaliser la transcription
                if self.whisperService.status == .listening {
                    print("🎙️ [ChatViewModel] Silence détecté, finalisation de la transcription...")
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
        }
        
        ttsService.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.voiceStatus = .idle
            if self.appMode == .avatar {
                // Se remettre en écoute automatiquement
                self.whisperService.startTranscription()
            }
        }
        
        ttsService.onSpeechInterrupted = { [weak self] in
            self?.voiceStatus = .idle
        }
    }
    
    /// Démarre l'écoute vocale continue pour le mode Avatar
    public func startFullDuplexVoiceMode() {
        audioEngine.startAudioEngine()
        whisperService.startTranscription()
        voiceStatus = .listening(level: 0.0)
    }
    
    /// Arrête l'écoute vocale
    public func stopVoiceMode() {
        whisperService.stopTranscription()
        audioEngine.stopAudioEngine()
        ttsService.stopSpeaking()
        voiceStatus = .idle
    }
    
    // MARK: - Traitement des Messages (Texte & Voix)
    
    /// Traite une entrée vocale transcrite par Whisper
    private func handleUserSpeechInput(_ transcription: String) {
        let userMessage = Message(content: transcription, isFromUser: true)
        messages.append(userMessage)
        persistCurrentState()
        
        voiceStatus = .processing
        isTyping = true
        
        Task {
            let response = await aiService.generateResponse(for: transcription)
            
            let aiMessage = Message(content: response, isFromUser: false)
            self.messages.append(aiMessage)
            self.isTyping = false
            self.persistCurrentState()
            
            // Prononcer la réponse à voix haute et animer l'avatar 3D
            self.ttsService.speak(text: response)
            
            await self.sendNotificationIfNeeded(message: response)
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
        
        Task {
            let response = await aiService.generateResponse(for: text)
            
            let aiMessage = Message(content: response, isFromUser: false)
            self.messages.append(aiMessage)
            self.isTyping = false
            self.persistCurrentState()
            
            // Synthèse vocale fluide et synchronisée à voix haute
            self.ttsService.speak(text: response)
            
            await self.sendNotificationIfNeeded(message: response)
        }
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
    
    private func sendNotificationIfNeeded(message: String) async {
        let state = await UIApplication.shared.applicationState
        if state != .active {
            notificationService.sendResponseNotification(message: message)
        }
    }
}

