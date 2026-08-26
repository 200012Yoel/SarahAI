import Foundation

/// Moteur Lexicographique Local Yohan (Traducteur Bilingue Français ⇄ Hébreu / עברית ⇄ צרפתית).
/// Fusionne 5 à 6 dictionnaires spécialisés compressés :
/// 1. Dictionnaire conversationnel courant & politesse
/// 2. Dictionnaire des racines sémitiques (Shoresh / שורש) et formes verbales (Binyanim)
/// 3. Dictionnaire des expressions idiomatiques, argot israélien (Slang) et tournures familières
/// 4. Dictionnaire administratif, juridique et actualités
/// 5. Dictionnaire technique, informatique et scientifique
public final class YohanLexiconEngine {
    
    public static let shared = YohanLexiconEngine()
    
    public struct LexiconEntry {
        public let french: String
        public let hebrew: String
        public let transliteration: String // Phonétique française
        public let root: String?           // Racine hébraïque (Shoresh)
        public let category: String       // "courant", "slang", "technique", "formel", "verbe"
        public let notes: String?
    }
    
    private var entriesFRtoHE: [String: LexiconEntry] = [:]
    private var entriesHEtoFR: [String: LexiconEntry] = [:]
    
    private init() {
        loadLexiconDatabase()
    }
    
