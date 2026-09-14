import Foundation

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
}
