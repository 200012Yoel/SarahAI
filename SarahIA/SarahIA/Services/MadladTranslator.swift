import Foundation
#if canImport(llama)
import llama
#endif

/// Offline neural translator for Translate Live: Google's open-source
/// MADLAD-400 3B MT model (Apache-2.0), run on the iPhone with llama.cpp.
///
/// It translates Hebrew straight into French (and ~400 other pairs) without
/// an English relay, so Whisper only needs ONE decode per audio chunk.
/// The 1.9 GB weights are downloaded once (Wi-Fi only) into Application
/// Support; nothing is sent to a server when translating.
public final class MadladTranslator: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = MadladTranslator()

    public static let downloadURL = URL(string:
        "https://huggingface.co/mtsdurica/madlad400-3b-mt-Q4_K_M-GGUF/resolve/main/madlad400-3b-mt-q4_k_m.gguf")!
    private static let fileName = "madlad400-3b-mt-q4_k_m.gguf"
    private static let minimumBytes: Int64 = 1_500_000_000

    @Published public private(set) var isInstalled = false
    @Published public private(set) var isDownloading = false
    @Published public private(set) var downloadProgress: Double = 0
    @Published public private(set) var lastDownloadError: String?

    /// Posted on the main queue when the model becomes usable.
    public static let installedNotification = Notification.Name("SarahMadladInstalled")

    private let queue = DispatchQueue(label: "com.sarahia.madlad.translate", qos: .userInitiated)
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var resumeData: Data?

    #if canImport(llama)
    private var backendReady = false
    private var model: OpaquePointer?
    private var languageTokens: [String: String] = [:]
    #endif

    private override init() {
        super.init()
        isInstalled = Self.validModelExists()
    }

    // MARK: - Files

    public static var modelURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SarahModels", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func validModelExists() -> Bool {
        let url = modelURL
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value >= minimumBytes,
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let magic = handle.readData(ofLength: 4)
        return magic == Data("GGUF".utf8)
    }

    public var isRuntimeLinked: Bool {
        #if canImport(llama)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Download (Wi-Fi only, resumable)

    public func startDownloadIfNeeded() {
        DispatchQueue.main.async { [self] in
            guard !isInstalled, !isDownloading else { return }
            let free = (try? URL(fileURLWithPath: NSHomeDirectory())
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
                .volumeAvailableCapacityForImportantUsage ?? 0
            guard free == 0 || free > 2_600_000_000 else {
                lastDownloadError = "Pas assez d'espace : il faut environ 2,5 Go libres pour le traducteur hébreu."
                return
            }
            let configuration = URLSessionConfiguration.default
            configuration.allowsExpensiveNetworkAccess = false // never on cellular
            configuration.allowsConstrainedNetworkAccess = false
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForResource = 6 * 3600
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
            self.session = session
            let task = resumeData.map { session.downloadTask(withResumeData: $0) }
                ?? session.downloadTask(with: Self.downloadURL)
            resumeData = nil
            self.task = task
            isDownloading = true
            lastDownloadError = nil
            task.resume()
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 1_860_000_000
        downloadProgress = min(1, Double(totalBytesWritten) / Double(expected))
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        let destination = Self.modelURL
        do {
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                throw NSError(domain: "SarahMadlad", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Téléchargement refusé (HTTP \(http.statusCode))."])
            }
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = destination
            try? mutable.setResourceValues(values)
            guard Self.validModelExists() else {
                try? FileManager.default.removeItem(at: destination)
                throw NSError(domain: "SarahMadlad", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Fichier du traducteur incomplet, nouvel essai nécessaire."])
            }
            isInstalled = true
            downloadProgress = 1
            NotificationCenter.default.post(name: Self.installedNotification, object: nil)
        } catch {
            lastDownloadError = error.localizedDescription
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        isDownloading = false
        self.task = nil
        session.finishTasksAndInvalidate()
        self.session = nil
        if let error {
            resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            lastDownloadError = "Téléchargement interrompu : " + error.localizedDescription
        }
    }

    // MARK: - Translation

    /// Loads the weights ahead of the first sentence so live captions do
    /// not wait for a 1.9 GB model load.
    public func warmUp() {
        queue.async { [weak self] in
            #if canImport(llama)
            _ = try? self?.loadedModel()
            #endif
        }
    }

    /// Releases the weights when Translate Live closes.
    public func unload() {
        queue.async { [weak self] in
            #if canImport(llama)
            if let model = self?.model { llama_model_free(model) }
            self?.model = nil
            self?.languageTokens.removeAll()
            #endif
        }
    }

    /// Translates `text` (any language) into `target` ("fr", "he", "en"…).
    /// Completion is called on the main queue.
    public func translate(_ text: String, to target: String,
                          completion: @escaping (Result<String, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            #if canImport(llama)
            let result = Result { try self.infer(text: text, target: target) }
            #else
            let result: Result<String, Error> = .failure(NSError(domain: "SarahMadlad", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Le moteur llama.cpp n'est pas inclus dans cette installation."]))
            #endif
            DispatchQueue.main.async { completion(result) }
        }
    }

    #if canImport(llama)
    private func loadedModel() throws -> OpaquePointer {
        if let model { return model }
        guard Self.validModelExists() else {
            throw NSError(domain: "SarahMadlad", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Traducteur hébreu ↔ français pas encore téléchargé."])
        }
        if !backendReady {
            llama_backend_init()
            backendReady = true
        }
        // Default load mode memory-maps the weights (file-backed pages).
        let params = llama_model_default_params()
        guard let loaded = llama_model_load_from_file(Self.modelURL.path, params) else {
            throw NSError(domain: "SarahMadlad", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Impossible de charger le traducteur MADLAD-400."])
        }
        model = loaded
        return loaded
    }

    private func tokenize(_ vocab: OpaquePointer, _ text: String) -> [llama_token] {
        let count = Int32(text.utf8.count)
        var tokens = [llama_token](repeating: 0, count: Int(count) + 16)
        var n = llama_tokenize(vocab, text, count, &tokens, Int32(tokens.count), true, true)
        if n < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-n))
            n = llama_tokenize(vocab, text, count, &tokens, Int32(tokens.count), true, true)
        }
        return n > 0 ? Array(tokens.prefix(Int(n))) : []
    }

    /// MADLAD selects the output language with a "<2xx>" token. Hebrew may
    /// be stored under its legacy Google code "iw": use whichever exists.
    private func languageTag(for code: String, vocab: OpaquePointer) -> String {
        if let cached = languageTokens[code] { return cached }
        var candidates = ["<2\(code)>"]
        if code == "he" { candidates.append("<2iw>") }
        if code == "iw" { candidates.append("<2he>") }
        let plain = tokenize(vocab, "x").count
        var chosen = candidates[0]
        for candidate in candidates where tokenize(vocab, candidate + " x").count <= plain + 1 {
            chosen = candidate
            break
        }
        languageTokens[code] = chosen
        return chosen
    }

    private func infer(text: String, target: String) throws -> String {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return "" }
        let model = try loadedModel()
        guard let vocab = llama_model_get_vocab(model) else {
            throw NSError(domain: "SarahMadlad", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Vocabulaire du traducteur indisponible."])
        }
        let prompt = languageTag(for: target, vocab: vocab) + " " + source
        var tokens = tokenize(vocab, prompt)
        guard !tokens.isEmpty else { return "" }
        if tokens.count > 384 { tokens = Array(tokens.prefix(384)) }

        let maxOutput = min(256, tokens.count * 3 + 16)
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(tokens.count + maxOutput + 8)
        contextParams.n_batch = UInt32(max(64, tokens.count))
        contextParams.n_ubatch = contextParams.n_batch
        let threads = Int32(max(2, min(4, ProcessInfo.processInfo.activeProcessorCount - 2)))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads
        guard let context = llama_init_from_model(model, contextParams) else {
            throw NSError(domain: "SarahMadlad", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Mémoire insuffisante pour le traducteur."])
        }
        defer { llama_free(context) }
        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw NSError(domain: "SarahMadlad", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Échantillonneur indisponible."])
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy())

        let encodeStatus = tokens.withUnsafeMutableBufferPointer { buffer in
            llama_encode(context, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count)))
        }
        guard encodeStatus == 0 else {
            throw NSError(domain: "SarahMadlad", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "Le traducteur n'a pas pu lire la phrase."])
        }

        var next = llama_model_decoder_start_token(model)
        if next == LLAMA_TOKEN_NULL { next = llama_vocab_bos(vocab) }
        var output = Data()
        for _ in 0..<maxOutput {
            var current = next
            guard llama_decode(context, llama_batch_get_one(&current, 1)) == 0 else { break }
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            var buffer = [CChar](repeating: 0, count: 64)
            var written = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
            if written < 0 {
                buffer = [CChar](repeating: 0, count: Int(-written))
                written = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
            }
            if written > 0 {
                output.append(contentsOf: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) })
            }
            next = token
        }
        return String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
