import Foundation

/// Chargeur d'Assets et Moteur de Traduction Locale Hors-Ligne (FR ⇄ EN ⇄ HE)
public final class OfflineTranslationAssetLoader {
    
    public static let shared = OfflineTranslationAssetLoader()
    
    // Dictionnaires hors-ligne embarqués (0ms de latence, zéro réseau requis)
    private var frToEnDict: [String: String] = [:]
    private var enToFrDict: [String: String] = [:]
    private var frToHeDict: [String: String] = [:]
    private var heToFrDict: [String: String] = [:]
    private var enToHeDict: [String: String] = [:]
    private var heToEnDict: [String: String] = [:]
    
    public private(set) var isLoaded: Bool = false
    
    private init() {
        loadOfflineDictionaries()
    }
    
    /// Précharge les dictionnaires et tables de traduction en mémoire RAM
    public func loadOfflineDictionaries() {
        // 1. Français <-> Anglais
        frToEnDict = [
            "bonjour": "hello", "salut": "hi", "comment ça va": "how are you", "comment vas-tu": "how are you doing",
            "merci": "thank you", "merci beaucoup": "thanks a lot", "au revoir": "goodbye", "à bientôt": "see you soon",
            "oui": "yes", "non": "no", "s'il te plaît": "please", "d'accord": "okay", "je t'appelle": "I am calling you",
            "où es-tu": "where are you", "j'arrive": "I am coming", "à quelle heure": "at what time",
            "bonne journée": "have a nice day", "bonne nuit": "good night", "je suis prêt": "I am ready",
            "j'ai envoyé le message": "I sent the message", "peux-tu me rappeler": "can you call me back",
            "je t'aime": "I love you", "prends soin de toi": "take care", "bon courage": "good luck",
            "tout va bien": "everything is fine", "fais attention": "be careful", "je te tiens au courant": "I'll keep you posted"
        ]
        for (k, v) in frToEnDict { enToFrDict[v] = k }
        
        // 2. Français <-> Hébreu (Validé par Yoann)
        frToHeDict = [
            "bonjour": "שלום", "salut": "היי", "comment ça va": "מה נשמע", "comment vas-tu": "מה שלומך",
            "merci": "תודה", "merci beaucoup": "תודה רבה", "au revoir": "להתראות", "à bientôt": "נתראה בקרוב",
            "oui": "כן", "non": "לא", "s'il te plaît": "בבקשה", "d'accord": "בסדר", "je t'appelle": "אני מתקשר אליך",
            "où es-tu": "איפה אתה", "j'arrive": "אני מגיע", "à quelle heure": "באיזו שעה",
            "bonne journée": "יום טוב", "bonne nuit": "לילה טוב", "je suis prêt": "אני מוכן",
            "tout va bien": "הכל בסדר", "fais attention": "תיזהר", "je t'aime": "אני אוהב אותך",
            "bon appétit": "בתיאבון", "chabbat chalom": "שבת שלום", "félicitations": "מזל טוב",
            "bonne fête": "חג שמח", "pardon": "סליחה", "je te tiens au courant": "אעדכן אותך"
        ]
        for (k, v) in frToHeDict { heToFrDict[v] = k }
        
        // 3. Anglais <-> Hébreu
        enToHeDict = [
            "hello": "שלום", "hi": "היי", "how are you": "מה שלומך", "thank you": "תודה",
            "thanks": "תודה רבה", "goodbye": "להתראות", "see you": "נתראה", "yes": "כן",
            "no": "לא", "please": "בבקשה", "okay": "בסדר", "where are you": "איפה אתה",
            "good morning": "בוקר טוב", "good evening": "ערב טוב", "good night": "לילה טוב",
            "everything is good": "הכל טוב", "call me back": "תחזור אליי", "i love you": "אני אוהב אותך"
        ]
        for (k, v) in enToHeDict { heToEnDict[v] = k }
        
        isLoaded = true
    }
    
    /// Traduction instantanée hors-ligne sans latence
    public func translateOffline(text: String, from sourceLang: String, to targetLang: String) -> String {
        let clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        if sourceLang == targetLang { return text }
        
        // FR -> EN
        if sourceLang == "fr" && targetLang == "en" {
            if let direct = frToEnDict[clean] { return direct.capitalized }
            return translateByTokens(text: text, dict: frToEnDict)
        }
        // EN -> FR
        if sourceLang == "en" && targetLang == "fr" {
            if let direct = enToFrDict[clean] { return direct.capitalized }
            return translateByTokens(text: text, dict: enToFrDict)
        }
        // FR -> HE
        if sourceLang == "fr" && targetLang == "he" {
            if let direct = frToHeDict[clean] { return direct }
            return translateByTokens(text: text, dict: frToHeDict)
        }
        // HE -> FR
        if sourceLang == "he" && targetLang == "fr" {
            if let direct = heToFrDict[clean] { return direct.capitalized }
            return translateByTokens(text: text, dict: heToFrDict)
        }
        // EN -> HE
        if sourceLang == "en" && targetLang == "he" {
            if let direct = enToHeDict[clean] { return direct }
            return translateByTokens(text: text, dict: enToHeDict)
        }
        // HE -> EN
        if sourceLang == "he" && targetLang == "en" {
            if let direct = heToEnDict[clean] { return direct.capitalized }
            return translateByTokens(text: text, dict: heToEnDict)
        }
        
        return text
    }
    
    private func translateByTokens(text: String, dict: [String: String]) -> String {
        let words = text.components(separatedBy: " ")
        var translatedWords: [String] = []
        
        for w in words {
            let clean = w.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let tr = dict[clean] {
                translatedWords.append(tr)
            } else {
                translatedWords.append(w)
            }
        }
        return translatedWords.joined(separator: " ")
    }
}
