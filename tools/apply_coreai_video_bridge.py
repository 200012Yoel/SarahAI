from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_braced_function(text: str, signature: str, replacement: str) -> str:
    start = text.index(signature)
    brace = text.index("{", start)
    depth = 0
    end = None
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise RuntimeError(f"Unable to find end of {signature}")
    return text[:start] + replacement.rstrip() + text[end:]


def patch_hardware_detector() -> None:
    path = ROOT / "SarahIA/SarahIA/Services/HardwareDetector.swift"
    text = path.read_text(encoding="utf-8")

    text = text.replace(
        'case "MIT", "Apache-2.0", "MIT (weights) / Apache-2.0 (code)":',
        'case "MIT", "Apache-2.0", "MIT (weights) / Apache-2.0 (code)", "Code SarahIA":',
    )

    replacement = r'''    public static func videoProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        // iOS 27 + appareils à forte mémoire : voie Core AI.
        // Le paquet Wan doit être converti en .aimodel/.aimodelc avant exécution.
        // Core AI choisit ensuite automatiquement l'artefact adapté à l'architecture.
        if os >= 27 && ram >= 7.5 {
            return SarahGenerativeModelProfile(
                kind: .video,
                identifier: "wan21-coreai-1.3b-4bit",
                displayName: "Wan 2.1 1.3B · Core AI 4-bit",
                resolution: "480p adaptatif",
                licenseName: "Apache-2.0",
                licenseURL: "https://github.com/Wan-Video/Wan2.1/blob/main/LICENSE.txt",
                sourceURL: "https://github.com/Wan-Video/Wan2.1",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 27,
                runtimeState: .experimental,
                note: "Runtime Core AI intégré. Sarah recherche un paquet Wan21Sarah.<architecture>.aimodelc ou Wan21Sarah.aimodel converti. Si le paquet n'est pas présent, elle garde le moteur vidéo local de secours au lieu de planter."
            )
        }

        // iPhone 15 Pro / classe 8 Go sous iOS 18+ : MOVD Core ML est le
        // candidat mobile natif le plus réaliste actuellement publié.
        if os >= 18 && ram >= 7.5 {
            return SarahGenerativeModelProfile(
                kind: .video,
                identifier: "movd-coreml",
                displayName: "MOVD · Core ML",
                resolution: "profil mobile adaptatif",
                licenseName: "MIT",
                licenseURL: "https://github.com/eai-lab/MOVD/blob/main/LICENSE",
                sourceURL: "https://github.com/eai-lab/MOVD",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 18,
                runtimeState: .experimental,
                note: "Voie Core ML publiée pour iPhone 15 Pro et appareils supérieurs. Les MLPackage convertis restent nécessaires."
            )
        }

        // Appareils intermédiaires : MobileI2V est très compact mais son
        // checkpoint PyTorch doit encore être converti pour une vraie inférence iOS.
        if os >= 16 && ram >= 4.0 {
            return SarahGenerativeModelProfile(
                kind: .video,
                identifier: "mobilei2v-027b",
                displayName: "MobileI2V 0.27B",
                resolution: ram >= 5.5 ? "960p / 17 images (profil cible)" : "512p / mémoire réduite",
                licenseName: "Apache-2.0",
                licenseURL: "https://github.com/hustvl/MobileI2V/blob/main/LICENSE.txt",
                sourceURL: "https://github.com/hustvl/MobileI2V",
                minimumRAMGB: 4.0,
                minimumIOSMajor: 16,
                runtimeState: .experimental,
                note: "Profil compact pour iPhone intermédiaires. Sarah ne prétend pas exécuter le checkpoint tant qu'un runtime mobile converti n'est pas installé."
            )
        }

        // XR / XS / anciens appareils : aucun gros modèle n'est téléchargé.
        // Le moteur de mouvement local reste utilisable et évite les crashs mémoire.
        return SarahGenerativeModelProfile(
            kind: .video,
            identifier: "sarah-motion-video",
            displayName: "Sarah Motion Video",
            resolution: ram >= 3.0 ? "720p adaptatif" : "540p mémoire réduite",
            licenseName: "Code SarahIA",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 16,
            runtimeState: .ready,
            note: "Moteur vidéo local de compatibilité pour les iPhone anciens. Il anime une image clé localement et reste disponible quand les modèles de diffusion sont trop lourds."
        )
    }
'''
    text = replace_braced_function(
        text,
        "    public static func videoProfile() -> SarahGenerativeModelProfile",
        replacement,
    )
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def patch_video_engine() -> None:
    path = ROOT / "SarahIA/SarahIA/Services/SarahLocalImageGenEngine.swift"
    text = path.read_text(encoding="utf-8")

    if "import CoreAI" not in text:
        text = text.replace(
            "import CoreImage\n",
            "import CoreImage\n\n#if canImport(CoreAI)\nimport CoreAI\n#endif\n",
            1,
        )

    marker = "// MARK: - Génération vidéo locale"
    if "public actor SarahCoreAIVideoRuntime" not in text:
        bridge = r'''
#if canImport(CoreAI)
/// Pont Core AI iOS 27. Il ne fabrique pas un faux modèle : il ne s'active que
/// lorsqu'un vrai paquet .aimodel/.aimodelc est installé sur l'appareil.
@available(iOS 27.0, *)
public actor SarahCoreAIVideoRuntime {
    public static let shared = SarahCoreAIVideoRuntime()

    public struct PreparedModelInfo: Sendable {
        public let modelURL: URL
        public let deviceArchitecture: String
        public let functionName: String
    }

    private var loadedModel: AIModel?
    private var mainFunction: InferenceFunction?

    private init() {}

    public static var deviceArchitectureName: String {
        AIModel.deviceArchitectureName
    }

    public static func discoverInstalledModelURL() -> URL? {
        let fileManager = FileManager.default
        let architecture = AIModel.deviceArchitectureName
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent("wan21-coreai-1.3b-4bit", isDirectory: true)

        let candidates = [
            directory.appendingPathComponent("Wan21Sarah.\(architecture).aimodelc"),
            directory.appendingPathComponent("Wan21Sarah.aimodel")
        ]

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        if let compiled = Bundle.main.url(
            forResource: "Wan21Sarah.\(architecture)",
            withExtension: "aimodelc"
        ) {
            return compiled
        }

        return Bundle.main.url(forResource: "Wan21Sarah", withExtension: "aimodel")
    }

    public static var isInstalled: Bool {
        discoverInstalledModelURL() != nil
    }

    /// Spécialise et charge le modèle pour l'iPhone courant. La signature de
    /// génération vidéo reste volontairement séparée : elle dépend du paquet
    /// Wan converti et de ses fonctions exportées.
    public func prepare() async throws -> PreparedModelInfo {
        guard let modelURL = Self.discoverInstalledModelURL() else {
            throw NSError(
                domain: "SarahCoreAIVideoRuntime",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Paquet vidéo Core AI Wan 2.1 absent."]
            )
        }

        let model = try await AIModel(contentsOf: modelURL)
        guard let function = try model.loadFunction(named: "main") else {
            throw NSError(
                domain: "SarahCoreAIVideoRuntime",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Le paquet Core AI ne contient pas de fonction main exploitable."]
            )
        }

        loadedModel = model
        mainFunction = function

        return PreparedModelInfo(
            modelURL: modelURL,
            deviceArchitecture: AIModel.deviceArchitectureName,
            functionName: "main"
        )
    }
}
#endif

'''
        text = text.replace(marker, bridge + marker, 1)

    old_comment = '''/// MobileI2V est sélectionné sur les appareils de classe iPhone 14 comme
/// candidat expérimental. MOVD est sélectionné sur les appareils plus puissants
/// lorsque la configuration publiée (iOS 18+, ~8 Go de RAM) est satisfaite.
///
/// Cette classe ne prétend pas qu'un portage est actif tant que les modèles
/// Core ML nécessaires ne sont pas réellement présents dans l'app.'''
    new_comment = '''/// Le catalogue sélectionne automatiquement un backend selon la RAM et iOS :
/// Wan 2.1/Core AI sur les appareils iOS 27 compatibles, MOVD/MobileI2V sur
/// les profils intermédiaires, et Sarah Motion Video sur les appareils anciens.
///
/// Cette classe ne prétend jamais qu'un runtime de diffusion est actif tant que
/// son vrai paquet converti n'est pas présent. Le fallback vidéo local reste
/// disponible pour éviter un échec complet sur les iPhone moins puissants.'''
    text = text.replace(old_comment, new_comment)

    needle = '''    public var profile: SarahGenerativeModelProfile {
        SarahGenerativeModelCatalog.videoProfile()
    }
'''
    if "public var adaptiveBackendSummary" not in text:
        addition = needle + r'''
    public var adaptiveBackendSummary: String {
        let selected = profile
        switch selected.identifier {
        case "wan21-coreai-1.3b-4bit":
            #if canImport(CoreAI)
            if #available(iOS 27.0, *) {
                let installed = SarahCoreAIVideoRuntime.isInstalled
                return installed
                    ? "Wan 2.1 / Core AI installé pour \(SarahCoreAIVideoRuntime.deviceArchitectureName)"
                    : "Wan 2.1 / Core AI sélectionné, paquet absent : fallback Sarah Motion Video"
            }
            #endif
            return "Core AI indisponible : fallback Sarah Motion Video"
        case "movd-coreml":
            return "MOVD Core ML sélectionné, fallback local tant que les MLPackage ne sont pas installés"
        case "mobilei2v-027b":
            return "MobileI2V sélectionné, fallback local tant que le runtime converti n'est pas installé"
        default:
            return "Sarah Motion Video actif"
        }
    }
'''
        text = text.replace(needle, addition, 1)

    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def patch_downloader() -> None:
    path = ROOT / "SarahIA/SarahIA/Services/BackgroundModelDownloader.swift"
    text = path.read_text(encoding="utf-8")

    needle = '''    public func startVideoModelDownload() {
        let profile = SarahGenerativeModelCatalog.videoProfile()

        guard profile.identifier == "mobilei2v-027b" else {
            publishFailure("Le profil vidéo de cet appareil nécessite un paquet Core ML spécifique qui n'est pas distribué automatiquement.")
            return
        }
'''
    replacement = '''    public func startVideoModelDownload() {
        let profile = SarahGenerativeModelCatalog.videoProfile()

        if profile.identifier == "wan21-coreai-1.3b-4bit" {
            publishFailure("Le runtime Core AI iOS 27 est intégré. Il attend un paquet Wan21Sarah .aimodel/.aimodelc converti pour l'architecture de cet iPhone ; les poids PyTorch bruts ne sont pas installés comme s'ils étaient exécutables.")
            return
        }

        if profile.identifier == "movd-coreml" {
            publishFailure("MOVD nécessite les MLPackage convertis publiés par le projet. Sarah conserve le moteur vidéo local tant que ces paquets ne sont pas installés.")
            return
        }

        if profile.identifier == "sarah-motion-video" {
            publishFailure("Cet iPhone utilise Sarah Motion Video : aucun gros modèle vidéo supplémentaire n'est nécessaire.")
            return
        }

        guard profile.identifier == "mobilei2v-027b" else {
            publishFailure("Aucun paquet vidéo téléchargeable n'est configuré pour ce profil.")
            return
        }
'''
    if needle not in text:
        raise RuntimeError("startVideoModelDownload block not found")
    text = text.replace(needle, replacement, 1)

    path.write_text(text.rstrip() + "\n", encoding="utf-8")


if __name__ == "__main__":
    patch_hardware_detector()
    patch_video_engine()
    patch_downloader()
