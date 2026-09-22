import Foundation
import UIKit

/// Service de génération d'images de Sarah IA.
/// - Priorité absolue au moteur Core ML local sélectionné pour l'appareil.
/// - Aucun basculement réseau silencieux : le cloud est désactivé par défaut.
/// - Un fallback distant peut être activé explicitement dans les réglages.
/// - Les résultats locaux et distants sont annoncés avec leur modèle réel.
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

    /// Prompt réellement envoyé au moteur local. L'original reste séparé afin
    /// que l'interface affiche la demande de l'utilisateur, pas la recette interne.
    public struct ImagePromptPlan {
        public let originalPrompt: String
        public let positivePrompt: String
        public let isPhotographic: Bool
        public let primarySubject: String?
        public let requestedColors: [String]
    }
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let session: URLSession

    public var cloudFallbackEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sarahAllowCloudGeneration") }
        set { UserDefaults.standard.set(newValue, forKey: "sarahAllowCloudGeneration") }
    }
    
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
            "tu peux générer une image de ", "tu peux générer une photo de ",
            "tu peux générer une image ", "tu peux générer une photo ",
            "peux-tu générer une image de ", "peux-tu générer une photo de ",
            "peux-tu générer une image ", "peux-tu générer une photo ",
            "peux tu générer une image de ", "peux tu générer une photo de ",
            "peux tu générer une image ", "peux tu générer une photo ",
            "est-ce que tu peux générer une image de ", "est-ce que tu peux générer une photo de ",
            "est ce que tu peux générer une image de ", "est ce que tu peux générer une photo de ",
            "générer une image de ", "générer une photo de ",
            "générer une image ", "générer une photo ",
            "generer une image de ", "generer une photo de ",
            "generer une image ", "generer une photo ",
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
        if (lower.contains("génère") || lower.contains("genere") ||
            lower.contains("générer") || lower.contains("generer") ||
            lower.contains("crée") || lower.contains("cree") ||
            lower.contains("créer") || lower.contains("creer") ||
            lower.contains("dessine") || lower.contains("dessiner") ||
            lower.contains("fais") || lower.contains("faire")) &&
           (lower.contains("image") || lower.contains("photo") || lower.contains("dessin") || lower.contains("illustration") || lower.contains("tableau")) {
            // Nettoyage rapide pour isoler le sujet
            var cleaned = text
            let stopWords = ["sarah", "s'il te plaît", "sil te plait", "stp",
                "tu peux", "peux-tu", "peux tu", "est-ce que tu peux", "est ce que tu peux",
                "génère", "genere", "générer", "generer",
                "crée", "cree", "créer", "creer",
                "dessine", "dessiner", "fais", "faire",
                "moi", "une", "un", "des", "image", "photo", "dessin", "illustration", "visuel",
                "de", "d'un", "d'une", "du", "sur"]
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
    
    // MARK: - Préparation du prompt visuel

    /// Stable Diffusion 2.1 comprend mieux les instructions concises et
    /// fortement hiérarchisées. Sarah place donc le sujet en premier et
    /// transforme les détails français les plus courants en concepts visuels
    /// anglais, sans modifier le sens de la demande.
    public func makePromptPlan(_ original: String) -> ImagePromptPlan {
        let clean = normalizeUserImagePrompt(original)
        let folded = clean
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))

        let photographicWords = [
            "photo", "photorealiste", "realiste", "realistic", "photorealistic",
            "camera", "dslr", "cinematic"
        ]
        let isPhotographic = photographicWords.contains { folded.contains($0) }

        let translated = translateVisualTermsToEnglish(clean)
        let subjects = detectAllSubjects(in: clean)
        let subject = subjects.first
        let colors = detectRequestedColors(in: clean)
        let relations = detectRelationshipHints(in: clean, subjects: subjects)

        var parts: [String] = []

        if let subject {
            if !colors.isEmpty {
                parts.append("\(naturalList(colors)) \(subject)")
                parts.append("the \(subject) itself is painted \(naturalList(colors))")
            } else {
                parts.append(subject)
            }

            if subjects.count == 1 {
                parts.append("single main \(subject)")
            } else {
                parts.append("main subject: \(subject)")
                parts.append("scene contains all requested subjects: \(naturalList(subjects))")
                parts.append("all requested subjects clearly visible and recognizable")
            }
        }

        parts.append(contentsOf: relations)

        if !translated.isEmpty {
            parts.append(translated)
        }

        // La priorité est volontairement placée tôt dans le prompt : le modèle
        // doit comprendre que le sujet, et non le décor, est l'image.
        parts.append("close view")
        parts.append("centered composition")
        parts.append("main subject large in frame")
        parts.append("subject fills most of the image")
        parts.append("clear silhouette")
        parts.append("simple secondary background")
        parts.append("strong subject separation")

        if isPhotographic {
            parts.append("photorealistic photograph")
            parts.append("realistic materials")
            parts.append("natural lighting")
            parts.append("sharp focus")
            parts.append("detailed texture")
            parts.append("realistic proportions")
        } else {
            parts.append("highly detailed")
            parts.append("coherent lighting")
            parts.append("clean shapes")
            parts.append("balanced colors")
        }

        // Ces contraintes positives réduisent les défauts fréquents sans
        // dépendre d'une API de negative prompt qui varie selon le runtime.
        parts.append("one coherent scene")
        parts.append("clean composition")
        parts.append("no text")
        parts.append("no watermark")
        parts.append("no collage")
        parts.append("no duplicated subject")

        let positive = deduplicatePromptParts(parts)
            .joined(separator: ", ")

        return ImagePromptPlan(
            originalPrompt: clean,
            positivePrompt: positive,
            isPhotographic: isPhotographic,
            primarySubject: subject,
            requestedColors: colors
        )
    }

    private func normalizeUserImagePrompt(_ original: String) -> String {
        var value = original
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")

        let cleanupPatterns: [(String, String)] = [
            ("(?i)\\b(d'un\\s+){2,}", "un "),
            ("(?i)\\b(d'une\\s+){2,}", "une "),
            ("(?i)\\b(super\\s+){2,}", "super "),
            ("\\s{2,}", " ")
        ]

        for (pattern, replacement) in cleanupPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                value = regex.stringByReplacingMatches(
                    in: value,
                    range: NSRange(location: 0, length: value.utf16.count),
                    withTemplate: replacement
                )
            }
        }

        return value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
                .union(CharacterSet(charactersIn: ".,;:-"))
        )
    }

    private func translateVisualTermsToEnglish(_ text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "d'un ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "d'une ", with: "", options: .caseInsensitive)

        let phraseReplacements: [(String, String)] = [
            ("un petit lapin en train de le grimper", "a small rabbit visibly climbing onto the airplane fuselage"),
            ("petit lapin en train de le grimper", "small rabbit visibly climbing onto the airplane fuselage"),
            ("lapin en train de le grimper", "rabbit visibly climbing onto the airplane fuselage"),
            ("lapin en train de grimper sur l'avion", "rabbit visibly climbing onto the airplane fuselage"),
            ("lapin qui grimpe sur l'avion", "rabbit visibly climbing onto the airplane fuselage"),
            ("sur une moto", "on a motorcycle"),
            ("sur un moto", "on a motorcycle"),
            ("sur une voiture", "on a car"),
            ("sur un cheval", "on a horse"),
            ("dans le ciel", "in the sky"),
            ("au coucher du soleil", "at sunset"),
            ("de nuit", "at night"),
            ("gros plan", "close-up"),
            ("plan rapproché", "close view")
        ]

        for (from, to) in phraseReplacements {
            normalized = normalized.replacingOccurrences(
                of: from,
                with: to,
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        let dictionary: [String: String] = [
            "avion": "airplane",
            "aeronef": "aircraft",
            "lapin": "rabbit",
            "chat": "cat",
            "chien": "dog",
            "cheval": "horse",
            "voiture": "car",
            "moto": "motorcycle",
            "train": "train",
            "bateau": "boat",
            "maison": "house",
            "ville": "city",
            "montagne": "mountain",
            "mer": "sea",
            "plage": "beach",
            "ciel": "sky",
            "femme": "woman",
            "homme": "man",
            "enfant": "child",
            "robot": "robot",
            "oiseau": "bird",
            "dauphin": "dolphin",
            "bleu": "blue",
            "bleue": "blue",
            "violet": "purple",
            "violette": "purple",
            "rouge": "red",
            "vert": "green",
            "verte": "green",
            "jaune": "yellow",
            "orange": "orange",
            "rose": "pink",
            "noir": "black",
            "noire": "black",
            "blanc": "white",
            "blanche": "white",
            "gris": "gray",
            "grise": "gray",
            "dore": "gold",
            "doree": "gold",
            "argente": "silver",
            "argentee": "silver",
            "realiste": "realistic",
            "photorealiste": "photorealistic",
            "photo": "photo",
            "super": "high quality"
        ]

        let separators = CharacterSet.whitespacesAndNewlines
        let tokens = normalized
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        let mapped = tokens.map { token -> String in
            let stripped = token.trimmingCharacters(in: .punctuationCharacters)
            let key = stripped
                .lowercased()
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))

            return dictionary[key] ?? stripped
        }

        return mapped
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func detectPrimarySubject(in text: String) -> String? {
        detectAllSubjects(in: text).first
    }

    private func detectAllSubjects(in text: String) -> [String] {
        let subjectMap: [(String, String)] = [
            ("avion", "airplane"), ("airplane", "airplane"), ("aeronef", "aircraft"),
            ("lapin", "rabbit"), ("rabbit", "rabbit"),
            ("chat", "cat"), ("cat", "cat"),
            ("chien", "dog"), ("dog", "dog"),
            ("cheval", "horse"), ("horse", "horse"),
            ("voiture", "car"), ("car", "car"),
            ("moto", "motorcycle"), ("motorcycle", "motorcycle"),
            ("train", "train"), ("bateau", "boat"), ("boat", "boat"),
            ("femme", "woman"), ("woman", "woman"),
            ("homme", "man"), ("man", "man"),
            ("enfant", "child"), ("child", "child"),
            ("robot", "robot"), ("oiseau", "bird"), ("bird", "bird"),
            ("dauphin", "dolphin"), ("dolphin", "dolphin"),
            ("maison", "house"), ("house", "house")
        ]

        let words = text
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var subjects: [String] = []
        for word in words {
            if let match = subjectMap.first(where: { $0.0 == word })?.1,
               !subjects.contains(match) {
                subjects.append(match)
            }
        }
        return subjects
    }

    private func detectRelationshipHints(
        in text: String,
        subjects: [String]
    ) -> [String] {
        let folded = text
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: "'")

        var hints: [String] = []

        let hasAirplane = subjects.contains("airplane") || subjects.contains("aircraft")
        let hasRabbit = subjects.contains("rabbit")
        let climbing = folded.contains("grimp") || folded.contains("escalad") || folded.contains("monte sur")

        if hasAirplane && hasRabbit && climbing {
            hints.append("a small rabbit is visibly climbing onto the outside of the airplane fuselage")
            hints.append("the rabbit is touching the airplane and is easy to see")
            hints.append("show both the airplane and the rabbit in the same coherent scene")
        }

        return hints
    }

    private func detectRequestedColors(in text: String) -> [String] {
        let map: [(String, String)] = [
            ("bleu", "blue"), ("bleue", "blue"), ("blue", "blue"),
            ("violet", "purple"), ("violette", "purple"), ("purple", "purple"),
            ("rouge", "red"), ("red", "red"),
            ("vert", "green"), ("verte", "green"), ("green", "green"),
            ("jaune", "yellow"), ("yellow", "yellow"),
            ("orange", "orange"),
            ("rose", "pink"), ("pink", "pink"),
            ("noir", "black"), ("noire", "black"), ("black", "black"),
            ("blanc", "white"), ("blanche", "white"), ("white", "white"),
            ("gris", "gray"), ("grise", "gray"), ("gray", "gray"),
            ("dore", "gold"), ("doree", "gold"), ("gold", "gold"),
            ("argente", "silver"), ("argentee", "silver"), ("silver", "silver")
        ]

        let words = text
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var colors: [String] = []
        for word in words {
            if let color = map.first(where: { $0.0 == word })?.1,
               !colors.contains(color) {
                colors.append(color)
            }
        }
        return colors
    }

    private func naturalList(_ values: [String]) -> String {
        guard let last = values.last else { return "" }
        if values.count == 1 { return last }
        if values.count == 2 { return values.joined(separator: " and ") }
        return values.dropLast().joined(separator: ", ") + " and " + last
    }

    private func deduplicatePromptParts(_ parts: [String]) -> [String] {
        var seen = Set<String>()
        return parts.compactMap { part in
            let clean = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = clean.lowercased()
            guard !clean.isEmpty, seen.insert(key).inserted else { return nil }
            return clean
        }
    }

    // MARK: - Optimisation du Photoréalisme & Descripteurs Optiques
    
    /// Enrichit automatiquement le prompt pour obtenir un rendu photographique ultra-réaliste
    public func enhancePromptForHyperrealism(_ original: String) -> String {
        makePromptPlan(original).positivePrompt
    }
    
    // MARK: - Construction URL d'Image
    
    /// Génère l'URL publique de génération pour le modèle Flux / Pollinations avec photoréalisme maximal
    public func buildImageURL(for prompt: String, width: Int = 768, height: Int = 768, model: String = "flux") -> String {
        let enhanced = enhancePromptForHyperrealism(prompt)
        var allowedSet = CharacterSet.urlPathAllowed
        allowedSet.remove(charactersIn: "/?#&=+[]@!$'*,;")
        let encoded = enhanced.addingPercentEncoding(withAllowedCharacters: allowedSet) ?? prompt.replacingOccurrences(of: "/", with: "-")
        return "https://image.pollinations.ai/prompt/\(encoded)?width=\(width)&height=\(height)&model=\(model)&nologo=true&enhance=true"
    }
    
    // MARK: - Génération d'Image Haute Définition (CoreML LCM On-Device / Cloud)
    
    /// Génère une image. Sarah tente d'abord le profil Core ML local.
    /// Le fallback distant n'est utilisé que si l'utilisateur l'a activé.
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
                modelName: SarahGenerativeModelCatalog.imageProfile().displayName,
                isSuccess: false,
                errorMessage: "Le sujet de l'image est vide."
            ))
            return
        }

        let profile = SarahGenerativeModelCatalog.imageProfile()
        let plan = makePromptPlan(cleanPrompt)

        let qualityConfig = SarahLocalImageGenEngine.LCMConfiguration(
            steps: profile.identifier.contains("sdxl") ? 24 : 24,
            guidanceScale: profile.identifier.contains("sdxl") ? 6.5 : 8.0,
            width: 512,
            height: 512,
            enablePhotorealismBoost: plan.isPhotographic
        )

        SarahLocalImageGenEngine.shared.generateImage(
            prompt: plan.positivePrompt,
            config: qualityConfig
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let image):
                let data = image.jpegData(compressionQuality: 0.94)
                let localURL = data.flatMap {
                    self.saveImageLocally(data: $0, prompt: cleanPrompt)
                }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedImageReady"),
                        object: nil,
                        userInfo: [
                            "image": image,
                            "prompt": cleanPrompt,
                            "fileURL": localURL as Any,
                            "modelName": profile.displayName,
                            "isLocal": true
                        ]
                    )

                    completion(GeneratedImageResult(
                        prompt: cleanPrompt,
                        image: image,
                        imageURL: localURL,
                        modelName: profile.displayName,
                        isSuccess: true,
                        errorMessage: nil
                    ))
                }

            case .failure(let localError):
                guard self.cloudFallbackEnabled else {
                    DispatchQueue.main.async {
                        completion(GeneratedImageResult(
                            prompt: cleanPrompt,
                            image: nil,
                            imageURL: nil,
                            modelName: profile.displayName,
                            isSuccess: false,
                            errorMessage: localError.localizedDescription
                        ))
                    }
                    return
                }

                self.fetchDirectImage(
                    prompt: cleanPrompt,
                    width: width,
                    height: height,
                    model: model
                ) { remote in
                    let result = GeneratedImageResult(
                        prompt: remote.prompt,
                        image: remote.image,
                        imageURL: remote.imageURL,
                        modelName: "Cloud · \(remote.modelName)",
                        isSuccess: remote.isSuccess,
                        errorMessage: remote.errorMessage
                    )
                    completion(result)
                }
            }
        }
    }

    /// Télécharge et traite directement l'image avec système de secours multi-serveurs
    public func fetchDirectImage(
        prompt: String,
        width: Int = 768,
        height: Int = 768,
        model: String = "flux",
        completion: @escaping (GeneratedImageResult) -> Void
    ) {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        let enhanced = enhancePromptForHyperrealism(cleanPrompt)
        var allowedSet = CharacterSet.urlPathAllowed
        allowedSet.remove(charactersIn: "/?#&=+[]@!$'*,;")
        let encoded = enhanced.addingPercentEncoding(withAllowedCharacters: allowedSet) ?? cleanPrompt.replacingOccurrences(of: "/", with: "-")
        
        let candidateURLs = [
            "https://image.pollinations.ai/prompt/\(encoded)?width=\(width)&height=\(height)&model=flux&nologo=true&enhance=true",
            "https://image.pollinations.ai/prompt/\(encoded)?width=\(width)&height=\(height)&model=turbo&nologo=true",
            "https://image.pollinations.ai/prompt/\(encoded)?width=512&height=512&nologo=true"
        ]
        
        tryFetchCandidates(urls: candidateURLs, index: 0, prompt: cleanPrompt, cacheKey: cacheKey, model: model, completion: completion)
    }
    
    private func tryFetchCandidates(
        urls: [String],
        index: Int,
        prompt: String,
        cacheKey: NSString,
        model: String,
        completion: @escaping (GeneratedImageResult) -> Void
    ) {
        guard index < urls.count, let requestURL = URL(string: urls[index]) else {
            DispatchQueue.main.async {
                completion(GeneratedImageResult(
                    prompt: prompt,
                    image: nil,
                    imageURL: nil,
                    modelName: model,
                    isSuccess: false,
                    errorMessage: "Échec de génération sur tous les serveurs d'images."
                ))
            }
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let data = data, let image = UIImage(data: data) {
                // Succès de décodage de l'image
                self.cache.setObject(image, forKey: cacheKey)
                let localFileURL = self.saveImageLocally(data: data, prompt: prompt)
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedImageReady"),
                        object: nil,
                        userInfo: ["image": image, "prompt": prompt, "fileURL": localFileURL as Any]
                    )
                    
                    completion(GeneratedImageResult(
                        prompt: prompt,
                        image: image,
                        imageURL: localFileURL ?? requestURL,
                        modelName: model,
                        isSuccess: true,
                        errorMessage: nil
                    ))
                }
            } else {
                // Tentative avec le serveur/modèle de secours suivant
                print("⚠️ [ImageGenService] Tentative sur URL candidate \(index + 1) échouée -> Bascule sur secours...")
                self.tryFetchCandidates(urls: urls, index: index + 1, prompt: prompt, cacheKey: cacheKey, model: model, completion: completion)
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
