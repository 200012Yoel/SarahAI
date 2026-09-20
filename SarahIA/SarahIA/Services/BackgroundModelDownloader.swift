import Foundation
import Combine
import ZIPFoundation

// ============================================================================
// BACKGROUND MODEL DOWNLOADER — TÉLÉCHARGEMENT PROGRESSIF DU MODÈLE QWEN3 GGUF
// ============================================================================
// Télécharge le modèle Qwen3 recommandé pour l'appareil depuis Hugging Face.
// Supporte la reprise de téléchargement en arrière-plan (URLSessionConfiguration.background)
// ============================================================================

public final class BackgroundModelDownloader: NSObject {
    
    public static let shared = BackgroundModelDownloader()
    
    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    
    public var onProgress: ((Double, Int64, Int64) -> Void)?
    public var onCompletion: ((Result<URL, Error>) -> Void)?
    
    public private(set) var isDownloading: Bool = false
    private let resumeDataKey = "sarah_qwen_model_download_resume_data"
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.sarahia.qwenmodeldownload")
        config.isDiscretionary = false
        // Les modèles peuvent être volumineux : la préparation continue en arrière-plan,
        // mais ne consomme jamais le forfait mobile sans une action explicite de l'utilisateur.
        config.allowsCellularAccess = false
        config.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.resumeData = UserDefaults.standard.data(forKey: resumeDataKey)

        self.session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            DispatchQueue.main.async {
                self.downloadTask = tasks.compactMap { $0 as? URLSessionDownloadTask }.first
                self.isDownloading = self.downloadTask != nil
            }
        }
    }
    
    /// Chemin vers le fichier GGUF local dans Application Support
    public static var localModelURL: URL? {
        let fileManager = FileManager.default
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let modelsDir = appSupportDir.appendingPathComponent("SarahAI/models", isDirectory: true)
        return modelsDir.appendingPathComponent(ModelSelectionEngine.shared.recommendedLocalModelFileName)
    }
    
    /// Vérifie si le modèle Qwen3 recommandé est déjà téléchargé.
    public static var isModelDownloaded: Bool {
        guard let url = localModelURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Lance le téléchargement du modèle Qwen3 adapté au profil matériel détecté.
    public func startQwenModelDownload() {
        guard !isDownloading else { return }
        guard ModelSelectionEngine.shared.isLocalGGUFAllowed() else {
            let error = NSError(domain: "com.sarahia.downloader", code: 403, userInfo: [NSLocalizedDescriptionKey: "Téléchargement interdit : RAM insuffisante (<= 2 Go). Utilisation du Cloud Fallback requise."])
            onCompletion?(.failure(error))
            return
        }

        guard hasEnoughDiskSpaceForRecommendedModel() else {
            let error = NSError(domain: "com.sarahia.downloader", code: 507, userInfo: [NSLocalizedDescriptionKey: "Espace de stockage insuffisant pour préparer Sarah hors ligne."])
            onCompletion?(.failure(error))
            return
        }
        
        guard let url = URL(string: ModelSelectionEngine.shared.recommendedDownloadURL) else {
            let error = NSError(domain: "com.sarahia.downloader", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL HuggingFace invalide."])
            onCompletion?(.failure(error))
            return
        }
        
        isDownloading = true
        NotificationCenter.default.post(name: NSNotification.Name("SarahModelDownloadStarted"), object: nil)
        
        if let resumeData = resumeData {
            print("🔄 [BackgroundModelDownloader] Reprise du téléchargement Qwen3...")
            downloadTask = session.downloadTask(withResumeData: resumeData)
        } else {
            print("🚀 [BackgroundModelDownloader] Démarrage du téléchargement HuggingFace : \(url.absoluteString)")
            downloadTask = session.downloadTask(with: url)
        }
        downloadTask?.resume()
    }

    /// Vérifie la place libre avant de lancer un téléchargement en arrière-plan.
    /// On conserve une marge afin que l'installation du modèle ne sature pas iOS.
    private func hasEnoughDiskSpaceForRecommendedModel() -> Bool {
        guard let modelURL = BackgroundModelDownloader.localModelURL else { return false }
        let required = ModelSelectionEngine.shared.recommendedDownloadBytes + (500 * 1024 * 1024)
        let values = try? modelURL.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return true }
        return available >= Int64(required)
    }
    
    /// Met en pause le téléchargement
    public func pauseDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            guard let self = self, let data = data else { return }
            self.resumeData = data
            self.isDownloading = false
            UserDefaults.standard.set(data, forKey: self.resumeDataKey)
            print("⏸️ [BackgroundModelDownloader] Téléchargement mis en pause avec \(data.count) octets sauvegardés.")
        })
    }
    
    /// Annule le téléchargement
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        resumeData = nil
        isDownloading = false
        UserDefaults.standard.removeObject(forKey: resumeDataKey)
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundModelDownloader: URLSessionDownloadDelegate {
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async { [weak self] in
            self?.onProgress?(progress, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        resumeData = nil
        isDownloading = false
        UserDefaults.standard.removeObject(forKey: resumeDataKey)
        
        let fileManager = FileManager.default
        guard let destinationURL = BackgroundModelDownloader.localModelURL else {
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(NSError(domain: "com.sarahia.downloader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Emplacement de stockage introuvable"])))
            }
            return
        }
        
        let parentDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            print("✅ [BackgroundModelDownloader] Modèle Qwen3 installé : \(destinationURL.path)")
            
            DispatchQueue.main.async { [weak self] in
                NotificationCenter.default.post(name: NSNotification.Name("SarahModelDownloadCompleted"), object: nil)
                self?.onCompletion?(.success(destinationURL))
            }
        } catch {
            print("❌ [BackgroundModelDownloader] Erreur déplacement modèle : \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(error))
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            isDownloading = false
            print("⚠️ [BackgroundModelDownloader] Téléchargement interrompu : \(error.localizedDescription)")
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = resumeData
                UserDefaults.standard.set(resumeData, forKey: resumeDataKey)
            }
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        AppDelegate.completeBackgroundSession(identifier: session.configuration.identifier)
    }
}


