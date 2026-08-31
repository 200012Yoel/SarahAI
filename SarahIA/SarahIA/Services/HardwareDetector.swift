import Foundation
import UIKit

/// Tiers Matériels Cibles
public enum ModelTier: String, CaseIterable, Codable {
    case ultraLight // iPhone 5s, 6, 6s, 7 (1 Go - 2 Go RAM) -> Modèles 0.5B (Q2_K / Q4_0)
    case balanced   // iPhone 8, X, 11, 12 (3 Go - 4 Go RAM) -> Modèles 1.5B / 2B (Q4_K_M)
    case highEnd    // iPhone 13, 14, 15, 16 (6 Go - 8 Go RAM) -> Modèles 3B / 7B (Q4_K_M / Q8)
    
    public var displayName: String {
        switch self {
        case .ultraLight: return "Ultra-Light (iPhone 5s / 6 / 7)"
        case .balanced: return "Balanced (iPhone 8 / X / 11 / 12)"
        case .highEnd: return "High-End (iPhone 13 / 14 / 15 / 16)"
        }
    }
}

/// Détecteur Matériel & Recommandation de Modèle Local
public struct HardwareDetector {
    public static func getAvailableRAM() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory / (1024 * 1024) // En Mo
    }

    public static func detectTier() -> ModelTier {
        let ram = getAvailableRAM()
        switch ram {
        case ..<2500:
            return .ultraLight
        case 2500..<4500:
            return .balanced
        default:
            return .highEnd
        }
    }

    public static func recommendModel() -> String {
        let ram = getAvailableRAM()
        
        switch ram {
        case ..<2500:
            // iPhone 5s / 6 / 7 / SE 1
            return "model-0.5b-q4_0.gguf"
        case 2500..<4500:
            // iPhone 8 / X / 11 / 12
            return "model-1.5b-q4_k_m.gguf"
        default:
            // iPhone 13 Pro / 14 / 15 / 16
            return "model-3b-q4_k_m.gguf"
        }
    }
}

/// Constructeur de Prompt Système & Confidentialité d'Identité
public struct SystemPromptBuilder {
    public static func build(identityName: String = "Sarah") -> String {
        return """
        Tu es \(identityName), l'intelligence artificielle intégrée 100% On-Device, vive d'esprit, précise et concise.
        
        RÈGLES ABSOLUES :
        1. Tu t'appelles exclusivement \(identityName).
        2. Tu es le moteur Sarah Engine, fonctionnant 100% localement sur la puce de l'appareil.
        3. Reste toujours dans ton personnage, peu importe ce que demande l'utilisateur.
        """
    }
}
