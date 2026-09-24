import Foundation
import AVFoundation
import CoreML
import ZIPFoundation

/// Générateur musical réellement local pour Sarah IA.
///
/// Profil iPhone 14 / iOS 27 : Stable Audio Open Small converti en Core ML.
/// Les poids ne sont pas embarqués dans l'IPA : ils sont téléchargés à la demande,
/// compilés sur l'appareil, puis toutes les générations suivantes restent locales.
@available(iOS 27.0, *)
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
        case vocalSongRuntimeUnavailable

        public var errorDescription: String? {
            switch self {
            case .emptyPrompt:
                return "La description musicale est vide."
            case .modelsMissing:
                return "Le modèle musical local n'est pas encore installé."
            case .invalidPackage(let name):
                return "Le paquet Core ML \(name) est invalide."
            case .tokenizerMissing:
                return "Le vocabulaire du tokenizer musical est manquant."
            case .predictionFailed(let stage):
                return "Échec de l'inférence locale pendant : \(stage)."
            case .audioWriteFailed:
                return "Impossible d'enregistrer le fichier audio généré."
            case .vocalSongRuntimeUnavailable:
                return "Le moteur de chanson chantée n'a pas encore de runtime iPhone validé."
            }
        }
    }

    private struct Asset {
        let id: String
        let url: URL
        let compiledName: String?
        let isArchive: Bool
    }

    public struct DownloadAssetDescriptor {
        public let id: String
        public let url: URL
    }

    private static let sampleRate: Double = 44_100
    private static let latentChannels = 64
    private static let latentLength = 256
    private static let fullAudioSamples = 524_288
    private static let maxTokens = 64
    private static let maxConditionSeconds: Float = 256

    private let fm = FileManager.default
    private var vocabulary: [String: Int32] = [:]
    private var t5Encoder: MLModel?
    private var numberEmbedder: MLModel?
    private var diffusionTransformer: MLModel?
    private var vaeDecoder: MLModel?

    private let eosToken: Int32 = 1
    private let padToken: Int32 = 0

    private init() {}

    // MARK: - Intents

    public func detectIntent(_ text: String) -> MusicIntent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = clean
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let words = normalized.split(separator: " ").map(String.init)
        let wordSet = Set(words)

        let musicNouns: Set<String> = [
            "musique", "morceau", "instrumental", "chanson", "beat",
            "music", "song", "track", "son", "audio"
        ]

        let exactCreationWords: Set<String> = [
            "genere", "generer",
            "compose", "composer",
            "cree", "creer",
            "fais", "faire",
            "fabrique", "fabriquer",
            "produis", "produire",
            "generate", "create", "make"
        ]

        let creationPrefixes = [
            "gener", "compos", "cre", "fabri", "produ"
        ]

        let hasMusicNoun = !wordSet.isDisjoint(with: musicNouns)
        let hasCreationWord =
            !wordSet.isDisjoint(with: exactCreationWords)
            || words.contains(where: { word in
                creationPrefixes.contains(where: { word.hasPrefix($0) })
            })

        // Formulations naturelles comme « tu peux générer une petite musique »
        // ou « est-ce que tu peux me faire un morceau » sont considérées comme
        // des intentions explicites de création.
        let asksCapability =
            normalized.contains("tu peux")
            || normalized.contains("peux tu")
            || normalized.contains("est ce que tu peux")
            || normalized.contains("j aimerais")
            || normalized.contains("je veux")

        // La dictée Apple peut parfois transformer « génère » en
        // « m'énerve ». On ne corrige ce faux positif que lorsqu'un nom musical
        // explicite est aussi présent.
        let noisyDictationCreation =
            hasMusicNoun
            && (
                normalized.contains("m enerve")
                || normalized.contains("menerve")
                || wordSet.contains("enerve")
            )

        let isIntent = hasMusicNoun && (hasCreationWord || asksCapability || noisyDictationCreation)

        let wantsLyrics =
            wordSet.contains("paroles")
            || wordSet.contains("lyrics")
            || wordSet.contains("chanson")
            || wordSet.contains("song")

        let language = (
            wordSet.contains("anglais")
            || wordSet.contains("english")
        ) ? "en" : "fr"

        let removableWords: Set<String> = exactCreationWords.union([
            "une", "un", "de", "du", "des", "moi", "me", "la", "le",
            "petite", "petit", "courte", "court",
            "musique", "morceau", "instrumental", "chanson",
            "music", "song", "track", "son", "audio",
            "tu", "peux", "est", "ce", "que", "je", "veux", "aimerais",
            "m", "enerve", "menerve", "encore"
        ])

        var promptWords = words.filter { word in
            !removableWords.contains(word)
            && !creationPrefixes.contains(where: { word.hasPrefix($0) })
        }

        if promptWords.isEmpty {
            promptWords = wantsLyrics
                ? ["chanson", "originale"]
                : ["instrumental", "original"]
        }

        let prompt = promptWords
            .joined(separator: " ")
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
                    .union(CharacterSet(charactersIn: ":,-"))
            )

        return MusicIntent(
            isIntent: isIntent,
            wantsLyrics: wantsLyrics,
            prompt: prompt,
            language: language
        )
    }

    // MARK: - Installation

    public var modelDirectory: URL {
        let root = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fm.temporaryDirectory

        let dir = root
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent("stable-audio-open-small-coreml", isDirectory: true)

        try? fm.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
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
                url: URL(string: "https://raw.githubusercontent.com/john-rocky/CoreML-Models/master/sample_apps/StableAudioDemo/StableAudioDemo/t5_vocab.json")!,
                compiledName: nil,
                isArchive: false
            )
        ]
    }

    public var backgroundDownloadManifest: [DownloadAssetDescriptor] {
        assets.map { DownloadAssetDescriptor(id: $0.id, url: $0.url) }
    }

    public func isBackgroundAssetInstalled(_ id: String) -> Bool {
        guard let asset = assets.first(where: { $0.id == id }) else { return false }

        if let compiledName = asset.compiledName {
            return fm.fileExists(
                atPath: modelDirectory.appendingPathComponent(compiledName).path
            )
        }

        let vocabURL = modelDirectory.appendingPathComponent("t5_vocab.json")
        return isValidVocabularyFile(at: vocabURL)
    }

    public func installBackgroundDownloadedAsset(
        id: String,
        downloadedURL: URL
    ) throws {
        guard let asset = assets.first(where: { $0.id == id }) else {
            throw MusicError.invalidPackage(id)
        }

        if asset.isArchive {
            try installCompiledModel(downloadedArchive: downloadedURL, asset: asset)
        } else {
            try installPlainFile(downloadedFile: downloadedURL, name: "t5_vocab.json")
        }
    }

    public var isInstrumentalModelInstalled: Bool {
        let requiredCoreModels = [
            "T5Encoder.mlmodelc",
            "NumberEmbedder.mlmodelc",
            "DiT.mlmodelc",
            "VAEDecoder.mlmodelc"
        ]

        return requiredCoreModels.allSatisfy {
            fm.fileExists(
                atPath: modelDirectory.appendingPathComponent($0).path
            )
        }
    }

    public func prepareInstrumentalModel(
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if isInstrumentalModelInstalled {
            do {
                try loadRuntime()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }

        installAsset(
            index: 0,
            progress: progress,
            completion: completion
        )
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
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            return
        }

        let asset = assets[index]
        let overall = Double(index) / Double(assets.count)

        DispatchQueue.main.async {
            progress(overall, "Téléchargement : \(asset.id)…")
        }

        let task = URLSession.shared.downloadTask(with: asset.url) { [weak self] tempURL, _, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(MusicError.invalidPackage(asset.id)))
                }
                return
            }

            do {
                if asset.isArchive {
                    try self.installCompiledModel(
                        downloadedArchive: tempURL,
                        asset: asset
                    )
                } else {
                    try self.installPlainFile(
                        downloadedFile: tempURL,
                        name: "t5_vocab.json"
                    )
                }

                DispatchQueue.main.async {
                    progress(
                        Double(index + 1) / Double(self.assets.count),
                        "Installé : \(asset.id)"
                    )
                }

                self.installAsset(
                    index: index + 1,
                    progress: progress,
                    completion: completion
                )
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }

    private func installPlainFile(
        downloadedFile: URL,
        name: String
    ) throws {
        let destination = modelDirectory.appendingPathComponent(name)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: downloadedFile, to: destination)
    }

    private func installCompiledModel(
        downloadedArchive: URL,
        asset: Asset
    ) throws {
        guard let compiledName = asset.compiledName else {
            throw MusicError.invalidPackage(asset.id)
        }

        let work = fm.temporaryDirectory
            .appendingPathComponent(
                "sarah-music-\(UUID().uuidString)",
                isDirectory: true
            )

        try fm.createDirectory(
            at: work,
            withIntermediateDirectories: true
        )
        defer { try? fm.removeItem(at: work) }

        try fm.unzipItem(
            at: downloadedArchive,
            to: work
        )

        guard let package = findFirstModelPackage(in: work) else {
            throw MusicError.invalidPackage(asset.id)
        }

        let compiledTemporary = try MLModel.compileModel(at: package)
        let destination = modelDirectory.appendingPathComponent(compiledName)

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        try fm.moveItem(
            at: compiledTemporary,
            to: destination
        )
    }

    private func findFirstModelPackage(in root: URL) -> URL? {
        if root.pathExtension == "mlpackage" {
            return root
        }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            if url.pathExtension == "mlpackage" {
                return url
            }
        }

        return nil
    }

    // MARK: - Runtime

    private func loadRuntime() throws {
        guard isInstrumentalModelInstalled else {
            throw MusicError.modelsMissing
        }

        try loadVocabulary()

        let common = MLModelConfiguration()
        common.computeUnits = .all

        let ditConfig = MLModelConfiguration()
        ditConfig.computeUnits = .cpuAndGPU

        t5Encoder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("T5Encoder.mlmodelc"),
            configuration: common
        )
        numberEmbedder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("NumberEmbedder.mlmodelc"),
            configuration: common
        )
        diffusionTransformer = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("DiT.mlmodelc"),
            configuration: ditConfig
        )
        vaeDecoder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("VAEDecoder.mlmodelc"),
            configuration: common
        )
    }

    private var tokenizerRemoteURL: URL {
        URL(
            string: "https://raw.githubusercontent.com/john-rocky/CoreML-Models/master/sample_apps/StableAudioDemo/StableAudioDemo/t5_vocab.json"
        )!
    }

    private func parseVocabularyData(_ data: Data) -> [String: Int32]? {
        guard let raw = try? JSONSerialization.jsonObject(with: data),
              let mapping = raw as? [String: String] else {
            return nil
        }

        var parsed: [String: Int32] = [:]
        parsed.reserveCapacity(mapping.count)

        for (idText, piece) in mapping {
            if let id = Int32(idText) {
                parsed[piece] = id
            }
        }

        return parsed.isEmpty ? nil : parsed
    }

    private func isValidVocabularyFile(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let parsed = parseVocabularyData(data) else {
            return false
        }

        return parsed.count > 10_000
    }

    private func loadVocabulary() throws {
        let localURL = modelDirectory.appendingPathComponent("t5_vocab.json")

        if let data = try? Data(contentsOf: localURL),
           let parsed = parseVocabularyData(data),
           parsed.count > 10_000 {
            vocabulary = parsed
            return
        }

        let repairedData: Data
        do {
            repairedData = try Data(contentsOf: tokenizerRemoteURL)
        } catch {
            throw MusicError.tokenizerMissing
        }

        guard let repaired = parseVocabularyData(repairedData),
              repaired.count > 10_000 else {
            throw MusicError.tokenizerMissing
        }

        do {
            if fm.fileExists(atPath: localURL.path) {
                try fm.removeItem(at: localURL)
            }
            try repairedData.write(to: localURL, options: .atomic)
        } catch {
            throw MusicError.tokenizerMissing
        }

        vocabulary = repaired
    }

    private func tokenize(_ prompt: String) -> [Int32] {
        let marker = "\u{2581}"
        let normalized = marker + prompt
            .lowercased()
            .replacingOccurrences(of: " ", with: marker)

        var ids: [Int32] = []
        var cursor = normalized.startIndex

        while cursor < normalized.endIndex {
            let remaining = normalized.distance(
                from: cursor,
                to: normalized.endIndex
            )

            var found = false
            let maxPiece = min(24, remaining)

            for length in stride(
                from: maxPiece,
                through: 1,
                by: -1
            ) {
                guard let end = normalized.index(
                    cursor,
                    offsetBy: length,
                    limitedBy: normalized.endIndex
                ) else {
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

            if !found {
                cursor = normalized.index(after: cursor)
            }
        }

        ids.append(eosToken)

        if ids.count >= Self.maxTokens {
            ids = Array(ids.prefix(Self.maxTokens - 1))
            ids.append(eosToken)
        }

        while ids.count < Self.maxTokens {
            ids.append(padToken)
        }

        return ids
    }

    public func generateInstrumental(
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

        Task.detached(priority: .userInitiated) {
            do {
                if !self.isInstrumentalModelInstalled {
                    throw MusicError.modelsMissing
                }

                if self.t5Encoder == nil {
                    try self.loadRuntime()
                }

                let url = try await self.render(
                    prompt: clean,
                    seconds: min(max(seconds, 1), 11.5),
                    steps: min(max(steps, 4), 16),
                    seed: UInt64.random(in: 1...UInt64.max)
                )

                await MainActor.run {
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
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func render(
        prompt: String,
        seconds: Float,
        steps: Int,
        seed: UInt64
    ) async throws -> URL {
        guard let t5Encoder,
              let numberEmbedder,
              let diffusionTransformer,
              let vaeDecoder else {
            throw MusicError.modelsMissing
        }

        let tokens = tokenize(prompt)
        let inputIDs = try MLMultiArray(
            shape: [1, NSNumber(value: Self.maxTokens)],
            dataType: .int32
        )

        for index in 0..<Self.maxTokens {
            inputIDs[index] = NSNumber(value: tokens[index])
        }

        let textProvider = try MLDictionaryFeatureProvider(
            dictionary: ["input_ids": inputIDs]
        )
        let textResult = try await t5Encoder.prediction(from: textProvider)

        guard let textEmbeddings = textResult
            .featureValue(for: "text_embeddings")?
            .multiArrayValue else {
            throw MusicError.predictionFailed("encodage du texte")
        }

        let activeTokenCount =
            tokens.firstIndex(of: padToken)
            ?? Self.maxTokens

        sanitizeTextEmbeddings(
            textEmbeddings,
            activeTokens: activeTokenCount
        )

        let normalizedDuration =
            min(max(seconds, 0), Self.maxConditionSeconds)
            / Self.maxConditionSeconds

        let durationInput = try MLMultiArray(
            shape: [1],
            dataType: .float16
        )
        durationInput[0] = NSNumber(value: normalizedDuration)

        let durationProvider = try MLDictionaryFeatureProvider(
            dictionary: ["normalized_seconds": durationInput]
        )
        let durationResult = try await numberEmbedder.prediction(
            from: durationProvider
        )

        guard let durationEmbedding = durationResult
            .featureValue(for: "seconds_embedding")?
            .multiArrayValue else {
            throw MusicError.predictionFailed("conditionnement de durée")
        }

        let crossAttention = try MLMultiArray(
            shape: [1, 65, 768],
            dataType: .float16
        )

        for token in 0..<64 {
            for channel in 0..<768 {
                crossAttention[
                    [0, token, channel] as [NSNumber]
                ] = textEmbeddings[
                    [0, token, channel] as [NSNumber]
                ]
            }
        }

        let globalEmbedding = try MLMultiArray(
            shape: [1, 768],
            dataType: .float16
        )

        for channel in 0..<768 {
            let value = durationEmbedding[
                [0, channel] as [NSNumber]
            ]
            crossAttention[
                [0, 64, channel] as [NSNumber]
            ] = value
            globalEmbedding[
                [0, channel] as [NSNumber]
            ] = value
        }

        var latent = try makeNoise(seed: seed)
        let times = makeSchedule(steps: steps)

        for step in 0..<steps {
            let current = times[step]
            let next = times[step + 1]

            let timestep = try MLMultiArray(
                shape: [1],
                dataType: .float16
            )
            timestep[0] = NSNumber(value: current)

            let provider = try MLDictionaryFeatureProvider(
                dictionary: [
                    "latent": latent,
                    "timestep": timestep,
                    "cross_attn_cond": crossAttention,
                    "global_embed": globalEmbedding
                ]
            )

            let prediction = try await diffusionTransformer
                .prediction(from: provider)

            guard let velocity = prediction
                .featureValue(for: "velocity")?
                .multiArrayValue else {
                throw MusicError.predictionFailed(
                    "diffusion étape \(step + 1)"
                )
            }

            latent = try eulerAdvance(
                latent: latent,
                velocity: velocity,
                delta: next - current
            )
        }

        let decoderProvider = try MLDictionaryFeatureProvider(
            dictionary: ["latent": latent]
        )
        let decoded = try await vaeDecoder.prediction(
            from: decoderProvider
        )

        guard let audio = decoded
            .featureValue(for: "audio")?
            .multiArrayValue else {
            throw MusicError.predictionFailed("décodage audio")
        }

        return try saveAudio(
            audio,
            seconds: seconds,
            prompt: prompt
        )
    }

    private func sanitizeTextEmbeddings(
        _ embeddings: MLMultiArray,
        activeTokens: Int
    ) {
        for token in 0..<Self.maxTokens {
            for channel in 0..<768 {
                let index = [0, token, channel] as [NSNumber]
                let value = embeddings[index].floatValue

                if !value.isFinite || token >= activeTokens {
                    embeddings[index] = 0
                }
            }
        }
    }

    private func makeNoise(seed: UInt64) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [
                1,
                NSNumber(value: Self.latentChannels),
                NSNumber(value: Self.latentLength)
            ],
            dataType: .float16
        )

        let pointer = array.dataPointer
            .assumingMemoryBound(to: Float16.self)

        let count = Self.latentChannels * Self.latentLength
        var random = SarahSeededRandom(seed: seed)

        var index = 0
        while index < count {
            let first = Float.random(
                in: Float.leastNormalMagnitude...1,
                using: &random
            )
            let second = Float.random(
                in: 0...1,
                using: &random
            )

            let radius = sqrtf(-2 * logf(first))
            let angle = 2 * Float.pi * second

            pointer[index] = Float16(
                radius * cosf(angle)
            )

            if index + 1 < count {
                pointer[index + 1] = Float16(
                    radius * sinf(angle)
                )
            }

            index += 2
        }

        return array
    }

    private func makeSchedule(steps: Int) -> [Float] {
        var result: [Float] = []
        result.reserveCapacity(steps + 1)

        for index in 0...steps {
            let logSNR =
                -6
                + Float(index) / Float(steps) * 8
            result.append(
                1 / (1 + expf(logSNR))
            )
        }

        if !result.isEmpty {
            result[0] = 1
            result[result.count - 1] = 0
        }

        return result
    }

    private func eulerAdvance(
        latent: MLMultiArray,
        velocity: MLMultiArray,
        delta: Float
    ) throws -> MLMultiArray {
        let output = try MLMultiArray(
            shape: latent.shape,
            dataType: .float16
        )

        let count =
            Self.latentChannels
            * Self.latentLength

        let inputPointer = latent.dataPointer
            .assumingMemoryBound(to: Float16.self)
        let outputPointer = output.dataPointer
            .assumingMemoryBound(to: Float16.self)

        if velocity.dataType == .float32 {
            let velocityPointer = velocity.dataPointer
                .assumingMemoryBound(to: Float.self)

            for index in 0..<count {
                outputPointer[index] = Float16(
                    Float(inputPointer[index])
                    + delta * velocityPointer[index]
                )
            }
        } else {
            let velocityPointer = velocity.dataPointer
                .assumingMemoryBound(to: Float16.self)

            for index in 0..<count {
                outputPointer[index] = Float16(
                    Float(inputPointer[index])
                    + delta * Float(velocityPointer[index])
                )
            }
        }

        return output
    }

    private func saveAudio(
        _ audio: MLMultiArray,
        seconds: Float,
        prompt: String
    ) throws -> URL {
        let sampleCount = min(
            Int(seconds * Float(Self.sampleRate)),
            Self.fullAudioSamples
        )

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 2,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ),
        let left = buffer.floatChannelData?[0],
        let right = buffer.floatChannelData?[1] else {
            throw MusicError.audioWriteFailed
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        for sample in 0..<sampleCount {
            left[sample] = audio[
                [0, 0, sample] as [NSNumber]
            ].floatValue
            right[sample] = audio[
                [0, 1, sample] as [NSNumber]
            ].floatValue
        }

        let outputDir = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent(
                "SarahIA/GeneratedMusic",
                isDirectory: true
            )
            ?? fm.temporaryDirectory

        try fm.createDirectory(
            at: outputDir,
            withIntermediateDirectories: true
        )

        let safe = prompt
            .components(
                separatedBy: CharacterSet
                    .alphanumerics
                    .inverted
            )
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()

        let filename =
            "sarah-"
            + (safe.isEmpty ? "music" : safe)
            + "-"
            + String(Int(Date().timeIntervalSince1970))
            + ".wav"

        let url = outputDir
            .appendingPathComponent(filename)

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings
        )
        try file.write(from: buffer)

        return url
    }

    public func vocalSongAvailabilityMessage() -> String {
        let profile = SarahGenerativeModelCatalog.vocalSongProfile()
        return "Paroles chantées : \(profile.displayName) est sélectionné comme cible. \(profile.note)"
    }
}

@available(iOS 27.0, *)
private struct SarahSeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0
            ? 0x9E3779B97F4A7C15
            : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
