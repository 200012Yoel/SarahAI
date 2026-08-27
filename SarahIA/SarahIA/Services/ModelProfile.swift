import Foundation

/// Profil de configuration d'un modèle IA adapté aux ressources matérielles
public struct ModelProfile: Codable, Equatable {
    public let profileId: String
    public let internalEngineId: String
    public let targetTier: HardwareTier
    public let maxContextLength: Int
    public let maxGenerationTokens: Int
    public let estimatedMemoryFootprintBytes: UInt64
    public let defaultBatchIntervalMs: UInt64
    public let allowsConcurrentAgents: Bool
    public let modelFileName: String
    public let fallbackProfileId: String?
    
    public init(
        profileId: String,
        internalEngineId: String,
        targetTier: HardwareTier,
        maxContextLength: Int,
        maxGenerationTokens: Int,
        estimatedMemoryFootprintBytes: UInt64,
        defaultBatchIntervalMs: UInt64,
        allowsConcurrentAgents: Bool,
        modelFileName: String,
        fallbackProfileId: String?
    ) {
        self.profileId = profileId
        self.internalEngineId = internalEngineId
        self.targetTier = targetTier
        self.maxContextLength = maxContextLength
        self.maxGenerationTokens = maxGenerationTokens
        self.estimatedMemoryFootprintBytes = estimatedMemoryFootprintBytes
        self.defaultBatchIntervalMs = defaultBatchIntervalMs
        self.allowsConcurrentAgents = allowsConcurrentAgents
        self.modelFileName = modelFileName
        self.fallbackProfileId = fallbackProfileId
    }
}
