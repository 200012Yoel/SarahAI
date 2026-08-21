import Foundation

/// Gestionnaire Résilient de Téléchargement des Modèles IA Légers (iOS 12.0+ à 18.0+) :
/// - Initialisation immédiate des modèles par défaut embarqués
/// - Téléchargement distant avec timeout 5s et repli hors-ligne automatique sans bloquer le démarrage
public final class ModelDownloader {
    
    public static let shared = ModelDownloader()
    
    public enum ModelType: String, CaseIterable {
        case frenchNLP = "fr_lite"
        case hebrewNLP = "he_lite"
        
        public var displayName: String {
            switch self {
            case .frenchNLP: return "Modèle IA Français Hors-Ligne"
            case .hebrewNLP: return "Modèle IA Hébreu Hors-Ligne"
            }
        }
        
        public var fileName: String {
            switch self {
            case .frenchNLP: return "sarah_fr_model.json"
            case .hebrewNLP: return "sarah_he_model.json"
            }
        }
        
        public var remoteUrl: URL {
            switch self {
            case .frenchNLP:
                return URL(string: "https://raw.githubusercontent.com/200012Yoel/SarahAI/main/models/fr_lite.json")!
            case .hebrewNLP:
                return URL(string: "https://raw.githubusercontent.com/200012Yoel/SarahAI/main/models/he_lite.json")!
            }
        }
    }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 8.0
        return URLSession(configuration: config)
    }()
    
    private var modelsDirectory: URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = (urls.first ?? fm.temporaryDirectory).appendingPathComponent("ai_models", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {
        ensureDefaultModelsCreated()
    }
    
    public func isModelDownloaded(type: ModelType) -> Bool {
        let file = modelsDirectory.appendingPathComponent(type.fileName)
        return FileManager.default.fileExists(atPath: file.path)
    }
    
    // MARK: - Téléchargement Callback (iOS 12.0+)
    
    public func downloadModel(type: ModelType, completion: @escaping (Bool) -> Void) {
        let destination = modelsDirectory.appendingPathComponent(type.fileName)
        let task = session.downloadTask(with: type.remoteUrl) { [weak self] tempUrl, response, error in
            if let tempUrl = tempUrl,
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let fm = FileManager.default
                if fm.fileExists(atPath: destination.path) {
                    try? fm.removeItem(at: destination)
                }
                do {
                    try fm.moveItem(at: tempUrl, to: destination)
                    completion(true)
                    return
                } catch {}
            }
            
            // Fallback modèle hors-ligne par défaut
            self?.createDefaultModel(type: type, destination: destination)
            completion(true)
        }
        task.resume()
    }
    
    // MARK: - Téléchargement Moderne Async/Await (iOS 13.0+)
    
    @available(iOS 13.0, *)
    public func downloadModel(type: ModelType) async -> Bool {
        return await withCheckedContinuation { continuation in
            self.downloadModel(type: type) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    private func ensureDefaultModelsCreated() {
        for type in ModelType.allCases {
            let dest = modelsDirectory.appendingPathComponent(type.fileName)
            if !FileManager.default.fileExists(atPath: dest.path) {
                createDefaultModel(type: type, destination: dest)
            }
        }
    }
    
    private func createDefaultModel(type: ModelType, destination: URL) {
        let content: String
        switch type {
        case .frenchNLP:
            content = """
            {"lang":"fr","name":"French Lite Core","version":"1.0","dictionary":{"bonjour":"Bonjour ! Comment puis-je vous aider ?","merci":"Avec grand plaisir !","qui es-tu":"Je suis Sarah, votre intelligence artificielle."}}
            """
        case .hebrewNLP:
            content = """
            {"lang":"he","name":"Hebrew Lite Core","version":"1.0","dictionary":{"שלום":"Bonjour ! שלום וברכה","מה נשמע":"הכל מצוין תודה, איך אני יכולה לעזור לך?","תודה":"בשמחה רבה!"}}
            """
        }
        try? content.write(to: destination, atomically: true, encoding: .utf8)
    }
}
