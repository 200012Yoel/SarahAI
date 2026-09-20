import Foundation
import UIKit
import CoreML

#if canImport(StableDiffusion)
import StableDiffusion
#endif

/// Moteur d'images local de Sarah.
///
/// Cette classe ne simule jamais une génération locale :
/// - le profil est choisi par SarahGenerativeModelCatalog,
/// - les ressources Core ML doivent réellement être présentes,
/// - le runtime StableDiffusion doit être lié au projet,
/// - sinon l'appel échoue explicitement au lieu de basculer silencieusement
///   vers un service réseau.
public final class SarahLocalImageGenEngine {

    public static let shared = SarahLocalImageGenEngine()

    public struct LCMConfiguration {
        public var steps: Int
        public var guidanceScale: Float
        public var width: Int
        public var height: Int
        public var seed: UInt32
        public var enablePhotorealismBoost: Bool

        public init(
            steps: Int = 24,
            guidanceScale: Float = 8.0,
            width: Int = 512,
            height: Int = 512,
            enablePhotorealismBoost: Bool = false
        ) {
            self.steps = max(1, min(steps, 50))
            self.guidanceScale = guidanceScale
            self.width = width
            self.height = height
            self.seed = UInt32.random(in: 0...UInt32.max)
            self.enablePhotorealismBoost = enablePhotorealismBoost
        }
    }

    public enum EngineStatus {
        case ready
        case missingModel
        case missingRuntime
        case generating(step: Int, totalSteps: Int)
        case error(String)
    }

    public var onStatusChanged: ((EngineStatus) -> Void)?

    private let fileManager = FileManager.default
    private let executionQueue = DispatchQueue(
        label: "com.sarahia.imagegen.local",
        qos: .userInitiated
    )

    private init() {
        checkLocalModelAvailability()
    }

    public static var modelIdentifier: String {
        SarahGenerativeModelCatalog.imageProfile().identifier
    }

    public static var modelDisplayName: String {
        SarahGenerativeModelCatalog.imageProfile().displayName
    }

    public var localModelDirectory: URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent(Self.modelIdentifier, isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return dir
    }

    /// Retrouve le dossier de ressources Core ML, même si l'archive Hugging Face
    /// contient un ou plusieurs dossiers parents.
    public func discoverResourceDirectory() -> URL? {
        let root = localModelDirectory

        if isValidResourceDirectory(root) {
            return root
        }

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            if isValidResourceDirectory(url) {
                return url
            }
        }

