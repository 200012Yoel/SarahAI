import Foundation

/// Représente un message dans la conversation entre l'utilisateur et Sarah AI.
public struct Message: Identifiable, Equatable, Codable {
    public let id: UUID
    public let content: String
    public let isFromUser: Bool
    public let timestamp: Date
    public var audioDuration: TimeInterval?
    public var imageData: Data?
    public var alertEvent: AlertEvent?
    public var generatedImageURL: String?
    public var generatedMusicStyle: String?
    public var isGeneratingImage: Bool?
    public var imageGenerationPrompt: String?
    
    public init(
        id: UUID = UUID(),
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        audioDuration: TimeInterval? = nil,
        imageData: Data? = nil,
        alertEvent: AlertEvent? = nil,
        generatedImageURL: String? = nil,
        generatedMusicStyle: String? = nil,
        isGeneratingImage: Bool? = nil,
        imageGenerationPrompt: String? = nil
    ) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.audioDuration = audioDuration
        self.imageData = imageData
        self.alertEvent = alertEvent
        self.generatedImageURL = generatedImageURL
        self.generatedMusicStyle = generatedMusicStyle
        self.isGeneratingImage = isGeneratingImage
        self.imageGenerationPrompt = imageGenerationPrompt
    }
    
    /// Détecte si le message contient une image générée (URL Pollinations / Flux ou fichier local)
    public var detectedImageURL: String? {
        if let explicit = generatedImageURL, !explicit.isEmpty { return explicit }
        if content.contains("https://image.pollinations.ai/prompt/") {
            let parts = content.components(separatedBy: "https://image.pollinations.ai/prompt/")
            if parts.count > 1 {
                let urlPart = parts[1].components(separatedBy: .whitespacesAndNewlines).first ?? ""
                return "https://image.pollinations.ai/prompt/\(urlPart)"
            }
        }
        if let prompt = imageGenerationPrompt, !prompt.isEmpty {
            if let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                return "https://image.pollinations.ai/prompt/\(encoded)?width=768&height=768&model=flux&nologo=true&enhance=true"
            }
        }
        return nil
    }
    
    /// Détecte si le message est une composition musicale de Sarah
    public var detectedMusicStyle: String? {
        if let explicit = generatedMusicStyle, !explicit.isEmpty { return explicit }
        if content.contains("Sarah Music Engine") || content.contains("Morceau composé") || content.contains("Moteur Musical Open Source") {
            for style in ["Lo-Fi Chill", "Synthwave Électro", "Piano Classique", "Ambiance Méditation", "Épique Cinématique", "Jazz Bossa"] {
                if content.contains(style) { return style }
            }
            return "Lo-Fi Chill"
        }
        return nil
    }
    
    /// Détecte si le message est un rapport d'analyse de vision
    public var isVisionReport: Bool {
        return content.contains("Éléments identifiés") || content.contains("Texte extrait (OCR)") || content.contains("Visages détectés")
    }
    
    /// Détecte si le message contient du code HTML (balises <html>, <!DOCTYPE html>, ou bloc de code ```html ... ```)
    public var detectedHTMLCode: String? {
        // 1. Détection bloc de code markdown avec balise explicite ```html
        if content.contains("```html") {
            let parts = content.components(separatedBy: "```html")
            if parts.count > 1 {
                let codePart = parts[1].components(separatedBy: "```").first ?? ""
                let trimmed = codePart.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        // 2. Détection bloc markdown générique ``` contenant du HTML
        if content.contains("```") {
            let parts = content.components(separatedBy: "```")
            for i in stride(from: 1, to: parts.count, by: 2) {
                var chunk = parts[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if chunk.hasPrefix("html\n") || chunk.hasPrefix("xml\n") {
                    let lines = chunk.components(separatedBy: "\n")
                    chunk = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let lowerChunk = chunk.lowercased()
                if lowerChunk.contains("<!doctype html") ||
                    (lowerChunk.contains("<html") && lowerChunk.contains("</html>")) ||
                    (lowerChunk.contains("<head") && lowerChunk.contains("<body")) ||
                    (lowerChunk.contains("<div") && lowerChunk.contains("</div>") && (lowerChunk.contains("<style") || lowerChunk.contains("<script") || lowerChunk.contains("class="))) {
                    return chunk
                }
            }
        }
        // 3. Détection HTML brut directement dans le corps du texte
        let lower = content.lowercased()
        if lower.contains("<!doctype html") ||
            (lower.contains("<html") && lower.contains("</html>")) ||
            (lower.contains("<head") && lower.contains("<body") && lower.contains("</body>")) {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    /// Vrai si le message contient du code HTML interactif à prévisualiser
    public var isHTMLCode: Bool {
        return detectedHTMLCode != nil
    }
    
    /// Formate l'heure du message pour l'affichage (ex: "14:32")
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
    
    /// Formate la date complète pour les séparateurs de conversation
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: timestamp)
    }
}

// MARK: - Extension String : Décodage Robuste des Entités HTML (iOS 12.0+ à iOS 18.0+)
extension String {
    
    /// Décode proprement toutes les entités HTML brutes (ex: &#xF4;, &#xE0;, &quot;, &amp;, etc.)
    public func decodingHTMLEntities() -> String {
        guard self.contains("&") else { return self }
        
        var result = self
            // Entités XML/HTML de base
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            
            // Accents français courants
            .replacingOccurrences(of: "&eacute;", with: "é")
            .replacingOccurrences(of: "&egrave;", with: "è")
            .replacingOccurrences(of: "&ecirc;", with: "ê")
            .replacingOccurrences(of: "&agrave;", with: "à")
            .replacingOccurrences(of: "&ccedil;", with: "ç")
            .replacingOccurrences(of: "&ocirc;", with: "ô")
            .replacingOccurrences(of: "&icirc;", with: "î")
            .replacingOccurrences(of: "&ucirc;", with: "û")
            .replacingOccurrences(of: "&iuml;", with: "ï")
            .replacingOccurrences(of: "&euml;", with: "ë")
            .replacingOccurrences(of: "&ouml;", with: "ö")
            .replacingOccurrences(of: "&uuml;", with: "ü")
            .replacingOccurrences(of: "&auml;", with: "ä")
            .replacingOccurrences(of: "&Eacute;", with: "É")
            .replacingOccurrences(of: "&Egrave;", with: "È")
            .replacingOccurrences(of: "&Agrave;", with: "À")
            .replacingOccurrences(of: "&Ccedil;", with: "Ç")
        
        // 1. Décodage des entités hexadécimales (ex: &#xF4;, &#xE0;, &#x27;)
        if let regexHex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);", options: []) {
            let nsStr = result as NSString
            let matches = regexHex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let hexStr = nsStr.substring(with: match.range(at: 1))
                if let codePoint = UInt32(hexStr, radix: 16),
                   let scalar = UnicodeScalar(codePoint) {
                    let charStr = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: charStr)
                    }
                }
            }
        }
        
        // 2. Décodage des entités décimales (ex: &#244;, &#224;)
        if let regexDec = try? NSRegularExpression(pattern: "&#([0-9]+);", options: []) {
            let nsStr = result as NSString
            let matches = regexDec.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let decStr = nsStr.substring(with: match.range(at: 1))
                if let codePoint = UInt32(decStr, radix: 10),
                   let scalar = UnicodeScalar(codePoint) {
                    let charStr = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: charStr)
                    }
                }
            }
        }
        
        return result
    }
}
