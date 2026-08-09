import Foundation

/// Modèle d'état persisté de l'application Sarah AI.
public struct AppPersistedState: Codable {
    public var activeMode: String // "text" ou "avatar"
    public var messages: [Message]
    public var lastActiveTimestamp: Date
    public var voiceSettings: VoiceSettings
    public var learnedMemories: [String: String] // Associations apprises [trigger: response]
    public var pendingLearningTrigger: String? // Déclencheur en attente d'apprentissage
    
    public init(
        activeMode: String = "avatar",
        messages: [Message] = [],
        lastActiveTimestamp: Date = Date(),
        voiceSettings: VoiceSettings = VoiceSettings(),
        learnedMemories: [String: String] = [:],
        pendingLearningTrigger: String? = nil
    ) {
        self.activeMode = activeMode
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

/// Service de persistance thread-safe pour les données et l'état de l'application Sarah AI.
public final class StorageService {
    
    public static let shared = StorageService()
    
    private let fileManager = FileManager.default
    private let stateFileName = "sarah_ai_state.json"
    private let queue = DispatchQueue(label: "com.sarahai.storage", qos: .utility)
    
    private var stateFileURL: URL {
        let directory: URL
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            directory = appSupport
        } else {
            directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        
        let appDirectory = directory.appendingPathComponent("SarahAI", isDirectory: true)
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return appDirectory.appendingPathComponent(stateFileName)
    }
    
    private init() {}
    
    /// Sauvegarde l'état complet de l'application de manière atomique
    public func saveState(_ state: AppPersistedState) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(state)
                
                try data.write(to: self.stateFileURL, options: [.atomicWrite, .completeFileProtectionUnlessOpen])
            } catch {
                print("⚠️ [StorageService] Erreur lors de la sauvegarde de l'état: \(error)")
            }
        }
    }
    
    /// Charge l'état persisté depuis le stockage local
    public func loadState() -> AppPersistedState {
        do {
            let url = stateFileURL
            guard fileManager.fileExists(atPath: url.path) else {
                return AppPersistedState()
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppPersistedState.self, from: data)
        } catch {
            print("⚠️ [StorageService] Erreur lors du chargement de l'état, initialisation par défaut: \(error)")
            return AppPersistedState()
        }
    }
    
    /// Efface l'historique et réinitialise l'état
    public func clearState() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.stateFileURL)
        }
    }
}
