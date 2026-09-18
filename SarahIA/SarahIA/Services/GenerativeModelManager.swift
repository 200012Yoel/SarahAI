import Foundation
import Combine
import ZIPFoundation

@available(iOS 16.0, *)
public final class GenerativeModelManager: ObservableObject {

    public static let shared = GenerativeModelManager()

    public enum Kind: String {
        case image
        case video
    }

    @Published public private(set) var isDownloading = false
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var statusText: String = ""
    @Published public private(set) var activeKind: Kind?

    private let fm = FileManager.default
    private var task: URLSessionDownloadTask?

    private init() {}

    public func downloadImageModel() {
        let profile = SarahGenerativeModelCatalog.imageProfile()
        let urlString: String?

        switch profile.identifier {
        case "apple-sd21-6bit":
            urlString = "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized/resolve/main/coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled.zip?download=true"
        case "apple-sdxl-1.0-ios-4bit":
            urlString = "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios/resolve/main/coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip?download=true"
        default:
            urlString = nil
        }

        guard let urlString = urlString, let url = URL(string: urlString) else {
            statusText = "Ce profil image doit être installé manuellement dans cette version."
            return
        }

        start(kind: .image, url: url)
    }

    public func downloadVideoCheckpoint() {
        let profile = SarahGenerativeModelCatalog.videoProfile()

        guard profile.identifier == "mobilei2v-027b",
              let url = URL(string: "https://huggingface.co/hustvl/MobileI2V/resolve/main/hybrid_371.pth?download=true") else {
            statusText = "Aucun checkpoint vidéo automatique pour ce profil."
            return
        }

        start(kind: .video, url: url)
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isDownloading = false
        progress = 0
        activeKind = nil
        statusText = "Téléchargement annulé."
    }

    public var isImageInstalled: Bool {
        SarahLocalImageGenEngine.shared.isInstalled
    }

    public var isVideoCheckpointInstalled: Bool {
        let profile = SarahGenerativeModelCatalog.videoProfile()
        guard profile.identifier == "mobilei2v-027b" else { return false }
        return fm.fileExists(
            atPath: videoDirectory.appendingPathComponent("hybrid_371.pth").path
        )
    }

    private var videoDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent(SarahGenerativeModelCatalog.videoProfile().identifier, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func start(kind: Kind, url: URL) {
        guard !isDownloading else { return }

        isDownloading = true
        progress = 0
        activeKind = kind
        statusText = kind == .image ? "Téléchargement du modèle image…" : "Téléchargement du checkpoint vidéo…"

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let session = URLSession(configuration: .default, delegate: ProgressDelegate(owner: self), delegateQueue: nil)
        task = session.downloadTask(with: request)
        task?.resume()
    }

    fileprivate func didWrite(total: Int64, expected: Int64) {
        guard expected > 0 else { return }
        DispatchQueue.main.async {
            self.progress = Double(total) / Double(expected)
        }
    }

    fileprivate func didFinish(location: URL) {
        guard let kind = activeKind else { return }

        do {
            switch kind {
            case .image:
                try installImageArchive(location)
                statusText = "Modèle image installé localement."
            case .video:
                let dest = videoDirectory.appendingPathComponent("hybrid_371.pth")
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: location, to: dest)
                statusText = "Checkpoint MobileI2V téléchargé. Runtime vidéo encore expérimental."
            }
            progress = 1
        } catch {
            statusText = error.localizedDescription
        }

        isDownloading = false
        activeKind = nil
        task = nil
    }

    fileprivate func didFail(_ error: Error) {
        DispatchQueue.main.async {
            self.statusText = error.localizedDescription
            self.isDownloading = false
            self.activeKind = nil
            self.task = nil
        }
    }

    private func installImageArchive(_ archive: URL) throws {
        let destination = SarahLocalImageGenEngine.shared.modelDirectory
        if fm.fileExists(atPath: destination.path) {
            let items = try fm.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
            for item in items { try fm.removeItem(at: item) }
        }
        try fm.unzipItem(at: archive, to: destination)

        guard SarahLocalImageGenEngine.shared.discoverResourceDirectory() != nil else {
            throw NSError(
                domain: "GenerativeModelManager",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Le paquet image ne contient pas les ressources Core ML attendues."]
            )
        }
    }
}

@available(iOS 16.0, *)
private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
    weak var owner: GenerativeModelManager?

    init(owner: GenerativeModelManager) {
        self.owner = owner
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        owner?.didWrite(total: totalBytesWritten, expected: totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        owner?.didFinish(location: location)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            owner?.didFail(error)
        }
    }
}
