import Foundation
import UIKit
import CoreML

#if canImport(StableDiffusion)
import StableDiffusion
#endif

public final class SarahLocalImageGenEngine {

    public static let shared = SarahLocalImageGenEngine()

    public struct Configuration {
        public var steps: Int = 20
        public var guidanceScale: Float = 7.5
        public var seed: UInt32 = UInt32.random(in: 0...UInt32.max)

        public init() {}
    }

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.sarahia.imagegen.local", qos: .userInitiated)

    private init() {}

    public var modelDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent(SarahGenerativeModelCatalog.imageProfile().identifier, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func discoverResourceDirectory() -> URL? {
        if isValidResourceDirectory(modelDirectory) { return modelDirectory }

        guard let e = fm.enumerator(
            at: modelDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in e {
            if isValidResourceDirectory(url) { return url }
        }
        return nil
    }

    public var isInstalled: Bool {
        discoverResourceDirectory() != nil
    }

    private func isValidResourceDirectory(_ dir: URL) -> Bool {
        let textEncoder = fm.fileExists(atPath: dir.appendingPathComponent("TextEncoder.mlmodelc").path)
        let unet =
            fm.fileExists(atPath: dir.appendingPathComponent("Unet.mlmodelc").path)
            || (
                fm.fileExists(atPath: dir.appendingPathComponent("UnetChunk1.mlmodelc").path)
                && fm.fileExists(atPath: dir.appendingPathComponent("UnetChunk2.mlmodelc").path)
            )
        let vae = fm.fileExists(atPath: dir.appendingPathComponent("VAEDecoder.mlmodelc").path)
        let vocab = fm.fileExists(atPath: dir.appendingPathComponent("vocab.json").path)
        let merges =
            fm.fileExists(atPath: dir.appendingPathComponent("merges.txt").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("merges.text").path)
        return textEncoder && unet && vae && vocab && merges
    }

    public func generate(
        prompt: String,
        configuration: Configuration = Configuration(),
        progress: ((Int, Int) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(error(400, "Le prompt image est vide.")))
            return
        }

        guard let resources = discoverResourceDirectory() else {
            completion(.failure(error(404, "Le modèle image local n'est pas installé.")))
            return
        }

        #if canImport(StableDiffusion)
        guard #available(iOS 16.2, *) else {
            completion(.failure(error(426, "Stable Diffusion local nécessite iOS 16.2 ou plus.")))
            return
        }

        queue.async {
            do {
                var config = StableDiffusionPipeline.Configuration(prompt: clean)
                config.seed = configuration.seed
                config.stepCount = max(1, min(configuration.steps, 50))
                config.guidanceScale = configuration.guidanceScale

                let mlConfig = MLModelConfiguration()
                mlConfig.computeUnits = .all

                let pipeline = try StableDiffusionPipeline(
                    resourcesAt: resources,
                    controlNet: [],
                    configuration: mlConfig,
                    disableSafety: false,
                    reduceMemory: true
                )

                try pipeline.loadResources()
                let images = try pipeline.generateImages(configuration: config) { state in
                    DispatchQueue.main.async {
                        progress?(state.step, config.stepCount)
                    }
                    return true
                }
                pipeline.unloadResources()

                guard let cg = images.compactMap({ $0 }).first else {
                    throw self.error(500, "Aucune image produite.")
                }

                let image = UIImage(cgImage: cg)
                let url = try self.save(image: image, prompt: clean)

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedImageReady"),
                        object: url,
                        userInfo: [
                            "prompt": clean,
                            "modelName": SarahGenerativeModelCatalog.imageProfile().displayName,
                            "isLocal": true
                        ]
                    )
                    completion(.success(url))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        #else
        completion(.failure(error(501, "Le runtime StableDiffusion n'est pas lié à cette compilation.")))
        #endif
    }

    private func save(image: UIImage, prompt: String) throws -> URL {
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = root.appendingPathComponent("SarahIA/GeneratedImages", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let safe = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()
        let file = "sarah-\(safe.isEmpty ? "image" : safe)-\(Int(Date().timeIntervalSince1970)).jpg"
        let url = dir.appendingPathComponent(file)
        guard let data = image.jpegData(compressionQuality: 0.94) else {
            throw error(500, "Impossible d'encoder l'image.")
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private func error(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "SarahLocalImageGenEngine", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