        return nil
    }

    public var isLocalLCMModelAvailable: Bool {
        discoverResourceDirectory() != nil
    }

    private func isValidResourceDirectory(_ dir: URL) -> Bool {
        let hasTextEncoder =
            fileManager.fileExists(atPath: dir.appendingPathComponent("TextEncoder.mlmodelc").path)

        let hasUNet =
            fileManager.fileExists(atPath: dir.appendingPathComponent("Unet.mlmodelc").path)
            || (
                fileManager.fileExists(atPath: dir.appendingPathComponent("UnetChunk1.mlmodelc").path)
                && fileManager.fileExists(atPath: dir.appendingPathComponent("UnetChunk2.mlmodelc").path)
            )

        let hasVAE =
            fileManager.fileExists(atPath: dir.appendingPathComponent("VAEDecoder.mlmodelc").path)

        let hasVocabulary =
            fileManager.fileExists(atPath: dir.appendingPathComponent("vocab.json").path)

        let hasMerges =
            fileManager.fileExists(atPath: dir.appendingPathComponent("merges.txt").path)
            || fileManager.fileExists(atPath: dir.appendingPathComponent("merges.text").path)

        return hasTextEncoder && hasUNet && hasVAE && hasVocabulary && hasMerges
    }

    public func checkLocalModelAvailability() {
        guard SarahGenerativeModelCatalog.imageProfile().runtimeState != .unsupported else {
            onStatusChanged?(.error("Génération d'images locale non prise en charge sur cet appareil."))
            return
        }

        guard isLocalLCMModelAvailable else {
            onStatusChanged?(.missingModel)
            return
        }

        #if canImport(StableDiffusion)
        onStatusChanged?(.ready)
        #else
        onStatusChanged?(.missingRuntime)
        #endif
    }

    public func generateImage(
        prompt: String,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        generateImage(
            prompt: prompt,
            config: LCMConfiguration(),
            progressHandler: nil,
            completion: completion
        )
    }

    public func generateImage(
        prompt: String,
        config: LCMConfiguration = LCMConfiguration(),
        progressHandler: ((Int, Int) -> Void)? = nil,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            completion(.failure(localError(
                code: 400,
                message: "Le prompt de génération d'image est vide."
            )))
            return
        }

        guard SarahGenerativeModelCatalog.imageProfile().runtimeState != .unsupported else {
            completion(.failure(localError(
                code: 410,
                message: "Cet iPhone ne prend pas en charge le profil d'image local sélectionné."
            )))
            return
        }

        guard isLocalLCMModelAvailable else {
            completion(.failure(localError(
                code: 404,
                message: "Le modèle Core ML local n'est pas installé."
            )))
            return
        }

        #if canImport(StableDiffusion)
        if #available(iOS 16.2, *) {
            runStableDiffusionPipeline(
                prompt: clean,
                config: config,
                progressHandler: progressHandler,
                completion: completion
            )
        } else {
            completion(.failure(localError(
                code: 426,
                message: "Le runtime Stable Diffusion local nécessite iOS 16.2 ou plus récent."
            )))
        }
        #else
        completion(.failure(localError(
            code: 501,
            message: "Le runtime StableDiffusion n'est pas encore lié à cette compilation."
        )))
        #endif
    }

    #if canImport(StableDiffusion)
    @available(iOS 16.2, *)
    private func runStableDiffusionPipeline(
        prompt: String,
        config: LCMConfiguration,
        progressHandler: ((Int, Int) -> Void)?,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        executionQueue.async { [weak self] in
            guard let self else { return }

            do {
                var pipelineConfig = StableDiffusionPipeline.Configuration(prompt: prompt)
                pipelineConfig.seed = UInt32(config.seed)
                pipelineConfig.stepCount = config.steps
                pipelineConfig.guidanceScale = Float(config.guidanceScale)

                let pipeline = try StableDiffusionPipeline(
                    resourcesAt: self.discoverResourceDirectory() ?? self.localModelDirectory,
                    controlNet: [],
                    configuration: MLModelConfiguration(),
                    disableSafety: false,
                    reduceMemory: true
                )

                try pipeline.loadResources()
                self.onStatusChanged?(.generating(step: 0, totalSteps: config.steps))

                let images = try pipeline.generateImages(
                    configuration: pipelineConfig
                ) { progress in
                    let step = min(config.steps, max(0, progress.step))
                    DispatchQueue.main.async {
                        progressHandler?(step, config.steps)
                        self.onStatusChanged?(.generating(step: step, totalSteps: config.steps))
                    }
                    return true
                }

                pipeline.unloadResources()

                guard let cgImage = images.compactMap({ $0 }).first else {
                    throw self.localError(
                        code: 500,
                        message: "Le pipeline local n'a produit aucune image."
                    )
                }

                let uiImage = UIImage(cgImage: cgImage)

                DispatchQueue.main.async {
                    self.onStatusChanged?(.ready)
                    completion(.success(uiImage))
                }
            } catch {
                DispatchQueue.main.async {
                    self.onStatusChanged?(.error(error.localizedDescription))
                    completion(.failure(error))
                }
            }
        }
    }
    #endif

    /// Emplacement prévu pour installer les ressources téléchargées par un
    /// gestionnaire de modèles. Cette méthode remplace l'ancien faux
    /// téléchargement qui écrivait simplement un fichier texte.
    public func expectedInstallDirectory() -> URL {
        localModelDirectory
    }

    private func localError(code: Int, message: String) -> NSError {
        NSError(
            domain: "SarahLocalImageGenEngine",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

// MARK: - Génération vidéo locale

/// Routage vidéo local de Sarah.
///
/// MobileI2V est sélectionné sur les appareils de classe iPhone 14 comme
/// candidat expérimental. MOVD est sélectionné sur les appareils plus puissants
/// lorsque la configuration publiée (iOS 18+, ~8 Go de RAM) est satisfaite.
///
/// Cette classe ne prétend pas qu'un portage est actif tant que les modèles
/// Core ML nécessaires ne sont pas réellement présents dans l'app.
public final class SarahLocalVideoGenEngine {

    public static let shared = SarahLocalVideoGenEngine()

    public struct VideoIntent {
        public let isIntent: Bool
        public let prompt: String
    }

    private let fileManager = FileManager.default

    private init() {}

    public var profile: SarahGenerativeModelProfile {
        SarahGenerativeModelCatalog.videoProfile()
    }

    public var localModelDirectory: URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent(profile.identifier, isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return dir
    }

    public func detectVideoIntent(_ text: String) -> VideoIntent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = clean
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let words = normalized.split(separator: " ").map(String.init)
        let wordSet = Set(words)

        let videoWords: Set<String> = [
            "video", "clip", "animation", "sequence", "film"
        ]

        let exactCreationWords: Set<String> = [
            "genere", "generer",
            "cree", "creer",
            "fais", "faire",
            "fabrique", "fabriquer",
            "produis", "produire",
            "anime", "animer",
            "generate", "create", "make"
        ]

        let creationPrefixes = [
            "gener", "cre", "fabri", "produ", "anim"
        ]

        let hasVideoWord = !wordSet.isDisjoint(with: videoWords)
        let hasCreationWord =
            !wordSet.isDisjoint(with: exactCreationWords)
            || words.contains(where: { word in
                creationPrefixes.contains(where: { word.hasPrefix($0) })
            })

        let asksCapability =
            normalized.contains("tu peux")
            || normalized.contains("peux tu")
            || normalized.contains("est ce que tu peux")
            || normalized.contains("j aimerais")
            || normalized.contains("je veux")

        // La dictée peut parfois transformer « génère-moi » en « généralement ».
        // On ne corrige ce cas que si un mot vidéo est aussi présent, pour éviter
        // de déclencher le moteur sur une phrase ordinaire.
        let noisyDictationCreation =
            hasVideoWord
            && words.contains(where: { $0 == "generalement" || $0 == "generalement" })

        guard hasVideoWord && (hasCreationWord || asksCapability || noisyDictationCreation) else {
            return VideoIntent(isIntent: false, prompt: "")
        }

        let removableWords: Set<String> = exactCreationWords.union([
            "une", "un", "de", "du", "des", "moi", "me", "la", "le",
            "petite", "petit", "courte", "court", "rapide",
            "video", "clip", "animation", "sequence", "film",
            "tu", "peux", "est", "ce", "que", "je", "veux", "aimerais",
            "generalement"
        ])

        let prompt = words
            .filter { word in
                !removableWords.contains(word)
                && !creationPrefixes.contains(where: { word.hasPrefix($0) })
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VideoIntent(
            isIntent: true,
            prompt: prompt
        )
    }

    /// Indique uniquement si un ensemble de ressources locales crédible est
    /// présent. L'inférence vidéo complète sera activée au moment où le
    /// runtime Core ML correspondant est intégré et validé sur l'appareil.
    public var hasInstalledRuntimeAssets: Bool {
        switch profile.identifier {
        case "movd-coreml":
            let names = ["T5.mlmodelc", "STDiT3.mlmodelc", "VAE"]
            return names.allSatisfy {
                fileManager.fileExists(
                    atPath: localModelDirectory.appendingPathComponent($0).path
                )
            }

        case "mobilei2v-027b":
            let names = ["MobileI2V.mlmodelc", "VideoVAE.mlmodelc"]
            return names.allSatisfy {
                fileManager.fileExists(
                    atPath: localModelDirectory.appendingPathComponent($0).path
                )
            }

        default:
            return false
        }
    }

    public func availabilityMessage() -> String {
        switch profile.runtimeState {
        case .unsupported:
            return "La génération vidéo locale n'est pas prise en charge sur cet appareil."

        case .experimental:
            return "Le profil \(profile.displayName) est sélectionné pour cet iPhone, mais son port Core ML iOS n'est pas encore validé dans cette version de Sarah."

        case .requiresDownload:
            if hasInstalledRuntimeAssets {
                return "Les ressources de \(profile.displayName) sont présentes, mais le runtime vidéo doit encore être validé avant activation."
            }
            return "Le profil \(profile.displayName) est compatible avec ce niveau de matériel, mais les ressources locales ne sont pas installées."

        case .ready:
            return "\(profile.displayName) est prêt."
        }
    }
}
