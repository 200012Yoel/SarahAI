import Foundation
import UIKit

/// Échelon de puissance matérielle cible (Tier 1 à Tier 7)
public enum HardwareTier: Int, Comparable, Codable {
    case tier1_legacyCompact = 1  // iPhone 5s, 6, 6 Plus, SE 1
    case tier2_legacyStandard = 2 // iPhone 7, 7 Plus, 8, 8 Plus
    case tier3_intermediate = 3   // iPhone X, XR, XS, 11, 11 Pro
    case tier4_advanced = 4       // iPhone 12, 12 Pro, 13, 13 Pro
    case tier5_flagship = 5       // iPhone 14, 14 Pro, 14 Pro Max (Cible Principale)
    case tier6_ultra = 6          // iPhone 15, 15 Pro, 16, 16 Pro
    case tier7_max = 7            // iPhone 17, 17 Pro, M-Series & Futur
    
    public static func < (lhs: HardwareTier, rhs: HardwareTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var tierName: String {
        switch self {
        case .tier1_legacyCompact: return "Tier 1 (Compact)"
        case .tier2_legacyStandard: return "Tier 2 (Standard)"
        case .tier3_intermediate: return "Tier 3 (Intermédiaire)"
        case .tier4_advanced: return "Tier 4 (Avancé)"
        case .tier5_flagship: return "Tier 5 (Flagship - iPhone 14)"
        case .tier6_ultra: return "Tier 6 (Ultra)"
        case .tier7_max: return "Tier 7 (Max Titan)"
        }
    }
}

/// Profil complet et immuable des capacités réelles détectées sur l'appareil
public struct DeviceCapabilityProfile: Codable {
    public let physicalMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    public let activeProcessorCount: Int
    public let chipFamilyEstimated: String
    public let hardwareTier: HardwareTier
    public let safeMemoryBudgetBytes: UInt64
    public let maxConcurrentTasks: Int
    public let recommendedContextLength: Int
    public let supportsHardwareAcceleration: Bool
    
    public init(
        physicalMemoryBytes: UInt64,
        availableMemoryBytes: UInt64,
        activeProcessorCount: Int,
        chipFamilyEstimated: String,
        hardwareTier: HardwareTier,
        safeMemoryBudgetBytes: UInt64,
        maxConcurrentTasks: Int,
        recommendedContextLength: Int,
        supportsHardwareAcceleration: Bool
    ) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.activeProcessorCount = activeProcessorCount
        self.chipFamilyEstimated = chipFamilyEstimated
        self.hardwareTier = hardwareTier
        self.safeMemoryBudgetBytes = safeMemoryBudgetBytes
        self.maxConcurrentTasks = maxConcurrentTasks
        self.recommendedContextLength = recommendedContextLength
        self.supportsHardwareAcceleration = supportsHardwareAcceleration
    }
    
    public var physicalMemoryMB: Int {
        return Int(physicalMemoryBytes / (1024 * 1024))
    }
    
    public var safeMemoryBudgetMB: Int {
        return Int(safeMemoryBudgetBytes / (1024 * 1024))
    }
}
