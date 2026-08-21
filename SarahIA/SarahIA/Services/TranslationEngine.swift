import Foundation

/// Moteur de Traduction Multilingue Résilient (Français, Hébreu, Anglais) :
/// - Dictionnaire local ultra-rapide (0ms, 100% hors-ligne)
/// - Requête réseau MyMemory avec timeout court (4s) et fallback local automatique
/// - Compatible iOS 12.0+ (Callbacks) et iOS 13.0+ (Async/Await)
public final class TranslationEngine {
    
    public static let shared = TranslationEngine()
    
    public enum TargetLanguage: String {
        case french = "fr"
        case hebrew = "he"
        case english = "en"
        
        public var displayNameFr: String {
            switch self {
            case .french: return "Français"
            case .hebrew: return "Hébreu"
            case .english: return "Anglais"
            }
        }
    }
    
    public struct TranslationRequest {
        public let textToTranslate: String
        public let sourceLanguage: String
        public let targetLanguage: TargetLanguage
    }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 6.0
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
    
    private let fastLocalDict: [String: String] = [
        // FR -> HE
        "bonjour": "שלום",
        "salut": "היי",
        "merci": "תודה",
        "merci beaucoup": "תודה רבה",
        "au revoir": "להתראות",
        "s'il vous plaît": "בבקשה",
        "s'il te plaît": "בבקשה",
        "oui": "כן",
        "non": "לא",
        "bonne nuit": "לילה טוב",
        "bonsoir": "ערב טוב",
        "comment ça va": "מה נשמע",
        "comment vas tu": "מה שלומך",
        "je t'aime": "אני אוהב אותך",
        "bienvenue": "ברוכים הבאים",
        "bon appétit": "בתיאבון",
        "félicitations": "מזל טוב",
        "pardon": "סליחה",
        
        // HE -> FR
        "שלום": "Bonjour",
        "תודה": "Merci",
        "תודה רבה": "Merci beaucoup",
        "להתראות": "Au revoir",
        "בבקשה": "S'il vous plaît",
        "כן": "Oui",
        "לא": "Non",
        "לילה טוב": "Bonne nuit",
        "ערב טוב": "Bonsoir",
        "מה נשמע": "Comment ça va ?",
        "מה שלומך": "Comment vas-tu ?",
        "סליחה": "Pardon / Excusez-moi",
        
        // FR -> EN
        "bonjour|en": "Hello",
        "salut|en": "Hi",
        "merci|en": "Thank you",
        "merci beaucoup|en": "Thank you very much",
        "au revoir|en": "Goodbye",
        "comment ça va|en": "How are you?",
        "bonne nuit|en": "Good night",
        "je t'aime|en": "I love you"
    ]
    
    private init() {}
    
    /// Analyse la phrase pour détecter une demande explicite de traduction
    public func parseTranslationIntent(input: String) -> TranslationRequest? {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Vers l'hébreu
        if lower.contains("en hébreu") || lower.contains("en hebreu") {
            let clean = lower
                .replacingOccurrences(of: "traduis", with: "")
                .replacingOccurrences(of: "traduit", with: "")
                .replacingOccurrences(of: "comment on dit", with: "")
                .replacingOccurrences(of: "comment se dit", with: "")
                .replacingOccurrences(of: "comment dit on", with: "")
                .replacingOccurrences(of: "en hébreu", with: "")
                .replacingOccurrences(of: "en hebreu", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                return TranslationRequest(textToTranslate: clean, sourceLanguage: "fr", targetLanguage: .hebrew)
            }
        }
        
        // 2. Vers l'anglais
        if lower.contains("en anglais") {
            let clean = lower
                .replacingOccurrences(of: "traduis", with: "")
                .replacingOccurrences(of: "traduit", with: "")
                .replacingOccurrences(of: "comment on dit", with: "")
                .replacingOccurrences(of: "comment se dit", with: "")
                .replacingOccurrences(of: "en anglais", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                return TranslationRequest(textToTranslate: clean, sourceLanguage: "fr", targetLanguage: .english)
            }
        }
        
        // 3. Vers le français
        if lower.contains("en français") || lower.contains("en francais") || lower.contains("לצרפתית") || lower.contains("בצרפתית") {
            let clean = lower
                .replacingOccurrences(of: "traduis", with: "")
                .replacingOccurrences(of: "traduit", with: "")
                .replacingOccurrences(of: "תרגם", with: "")
                .replacingOccurrences(of: "איך אומרים", with: "")
                .replacingOccurrences(of: "en français", with: "")
                .replacingOccurrences(of: "en francais", with: "")
                .replacingOccurrences(of: "לצרפתית", with: "")
                .replacingOccurrences(of: "בצרפתית", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                let src = detectLanguage(text: clean) == "he" ? "he" : "en"
                return TranslationRequest(textToTranslate: clean, sourceLanguage: src, targetLanguage: .french)
            }
        }
        
        return nil
    }
    
    public func detectLanguage(text: String) -> String {
        var hebrewCount = 0
        var latinCount = 0
        for scalar in text.unicodeScalars {
            let val = scalar.value
            if val >= 0x0590 && val <= 0x05FF {
                hebrewCount += 1
            } else if (val >= 65 && val <= 90) || (val >= 97 && val <= 122) || (val >= 0x00C0 && val <= 0x017F) {
                latinCount += 1
            }
        }
        return (hebrewCount > latinCount && hebrewCount > 0) ? "he" : "fr"
    }
    
    // MARK: - Traduction avec Callback (iOS 12.0+)
    
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage, completion: @escaping (String) -> Void) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        
        // 1. Dictionnaire local instantané (0ms, 100% hors-ligne)
        let dictKey = targetLang == .english ? "\(lower)|en" : lower
        if let localMatch = fastLocalDict[dictKey] {
            completion(localMatch)
            return
        }
        
        // 2. Requête API distante sécurisée avec timeout 4s
        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(sourceLang)|\(targetLang.rawValue)") else {
            completion(clean)
            return
        }
        
        let request = URLRequest(url: url)
        session.dataTask(with: request) { data, response, error in
            if let data = data,
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["responseData"] as? [String: Any],
               let translatedText = responseData["translatedText"] as? String,
               !translatedText.isEmpty,
               !translatedText.lowercased().contains("no query specified") {
                completion(translatedText)
            } else {
                // Fallback sur le texte d'origine
                completion(clean)
            }
        }.resume()
    }
    
    // MARK: - Traduction Asynchrone (iOS 13.0+)
    
    @available(iOS 13.0, *)
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage) async -> String {
        return await withCheckedContinuation { continuation in
            self.translate(text: text, sourceLang: sourceLang, targetLang: targetLang) { translated in
                continuation.resume(returning: translated)
            }
        }
    }
}
