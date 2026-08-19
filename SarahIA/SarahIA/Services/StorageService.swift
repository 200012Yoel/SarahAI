import Foundation

/// Modèle d'état persisté complet de l'application Sarah AI.
public struct AppPersistedState: Codable {
    public var activeMode: String // "text" ou "avatar"
    public var conversations: [Conversation]
    public var currentConversationId: UUID?
    public var messages: [Message] // Fallback historique
    public var lastActiveTimestamp: Date
    public var voiceSettings: VoiceSettings
    public var learnedMemories: [String: String] // Associations apprises [trigger: response]
    public var pendingLearningTrigger: String? // Déclencheur en attente d'apprentissage
    
    public init(
        activeMode: String = "avatar",
        conversations: [Conversation] = [],
        currentConversationId: UUID? = nil,
        messages: [Message] = [],
        lastActiveTimestamp: Date = Date(),
        voiceSettings: VoiceSettings = VoiceSettings(),
        learnedMemories: [String: String] = [:],
        pendingLearningTrigger: String? = nil
    ) {
        self.activeMode = activeMode
        self.conversations = conversations
        self.currentConversationId = currentConversationId
        self.messages = messages
        self.lastActiveTimestamp = lastActiveTimestamp
        self.voiceSettings = voiceSettings
        self.learnedMemories = learnedMemories
        self.pendingLearningTrigger = pendingLearningTrigger
    }
}

/// Paramètres vocaux et VAD persistés
public struct VoiceSettings: Codable {
    public var vadSensitivity: Float // 0.0 à 1.0
    public var speechRate: Float // 0.5 (normal)
    public var speechPitch: Float // 1.0
    public var language: String // "fr-FR"
    public var autoListenInAvatarMode: Bool
    
    public init(
        vadSensitivity: Float = 0.65,
        speechRate: Float = 0.52,
        speechPitch: Float = 1.05,
        language: String = "fr-FR",
        autoListenInAvatarMode: Bool = true
    ) {
        self.vadSensitivity = vadSensitivity
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.language = language
        self.autoListenInAvatarMode = autoListenInAvatarMode
    }
}

/// Service de persistance atomique et thread-safe pour les données et l'état de l'application Sarah AI.
public final class StorageService {
    
    public static let shared = StorageService()
    
    private let fileManager = FileManager.default
    private let stateFileName = "sarah_ai_state.json"
    private let backupFileName = "sarah_ai_state.json.bak"
    private let ioQueue = DispatchQueue(label: "com.sarahai.storage.queue", qos: .userInitiated)
    
    private var appDirectoryURL: URL {
        let baseDirectory: URL
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDirectory = appSupport
        } else {
            baseDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        let dir = baseDirectory.appendingPathComponent("SarahAI", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("⚠️ [StorageService] Impossible de créer le dossier SarahAI: \(error)")
            }
        }
        return dir
    }
    
    private var stateFileURL: URL {
        return appDirectoryURL.appendingPathComponent(stateFileName)
    }
    
    private var backupFileURL: URL {
        return appDirectoryURL.appendingPathComponent(backupFileName)
    }
    
    private init() {}
    
    /// Sauvegarde l'état complet de l'application de manière atomique et thread-safe.
    public func saveState(_ state: AppPersistedState) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(state)
                
                // Sauvegarde d'un fichier de secours avant écriture atomique
                if self.fileManager.fileExists(atPath: self.stateFileURL.path) {
                    try? self.fileManager.removeItem(at: self.backupFileURL)
                    try? self.fileManager.copyItem(at: self.stateFileURL, to: self.backupFileURL)
                }
                
                // Écriture atomique sécurisée
                try data.write(to: self.stateFileURL, options: [.atomicWrite])
            } catch {
                print("❌ [StorageService] Erreur critique de sauvegarde: \(error.localizedDescription)")
            }
        }
    }
    
    /// Charge l'état persisté depuis le stockage local avec restauration automatique de secours.
    public func loadState() -> AppPersistedState {
        return ioQueue.sync {
            // 1. Essai de lecture du fichier principal
            if fileManager.fileExists(atPath: stateFileURL.path) {
                do {
                    let data = try Data(contentsOf: stateFileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(AppPersistedState.self, from: data)
                } catch {
                    print("⚠️ [StorageService] Fichier principal corrompu, essai du secours: \(error.localizedDescription)")
                }
            }
            
            // 2. Essai de restauration depuis le fichier de secours (.bak)
            if fileManager.fileExists(atPath: backupFileURL.path) {
                do {
                    let data = try Data(contentsOf: backupFileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let state = try decoder.decode(AppPersistedState.self, from: data)
                    print("✅ [StorageService] État restauré depuis la sauvegarde de secours")
                    return state
                } catch {
                    print("⚠️ [StorageService] Échec du secours: \(error.localizedDescription)")
                }
            }
            
            // 3. Fallback état par défaut si aucun fichier n'existe ou si corruption complète
            return AppPersistedState()
        }
    }
    
    /// Efface l'historique et réinitialise l'état
    public func clearState() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.stateFileURL)
            try? self.fileManager.removeItem(at: self.backupFileURL)
        }
    }
}
