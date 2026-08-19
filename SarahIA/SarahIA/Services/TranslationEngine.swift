import Foundation

/// Moteur de Traduction Multilingue Temps Réel (Français, Hébreu, Anglais) pour iOS
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
        "merci|en": "Thank you",
        "au revoir|en": "Goodbye",
        "comment ça va|en": "How are you?",
        "bonne nuit|en": "Good night"
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
    
    /// Traduit le texte de manière asynchrone ultra-réactive
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage) async -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        
        // 1. Dictionnaire local instantané (0ms)
        let dictKey = targetLang == .english ? "\(lower)|en" : lower
        if let localMatch = fastLocalDict[dictKey] {
            return localMatch
        }
        
        // 2. Traduction réseau haute fidélité
        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(sourceLang)|\(targetLang.rawValue)") else {
            return clean
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["responseData"] as? [String: Any],
               let translatedText = responseData["translatedText"] as? String,
               !translatedText.isEmpty,
               !translatedText.lowercased().contains("no query specified") {
                return translatedText
            }
        } catch {}
        
        return clean
    }
}
