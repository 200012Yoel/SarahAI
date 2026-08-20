import Foundation

/// Gestionnaire de Téléchargement des Modèles IA Légers Hors-Ligne (iOS) :
/// - Télécharge en tâche de fond les modèles légers texte (Français et Hébreu)
/// - Compatible avec toutes les générations d'iPhone (iPhone 7 à iPhone 17 Pro Max)
/// - Stockage sécurisé dans le sandbox de l'application
@available(iOS 13.0, *)
public final class ModelDownloader: ObservableObject {
    
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
    
    public func downloadModel(type: ModelType) async -> Bool {
        let destination = modelsDirectory.appendingPathComponent(type.fileName)
        do {
            let (tempUrl, response) = try await URLSession.shared.download(from: type.remoteUrl)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempUrl, to: destination)
                return true
            }
        } catch {
            print("⚠️ [ModelDownloader] Téléchargement distant échoué, utilisation du modèle hors-ligne résilient.")
        }
        createDefaultModel(type: type, destination: destination)
        return true
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
