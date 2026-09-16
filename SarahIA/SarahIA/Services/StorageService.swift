import Foundation

/// Modèle d'état persisté complet de l'application Sarah AI.
public struct AppPersistedState: Codable {
    public var activeMode: String // "text"
    public var conversations: [Conversation]
    public var currentConversationId: UUID?
    public var messages: [Message] // Fallback historique
    public var lastActiveTimestamp: Date
    public var voiceSettings: VoiceSettings
    public var learnedMemories: [String: String] // Associations apprises [trigger: response]
    public var pendingLearningTrigger: String? // Déclencheur en attente d'apprentissage
    
    public init(
        activeMode: String = "text",
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
    
    public init(
        vadSensitivity: Float = 0.65,
        speechRate: Float = 0.52,
        speechPitch: Float = 1.05,
        language: String = "fr-FR"
    ) {
        self.vadSensitivity = vadSensitivity
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.language = language
    }
}

/// Service de persistance atomique et thread-safe pour les données et l'état de l'application Sarah AI.
public final class StorageService {
    
    public static let shared = StorageService()
    
    private let fileManager = FileManager.default
    private let stateFileName = "sarah_ai_state.json"
    private let backupFileName = "sarah_ai_state.json.bak"
    private let installedBuildKey = "sarah_installed_build_identifier"
    private let appGroupSuite = "group.com.sarahia.app"
    private let appGroupMemoryKey = "sarah_learned_memories_v2"
    private let ioQueue = DispatchQueue(label: "com.sarahai.storage.queue", qos: .userInitiated)
    
    /// Emplacement sans effet de bord : utile pour savoir si une ancienne version a laissé
    /// des données avant de créer le dossier de travail de la nouvelle version.
    private var appDirectoryLocationURL: URL {
        let baseDirectory: URL
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDirectory = appSupport
        } else {
            baseDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        return baseDirectory.appendingPathComponent("SarahAI", isDirectory: true)
    }

    private var appDirectoryURL: URL {
        let dir = appDirectoryLocationURL
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
        ioQueue.sync { [weak self] in
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
    
    /// Met à jour rapidement les paramètres vocaux
    public func updateVoiceSettings(rate: Float, pitch: Float) {
        var state = loadState()
        state.voiceSettings.speechRate = rate
        state.voiceSettings.speechPitch = pitch
        saveState(state)
    }
    
    /// Efface l'historique et réinitialise l'état
    public func clearState() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.stateFileURL)
            try? self.fileManager.removeItem(at: self.backupFileURL)
        }
    }

    /// Réinitialise les données locales lorsqu'une IPA portant un nouveau numéro de build est installée.
    /// Pendant cette phase de test, Sarah repart exactement avec une discussion, des réglages et des espaces
    /// de travail vierges. Les ressources livrées dans l'IPA ne sont jamais touchées.
    @discardableResult
    public func resetUserStateForNewBuildIfNeeded(currentBuild: String) -> Bool {
        let build = currentBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !build.isEmpty else { return false }

        let didReset = ioQueue.sync { [weak self] () -> Bool in
            guard let self = self else { return false }
            let defaults = UserDefaults.standard
            let previousBuild = defaults.string(forKey: self.installedBuildKey)
            let hasExistingState = self.fileManager.fileExists(atPath: self.appDirectoryLocationURL.path)

            // Une absence de marqueur avec un état déjà présent correspond à la migration depuis
            // une version antérieure de Sarah IA : elle doit également repartir de zéro une fois.
            let mustReset = (previousBuild != nil && previousBuild != build) || (previousBuild == nil && hasExistingState)
            guard mustReset else {
                defaults.set(build, forKey: self.installedBuildKey)
                return false
            }

            // Application Support/SarahAI contient l'état JSON, SQLite et les éventuels
            // téléchargements de test liés à une ancienne version.
            try? self.fileManager.removeItem(at: self.appDirectoryLocationURL)

            // Espaces générés par l'utilisateur : code, exports de raccourcis et images.
            if let documents = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let generatedDirectories = [
                    "VAI_Workspace",
                    "SandboxScripts",
                    "Shortcuts",
                    "SarahGeneratedImages"
                ]
                for directory in generatedDirectories {
                    try? self.fileManager.removeItem(at: documents.appendingPathComponent(directory, isDirectory: true))
                }
            }

            // Le cache de modèles déployé est régénéré par Sarah Engine au lancement suivant.
            if let appSupport = self.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? self.fileManager.removeItem(at: appSupport.appendingPathComponent("ai_models", isDirectory: true))
            }

            // Tous les réglages applicatifs sont des données de test : les supprimer évite
            // qu'un ancien mode, une mémoire ou un téléchargement en pause réapparaisse.
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                defaults.removePersistentDomain(forName: bundleIdentifier)
            }
            defaults.set(build, forKey: self.installedBuildKey)
            return true
        }

        guard didReset else { return false }

        // SQLite détient une seconde copie des messages : la vider de manière synchrone évite
        // qu'un ancien historique réapparaisse pendant le démarrage de la nouvelle version.
        SQLiteChatDatabase.shared.clearAllHistorySynchronously()
        if let groupDefaults = UserDefaults(suiteName: appGroupSuite) {
            groupDefaults.removePersistentDomain(forName: appGroupSuite)
            groupDefaults.removeObject(forKey: appGroupMemoryKey)
        }
        return true
    }
    
    // MARK: - Gestion de Mémoire Permanente (Learned Memories)
    
    public func saveMemory(trigger: String, response: String) {
        var state = loadState()
        state.learnedMemories[trigger] = response
        saveState(state)
    }
    
    public func deleteMemory(forTrigger trigger: String) {
        var state = loadState()
        state.learnedMemories.removeValue(forKey: trigger)
        saveState(state)
    }
    
    public func clearAllMemories() {
        var state = loadState()
        state.learnedMemories.removeAll()
        saveState(state)
    }
}
