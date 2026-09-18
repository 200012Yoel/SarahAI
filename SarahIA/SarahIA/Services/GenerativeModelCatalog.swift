import Foundation

public enum SarahGenerativeMediaKind: String, Codable {
    case image
    case video
    case music
    case vocalSong
}

public enum SarahGenerativeRuntimeState: String, Codable {
    case ready
    case requiresDownload
    case experimental
    case unsupported
}

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
            return .init(
                kind: .image,
                identifier: "apple-sdxl-1.0-ios-4bit",
                displayName: "SDXL 1.0 Core ML 4-bit",
                resolution: "768 × 768",
                licenseName: "OpenRAIL++",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 17,
                runtimeState: .requiresDownload,
                note: "Profil haute qualité pour les iPhone disposant d'environ 8 Go de RAM ou plus."
            )
        }

        if os >= 17 && ram >= 5.5 {
            return .init(
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
                note: "Profil recommandé pour iPhone 14 : compact et optimisé Core ML."
            )
        }

        if os >= 16 && ram >= 4.0 {
            return .init(
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
                note: "Profil compatible avec les iPhone plus anciens disposant d'au moins 4 Go de RAM."
            )
        }

        return .init(
            kind: .image,
            identifier: "image-local-unsupported",
            displayName: "Image locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 16,
            runtimeState: .unsupported,
            note: "Mémoire insuffisante pour Stable Diffusion local."
        )
    }

    public static func videoProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        if os >= 18 && ram >= 7.5 {
            return .init(
                kind: .video,
                identifier: "movd-coreml",
                displayName: "MOVD Core ML",
                resolution: "Texte → vidéo",
                licenseName: "MIT",
                licenseURL: "https://github.com/eai-lab/MOVD/blob/main/LICENSE",
                sourceURL: "https://github.com/eai-lab/MOVD",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 18,
                runtimeState: .experimental,
                note: "Profil vidéo pour les iPhone puissants. Le runtime doit encore être validé dans Sarah avant activation."
            )
        }

        if os >= 17 && ram >= 5.5 {
            return .init(
                kind: .video,
                identifier: "mobilei2v-027b",
                displayName: "MobileI2V 0.27B",
                resolution: "Image → vidéo",
                licenseName: "MIT (poids) / Apache-2.0 (code)",
                licenseURL: "https://huggingface.co/hustvl/MobileI2V",
                sourceURL: "https://github.com/hustvl/MobileI2V",
                minimumRAMGB: 5.5,
                minimumIOSMajor: 17,
                runtimeState: .experimental,
                note: "Profil iPhone 14. Le checkpoint est téléchargeable, mais le runtime iOS public n'est pas encore prêt : Sarah ne prétend pas générer tant que l'inférence locale n'est pas validée."
            )
        }

        return .init(
            kind: .video,
            identifier: "video-local-unsupported",
            displayName: "Vidéo locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 16,
            runtimeState: .unsupported,
            note: "Pas de moteur vidéo local vérifié pour ce matériel."
        )
    }

    public static func musicProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        guard os >= 16 && ram >= 5.5 else {
            return .init(
                kind: .music,
                identifier: "music-local-unsupported",
                displayName: "Musique locale indisponible",
                resolution: "—",
                licenseName: "—",
                licenseURL: "",
                sourceURL: "",
                minimumRAMGB: 0,
                minimumIOSMajor: 16,
                runtimeState: .unsupported,
                note: "La génération musicale demande environ 6 Go de RAM."
            )
        }

        return .init(
            kind: .music,
            identifier: "stable-audio-open-small-coreml",
            displayName: "Stable Audio Open Small · Core ML",
            resolution: "44,1 kHz stéréo · ~10 s",
            licenseName: "Stability AI Community License",
            licenseURL: "https://stability.ai/license",
            sourceURL: "https://github.com/john-rocky/CoreML-Models/tree/main/sample_apps/StableAudioDemo",
            minimumRAMGB: 5.5,
            minimumIOSMajor: 16,
            runtimeState: .requiresDownload,
            note: "Profil iPhone 14 : environ 580 Mo de modèles Core ML téléchargés à la demande."
        )
    }

    public static func vocalSongProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        guard os >= 16 && ram >= 5.5 else {
            return .init(
                kind: .vocalSong,
                identifier: "vocal-song-local-unsupported",
                displayName: "Chanson chantée locale indisponible",
                resolution: "—",
                licenseName: "—",
                licenseURL: "",
                sourceURL: "",
                minimumRAMGB: 0,
                minimumIOSMajor: 16,
                runtimeState: .unsupported,
                note: "Pas de runtime de chant local validé pour cet appareil."
            )
        }

        return .init(
            kind: .vocalSong,
            identifier: "ace-step-1.5-turbo",
            displayName: "ACE-Step 1.5 Turbo",
            resolution: "Chanson complète · paroles multilingues",
            licenseName: "MIT",
            licenseURL: "https://github.com/ace-step/ACE-Step-1.5/blob/main/LICENSE",
            sourceURL: "https://github.com/ace-step/ACE-Step-1.5",
            minimumRAMGB: 5.5,
            minimumIOSMajor: 16,
            runtimeState: .experimental,
            note: "Cible pour chansons chantées en français et anglais. Pas encore activée sur iPhone faute de runtime iOS local validé."
        )
    }
}
