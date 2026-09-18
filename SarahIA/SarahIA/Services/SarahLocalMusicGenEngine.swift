import Foundation
import AVFoundation
import CoreML
import ZIPFoundation

@available(iOS 16.0, *)
public final class SarahLocalMusicGenEngine {

    public static let shared = SarahLocalMusicGenEngine()

    public struct MusicIntent {
        public let isIntent: Bool
        public let wantsLyrics: Bool
        public let prompt: String
        public let language: String
    }

    public enum MusicError: LocalizedError {
        case emptyPrompt
        case modelsMissing
        case invalidPackage(String)
        case tokenizerMissing
        case predictionFailed(String)
        case audioWriteFailed

        public var errorDescription: String? {
            switch self {
            case .emptyPrompt: return "La description musicale est vide."
            case .modelsMissing: return "Le modèle musical local n'est pas installé."
            case .invalidPackage(let name): return "Le paquet Core ML \(name) est invalide."
            case .tokenizerMissing: return "Le vocabulaire du tokenizer musical est manquant."
            case .predictionFailed(let stage): return "Échec de l'inférence musicale : \(stage)."
            case .audioWriteFailed: return "Impossible d'enregistrer le fichier audio."
            }
        }
    }

    private struct Asset {
        let id: String
        let url: URL
        let compiledName: String?
        let isArchive: Bool
    }

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.sarahia.music.local", qos: .userInitiated)

    private var vocabulary: [String: Int32] = [:]
    private var t5Encoder: MLModel?
    private var numberEmbedder: MLModel?
    private var diffusionTransformer: MLModel?
    private var vaeDecoder: MLModel?

    private let eosToken: Int32 = 1
    private let padToken: Int32 = 0

    private static let sampleRate: Double = 44_100
    private static let latentChannels = 64
    private static let latentLength = 256
    private static let fullAudioSamples = 524_288
    private static let maxTokens = 64
    private static let maxConditionSeconds: Float = 256

    private init() {}

    public func detectIntent(_ text: String) -> MusicIntent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let triggers = [
            "génère une musique", "genere une musique", "génère un morceau",
            "genere un morceau", "compose une musique", "compose un morceau",
            "crée une musique", "cree une musique", "fais une musique",
            "fais un morceau", "generate music", "generate a song",
            "instrumental", "chanson avec paroles"
        ]

        let isIntent = triggers.contains { lower.contains($0) }
        let wantsLyrics =
            lower.contains("paroles")
            || lower.contains("lyrics")
            || lower.contains("chanson")
            || lower.contains("song")

        let language = (lower.contains("anglais") || lower.contains("english")) ? "en" : "fr"

