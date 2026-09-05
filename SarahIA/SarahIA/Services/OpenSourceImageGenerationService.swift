import Foundation
import UIKit

/// Service de Génération d'Images et Photos Open Source & Gratuit pour Sarah IA
/// - Utilise les modèles open source de pointe (Flux, SDXL-Turbo, Stable Diffusion) via l'infrastructure décentralisée et ouverte
/// - Zéro clé API requise, 100% fonctionnel et accessible sur mobile
/// - Gestion du cache mémoire et disque pour un affichage instantané
/// - Notification automatique pour intégration visuelle dans le chat et l'orbe
public final class OpenSourceImageGenerationService {
    
    public static let shared = OpenSourceImageGenerationService()
    
    public struct GeneratedImageResult {
        public let prompt: String
        public let image: UIImage?
        public let imageURL: URL?
        public let modelName: String
        public let isSuccess: Bool
        public let errorMessage: String?
    }
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let session: URLSession
    
    private var imagesDirectory: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = (urls.first ?? fileManager.temporaryDirectory).appendingPathComponent("SarahGeneratedImages", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 35.0
        self.session = URLSession(configuration: config)
        self.cache.countLimit = 30
    }
    
    // MARK: - Détection d'Intention de Génération d'Image
    
    /// Détecte si la requête de l'utilisateur demande de générer, dessiner ou créer une image / photo
    public func isImageGenerationIntent(_ text: String) -> (isIntent: Bool, cleanedPrompt: String) {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let triggers = [
            "génère une image de ", "génère une photo de ", "génère une image d'un ", "génère une photo d'un ",
            "genere une image de ", "genere une photo de ", "genere une image d un ", "genere une photo d un ",
            "génère-moi une image de ", "génère-moi une photo de ", "genere moi une image de ", "genere moi une photo de ",
            "crée une image de ", "crée une photo de ", "cree une image de ", "cree une photo de ",
            "crée-moi une image de ", "crée-moi une photo de ", "cree moi une image de ", "cree moi une photo de ",
            "dessine-moi ", "dessine moi ", "dessine une ", "dessine un ", "dessine ",
            "fais-moi une image de ", "fais moi une image de ", "fais une image de ", "fais une photo de ",
            "génère une illustration de ", "genere une illustration de ", "crée un visuel de ", "cree un visuel de ",
            "génère une image ", "genere une image ", "génère une photo ", "genere une photo ",
            "generate an image of ", "generate a picture of ", "draw me "
        ]
        
        for trigger in triggers {
            if lower.starts(with: trigger) {
                let prompt = String(text.dropFirst(trigger.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prompt.isEmpty {
                    return (true, prompt)
                }
            } else if let range = lower.range(of: trigger) {
                let prompt = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prompt.isEmpty {
                    return (true, prompt)
                }
            }
        }
        
        // Mots-clés isolés de déclenchement
        if (lower.contains("génère") || lower.contains("genere") || lower.contains("crée") || lower.contains("cree") || lower.contains("fais")) &&
           (lower.contains("image") || lower.contains("photo") || lower.contains("dessin") || lower.contains("illustration") || lower.contains("tableau")) {
            // Nettoyage rapide pour isoler le sujet
            var cleaned = text
            let stopWords = ["sarah", "s'il te plaît", "sil te plait", "stp", "peux-tu", "peux tu", "génère", "genere", "crée", "cree", "fais", "moi", "une", "un", "des", "image", "photo", "dessin", "illustration", "de", "d'un", "d'une", "du", "sur"]
            for word in stopWords {
                let pattern = "\\b\(word)\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count), withTemplate: "")
                }
            }
            let res = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            if res.count >= 3 {
                return (true, res)
            }
        }
        
        return (false, "")
    }
    
    // MARK: - Génération d'Image Haute Définition (CoreML LCM On-Device / Cloud)
    
    /// Génère une image via le modèle local CoreML LCM (Sarah_ImageGen_Local) ou Cloud HD
    public func generateImage(
        prompt: String,
        width: Int = 768,
        height: Int = 768,
        model: String = "flux",
        completion: @escaping (GeneratedImageResult) -> Void
    ) {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else {
            completion(GeneratedImageResult(
                prompt: prompt,
                image: nil,
                imageURL: nil,
                modelName: model,
                isSuccess: false,
                errorMessage: "Le sujet de l'image est vide."
            ))
            return
        }
        
        // 1. Vérifier si le modèle CoreML Sarah_ImageGen_Local est actif (A15 Bionic / Neural Engine)
        if SarahLocalImageGenEngine.shared.isLocalLCMModelAvailable {
            let config = SarahLocalImageGenEngine.LCMConfiguration(steps: 4, guidanceScale: 1.8, width: width, height: height)
            SarahLocalImageGenEngine.shared.generateImage(prompt: cleanPrompt, config: config) { result in
                switch result {
                case .success(let image):
                    completion(GeneratedImageResult(
                        prompt: cleanPrompt,
                        image: image,
                        imageURL: nil,
                        modelName: SarahLocalImageGenEngine.modelIdentifier,
                        isSuccess: true,
                        errorMessage: nil
                    ))
                case .failure(let error):
                    completion(GeneratedImageResult(
                        prompt: cleanPrompt,
                        image: nil,
                        imageURL: nil,
                        modelName: SarahLocalImageGenEngine.modelIdentifier,
                        isSuccess: false,
                        errorMessage: error.localizedDescription
                    ))
                }
            }
            return
        }
        
        // 2. Vérifier le cache mémoire d'abord
        let cacheKey = "\(model)_\(cleanPrompt)_\(width)x\(height)" as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            completion(GeneratedImageResult(
                prompt: cleanPrompt,
                image: cachedImage,
                imageURL: nil,
                modelName: model,
                isSuccess: true,
                errorMessage: nil
            ))
            return
        }
        
        guard NetworkMonitor.shared.isOnline else {
            completion(GeneratedImageResult(
                prompt: cleanPrompt,
                image: nil,
                imageURL: nil,
                modelName: model,
                isSuccess: false,
                errorMessage: "Mode hors-ligne actif (génération distante suspendue)."
            ))
            return
        }
        
        // Construction de l'URL sécurisée pour le modèle open source Flux / Pollinations
        guard let encodedPrompt = cleanPrompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            completion(GeneratedImageResult(
                prompt: cleanPrompt,
                image: nil,
                imageURL: nil,
                modelName: model,
                isSuccess: false,
                errorMessage: "Erreur d'encodage du prompt."
            ))
            return
        }
        
