import Foundation

// ============================================================================
// BACKGROUND MODEL DOWNLOADER — TÉLÉCHARGEMENT PROGRESSIF DES MODÈLES GGUF
// ============================================================================
// Utilise URLSessionConfiguration.background avec support de la reprise (resumeData)
// et gestion des octets partiels (Range: bytes=...).
// Permet le téléchargement complet même si l'application est en arrière-plan
// ou si l'iPhone est verrouillé.
// ============================================================================

public final class BackgroundModelDownloader: NSObject {
    
    public static let shared = BackgroundModelDownloader()
    
    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    
    public var onProgress: ((Double, Int64, Int64) -> Void)?
    public var onCompletion: ((Result<URL, Error>) -> Void)?
    
    private let resumeDataKey = "sarah_model_download_resume_data"
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.sarahia.modeldownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        // Restauration des données de reprise en cas de crash ou redémarrage
        self.resumeData = UserDefaults.standard.data(forKey: resumeDataKey)
    }
    
    /// Lance ou reprend le téléchargement du fichier de modèle
    public func startDownload(from url: URL) {
        if let resumeData = resumeData {
            print("🔄 [BackgroundModelDownloader] Reprise du téléchargement partiel...")
            downloadTask = session.downloadTask(withResumeData: resumeData)
        } else {
            print("🚀 [BackgroundModelDownloader] Démarrage du téléchargement depuis : \(url.absoluteString)")
            downloadTask = session.downloadTask(with: url)
        }
        downloadTask?.resume()
    }
    
    /// Met en pause et sauvegarde les octets déjà reçus
    public func pauseDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            guard let self = self, let data = data else { return }
            self.resumeData = data
            UserDefaults.standard.set(data, forKey: self.resumeDataKey)
            print("⏸️ [BackgroundModelDownloader] Téléchargement mis en pause avec \(data.count) octets sauvegardés.")
        })
    }
    
    /// Annule et supprime la session de téléchargement
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        resumeData = nil
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
        // Nettoyage des données de reprise
        resumeData = nil
        UserDefaults.standard.removeObject(forKey: resumeDataKey)
        
        let fileManager = FileManager.default
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(NSError(domain: "com.sarahia.downloader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Dossier Application Support introuvable"])))
            }
            return
        }
        
        let modelsDir = appSupportDir.appendingPathComponent("SarahAI/models", isDirectory: true)
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let destinationURL = modelsDir.appendingPathComponent("model_ondevice.gguf")
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            print("✅ [BackgroundModelDownloader] Modèle déplacé vers : \(destinationURL.path)")
            
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.success(destinationURL))
            }
        } catch {
            print("❌ [BackgroundModelDownloader] Erreur lors du déplacement : \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(error))
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("⚠️ [BackgroundModelDownloader] Téléchargement interrompu : \(error.localizedDescription)")
            // Si des données de reprise sont disponibles dans l'erreur
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = resumeData
                UserDefaults.standard.set(resumeData, forKey: resumeDataKey)
            }
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            if let completionHandler = AppDelegate.backgroundSessionCompletionHandler {
                AppDelegate.backgroundSessionCompletionHandler = nil
                completionHandler()
                print("⚡ [BackgroundModelDownloader] Callback système d'arrière-plan notifié avec succès.")
            }
        }
    }
}
