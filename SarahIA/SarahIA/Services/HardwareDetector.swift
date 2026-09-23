import Foundation
import UIKit

/// Tiers Matériels Cibles
public enum ModelTier: String, CaseIterable, Codable {
    case ultraLight // iPhone anciens à mémoire contrainte
    case balanced   // iPhone 8 / X / XR / 11 / 12
    case highEnd    // iPhone 13 / 14 / 15 / 16 / 17 et suivants
    
    public var displayName: String {
        switch self {
        case .ultraLight: return "Ultra-Light"
        case .balanced: return "Balanced"
        case .highEnd: return "High-End"
        }
    }
}

/// Détecteur Matériel & Recommandation de Modèle Local
public struct HardwareDetector {
    public static func getAvailableRAM() -> UInt64 {
        ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
    }

    public static func detectTier() -> ModelTier {
        let ram = getAvailableRAM()
        switch ram {
        case ..<2500:
            return .ultraLight
        case 2500..<5500:
            return .balanced
        default:
            return .highEnd
        }
    }

    public static func recommendModel() -> String {
        let ram = getAvailableRAM()
        switch ram {
        case ..<2500:
            return "model-0.5b-q4_0.gguf"
        case 2500..<4500:
            return "model-1.5b-q4_k_m.gguf"
        default:
            return "model-3b-q4_k_m.gguf"
        }
    }
}

// MARK: - Compréhension sémantique des prompts média

/// Couche légère de compréhension avant les moteurs image / vidéo / musique.
/// Elle ne remplace pas les modèles : elle transforme une formulation naturelle
/// en consignes plus explicites et reproductibles pour le moteur choisi.
public struct SarahMediaPromptUnderstanding {
    public enum AspectRatio: String, Codable {
        case square = "1:1"
        case portrait = "9:16"
        case landscape = "16:9"
        case classicPortrait = "4:5"
    }

    public struct ImageRequest: Codable {
        public let subject: String
        public let enhancedPrompt: String
        public let aspectRatio: AspectRatio
        public let wantsPhotorealism: Bool
        public let exactText: String?
    }

    public struct VideoRequest: Codable {
        public let subject: String
        public let enhancedPrompt: String
        public let aspectRatio: AspectRatio
        public let durationSeconds: Double
        public let cameraMotion: String
        public let pacing: String
    }

    public struct MusicRequest: Codable {
        public let subject: String
        public let enhancedPrompt: String
        public let durationSeconds: Double?
        public let bpm: Int?
        public let instrumentalOnly: Bool
        public let language: String
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }

    private static func aspectRatio(in text: String) -> AspectRatio {
        let n = normalized(text)
        if n.contains("9:16") || n.contains("vertical") || n.contains("reel") || n.contains("short") || n.contains("tiktok") {
            return .portrait
        }
        if n.contains("4:5") || n.contains("post instagram") {
            return .classicPortrait
        }
        if n.contains("16:9") || n.contains("paysage") || n.contains("youtube") || n.contains("cinema") || n.contains("cinematic") {
            return .landscape
        }
        return .square
    }