        let urlString = "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=\(width)&height=\(height)&model=\(model)&nologo=true&enhance=true"
        guard let requestURL = URL(string: urlString) else {
            completion(GeneratedImageResult(
                prompt: cleanPrompt,
                image: nil,
                imageURL: nil,
                modelName: model,
                isSuccess: false,
                errorMessage: "URL de génération invalide."
            ))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.cachePolicy = .returnCacheDataElseLoad
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(GeneratedImageResult(
                        prompt: cleanPrompt,
                        image: nil,
                        imageURL: requestURL,
                        modelName: model,
                        isSuccess: false,
                        errorMessage: error.localizedDescription
                    ))
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(GeneratedImageResult(
                        prompt: cleanPrompt,
                        image: nil,
                        imageURL: requestURL,
                        modelName: model,
                        isSuccess: false,
                        errorMessage: "Format d'image non reconnu ou flux corrompu."
                    ))
                }
                return
            }
            
            // Mise en cache et enregistrement local sur le disque
            self.cache.setObject(image, forKey: cacheKey)
            let localFileURL = self.saveImageLocally(data: data, prompt: cleanPrompt)
            
            DispatchQueue.main.async {
                // Émettre une notification globale pour l'interface UI
                NotificationCenter.default.post(
                    name: NSNotification.Name("SarahGeneratedImageReady"),
                    object: nil,
                    userInfo: ["image": image, "prompt": cleanPrompt, "fileURL": localFileURL as Any]
                )
                
                completion(GeneratedImageResult(
                    prompt: cleanPrompt,
                    image: image,
                    imageURL: localFileURL ?? requestURL,
                    modelName: "Flux / SDXL Open Source",
                    isSuccess: true,
                    errorMessage: nil
                ))
            }
        }.resume()
    }
    
    // MARK: - Sauvegarde Locale
    
    private func saveImageLocally(data: Data, prompt: String) -> URL? {
        let safeName = prompt.prefix(20).replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        let filename = "sarah_img_\(Int(Date().timeIntervalSince1970))_\(safeName).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    /// Récupère la liste de toutes les images générées localement
    public func getSavedGeneratedImages() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        return files.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return d1 > d2
        }
    }
}