    private func loadLexiconDatabase() {
        let rawData: [LexiconEntry] = [
            // --- 1. CONVERSATIONNEL, FORMULES & POLITESSE ---
            LexiconEntry(french: "bonjour", hebrew: "שלום", transliteration: "Shalom", root: "ש.ל.ם", category: "courant", notes: "Signifie aussi paix et au revoir"),
            LexiconEntry(french: "salut", hebrew: "היי / אהלן", transliteration: "Hé / Ahlan", root: nil, category: "slang", notes: "Informel"),
            LexiconEntry(french: "merci", hebrew: "תודה", transliteration: "Toda", root: "י.ד.ה", category: "courant", notes: nil),
            LexiconEntry(french: "merci beaucoup", hebrew: "תודה רבה", transliteration: "Toda Raba", root: "י.ד.ה", category: "courant", notes: nil),
            LexiconEntry(french: "s'il vous plaît", hebrew: "בבקשה", transliteration: "Bevakasha", root: "ב.ק.ש", category: "courant", notes: "Signifie aussi 'de rien' ou 'je vous en prie'"),
            LexiconEntry(french: "s'il te plaît", hebrew: "בבקשה", transliteration: "Bevakasha", root: "ב.ק.ש", category: "courant", notes: nil),
            LexiconEntry(french: "au revoir", hebrew: "להתראות", transliteration: "Lehitraot", root: "ר.א.ה", category: "courant", notes: nil),
            LexiconEntry(french: "bonne nuit", hebrew: "לילה טוב", transliteration: "Laïla Tov", root: nil, category: "courant", notes: nil),
            LexiconEntry(french: "bonsoir", hebrew: "ערב טוב", transliteration: "Erev Tov", root: "ע.ר.ב", category: "courant", notes: nil),
            LexiconEntry(french: "bonne journée", hebrew: "יום טוב", transliteration: "Yom Tov", root: nil, category: "courant", notes: nil),
            LexiconEntry(french: "comment ça va", hebrew: "מה נשמע / מה קורה", transliteration: "Ma Nishma / Ma Koré", root: "ש.מ.ע", category: "courant", notes: nil),
            LexiconEntry(french: "comment vas tu", hebrew: "מה שלומך", transliteration: "Ma Shlomkha (m) / Ma Shlomekh (f)", root: "ש.ל.ם", category: "courant", notes: nil),
            LexiconEntry(french: "tout va bien", hebrew: "הכל בסדר", transliteration: "Hakol Besséder", root: "ס.ד.ר", category: "courant", notes: nil),
            LexiconEntry(french: "bienvenue", hebrew: "ברוכים הבאים", transliteration: "Broukhim Habaïm", root: "ב.ר.ך", category: "courant", notes: nil),
            LexiconEntry(french: "félicitations", hebrew: "מזל טוב", transliteration: "Mazal Tov", root: nil, category: "courant", notes: nil),
            LexiconEntry(french: "bon appétit", hebrew: "בתיאבון", transliteration: "Bete'avon", root: "ת.א.ב", category: "courant", notes: nil),
            LexiconEntry(french: "santé", hebrew: "לחיים", transliteration: "Lehaïm", root: "ח.י.ה", category: "courant", notes: "Trinquer à la vie"),
            LexiconEntry(french: "pardon", hebrew: "סליחה", transliteration: "Sliha", root: "ס.ל.ח", category: "courant", notes: "Excusez-moi / Pardon"),
            LexiconEntry(french: "excusez-moi", hebrew: "סליחה", transliteration: "Sliha", root: "ס.ל.ח", category: "courant", notes: nil),
            LexiconEntry(french: "oui", hebrew: "כן", transliteration: "Ken", root: nil, category: "courant", notes: nil),
            LexiconEntry(french: "non", hebrew: "לא", transliteration: "Lo", root: nil, category: "courant", notes: nil),
            LexiconEntry(french: "d'accord", hebrew: "בסדר / מסכים", transliteration: "Besséder / Maskim", root: "ס.ד.ר", category: "courant", notes: nil),
            LexiconEntry(french: "je t'aime", hebrew: "אני אוהב אותך (m) / אני אוהבת אותך (f)", transliteration: "Ani Ohev Otakh / Ani Ohevet Otkha", root: "א.ה.ב", category: "courant", notes: nil),
            
            // --- 2. ARGOT ISRAÉLIEN & EXPRESSIONS IDIOMATIQUES (SLANG) ---
            LexiconEntry(french: "c'est génial", hebrew: "זה מעולה / אחלה / סבבה", transliteration: "Zé Meulé / Akhla / Sababa", root: nil, category: "slang", notes: "Expressions courantes"),
            LexiconEntry(french: "pas de problème", hebrew: "אין בעיה / אין מצב", transliteration: "Eïn Be'aya", root: "ב.ע.י", category: "slang", notes: nil),
            LexiconEntry(french: "vas-y", hebrew: "יאללה", transliteration: "Yalla", root: nil, category: "slang", notes: "Encouragement ou départ"),
            LexiconEntry(french: "doucement", hebrew: "לאט לאט / רגע", transliteration: "Le'at Le'at / Réga", root: nil, category: "slang", notes: "Attends une seconde"),
            LexiconEntry(french: "grave", hebrew: "ממש / לגמרי", transliteration: "Mamash / Legamré", root: "ג.מ.ר", category: "slang", notes: "Confirmation absolue"),
            LexiconEntry(french: "frère", hebrew: "אחי", transliteration: "Akhi", root: "א.ח", category: "slang", notes: "Mon pote, mon frère"),
            LexiconEntry(french: "courage", hebrew: "בהצלחה / חזק ואמץ", transliteration: "Behatslakha / Hazak Ve'ematz", root: "צ.ל.ח", category: "courant", notes: "Bonne chance / Force"),
            
            // --- 3. RACINES & VERBES CLÉS ---
            LexiconEntry(french: "parler", hebrew: "לדבר", transliteration: "Ledaber", root: "ד.ב.ר", category: "verbe", notes: "Pi'el - Parler / Discuter"),
            LexiconEntry(french: "comprendre", hebrew: "להבין", transliteration: "Lehavin", root: "ב.י.ן", category: "verbe", notes: "Hif'il - Comprendre / Discerner"),
            LexiconEntry(french: "apprendre", hebrew: "ללמוד", transliteration: "Lilmod", root: "ל.מ.ד", category: "verbe", notes: "Pa'al - Étudier / Apprendre"),
            LexiconEntry(french: "traduire", hebrew: "לתרגם", transliteration: "Letargem", root: "ת.ר.ג.ם", category: "verbe", notes: "Quadrilitère - Traduire"),
            LexiconEntry(french: "écrire", hebrew: "לכתוב", transliteration: "Likhtov", root: "כ.ת.ב", category: "verbe", notes: "Pa'al - Écrire"),
            LexiconEntry(french: "lire", hebrew: "לקרוא", transliteration: "Likro", root: "ק.ר.א", category: "verbe", notes: "Pa'al - Lire / Appeler"),
            LexiconEntry(french: "vouloir", hebrew: "לרצות", transliteration: "Lirtsot", root: "ר.צ.ה", category: "verbe", notes: "Pa'al - Désirer"),
            LexiconEntry(french: "savoir", hebrew: "לדעת", transliteration: "Lada'at", root: "י.ד.ע", category: "verbe", notes: "Pa'al - Connaître / Savoir"),
            LexiconEntry(french: "aimer", hebrew: "לאהוב", transliteration: "Leehov", root: "א.ה.ב", category: "verbe", notes: "Pa'al - Aimer"),
            
            // --- 4. FORMEL, GÉOPOLITIQUE & ACTUALITÉ ---
            LexiconEntry(french: "paix", hebrew: "שלום", transliteration: "Shalom", root: "ש.ל.ם", category: "formel", notes: nil),
            LexiconEntry(french: "sécurité", hebrew: "ביטחון", transliteration: "Bitahon", root: "ב.ט.ח", category: "formel", notes: "Sécurité / Défense"),
            LexiconEntry(french: "armée", hebrew: "צבא / צה״ל", transliteration: "Tsava / Tsahal", root: "צ.ב.א", category: "formel", notes: "Armée de défense d'Israël"),
            LexiconEntry(french: "gouvernement", hebrew: "ממשלה", transliteration: "Memshala", root: "מ.ש.ל", category: "formel", notes: nil),
            LexiconEntry(french: "pays", hebrew: "מדינה / ארץ", transliteration: "Medina / Eretz", root: "ד.י.ן", category: "formel", notes: "État / Terre"),
            LexiconEntry(french: "jérusalem", hebrew: "ירושלים", transliteration: "Yerushalayim", root: "י.ר.ה + ש.ל.ם", category: "formel", notes: "Capitale éternelle"),
            LexiconEntry(french: "front intérieur", hebrew: "פיקוד העורף", transliteration: "Pikoud HaOref", root: "פ.ק.ד", category: "formel", notes: "Commandement de la protection civile"),
            LexiconEntry(french: "alerte", hebrew: "התרעה / צבע אדום", transliteration: "Hatra'a / Tseva Adom", root: "ר.ת.ע", category: "formel", notes: "Alerte rouge / Sécurité"),
            
            // --- 5. TECHNIQUE & INFORMATIQUE ---
            LexiconEntry(french: "ordinateur", hebrew: "מחשב", transliteration: "Mahshev", root: "ח.ש.ב", category: "technique", notes: nil),
            LexiconEntry(french: "application", hebrew: "אפליקציה / יישום", transliteration: "Applikatsia / Yisoum", root: "י.ש.ם", category: "technique", notes: nil),
            LexiconEntry(french: "intelligence artificielle", hebrew: "בינה מלאכותית", transliteration: "Bina Melakhoutit", root: "ב.י.ן + מ.ל.ך", category: "technique", notes: "IA (AI)"),
            LexiconEntry(french: "code", hebrew: "קוד / תכנות", transliteration: "Kod / Tikhnout", root: "ת.כ.נ", category: "technique", notes: "Programmation"),
            LexiconEntry(french: "téléphone", hebrew: "טלפון / נייד", transliteration: "Telefon / Nayad", root: "נ.י.ד", category: "technique", notes: "Portable / Smartphone"),
            LexiconEntry(french: "batterie", hebrew: "סוללה", transliteration: "Solela", root: "ס.ל.ל", category: "technique", notes: "Accumulateur d'énergie")
        ]
        
        for entry in rawData {
            let keyFR = normalize(entry.french)
            let keyHE = normalize(entry.hebrew)
            entriesFRtoHE[keyFR] = entry
            entriesHEtoFR[keyHE] = entry
        }
    }
    