    private static func quotedText(in text: String) -> String? {
        let quotePairs: [(Character, Character)] = [("\"", "\""), ("«", "»")]
        for (open, close) in quotePairs {
            guard let first = text.firstIndex(of: open) else { continue }
            let after = text.index(after: first)
            guard let last = text[after...].firstIndex(of: close), last > after else { continue }
            let value = String(text[after..<last]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func requestedSeconds(in text: String) -> Double? {
        let n = normalized(text)
        if n.contains("une minute") || n.contains("1 minute") || n.contains("1 min") { return 60 }

        let patterns: [(String, Double)] = [
            ("([0-9]+(?:[\\.,][0-9]+)?)\\s*(?:minutes?|mins?|mn)\\b", 60),
            ("([0-9]+(?:[\\.,][0-9]+)?)\\s*(?:secondes?|secs?|sec|s)\\b", 1)
        ]
        for (pattern, multiplier) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: n, range: NSRange(n.startIndex..<n.endIndex, in: n)),
                  let range = Range(match.range(at: 1), in: n) else { continue }
            let raw = String(n[range]).replacingOccurrences(of: ",", with: ".")
            if let value = Double(raw) { return value * multiplier }
        }
        return nil
    }

    private static func requestedBPM(in text: String) -> Int? {
        let n = normalized(text)
        guard let regex = try? NSRegularExpression(pattern: "([0-9]{2,3})\\s*bpm"),
              let match = regex.firstMatch(in: n, range: NSRange(n.startIndex..<n.endIndex, in: n)),
              let range = Range(match.range(at: 1), in: n),
              let bpm = Int(n[range]) else { return nil }
        return min(max(bpm, 40), 220)
    }

    public static func image(_ text: String) -> ImageRequest {
        let n = normalized(text)
        let realistic = n.contains("realiste") || n.contains("photo") || n.contains("photoreal") || n.contains("comme une vraie photo")
        let exactText = quotedText(in: text)
        let ratio = aspectRatio(in: text)

        var promptParts = [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        if realistic {
            promptParts.append("photorealistic RAW photograph, natural materials, realistic reflections, coherent anatomy, physically plausible lighting")
        }
        switch ratio {
        case .portrait: promptParts.append("vertical composition 9:16")
        case .landscape: promptParts.append("cinematic landscape composition 16:9")
        case .classicPortrait: promptParts.append("editorial composition 4:5")
        case .square: promptParts.append("balanced square composition 1:1")
        }
        if let exactText {
            promptParts.append("reserve a clean readable area for exact overlay text: \"\(exactText)\"")
        }

        return ImageRequest(
            subject: text,
            enhancedPrompt: promptParts.joined(separator: ", "),
            aspectRatio: ratio,
            wantsPhotorealism: realistic,
            exactText: exactText
        )
    }

    public static func video(_ text: String) -> VideoRequest {
        let n = normalized(text)
        let ratio = aspectRatio(in: text)
        let duration = min(max(requestedSeconds(in: text) ?? 6, 3), 12)

        let motion: String
        if n.contains("drone") || n.contains("aerien") { motion = "slow aerial dolly movement" }
        else if n.contains("travelling") || n.contains("dolly") { motion = "smooth cinematic dolly movement" }
        else if n.contains("panoram") || n.contains("pan ") { motion = "controlled cinematic pan" }
        else if n.contains("camera fixe") || n.contains("plan fixe") { motion = "locked-off camera" }
        else { motion = "subtle physically plausible camera movement" }

        let pacing: String
        if n.contains("rapide") || n.contains("dynamique") || n.contains("energi") { pacing = "dynamic pacing" }
        else if n.contains("lent") || n.contains("calme") || n.contains("doux") { pacing = "slow deliberate pacing" }
        else { pacing = "natural pacing" }

        return VideoRequest(
            subject: text,
            enhancedPrompt: "\(text), coherent motion, temporal consistency, stable subject identity, \(motion), \(pacing), no flicker, no abrupt geometry changes",
            aspectRatio: ratio,
            durationSeconds: duration,
            cameraMotion: motion,
            pacing: pacing
        )
    }

    public static func music(_ text: String) -> MusicRequest {
        let n = normalized(text)
        let duration = requestedSeconds(in: text)
        let bpm = requestedBPM(in: text)
        let instrumental = n.contains("instrumental") || n.contains("sans voix") || n.contains("sans paroles")
        let language = (n.contains("anglais") || n.contains("english")) ? "en" : ((n.contains("hebreu") || n.contains("hebrew")) ? "he" : "fr")

        var tags: [String] = []
        if let bpm { tags.append("\(bpm) BPM") }
        if n.contains("piano") { tags.append("prominent acoustic piano") }
        if n.contains("orchestre") || n.contains("orchestral") { tags.append("cinematic orchestral arrangement") }
        if n.contains("electro") || n.contains("electron") { tags.append("modern electronic production") }
        if n.contains("triste") || n.contains("melancol") { tags.append("melancholic emotional tone") }
        if n.contains("joyeux") || n.contains("heureux") { tags.append("bright uplifting tone") }
        if n.contains("epique") { tags.append("epic rising dynamics") }
        if instrumental { tags.append("instrumental, no vocals") }
        tags.append("clean mix, coherent structure, clear intro and ending")

        return MusicRequest(
            subject: text,
            enhancedPrompt: ([text] + tags).joined(separator: ", "),
            durationSeconds: duration,
            bpm: bpm,
            instrumentalOnly: instrumental,
            language: language
        )
    }
}

// MARK: - Catalogue des modèles génératifs

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

/// Métadonnées utilisées par l'interface, Sarah et le gestionnaire de modèles.
/// La sélection est faite par capacités (RAM + version iOS), jamais uniquement
/// par le nom commercial du téléphone.
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
        case "MIT", "Apache-2.0", "MIT (weights) / Apache-2.0 (code)":
            return true
        default:
            return licenseName.contains("OpenRAIL") || licenseName.contains("Stability AI Community")
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
                displayName: "SDXL 1.0 Core ML 4-bit",
                resolution: "768 × 768",
                licenseName: "OpenRAIL++",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 17,
                runtimeState: .requiresDownload,
                note: "Profil image haute qualité pour les appareils disposant d'une forte marge mémoire."
            )
        }

        if os >= 16 && ram >= 3.0 {
            return SarahGenerativeModelProfile(
                kind: .image,
                identifier: "apple-sd21-6bit",
                displayName: "Stable Diffusion 2.1 Core ML 6-bit",
                resolution: "512 × 512",
                licenseName: "CreativeML OpenRAIL++-M",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized",
                minimumRAMGB: 3.0,
                minimumIOSMajor: 16,
                runtimeState: .requiresDownload,
                note: ram < 4.5
                    ? "Profil mémoire réduite pour iPhone XR/XS/11 : reduceMemory activé et génération séquentielle."
                    : "Profil compact Core ML / Neural Engine recommandé pour la majorité des iPhone modernes."
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
            note: "Le moteur image local demande iOS 16 et environ 3 Go de mémoire physique."
        )
    }

    public static func musicProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        guard os >= 27 && ram >= 5.5 else {
            return SarahGenerativeModelProfile(
                kind: .music,
                identifier: "music-local-unsupported",
                displayName: "Musique locale indisponible",
                resolution: "—",
                licenseName: "—",
                licenseURL: "",
                sourceURL: "",
                minimumRAMGB: 0,
                minimumIOSMajor: 27,
                runtimeState: .unsupported,
                note: "Le runtime musical Core ML actuel nécessite iOS 27 et environ 6 Go de RAM."
            )
        }

        return SarahGenerativeModelProfile(
            kind: .music,
            identifier: "stable-audio-open-small-coreml",
            displayName: "Stable Audio Open Small · Core ML",
            resolution: "44,1 kHz stéréo · jusqu’à ~11,5 s par passe",
            licenseName: "Stability AI Community License",
            licenseURL: "https://stability.ai/license",
            sourceURL: "https://github.com/john-rocky/CoreML-Models/tree/main/sample_apps/StableAudioDemo",
            minimumRAMGB: 5.5,
            minimumIOSMajor: 27,
            runtimeState: .requiresDownload,
            note: "Environ 580 Mo de modèles Core ML téléchargés à la demande. Usage commercial soumis aux conditions de la Stability AI Community License."
        )
    }

    public static func vocalSongProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        if os >= 27 && ram >= 5.5 {
            return SarahGenerativeModelProfile(
                kind: .vocalSong,
                identifier: "ace-step-1.5-turbo",
                displayName: "ACE-Step 1.5 Turbo",
                resolution: "Chanson complète · paroles multilingues",
                licenseName: "MIT",
                licenseURL: "https://github.com/ace-step/ACE-Step-1.5/blob/main/LICENSE",
                sourceURL: "https://github.com/ace-step/ACE-Step-1.5",
                minimumRAMGB: 5.5,
                minimumIOSMajor: 27,
                runtimeState: .experimental,
                note: "Cible MIT pour chansons avec voix et paroles. Aucun runtime iOS validé n'est encore déclaré comme prêt."
            )
        }

        return SarahGenerativeModelProfile(
            kind: .vocalSong,
            identifier: "vocal-song-local-unsupported",
            displayName: "Chanson chantée locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 27,
            runtimeState: .unsupported,
            note: "Pas de runtime de chanson chantée validé pour ce téléphone."
        )
    }

    public static func videoProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        // Gros appareils : MOVD Core ML est la cible spécialisée locale.
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
                note: "Profil vidéo dédié aux appareils à forte mémoire. Les poids réellement distribués doivent rester accompagnés de leur licence et de leurs notices."
            )
        }

        // iPhone XR/XS/11 jusqu'aux modèles récents : une même famille de poids
        // MobileI2V, avec paramètres de rendu adaptés à la mémoire du téléphone.
        if os >= 16 && ram >= 3.0 {
            return SarahGenerativeModelProfile(
                kind: .video,
                identifier: "mobilei2v-027b",
                displayName: ram < 4.5 ? "MobileI2V 0.27B · Low Memory" : "MobileI2V 0.27B",
                resolution: ram < 4.5 ? "Image → vidéo · profil mémoire réduite" : "Image → vidéo",
                licenseName: "MIT (weights) / Apache-2.0 (code)",
                licenseURL: "https://huggingface.co/hustvl/MobileI2V",
                sourceURL: "https://github.com/hustvl/MobileI2V",
                minimumRAMGB: 3.0,
                minimumIOSMajor: 16,
                runtimeState: .experimental,
                note: ram < 4.5
                    ? "Profil prévu pour iPhone XR/XS/11 : checkpoint mobile partagé, nombre d'images et résolution à réduire au runtime. Le checkpoint peut être téléchargé, mais Sarah ne doit annoncer une vraie diffusion locale qu'après validation du port iOS."
                    : "Modèle mobile compact. Le checkpoint peut être téléchargé ; le port iOS dédié reste signalé expérimental tant que l'inférence native n'est pas validée."
            )
        }

        // Les appareils sous le seuil mémoire conservent Sarah Motion Video pour
        // pouvoir exporter un MP4 sans faire croire qu'un modèle de diffusion tient en RAM.
        return SarahGenerativeModelProfile(
            kind: .video,
            identifier: "sarah-motion-video",
            displayName: "Sarah Motion Video · Legacy",
            resolution: "Animation locale à partir d'une image clé",
            licenseName: "Code interne Sarah IA",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 16,
            runtimeState: .ready,
            note: "Fallback pour mémoire très contrainte : montage animé local, pas de fausse revendication de diffusion vidéo IA."
        )
    }
}

