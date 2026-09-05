import Foundation

/// Moteur de Sélection Intelligent de Modèles (Sarah Engine Architecture)
/// Gère la séparation stricte On-Device vs Cloud selon la mémoire physique réelle (ProcessInfo) :
/// - RAM >= 6 Go (iPhone 14 Pro, 15 Pro, 16, 17+) -> Qwen 2.5 Coder 7B Instruct Q4_K_M (Metal MPS, Context 4096 tokens)
/// - RAM 4-5.5 Go (iPhone 13, 14 standard) -> Qwen 2.5 Coder 3B Instruct Q4_K_M (Auto-downgrade de sécurité)
/// - RAM < 4 Go / Legacy (iPhone 5s à 12, SE) -> 🚫 Zéro modèle local (Protection Jetsam OOM) -> Cloud Fallback Puissance Absolue (Claude 3.5 Sonnet / GPT-4o)
public final class ModelSelectionEngine {
    
    public static let shared = ModelSelectionEngine()
    
    // Modèle Local Ultime (RAM >= 6 Go)
    public static let qwen7BDownloadURL = "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
    public static let qwen7BFileName = "qwen2.5-coder-7b-instruct-q4_k_m.gguf"
    
    // Modèle Local Sécurisé (RAM 4-5.5 Go ou Fallback mémoire)
    public static let qwen3BDownloadURL = "https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
    public static let qwen3BFileName = "qwen2.5-coder-3b-instruct-q4_k_m.gguf"
    
    // Modèles Cloud de Puissance Absolue
    public static let defaultCloudOpenAIModel = "gpt-4o"
    public static let defaultCloudAnthropicModel = "claude-3-5-sonnet-20240620"
    
    private var registeredProfiles: [ModelProfile] = []
    
    private init() {
        setupDefaultCatalog()
    }
    
    private func setupDefaultCatalog() {
        // 1. Profil Cloud Puissance Absolue (iPhone 5s à iPhone 12 / SE - RAM < 4 Go)
        let cloudAbsoluteProfile = ModelProfile(
            profileId: "profile_cloud_absolute_power",
            internalEngineId: "Sarah Cloud Absolute (Claude 3.5 Sonnet / GPT-4o)",
            targetTier: .tier1_legacyCompact,
            maxContextLength: 128000,
            maxGenerationTokens: 4096,
            estimatedMemoryFootprintBytes: 0, // Zéro RAM modèle local
            defaultBatchIntervalMs: 0,
            allowsConcurrentAgents: true,
            modelFileName: "cloud_proxy",
            fallbackProfileId: nil
        )
        
        // 2. Profil Local 3B Sécurité (iPhone 13/14 Standard - RAM 4 Go - 5.5 Go)
        let qwen3BProfile = ModelProfile(
            profileId: "profile_qwen_2_5_coder_3b",
            internalEngineId: "Qwen 2.5 Coder 3B Instruct (Q4_K_M Metal MPS)",
            targetTier: .tier4_advanced,
            maxContextLength: 4096,
            maxGenerationTokens: 2048,
            estimatedMemoryFootprintBytes: 2200 * 1024 * 1024, // ~2.2 Go
            defaultBatchIntervalMs: 4,
            allowsConcurrentAgents: true,
            modelFileName: ModelSelectionEngine.qwen3BFileName,
            fallbackProfileId: "profile_cloud_absolute_power"
        )
        
        // 3. Profil Local 7B Haute Performance (iPhone 14 Pro / 15 Pro / 16 / 17+ - RAM >= 6 Go)
        let qwen7BProfile = ModelProfile(
            profileId: "profile_qwen_2_5_coder_7b",
            internalEngineId: "Qwen 2.5 Coder 7B Instruct (Q4_K_M Metal MPS GPU)",
            targetTier: .tier6_ultra,
            maxContextLength: 4096,
            maxGenerationTokens: 2048,
            estimatedMemoryFootprintBytes: 4500 * 1024 * 1024, // ~4.5 Go
            defaultBatchIntervalMs: 2,
            allowsConcurrentAgents: true,
            modelFileName: ModelSelectionEngine.qwen7BFileName,
            fallbackProfileId: "profile_qwen_2_5_coder_3b"
        )
        
        registeredProfiles = [qwen7BProfile, qwen3BProfile, cloudAbsoluteProfile]
    }
    
    /// Mémoire physique totale en Gigaoctets (Go)
    public var physicalMemoryGB: Double {
        return Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
    }
    
    /// Détermine si l'appareil a au moins 6 Go de RAM (capable d'exécuter Qwen 7B)
    public func canRun7BModel() -> Bool {
        return physicalMemoryGB >= 5.5
    }
    
    /// Détermine si l'appareil a au moins 4 Go de RAM (capable d'exécuter Qwen 3B)
    public func isLocalGGUFAllowed() -> Bool {
        return physicalMemoryGB >= 3.5
    }
    
    /// Indique si l'inférence doit obligatoirement être routée vers le Cloud Fallback
    public func shouldForceCloudFallback() -> Bool {
        return !isLocalGGUFAllowed()
    }
    
    /// Nom du fichier de modèle recommandé pour cet appareil
    public var recommendedLocalModelFileName: String {
        if canRun7BModel() {
            return ModelSelectionEngine.qwen7BFileName
        } else if isLocalGGUFAllowed() {
            return ModelSelectionEngine.qwen3BFileName
        } else {
            return "cloud_proxy"
        }
    }
    
    /// URL de téléchargement recommandée
    public var recommendedDownloadURL: String {
        if canRun7BModel() {
            return ModelSelectionEngine.qwen7BDownloadURL
        } else {
            return ModelSelectionEngine.qwen3BDownloadURL
        }
    }
    
    /// Sélectionne le profil adapté à la capacité matérielle
    public func selectOptimalProfile(for capability: DeviceCapabilityProfile) -> ModelProfile {
        if canRun7BModel() {
            return registeredProfiles.first(where: { $0.profileId == "profile_qwen_2_5_coder_7b" }) ?? registeredProfiles[0]
        } else if isLocalGGUFAllowed() {
            return registeredProfiles.first(where: { $0.profileId == "profile_qwen_2_5_coder_3b" }) ?? registeredProfiles[1]
        } else {
            return registeredProfiles.first(where: { $0.profileId == "profile_cloud_absolute_power" }) ?? registeredProfiles[2]
        }
    }
    
    /// Génère le prompt formaté selon le standard ChatML strict (<|im_start|>, <|im_end|>)
    public func formatChatMLPrompt(system: String, user: String) -> String {
        return """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        
        """
    }
    
    /// Récupère un profil par son identifiant
    public func getProfile(byId id: String) -> ModelProfile? {
        return registeredProfiles.first { $0.profileId == id }
    }
}


