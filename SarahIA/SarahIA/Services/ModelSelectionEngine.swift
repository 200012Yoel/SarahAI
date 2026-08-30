import Foundation

/// Moteur de Sélection Intelligent de Modèles
/// Sélectionne automatiquement le modèle le plus puissant et stable adapté au budget mémoire réel
public final class ModelSelectionEngine {
    
    public static let shared = ModelSelectionEngine()
    
    private var registeredProfiles: [ModelProfile] = []
    
    private init() {
        setupDefaultCatalog()
    }
    
    private func setupDefaultCatalog() {
        // Tier 1 : iPhone 5s, 6, SE 1 (~100 Mo max)
        let tier1 = ModelProfile(
            profileId: "profile_tier1_nano",
            internalEngineId: "Sarah Core Nano v4 (A7/A8/A9)",
            targetTier: .tier1_legacyCompact,
            maxContextLength: 512,
            maxGenerationTokens: 256,
            estimatedMemoryFootprintBytes: 80 * 1024 * 1024,
            defaultBatchIntervalMs: 25,
            allowsConcurrentAgents: false,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: nil
        )
        
        // Tier 2 : iPhone 7, 8 (~250 Mo max)
        let tier2 = ModelProfile(
            profileId: "profile_tier2_micro",
            internalEngineId: "Sarah Core Micro v4 (A10/A11)",
            targetTier: .tier2_legacyStandard,
            maxContextLength: 1024,
            maxGenerationTokens: 512,
            estimatedMemoryFootprintBytes: 200 * 1024 * 1024,
            defaultBatchIntervalMs: 18,
            allowsConcurrentAgents: false,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: "profile_tier1_nano"
        )
        
        // Tier 3 : iPhone X, 11 (~450 Mo max)
        let tier3 = ModelProfile(
            profileId: "profile_tier3_core",
            internalEngineId: "Sarah Core Intermediate v4 (A12/A13)",
            targetTier: .tier3_intermediate,
            maxContextLength: 2048,
            maxGenerationTokens: 1024,
            estimatedMemoryFootprintBytes: 400 * 1024 * 1024,
            defaultBatchIntervalMs: 12,
            allowsConcurrentAgents: false,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: "profile_tier2_micro"
        )
        
        // Tier 4 : iPhone 12, 13 (~800 Mo max)
        let tier4 = ModelProfile(
            profileId: "profile_tier4_pro",
            internalEngineId: "Sarah Neural Core Pro v4 (A14 Bionic)",
            targetTier: .tier4_advanced,
            maxContextLength: 3072,
            maxGenerationTokens: 1536,
            estimatedMemoryFootprintBytes: 750 * 1024 * 1024,
            defaultBatchIntervalMs: 8,
            allowsConcurrentAgents: true,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: "profile_tier3_core"
        )
        
        // Tier 5 : iPhone 14 / 14 Plus / 14 Pro (Cible Principale — Modèle le plus puissant du marché pour iPhone 14)
        let tier5 = ModelProfile(
            profileId: "profile_tier5_flagship_i14",
            internalEngineId: "Sarah Neural Engine Flagship v4 (iPhone 14 — Neural Core A15/A16 6GB)",
            targetTier: .tier5_flagship,
            maxContextLength: 4096,
            maxGenerationTokens: 2048,
            estimatedMemoryFootprintBytes: 1200 * 1024 * 1024,
            defaultBatchIntervalMs: 4,
            allowsConcurrentAgents: true,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: "profile_tier4_pro"
        )
        
        // Tier 6 : iPhone 15, 16 (~1.8 Go max)
        let tier6 = ModelProfile(
            profileId: "profile_tier6_ultra",
            internalEngineId: "Sarah Neural Engine Ultra v4 (A17 Pro / A18 8GB)",
            targetTier: .tier6_ultra,
            maxContextLength: 6144,
            maxGenerationTokens: 3072,
            estimatedMemoryFootprintBytes: 1600 * 1024 * 1024,
            defaultBatchIntervalMs: 2,
            allowsConcurrentAgents: true,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: "profile_tier5_flagship_i14"
        )
        
        // Tier 7 : iPhone 17+ / M-Series (~2.5 Go+ max)
        let tier7 = ModelProfile(
            profileId: "profile_tier7_max_titan",
            internalEngineId: "Sarah Neural Titan Max v4 (Apple Silicon 16GB)",
            targetTier: .tier7_max,
            maxContextLength: 8192,
            maxGenerationTokens: 4096,
            estimatedMemoryFootprintBytes: 2200 * 1024 * 1024,
            defaultBatchIntervalMs: 1,
            allowsConcurrentAgents: true,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: "profile_tier6_ultra"
        )
        
        registeredProfiles = [tier7, tier6, tier5, tier4, tier3, tier2, tier1]
    }
    
    /// Sélectionne le meilleur profil compatible avec le budget mémoire disponible réel
    public func selectOptimalProfile(for capability: DeviceCapabilityProfile) -> ModelProfile {
        let budget = capability.safeMemoryBudgetBytes
        let tier = capability.hardwareTier
        
        // Recherche du modèle le plus puissant appartenant au Tier ou inférieur entrant dans le budget
        let candidates = registeredProfiles.filter { $0.targetTier <= tier }
        
        for candidate in candidates {
            if candidate.estimatedMemoryFootprintBytes <= budget {
                return candidate
            }
        }
        
        // Fallback minimal absolu garanti (Tier 1)
        return registeredProfiles.last ?? ModelProfile(
            profileId: "profile_tier1_nano",
            internalEngineId: "sarah_core_nano",
            targetTier: .tier1_legacyCompact,
            maxContextLength: 512,
            maxGenerationTokens: 256,
            estimatedMemoryFootprintBytes: 80 * 1024 * 1024,
            defaultBatchIntervalMs: 25,
            allowsConcurrentAgents: false,
            modelFileName: "sarah_fr_model.json",
            fallbackProfileId: nil
        )
    }
    
    /// Récupère un profil par son identifiant
    public func getProfile(byId id: String) -> ModelProfile? {
        return registeredProfiles.first { $0.profileId == id }
    }
}