// ============================================================================
// GENERATIVE MODEL DOWNLOADER — IMAGE / VIDEO
// ============================================================================

@available(iOS 13.0, *)
public final class GenerativeModelDownloader: NSObject, ObservableObject {

    public static let shared = GenerativeModelDownloader()

    public enum DownloadKind: String {
        case image
        case video
    }

    @Published public private(set) var isDownloading: Bool = false
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var statusText: String = ""
    @Published public private(set) var activeKind: DownloadKind?

    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var activeIdentifier: String?
    private var activeURL: URL?
    private let fileManager = FileManager.default

    private override init() {
        super.init()

        let config = URLSessionConfiguration.background(
            withIdentifier: "com.sarahia.generative-model-download"
        )
        config.isDiscretionary = false
        config.allowsCellularAccess = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true

        self.session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )

        self.session.getAllTasks { [weak self] tasks in
            guard let self,
                  let existing = tasks.compactMap({ $0 as? URLSessionDownloadTask }).first else { return }

            let parts = (existing.taskDescription ?? "").split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, let kind = DownloadKind(rawValue: parts[0]) else { return }

            DispatchQueue.main.async {
                self.task = existing
                self.activeKind = kind
                self.activeIdentifier = parts[1]
                self.isDownloading = true
                self.statusText = kind == .image
                    ? "Téléchargement du modèle image…"
                    : "Téléchargement du modèle vidéo…"
            }
        }
    }

    public func startImageModelDownload() {
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

        guard let urlString, let url = URL(string: urlString) else {
            publishFailure("Aucun paquet Core ML téléchargeable n'est configuré pour cet appareil.")
            return
        }

        start(
            kind: .image,
            identifier: profile.identifier,
            url: url,
            minimumFreeBytes: profile.identifier.contains("sdxl")
                ? 7_000_000_000
                : 3_000_000_000
        )
    }

    /// Télécharge le checkpoint MobileI2V officiel pour préparer le port local.
    /// Le checkpoint seul ne suffit pas pour l'inférence iOS : le runtime mobile
    /// doit encore être converti/branché. Sarah l'affiche explicitement comme tel.
    public func startVideoModelDownload() {
        let profile = SarahGenerativeModelCatalog.videoProfile()

        guard profile.identifier == "mobilei2v-027b" else {
            publishFailure("Le profil vidéo de cet appareil nécessite un paquet Core ML spécifique qui n'est pas distribué automatiquement.")
            return
        }

        guard let url = URL(
            string: "https://huggingface.co/hustvl/MobileI2V/resolve/main/hybrid_371.pth?download=true"
        ) else {
            publishFailure("URL MobileI2V invalide.")
            return
        }

        start(
            kind: .video,
            identifier: profile.identifier,
            url: url,
            minimumFreeBytes: 2_500_000_000
        )
    }

    public func cancel() {
        task?.cancel()
        task = nil
        DispatchQueue.main.async {
            self.isDownloading = false
            self.progress = 0
            self.statusText = "Téléchargement annulé"
            self.activeKind = nil
        }
    }

    public func isInstalled(kind: DownloadKind) -> Bool {
        switch kind {
        case .image:
            return SarahLocalImageGenEngine.shared.isLocalLCMModelAvailable
        case .video:
            let profile = SarahGenerativeModelCatalog.videoProfile()
            guard profile.identifier == "mobilei2v-027b" else {
                return SarahLocalVideoGenEngine.shared.hasInstalledRuntimeAssets
            }
            let checkpoint = modelDirectory(for: profile.identifier)
                .appendingPathComponent("hybrid_371.pth")
            return fileManager.fileExists(atPath: checkpoint.path)
        }
    }

    private func start(
        kind: DownloadKind,
        identifier: String,
        url: URL,
        minimumFreeBytes: Int64
    ) {
        guard !isDownloading else { return }

        guard hasEnoughFreeSpace(minimum: minimumFreeBytes) else {
            publishFailure("Espace de stockage insuffisant pour ce modèle.")
            return
        }

        activeKind = kind
        activeIdentifier = identifier
        activeURL = url
        isDownloading = true
        progress = 0
        statusText = kind == .image
            ? "Téléchargement du modèle image…"
            : "Téléchargement du modèle vidéo…"

        task = session.downloadTask(with: url)
        task?.taskDescription = "\(kind.rawValue)|\(identifier)"
        task?.resume()
    }

    private func hasEnoughFreeSpace(minimum: Int64) -> Bool {
        let root = modelRootDirectory
        let values = try? root.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        guard let available = values?.volumeAvailableCapacityForImportantUsage else {
            return true
        }
        return available >= minimum
    }

    private var modelRootDirectory: URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        let root = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)

        try? fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return root
    }

    private func modelDirectory(for identifier: String) -> URL {
        let dir = modelRootDirectory.appendingPathComponent(
            identifier,
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return dir
    }

    private func installImageArchive(
        from downloadedURL: URL,
        identifier: String
    ) throws -> URL {
        let destination = modelDirectory(for: identifier)

        if fileManager.fileExists(atPath: destination.path) {
            let items = try fileManager.contentsOfDirectory(
                at: destination,
                includingPropertiesForKeys: nil
            )
            for item in items {
                try fileManager.removeItem(at: item)
            }
        }

        DispatchQueue.main.async {
            self.statusText = "Installation du modèle…"
        }

        try fileManager.unzipItem(
            at: downloadedURL,
            to: destination
        )

        guard SarahLocalImageGenEngine.shared.discoverResourceDirectory() != nil else {
            throw NSError(
                domain: "com.sarahia.generative-model-download",
                code: 422,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Le paquet téléchargé ne contient pas les ressources Core ML attendues."
                ]
            )
        }

        return destination
    }

    private func installVideoCheckpoint(
        from downloadedURL: URL,
        identifier: String
    ) throws -> URL {
        let destination = modelDirectory(for: identifier)
            .appendingPathComponent("hybrid_371.pth")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: downloadedURL, to: destination)
        return destination
    }

    private func publishFailure(_ message: String) {
        DispatchQueue.main.async {
            self.isDownloading = false
            self.statusText = message
            self.activeKind = nil
        }
    }
}