        var prompt = clean
        for trigger in triggers {
            prompt = prompt.replacingOccurrences(of: trigger, with: "", options: .caseInsensitive)
        }
        prompt = prompt.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":,-"))
        )
        if prompt.isEmpty { prompt = clean }

        return MusicIntent(
            isIntent: isIntent,
            wantsLyrics: wantsLyrics,
            prompt: prompt,
            language: language
        )
    }

    public var modelDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent("stable-audio-open-small-coreml", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var assets: [Asset] {
        [
            Asset(
                id: "T5Encoder",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioT5Encoder.mlpackage.zip")!,
                compiledName: "T5Encoder.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "NumberEmbedder",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioNumberEmbedder.mlpackage.zip")!,
                compiledName: "NumberEmbedder.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "DiT",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioDiT.mlpackage.zip")!,
                compiledName: "DiT.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "VAEDecoder",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioVAEDecoder.mlpackage.zip")!,
                compiledName: "VAEDecoder.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "t5_vocab",
                url: URL(string: "https://raw.githubusercontent.com/john-rocky/CoreML-Models/main/sample_apps/StableAudioDemo/StableAudioDemo/t5_vocab.json")!,
                compiledName: nil,
                isArchive: false
            )
        ]
    }

    public var isInstalled: Bool {
        let required = [
            "T5Encoder.mlmodelc",
            "NumberEmbedder.mlmodelc",
            "DiT.mlmodelc",
            "VAEDecoder.mlmodelc",
            "t5_vocab.json"
        ]
        return required.allSatisfy {
            fm.fileExists(atPath: modelDirectory.appendingPathComponent($0).path)
        }
    }

    public func prepareModel(
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if isInstalled {
            do {
                try loadRuntime()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        installAsset(index: 0, progress: progress, completion: completion)
    }

    private func installAsset(
        index: Int,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard index < assets.count else {
            do {
                try loadRuntime()
                DispatchQueue.main.async {
                    progress(1, "Modèle musical prêt")
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
            return
        }

        let asset = assets[index]
        DispatchQueue.main.async {
            progress(Double(index) / Double(self.assets.count), "Téléchargement : \(asset.id)…")
        }

        URLSession.shared.downloadTask(with: asset.url) { [weak self] tempURL, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let tempURL = tempURL else {
                DispatchQueue.main.async { completion(.failure(MusicError.invalidPackage(asset.id))) }
                return
            }

            do {
                if asset.isArchive {
                    try self.installCompiledModel(downloadedArchive: tempURL, asset: asset)
                } else {
                    try self.installPlainFile(downloadedFile: tempURL, name: "t5_vocab.json")
                }

                DispatchQueue.main.async {
                    progress(Double(index + 1) / Double(self.assets.count), "Installé : \(asset.id)")
                }
                self.installAsset(index: index + 1, progress: progress, completion: completion)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func installPlainFile(downloadedFile: URL, name: String) throws {
        let destination = modelDirectory.appendingPathComponent(name)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: downloadedFile, to: destination)
    }

    private func installCompiledModel(downloadedArchive: URL, asset: Asset) throws {
        guard let compiledName = asset.compiledName else {
            throw MusicError.invalidPackage(asset.id)
        }

        let work = fm.temporaryDirectory.appendingPathComponent("sarah-music-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        try fm.unzipItem(at: downloadedArchive, to: work)

        guard let package = findFirstModelPackage(in: work) else {
            throw MusicError.invalidPackage(asset.id)
        }

        let compiled = try MLModel.compileModel(at: package)
        let destination = modelDirectory.appendingPathComponent(compiledName)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: compiled, to: destination)
    }

    private func findFirstModelPackage(in root: URL) -> URL? {
        if root.pathExtension == "mlpackage" { return root }
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return nil
        }
        for case let url as URL in e where url.pathExtension == "mlpackage" {
            return url
        }
        return nil
    }

    private func loadRuntime() throws {
        guard isInstalled else { throw MusicError.modelsMissing }
        try loadVocabulary()

        let normal = MLModelConfiguration()
        normal.computeUnits = .all

        let dit = MLModelConfiguration()
        dit.computeUnits = .cpuAndGPU

        t5Encoder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("T5Encoder.mlmodelc"),
            configuration: normal
        )
        numberEmbedder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("NumberEmbedder.mlmodelc"),
            configuration: normal
        )
        diffusionTransformer = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("DiT.mlmodelc"),
            configuration: dit
        )
        vaeDecoder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("VAEDecoder.mlmodelc"),
            configuration: normal
        )
    }

    private func loadVocabulary() throws {
        let url = modelDirectory.appendingPathComponent("t5_vocab.json")
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let mapping = raw as? [String: String] else {
            throw MusicError.tokenizerMissing
        }

        var parsed: [String: Int32] = [:]
        for (idText, piece) in mapping {
            if let id = Int32(idText) { parsed[piece] = id }
        }
        guard !parsed.isEmpty else { throw MusicError.tokenizerMissing }
        vocabulary = parsed
    }

    private func tokenize(_ prompt: String) -> [Int32] {
        let marker = "\u{2581}"
        let normalized = marker + prompt.lowercased().replacingOccurrences(of: " ", with: marker)
        var ids: [Int32] = []
        var cursor = normalized.startIndex

        while cursor < normalized.endIndex {
            let remaining = normalized.distance(from: cursor, to: normalized.endIndex)
            var found = false
            for length in stride(from: min(24, remaining), through: 1, by: -1) {
                guard let end = normalized.index(cursor, offsetBy: length, limitedBy: normalized.endIndex) else {
                    continue
                }
                let piece = String(normalized[cursor..<end])
                if let id = vocabulary[piece] {
                    ids.append(id)
                    cursor = end
                    found = true
                    break
                }
            }
            if !found { cursor = normalized.index(after: cursor) }
        }

        ids.append(eosToken)
        if ids.count >= Self.maxTokens {
            ids = Array(ids.prefix(Self.maxTokens - 1))
            ids.append(eosToken)
        }
        while ids.count < Self.maxTokens { ids.append(padToken) }
        return ids
    }

    public func generate(
        prompt: String,
        seconds: Float = 10,
        steps: Int = 8,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(MusicError.emptyPrompt))
            return
        }

        queue.async {
            do {
                if self.t5Encoder == nil { try self.loadRuntime() }
                let url = try self.render(
                    prompt: clean,
                    seconds: min(max(seconds, 1), 11.5),
                    steps: min(max(steps, 4), 16),
                    seed: UInt64.random(in: 1...UInt64.max)
                )
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedMusicReady"),
                        object: url,
                        userInfo: [
                            "prompt": clean,
                            "modelName": "Stable Audio Open Small · Core ML",
                            "isLocal": true
                        ]
                    )
                    completion(.success(url))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func render(prompt: String, seconds: Float, steps: Int, seed: UInt64) throws -> URL {
        guard let t5Encoder = t5Encoder,
              let numberEmbedder = numberEmbedder,
              let diffusionTransformer = diffusionTransformer,
              let vaeDecoder = vaeDecoder else {
            throw MusicError.modelsMissing
        }

        let tokens = tokenize(prompt)
        let inputIDs = try MLMultiArray(shape: [1, NSNumber(value: Self.maxTokens)], dataType: .int32)
        for i in 0..<Self.maxTokens { inputIDs[i] = NSNumber(value: tokens[i]) }

        let textProvider = try MLDictionaryFeatureProvider(dictionary: ["input_ids": inputIDs])
        let textResult = try t5Encoder.prediction(from: textProvider)
        guard let textEmbeddings = textResult.featureValue(for: "text_embeddings")?.multiArrayValue else {
            throw MusicError.predictionFailed("encodage du texte")
        }

        let activeCount = tokens.firstIndex(of: padToken) ?? Self.maxTokens
        sanitize(textEmbeddings, activeTokens: activeCount)

        let normalizedDuration = min(max(seconds, 0), Self.maxConditionSeconds) / Self.maxConditionSeconds
        let durationInput = try MLMultiArray(shape: [1], dataType: .float16)
        durationInput[0] = NSNumber(value: normalizedDuration)

        let durationProvider = try MLDictionaryFeatureProvider(dictionary: ["normalized_seconds": durationInput])
        let durationResult = try numberEmbedder.prediction(from: durationProvider)
        guard let durationEmbedding = durationResult.featureValue(for: "seconds_embedding")?.multiArrayValue else {
            throw MusicError.predictionFailed("conditionnement durée")
        }

        let crossAttention = try MLMultiArray(shape: [1, 65, 768], dataType: .float16)
        for token in 0..<64 {
            for channel in 0..<768 {
                crossAttention[[0, token, channel] as [NSNumber]] =
                    textEmbeddings[[0, token, channel] as [NSNumber]]
            }
        }

        let globalEmbedding = try MLMultiArray(shape: [1, 768], dataType: .float16)
        for channel in 0..<768 {
            let value = durationEmbedding[[0, channel] as [NSNumber]]
            crossAttention[[0, 64, channel] as [NSNumber]] = value
            globalEmbedding[[0, channel] as [NSNumber]] = value
        }

        var latent = try makeNoise(seed: seed)
        let schedule = makeSchedule(steps: steps)

        for step in 0..<steps {
            let timestep = try MLMultiArray(shape: [1], dataType: .float16)
            timestep[0] = NSNumber(value: schedule[step])

            let provider = try MLDictionaryFeatureProvider(dictionary: [
                "latent": latent,
                "timestep": timestep,
                "cross_attn_cond": crossAttention,
                "global_embed": globalEmbedding
            ])
            let prediction = try diffusionTransformer.prediction(from: provider)
            guard let velocity = prediction.featureValue(for: "velocity")?.multiArrayValue else {
                throw MusicError.predictionFailed("diffusion")
            }
            latent = try eulerAdvance(
                latent: latent,
                velocity: velocity,
                delta: schedule[step + 1] - schedule[step]
            )
        }

        let decoded = try vaeDecoder.prediction(
            from: MLDictionaryFeatureProvider(dictionary: ["latent": latent])
        )
        guard let audio = decoded.featureValue(for: "audio")?.multiArrayValue else {
            throw MusicError.predictionFailed("décodage audio")
        }
        return try saveAudio(audio, seconds: seconds, prompt: prompt)
    }

    private func sanitize(_ embeddings: MLMultiArray, activeTokens: Int) {
        for token in 0..<Self.maxTokens {
            for channel in 0..<768 {
                let index = [0, token, channel] as [NSNumber]
                let value = embeddings[index].floatValue
                if !value.isFinite || token >= activeTokens { embeddings[index] = 0 }
            }
        }
    }

    private func makeNoise(seed: UInt64) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, NSNumber(value: Self.latentChannels), NSNumber(value: Self.latentLength)],
            dataType: .float16
        )
        let pointer = array.dataPointer.assumingMemoryBound(to: Float16.self)
        let count = Self.latentChannels * Self.latentLength
        var rng = SarahSeededRandom(seed: seed)

        var i = 0
        while i < count {
            let u1 = Float.random(in: Float.leastNormalMagnitude...1, using: &rng)
            let u2 = Float.random(in: 0...1, using: &rng)
            let radius = sqrtf(-2 * logf(u1))
            let angle = 2 * Float.pi * u2
            pointer[i] = Float16(radius * cosf(angle))
            if i + 1 < count { pointer[i + 1] = Float16(radius * sinf(angle)) }
            i += 2
        }
        return array
    }

    private func makeSchedule(steps: Int) -> [Float] {
        var result: [Float] = []
        for i in 0...steps {
            let logSNR = -6 + Float(i) / Float(steps) * 8
            result.append(1 / (1 + expf(logSNR)))
        }
        if !result.isEmpty {
            result[0] = 1
            result[result.count - 1] = 0
        }
        return result
    }

    private func eulerAdvance(latent: MLMultiArray, velocity: MLMultiArray, delta: Float) throws -> MLMultiArray {
        let output = try MLMultiArray(shape: latent.shape, dataType: .float16)
        let count = Self.latentChannels * Self.latentLength
        let input = latent.dataPointer.assumingMemoryBound(to: Float16.self)
        let out = output.dataPointer.assumingMemoryBound(to: Float16.self)

        if velocity.dataType == .float32 {
            let v = velocity.dataPointer.assumingMemoryBound(to: Float.self)
            for i in 0..<count { out[i] = Float16(Float(input[i]) + delta * v[i]) }
        } else {
            let v = velocity.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<count { out[i] = Float16(Float(input[i]) + delta * Float(v[i])) }
        }
        return output
    }

    private func saveAudio(_ audio: MLMultiArray, seconds: Float, prompt: String) throws -> URL {
        let sampleCount = min(Int(seconds * Float(Self.sampleRate)), Self.fullAudioSamples)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 2,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)),
        let left = buffer.floatChannelData?[0],
        let right = buffer.floatChannelData?[1] else {
            throw MusicError.audioWriteFailed
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        for sample in 0..<sampleCount {
            left[sample] = audio[[0, 0, sample] as [NSNumber]].floatValue
            right[sample] = audio[[0, 1, sample] as [NSNumber]].floatValue
        }

        let root = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = root.appendingPathComponent("SarahIA/GeneratedMusic", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let safe = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()
        let url = dir.appendingPathComponent(
            "sarah-\(safe.isEmpty ? "music" : safe)-\(Int(Date().timeIntervalSince1970)).wav"
        )

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}

@available(iOS 16.0, *)
private struct SarahSeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