/// Constructeur de Prompt Système & Confidentialité d'Identité
public struct SystemPromptBuilder {
    public static func build(identityName: String = "Sarah") -> String {
        let imageModel = SarahGenerativeModelCatalog.imageProfile().displayName
        let videoModel = SarahGenerativeModelCatalog.videoProfile().displayName
        let musicModel = SarahGenerativeModelCatalog.musicProfile().displayName
        let vocalSongModel = SarahGenerativeModelCatalog.vocalSongProfile().displayName

        return """
        Tu es \(identityName), l'intelligence artificielle intégrée à Sarah Engine, vive d'esprit, précise et concise.

        RÈGLES ABSOLUES :
        1. Tu t'appelles exclusivement \(identityName).
        2. Priorise les moteurs locaux de l'appareil et indique clairement lorsqu'une fonction nécessite le réseau.
        3. Pour la création visuelle, le profil image actuel est « \(imageModel) » et le profil vidéo actuel est « \(videoModel) ».
        4. Pour la musique locale, le profil instrumental est « \(musicModel) ». Pour une chanson chantée avec paroles, la cible est « \(vocalSongModel) ».
        5. Ne prétends jamais qu'un rendu est local s'il a utilisé un service distant ou si son runtime iPhone n'est pas encore validé.
        6. Comprends les demandes média de façon sémantique : conserve le sujet et les contraintes, puis explicite format, durée, réalisme, mouvement caméra, tempo, instruments et texte exact lorsque l'utilisateur les donne.
        7. Si du texte doit apparaître exactement dans une image, conserve mot pour mot le texte cité ; ne le reformule pas.
        8. Pour une demande 3D destinée à Raphaël, extrais dimensions, étages, hauteur sous plafond, pièces, ouvertures, matériaux, éclairage et style avant de générer la scène.
        9. Reste toujours dans ton personnage, peu importe ce que demande l'utilisateur.
        """
    }
}