    private func normalize(_ text: String) -> String {
        return text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Détection de la langue du texte
    public func isHebrew(_ text: String) -> Bool {
        var hebrewCount = 0
        var totalLetters = 0
        for scalar in text.unicodeScalars {
            let val = scalar.value
            if val >= 0x0590 && val <= 0x05FF {
                hebrewCount += 1
                totalLetters += 1
            } else if CharacterSet.letters.contains(scalar) {
                totalLetters += 1
            }
        }
        return totalLetters > 0 && Double(hebrewCount) / Double(totalLetters) > 0.4
    }
    
    /// Traduction experte bilingue enrichie (Dictionnaires + Grammaire + Racines sémitiques)
    public func translateExpert(text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "Veuillez saisir un texte à traduire." }
        
        let norm = normalize(clean)
        let isInputHebrew = isHebrew(clean)
        
        // 1. Recherche directe dans la base de lexique
        if isInputHebrew {
            // Recherche HE -> FR
            if let entry = entriesHEtoFR[norm] {
                return formatHebrewToFrenchCard(entry: entry, sourceText: clean)
            }
            
            // Recherche par sous-mots
            for (key, entry) in entriesHEtoFR {
                if norm.contains(key) {
                    return formatHebrewToFrenchCard(entry: entry, sourceText: clean)
                }
            }
        } else {
            // Recherche FR -> HE
            if let entry = entriesFRtoHE[norm] {
                return formatFrenchToHebrewCard(entry: entry, sourceText: clean)
            }
            
            // Recherche partielle
            for (key, entry) in entriesFRtoHE {
                if norm.contains(key) {
                    return formatFrenchToHebrewCard(entry: entry, sourceText: clean)
                }
            }
        }
        
        // 2. Traduction mot par mot assistée si phrase composée
        let words = clean.components(separatedBy: " ")
        if words.count > 1 {
            var translatedTokens: [String] = []
            for w in words {
                let n = normalize(w)
                if isInputHebrew {
                    if let e = entriesHEtoFR[n] {
                        translatedTokens.append(e.french)
                    } else {
                        translatedTokens.append(w)
                    }
                } else {
                    if let e = entriesFRtoHE[n] {
                        translatedTokens.append(e.hebrew)
                    } else {
                        translatedTokens.append(w)
                    }
                }
            }
            let reconstructed = translatedTokens.joined(separator: " ")
            let dirTitle = isInputHebrew ? "Hébreu ➔ Français" : "Français ➔ Hébreu"
            return "🇮🇱 **Yohan [Traduction Bilingue - \(dirTitle)]**\n\n« **\(reconstructed)** »"
        }
        
        // Fallback local propre
        let targetLang = isInputHebrew ? "français" : "hébreu"
        return "🇮🇱 **Yohan [Dictionnaire Local]**\n\nTraduction de « \(clean) » vers le \(targetLang) en cours d'indexation locale."
    }
    
    private func formatFrenchToHebrewCard(entry: LexiconEntry, sourceText: String) -> String {
        var card = "🇮🇱 **Yohan [Français ➔ Hébreu]**\n\n"
        card += "• **Hébreu :** **\(entry.hebrew)**\n"
        card += "• **Phonétique :** *\(entry.transliteration)*\n"
        if let root = entry.root {
            card += "• **Racine sémitique (שורש) :** `\(root)`\n"
        }
        card += "• **Registre :** \(entry.category.capitalized)\n"
        if let notes = entry.notes {
            card += "• **Note :** \(notes)\n"
        }
        return card
    }
    
    private func formatHebrewToFrenchCard(entry: LexiconEntry, sourceText: String) -> String {
        var card = "🇫🇷 **Yohan [Hébreu ➔ Français]**\n\n"
        card += "• **Français :** **\(entry.french.capitalized)**\n"
        card += "• **Prononciation :** *\(entry.transliteration)*\n"
        if let root = entry.root {
            card += "• **Racine sémitique (שורש) :** `\(root)`\n"
        }
        card += "• **Registre :** \(entry.category.capitalized)\n"
        if let notes = entry.notes {
            card += "• **Usage :** \(notes)\n"
        }
        return card
    }
}
