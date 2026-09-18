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

// MARK: - Catalogue des modèles génératifs

public enum SarahGenerativeMediaKind: String, Codable {
    case image
    case video
}

public enum SarahGenerativeRuntimeState: String, Codable {
    case ready
    case requiresDownload
    case experimental
    case unsupported
}

/// Métadonnées utilisées par l'interface, Sarah et le gestionnaire de modèles.
/// La sélection est faite par capacités (RAM + version iOS) afin de rester
/// compatible avec de futurs iPhone sans coder un numéro de modèle en dur.
public struct SarahGenerativeModelProfile: Codable, Equatable {
    public let kind: SarahGenerativeMediaKind
    public let identifier: String
    public let displayName: String
    public let resolution: String
    public let licenseName: String
    public let licenseURL: String
    public let sourceURL: String
    public let minimumRAMGB: Double
    public let minimumIOSMajor: Int
    public let runtimeState: SarahGenerativeRuntimeState
    public let note: String

    public var isCommerciallyDistributableWithConditions: Bool {
        switch licenseName {
        case "MIT", "Apache-2.0":
            return true
        default:
            // OpenRAIL autorise l'usage commercial, mais impose des restrictions
            // d'usage et des obligations propres aux poids du modèle.
            return licenseName.contains("OpenRAIL")
        }
    }
}

public struct SarahGenerativeModelCatalog {
    public static var physicalRAMGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
    }

    public static var iosMajor: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    public static func imageProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        if os >= 17 && ram >= 7.5 {
            return SarahGenerativeModelProfile(
                kind: .image,
                identifier: "apple-sdxl-1.0-ios-4bit",
                displayName: "SDXL 1.0 Core ML 4.04-bit",
                resolution: "768 × 768",
                licenseName: "OpenRAIL++",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 17,
                runtimeState: .requiresDownload,
                note: "Profil haute qualité pour les iPhone à mémoire élevée."
            )
        }

        if os >= 17 && ram >= 5.5 {
            return SarahGenerativeModelProfile(
                kind: .image,
                identifier: "apple-sd21-6bit",
                displayName: "Stable Diffusion 2.1 Core ML 6-bit",
                resolution: "512 × 512",
                licenseName: "CreativeML OpenRAIL++-M",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized",
                minimumRAMGB: 5.5,
                minimumIOSMajor: 17,
                runtimeState: .requiresDownload,
                note: "Profil recommandé pour iPhone 14 : compact, Core ML et Neural Engine."
            )
        }

        if os >= 16 && ram >= 4.0 {
            return SarahGenerativeModelProfile(
                kind: .image,
                identifier: "apple-sd21-base",
                displayName: "Stable Diffusion 2.1 Core ML",
                resolution: "512 × 512",
                licenseName: "CreativeML OpenRAIL++-M",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base",
                minimumRAMGB: 4.0,
                minimumIOSMajor: 16,
                runtimeState: .requiresDownload,
                note: "Profil compatible avec les iPhone A14/A15 disposant de moins de mémoire."
            )
        }

        return SarahGenerativeModelProfile(
            kind: .image,
            identifier: "image-local-unsupported",
            displayName: "Génération locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 0,
            runtimeState: .unsupported,
            note: "Cet appareil ne dispose pas d'un budget mémoire suffisant pour Stable Diffusion local."
        )
    }

    public static func videoProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        // MOVD fournit un pipeline Core ML et une app iOS de référence, avec
        // une exigence publiée : iPhone 15 Pro ou supérieur, iOS 18+.
        if os >= 18 && ram >= 7.5 {
            return SarahGenerativeModelProfile(
                kind: .video,
                identifier: "movd-coreml",
                displayName: "MOVD Core ML",
                resolution: "Texte → vidéo",
                licenseName: "MIT",
                licenseURL: "https://github.com/eai-lab/MOVD/blob/main/LICENSE",
                sourceURL: "https://github.com/eai-lab/MOVD",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 18,
                runtimeState: .requiresDownload,
                note: "Profil vidéo pour iPhone 15 Pro et appareils plus puissants. Les poids convertis doivent être audités avant distribution commerciale."
            )
        }

        // MobileI2V est très compact (0.27B) et sous Apache-2.0, mais son
        // dépôt public ne fournit pas encore un paquet Core ML iOS prêt à
        // intégrer. On le marque volontairement expérimental sur iPhone 14.
        if os >= 17 && ram >= 5.5 {
            return SarahGenerativeModelProfile(
                kind: .video,
                identifier: "mobilei2v-027b",
                displayName: "MobileI2V 0.27B",
                resolution: "Image → vidéo",
                licenseName: "Apache-2.0",
                licenseURL: "https://github.com/hustvl/MobileI2V/blob/main/LICENSE.txt",
                sourceURL: "https://github.com/hustvl/MobileI2V",
                minimumRAMGB: 5.5,
                minimumIOSMajor: 17,
                runtimeState: .experimental,
                note: "Candidat iPhone 14 : modèle mobile léger. Un port Core ML iOS vérifié reste nécessaire avant activation."
            )
        }

        return SarahGenerativeModelProfile(
            kind: .video,
            identifier: "video-local-unsupported",
            displayName: "Vidéo locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 0,
            runtimeState: .unsupported,
            note: "Pas de moteur vidéo local suffisamment vérifié pour ce matériel."
        )
    }
}

/// Constructeur de Prompt Système & Confidentialité d'Identité
public struct SystemPromptBuilder {
    public static func build(identityName: String = "Sarah") -> String {
        let imageModel = SarahGenerativeModelCatalog.imageProfile().displayName
        let videoModel = SarahGenerativeModelCatalog.videoProfile().displayName

        return """
        Tu es \(identityName), l'intelligence artificielle intégrée à Sarah Engine, vive d'esprit, précise et concise.

        RÈGLES ABSOLUES :
        1. Tu t'appelles exclusivement \(identityName).
        2. Priorise les moteurs locaux de l'appareil et indique clairement lorsqu'une fonction nécessite le réseau.
        3. Pour la création visuelle, le profil image actuel est « \(imageModel) » et le profil vidéo actuel est « \(videoModel) ».
        4. Ne prétends jamais qu'un rendu est local s'il a utilisé un service distant.
        5. Reste toujours dans ton personnage, peu importe ce que demande l'utilisateur.
        """
    }
}
