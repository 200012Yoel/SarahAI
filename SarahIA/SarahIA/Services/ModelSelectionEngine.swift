import Foundation

/// Sélection locale et prudente du modèle Sarah Engine.
/// Aucun nom de modèle n'est exposé dans l'interface : l'utilisateur parle à Sarah.
public final class ModelSelectionEngine {
    public static let shared = ModelSelectionEngine()

    // Poids Qwen3 sous licence Apache-2.0, en GGUF Q4.
    public static let qwen06BDownloadURL = "https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf"
    public static let qwen06BFileName = "Qwen3-0.6B-Q4_K_M.gguf"
    public static let qwen17BDownloadURL = "https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf"
    public static let qwen17BFileName = "Qwen3-1.7B-Q4_K_M.gguf"
    public static let qwen4BDownloadURL = "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf"
    public static let qwen4BFileName = "Qwen3-4B-Q4_K_M.gguf"

    private var registeredProfiles: [ModelProfile] = []

    private init() { setupDefaultCatalog() }

    private func setupDefaultCatalog() {
        let compact = ModelProfile(profileId: "profile_qwen3_06b_local", internalEngineId: "Sarah Engine Compact", targetTier: .tier3_intermediate, maxContextLength: 1024, maxGenerationTokens: 512, estimatedMemoryFootprintBytes: 700 * 1024 * 1024, defaultBatchIntervalMs: 8, allowsConcurrentAgents: false, modelFileName: Self.qwen06BFileName, fallbackProfileId: nil)
        let balanced = ModelProfile(profileId: "profile_qwen3_17b_local", internalEngineId: "Sarah Engine Multilingue", targetTier: .tier4_advanced, maxContextLength: 2048, maxGenerationTokens: 1024, estimatedMemoryFootprintBytes: 1600 * 1024 * 1024, defaultBatchIntervalMs: 5, allowsConcurrentAgents: false, modelFileName: Self.qwen17BFileName, fallbackProfileId: "profile_qwen3_06b_local")
        let powerful = ModelProfile(profileId: "profile_qwen3_4b_local", internalEngineId: "Sarah Engine Multilingue Plus", targetTier: .tier6_ultra, maxContextLength: 4096, maxGenerationTokens: 1536, estimatedMemoryFootprintBytes: 3200 * 1024 * 1024, defaultBatchIntervalMs: 3, allowsConcurrentAgents: false, modelFileName: Self.qwen4BFileName, fallbackProfileId: "profile_qwen3_17b_local")
        registeredProfiles = [powerful, balanced, compact]
    }

    public var currentCapability: DeviceCapabilityProfile { DeviceCapabilityDetector.shared.detectProfile() }

    /// iOS 15 est le minimum de Sarah IA et du runtime local moderne.
    public func supportsLocalRuntime(_ capability: DeviceCapabilityProfile) -> Bool {
        guard capability.supportsHardwareAcceleration else { return false }
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15
    }

    /// Le profil dépend de la mémoire réellement libre, pas du seul nom commercial de l'iPhone.
    public func selectOptimalProfile(for capability: DeviceCapabilityProfile) -> ModelProfile {
        guard supportsLocalRuntime(capability) else { return registeredProfiles[2] }
        if capability.safeMemoryBudgetBytes >= registeredProfiles[0].estimatedMemoryFootprintBytes { return registeredProfiles[0] }
        if capability.safeMemoryBudgetBytes >= registeredProfiles[1].estimatedMemoryFootprintBytes { return registeredProfiles[1] }
        return registeredProfiles[2]
    }

    public func isLocalGGUFAllowed() -> Bool {
        supportsLocalRuntime(currentCapability) && currentCapability.safeMemoryBudgetBytes >= registeredProfiles[2].estimatedMemoryFootprintBytes
    }

    public var recommendedLocalModelFileName: String { selectOptimalProfile(for: currentCapability).modelFileName }

    /// Taille de téléchargement estimée : utilisée uniquement pour réserver l'espace disque.
    public var recommendedDownloadBytes: UInt64 {
        switch recommendedLocalModelFileName {
        case Self.qwen4BFileName: return 2_800 * 1024 * 1024
        case Self.qwen17BFileName: return 1_350 * 1024 * 1024
        default: return 550 * 1024 * 1024
        }
    }

    public var recommendedDownloadURL: String {
        switch recommendedLocalModelFileName {
        case Self.qwen4BFileName: return Self.qwen4BDownloadURL
        case Self.qwen17BFileName: return Self.qwen17BDownloadURL
        default: return Self.qwen06BDownloadURL
        }
    }

    public func formatChatMLPrompt(system: String, user: String) -> String {
        """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        """
    }

    public func getProfile(byId id: String) -> ModelProfile? { registeredProfiles.first { $0.profileId == id } }
}
