import Foundation
import UIKit
import CoreML
import AVFoundation
import CoreImage

#if canImport(CoreAI)
import CoreAI
#endif

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
            steps: Int = 20,
            guidanceScale: Float = 7.5,
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

// MARK: - Génération vidéo locale

/// Routage vidéo local de Sarah.
///
/// Le catalogue sélectionne automatiquement un backend selon la RAM et iOS :
/// Wan 2.1/Core AI sur les appareils iOS 27 compatibles, MOVD/MobileI2V sur
/// les profils intermédiaires, et Sarah Motion Video sur les appareils anciens.
///
/// Cette classe ne prétend jamais qu'un runtime de diffusion est actif tant que
/// son vrai paquet converti n'est pas présent. Le fallback vidéo local reste
/// disponible pour éviter un échec complet sur les iPhone moins puissants.
public final class SarahLocalVideoGenEngine {

    public static let shared = SarahLocalVideoGenEngine()

    public struct VideoIntent {
        public let isIntent: Bool
        public let prompt: String
        public let duration: TimeInterval
        public let isVertical: Bool
    }

    public enum VideoError: LocalizedError {
        case emptyPrompt
        case keyframeGenerationFailed(String)
        case imageConversionFailed
        case writerCreationFailed
        case pixelBufferFailed
        case exportFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .emptyPrompt:
                return "La description de la vidéo est vide."
            case .keyframeGenerationFailed(let reason):
                return "Impossible de créer l'image de départ : \(reason)"
            case .imageConversionFailed:
                return "Impossible de préparer l'image pour la vidéo."
            case .writerCreationFailed:
                return "Impossible de démarrer l'encodeur vidéo."
            case .pixelBufferFailed:
                return "Impossible de créer une image vidéo."
            case .exportFailed(let reason):
                return "Échec de l'export vidéo : \(reason)"
            case .cancelled:
                return "La génération vidéo a été arrêtée."
            }
        }
    }

    private let fileManager = FileManager.default
    private let renderQueue = DispatchQueue(
        label: "com.sarahia.video.motion",
        qos: .userInitiated
    )
    private let ciContext = CIContext(options: [
        .cacheIntermediates: false
    ])
    private let generationLock = NSLock()
    private var activeGenerationID: UUID?

    private init() {}

    public var profile: SarahGenerativeModelProfile {
        SarahGenerativeModelCatalog.videoProfile()
    }

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
        let semanticVideo = SarahMediaPromptUnderstanding.video(clean)
        let lower = clean
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
            .lowercased()

        let triggers = [
            "genere une video", "genere-moi une video", "genere moi une video",
            "cree une video", "cree-moi une video", "cree moi une video",
            "fais une video", "fabrique une video",
            "generate a video", "create a video",
            "cree un short", "genere un short", "fais un short",
            "cree un reel", "genere un reel"
        ]

        guard let trigger = triggers.first(where: { lower.contains($0) }) else {
            return VideoIntent(
                isIntent: false,
                prompt: "",
                duration: 6,
                isVertical: false
            )
        }

        var prompt = clean
        if let range = lower.range(of: trigger) {
            let distance = lower.distance(
                from: lower.startIndex,
                to: range.upperBound
            )
            let safeDistance = min(distance, clean.count)
            let index = clean.index(
                clean.startIndex,
                offsetBy: safeDistance
            )
            prompt = String(clean[index...])
        }

        prompt = removingVideoDuration(from: prompt)
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
                    .union(CharacterSet(charactersIn: ":,-."))
            )

        if prompt.isEmpty {
            prompt = "scène cinématique élégante"
        }

        let vertical =
            lower.contains("short")
            || lower.contains("reel")
            || lower.contains("tiktok")
            || lower.contains("vertical")
            || lower.contains("9:16")

        return VideoIntent(
            isIntent: true,
            prompt: semanticVideo.enhancedPrompt,
            duration: semanticVideo.durationSeconds,
            isVertical: semanticVideo.aspectRatio == .portrait
        )
    }

    private func requestedDuration(from text: String) -> TimeInterval? {
        let normalized = text
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
            .lowercased()

        let pattern = "([0-9]+(?:[\\.,][0-9]+)?)\\s*(?:secondes?|secs?|sec|s)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: normalized,
                range: NSRange(
                    normalized.startIndex..<normalized.endIndex,
                    in: normalized
                )
              ),
              let range = Range(match.range(at: 1), in: normalized) else {
            return nil
        }

        let raw = String(normalized[range])
            .replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(raw) else { return nil }
        return min(max(seconds, 3), 12)
    }

    private func removingVideoDuration(from text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "(?i)\\b(?:de\\s+)?[0-9]+(?:[\\.,][0-9]+)?\\s*(?:secondes?|secs?|sec|s)\\b"
        ) else {
            return text
        }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text),
            withTemplate: " "
        )
    }

    /// Génération vidéo immédiatement utilisable sur iPhone.
    ///
    /// Sarah crée d'abord une image clé avec le moteur image sélectionné, puis
    /// produit localement un MP4 animé (zoom/panoramique cinématique). Cette
    /// voie est distincte d'un vrai modèle de diffusion vidéo comme MOVD ou
    /// MobileI2V, dont les runtimes Core ML restent signalés comme expérimentaux.
    public func generateVideo(
        prompt: String,
        duration: TimeInterval = 6,
        vertical: Bool = false,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(VideoError.emptyPrompt))
            return
        }

        let safeDuration = min(max(duration, 3), 12)
        let generationID = beginGeneration()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("SarahVideoGenerationProgress"),
                object: nil,
                userInfo: [
                    "prompt": clean,
                    "progress": 0.03,
                    "phase": "Création de l’image clé",
                    "duration": safeDuration,
                    "vertical": vertical
                ]
            )
        }

        OpenSourceImageGenerationService.shared.generateImage(
            prompt: clean,
            width: vertical ? 768 : 1024,
            height: vertical ? 1024 : 768,
            model: "flux",
            notifyChat: false
        ) { [weak self] result in
            guard let self = self else { return }

            guard self.isGenerationCurrent(generationID) else {
                completion(.failure(VideoError.cancelled))
                return
            }

            guard result.isSuccess, let image = result.image else {
                let error = VideoError.keyframeGenerationFailed(
                    result.errorMessage ?? "moteur image indisponible"
                )
                self.finishGeneration(generationID)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahVideoGenerationFailed"),
                        object: nil,
                        userInfo: [
                            "prompt": clean,
                            "error": error.localizedDescription
                        ]
                    )
                    completion(.failure(error))
                }
                return
            }

            self.renderQueue.async {
                do {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SarahVideoGenerationProgress"),
                            object: nil,
                            userInfo: [
                                "prompt": clean,
                                "progress": 0.20,
                                "phase": "Animation de la scène",
                                "duration": safeDuration,
                                "vertical": vertical
                            ]
                        )
                    }

                    let url = try self.renderMotionVideo(
                        image: image,
                        prompt: clean,
                        duration: safeDuration,
                        vertical: vertical,
                        generationID: generationID
                    )

                    self.finishGeneration(generationID)

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SarahGeneratedVideoReady"),
                            object: url,
                            userInfo: [
                                "prompt": clean,
                                "duration": safeDuration,
                                "vertical": vertical,
                                "engineName": "Sarah Motion Video",
                                "isLocalMotionRender": true
                            ]
                        )
                        completion(.success(url))
                    }
                } catch {
                    self.finishGeneration(generationID)

                    let wasCancelled: Bool
                    if let videoError = error as? VideoError,
                       case .cancelled = videoError {
                        wasCancelled = true
                    } else {
                        wasCancelled = false
                    }

                    DispatchQueue.main.async {
                        if wasCancelled {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SarahVideoGenerationCancelled"),
                                object: nil,
                                userInfo: ["prompt": clean]
                            )
                        } else {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SarahVideoGenerationFailed"),
                                object: nil,
                                userInfo: [
                                    "prompt": clean,
                                    "error": error.localizedDescription
                                ]
                            )
                        }
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    private func renderMotionVideo(
        image: UIImage,
        prompt: String,
        duration: TimeInterval,
        vertical: Bool,
        generationID: UUID
    ) throws -> URL {
        guard isGenerationCurrent(generationID) else {
            throw VideoError.cancelled
        }
        guard let ciImage = CIImage(image: image) else {
            throw VideoError.imageConversionFailed
        }

        let width = vertical ? 720 : 1280
        let height = vertical ? 1280 : 720
        let fps: Int32 = 24
        let totalFrames = max(1, Int(duration * Double(fps)))

        let outputURL = generatedVideoURL(prompt: prompt)
        try? fileManager.removeItem(at: outputURL)

        let writer = try AVAssetWriter(
            outputURL: outputURL,
            fileType: .mp4
        )

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: vertical ? 5_500_000 : 6_500_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )

        guard writer.canAdd(input) else {
            throw VideoError.writerCreationFailed
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw VideoError.exportFailed(
                writer.error?.localizedDescription ?? "démarrage impossible"
            )
        }
        writer.startSession(atSourceTime: .zero)

        let target = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: height
        )
        let background = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        ).cropped(to: target)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for frameIndex in 0..<totalFrames {
            guard isGenerationCurrent(generationID) else {
                writer.cancelWriting()
                throw VideoError.cancelled
            }

            while !input.isReadyForMoreMediaData {
                if writer.status == .failed {
                    throw VideoError.exportFailed(
                        writer.error?.localizedDescription ?? "encodeur interrompu"
                    )
                }
                Thread.sleep(forTimeInterval: 0.002)
            }

            guard let pool = adaptor.pixelBufferPool else {
                throw VideoError.pixelBufferFailed
            }

            var optionalBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(
                nil,
                pool,
                &optionalBuffer
            )
            guard status == kCVReturnSuccess,
                  let pixelBuffer = optionalBuffer else {
                throw VideoError.pixelBufferFailed
            }

            let progress = CGFloat(frameIndex) / CGFloat(max(totalFrames - 1, 1))
            let baseScale = max(
                CGFloat(width) / ciImage.extent.width,
                CGFloat(height) / ciImage.extent.height
            )
            let zoom = baseScale * (1.0 + 0.09 * progress)

            var frameImage = ciImage.transformed(
                by: CGAffineTransform(
                    scaleX: zoom,
                    y: zoom
                )
            )

            let extent = frameImage.extent
            let travel = max(0, extent.width - CGFloat(width))
            let pan = travel * (0.18 + 0.64 * progress)
            let x = -pan
            let y = (CGFloat(height) - extent.height) / 2

            frameImage = frameImage.transformed(
                by: CGAffineTransform(
                    translationX: x - extent.minX,
                    y: y - extent.minY
                )
            )

            frameImage = frameImage
                .composited(over: background)
                .cropped(to: target)

            ciContext.render(
                frameImage,
                to: pixelBuffer,
                bounds: target,
                colorSpace: colorSpace
            )

            let time = CMTime(
                value: Int64(frameIndex),
                timescale: fps
            )

            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw VideoError.exportFailed(
                    writer.error?.localizedDescription ?? "image refusée"
                )
            }

            if frameIndex % 6 == 0 {
                let renderProgress =
                    0.20 + 0.78 * Double(frameIndex + 1) / Double(totalFrames)

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahVideoGenerationProgress"),
                        object: nil,
                        userInfo: [
                            "prompt": prompt,
                            "progress": min(renderProgress, 0.98),
                            "phase": "Encodage vidéo",
                            "duration": duration,
                            "vertical": vertical
                        ]
                    )
                }
            }
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw VideoError.exportFailed(
                writer.error?.localizedDescription ?? "export incomplet"
            )
        }

        return outputURL
    }

    private func generatedVideoURL(prompt: String) -> URL {
        let base = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        let directory = base
            .appendingPathComponent("SarahIA", isDirectory: true)
            .appendingPathComponent("GeneratedVideos", isDirectory: true)

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let safe = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()

        return directory.appendingPathComponent(
            "sarah-"
            + (safe.isEmpty ? "video" : safe)
            + "-"
            + String(UUID().uuidString.prefix(8))
            + ".mp4"
        )
    }

    public func cancelCurrentGeneration() {
        generationLock.lock()
        activeGenerationID = nil
        generationLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("SarahVideoGenerationCancelled"),
                object: nil
            )
        }
    }

    private func beginGeneration() -> UUID {
        let id = UUID()
        generationLock.lock()
        activeGenerationID = id
        generationLock.unlock()
        return id
    }

    private func isGenerationCurrent(_ id: UUID) -> Bool {
        generationLock.lock()
        let current = activeGenerationID == id
        generationLock.unlock()
        return current
    }

    private func finishGeneration(_ id: UUID) {
        generationLock.lock()
        if activeGenerationID == id {
            activeGenerationID = nil
        }
        generationLock.unlock()
    }

    /// Vrai uniquement pour les runtimes de diffusion vidéo dédiés.
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
        let diffusionDetail: String
        switch profile.runtimeState {
        case .unsupported:
            diffusionDetail = "Le modèle de diffusion vidéo dédié n'est pas disponible sur cet appareil."
        case .experimental:
            diffusionDetail = "\(profile.displayName) reste expérimental sur iPhone."
        case .requiresDownload:
            diffusionDetail = hasInstalledRuntimeAssets
                ? "Les ressources de \(profile.displayName) sont présentes, mais son runtime doit encore être validé."
                : "Les ressources de \(profile.displayName) ne sont pas encore installées."
        case .ready:
            diffusionDetail = "\(profile.displayName) est prêt."
        }

        return "Sarah Motion Video est prêt : Sarah peut générer une image clé puis produire localement un MP4 animé. \(diffusionDetail)"
    }
}