@available(iOS 13.0, *)
extension GenerativeModelDownloader: URLSessionDownloadDelegate {

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let value = Double(totalBytesWritten)
            / Double(totalBytesExpectedToWrite)

        DispatchQueue.main.async {
            self.progress = value
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let metadata = (downloadTask.taskDescription ?? "")
            .split(separator: "|", maxSplits: 1)
            .map(String.init)

        let restoredKind = metadata.count == 2 ? DownloadKind(rawValue: metadata[0]) : nil
        let restoredIdentifier = metadata.count == 2 ? metadata[1] : nil

        guard let kind = activeKind ?? restoredKind,
              let identifier = activeIdentifier ?? restoredIdentifier else {
            publishFailure("Téléchargement terminé sans profil identifiable.")
            return
        }

        do {
            let installedURL: URL

            switch kind {
            case .image:
                installedURL = try installImageArchive(
                    from: location,
                    identifier: identifier
                )
                SarahLocalImageGenEngine.shared.checkLocalModelAvailability()

            case .video:
                installedURL = try installVideoCheckpoint(
                    from: location,
                    identifier: identifier
                )
            }

            DispatchQueue.main.async {
                self.isDownloading = false
                self.progress = 1
                self.statusText = kind == .image
                    ? "Modèle image installé localement"
                    : "Checkpoint vidéo téléchargé"
                self.activeKind = nil

                NotificationCenter.default.post(
                    name: NSNotification.Name("SarahGenerativeModelInstalled"),
                    object: installedURL,
                    userInfo: [
                        "kind": kind.rawValue,
                        "identifier": identifier
                    ]
                )
            }
        } catch {
            publishFailure(error.localizedDescription)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        publishFailure(error.localizedDescription)
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        AppDelegate.completeBackgroundSession(identifier: session.configuration.identifier)
    }
}
