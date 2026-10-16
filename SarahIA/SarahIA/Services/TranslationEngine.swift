import Foundation
import Security
#if canImport(Translation)
import Translation
#endif

/// Moteur de traduction de Sarah (français, hébreu, anglais), entièrement dans l'application.
///
/// Ordre des moteurs :
/// - `.fast` (sous-titres pendant que la personne parle) :
///   dictionnaire → cache → moteur iOS sur l'appareil (hors ligne).
/// - `.best` (phrase terminée, celle qui est prononcée) :
///   dictionnaire → cache → DeepL (Internet) → moteur iOS sur l'appareil → MyMemory → dictionnaire de phrases.
///
/// Le moteur iOS est la brique système `Translation` : il fonctionne dans Sarah,
/// sans ouvrir l'app Traduction. L'hébreu y est disponible à partir d'iOS 27.
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

    /// `.fast` : réponse quasi instantanée, sans réseau (sous-titres en direct).
    /// `.best` : meilleure qualité possible (phrase finale).
    public enum Quality {
        case fast
        case best
    }

    /// Moteur ayant produit la dernière traduction (affichable dans l'interface).
    public enum EngineUsed: String {
        case dictionary = "Dictionnaire"
        case cache = "Cache"
        case deepL = "DeepL"
        case onDevice = "iPhone (hors ligne)"
        case myMemory = "MyMemory"
        case phrasebook = "Lexique local"
        case none = "Aucun"
    }

    public struct TranslationRequest {
        public let textToTranslate: String
        public let sourceLanguage: String
        public let targetLanguage: TargetLanguage
    }

    public private(set) var lastEngineUsed: EngineUsed = .none

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 8.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private let cache = NSCache<NSString, NSString>()

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

    private init() {
        cache.countLimit = 500
    }

    // MARK: - Clé DeepL (stockée dans le trousseau iOS)

    private static let keychainService = "com.sarahia.deepl"
    private static let keychainAccount = "apiKey"

    /// Clé API DeepL saisie dans les Réglages. `nil` si aucune clé.
    public var deepLAPIKey: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data,
                  let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !key.isEmpty else {
                return nil
            }
            return key
        }
        set {
            let baseQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount
            ]
            SecItemDelete(baseQuery as CFDictionary)
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    public var hasDeepLKey: Bool { deepLAPIKey != nil }

    // MARK: - Détection d'intention

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

    // MARK: - API publique

    /// Traduction avec callback (compatible avec l'ancien code). Utilise la meilleure qualité.
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage, completion: @escaping (String) -> Void) {
        translate(text: text, sourceLang: sourceLang, targetLang: targetLang, quality: .best, completion: completion)
    }

    /// Traduction avec callback et niveau de qualité choisi.
    /// Le callback est appelé une seule fois, sur une file quelconque.
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage, quality: Quality, completion: @escaping (String) -> Void) {
        guard #available(iOS 13.0, *) else {
            completion(legacyTranslate(text: text, sourceLang: sourceLang, targetLang: targetLang))
            return
        }
        Task {
            let result = await self.translate(text: text, sourceLang: sourceLang, targetLang: targetLang, quality: quality)
            completion(result)
        }
    }

    /// Traduction asynchrone (meilleure qualité).
    @available(iOS 13.0, *)
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage) async -> String {
        await translate(text: text, sourceLang: sourceLang, targetLang: targetLang, quality: .best)
    }

    /// Traduction asynchrone avec niveau de qualité.
    @available(iOS 13.0, *)
    public func translate(text: String, sourceLang: String, targetLang: TargetLanguage, quality: Quality) async -> String {
        if let translated = await translateIfPossible(text: text, sourceLang: sourceLang, targetLang: targetLang, quality: quality) {
            return translated
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Comme `translate`, mais renvoie `nil` si aucun moteur n'a vraiment traduit
    /// (utile pour les sous-titres : on garde alors l'ancienne traduction affichée).
    @available(iOS 13.0, *)
    public func translateIfPossible(text: String, sourceLang: String, targetLang: TargetLanguage, quality: Quality) async -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let target = targetLang.rawValue
        let source = normalizedSource(sourceLang, text: clean)
        if source == target { return clean }

        // 1. Dictionnaire instantané
        let lower = clean.lowercased()
        let dictKey = targetLang == .english ? "\(lower)|en" : lower
        if let localMatch = fastLocalDict[dictKey] {
            lastEngineUsed = .dictionary
            return localMatch
        }

        // 2. Cache (la qualité "best" n'utilise que les résultats DeepL / iOS mis en cache)
        let cacheKey = "\(source)|\(target)|\(clean)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            lastEngineUsed = .cache
            return cached as String
        }

        switch quality {
        case .fast:
            // Sous-titres : uniquement le moteur iOS sur l'appareil (aucun réseau, aucun quota consommé)
            if let onDevice = await translateOnDevice(clean, from: source, to: target) {
                lastEngineUsed = .onDevice
                return onDevice
            }
            return nil

        case .best:
            let online = NetworkMonitor.shared.isOnline

            // 3. DeepL (Internet, meilleure qualité)
            if online, let key = deepLAPIKey,
               let deepL = await translateWithDeepL(clean, from: source, to: target, apiKey: key) {
                cache.setObject(deepL as NSString, forKey: cacheKey)
                lastEngineUsed = .deepL
                return deepL
            }

            // 4. Moteur iOS sur l'appareil (hors ligne)
            if let onDevice = await translateOnDevice(clean, from: source, to: target) {
                cache.setObject(onDevice as NSString, forKey: cacheKey)
                lastEngineUsed = .onDevice
                return onDevice
            }

            // 5. MyMemory (gratuit, qualité moyenne, petit quota)
            if online, let memory = await translateWithMyMemory(clean, from: source, to: target) {
                lastEngineUsed = .myMemory
                return memory
            }

            // 6. Lexique de phrases embarqué
            let phrase = OfflineTranslationAssetLoader.shared.translateOffline(text: clean, from: source, to: target)
            if phrase.lowercased() != clean.lowercased() {
                lastEngineUsed = .phrasebook
                return phrase
            }

            lastEngineUsed = .none
            return nil
        }
    }

    // MARK: - Moteur iOS sur l'appareil

    /// État du moteur hors ligne pour une paire de langues.
    public enum OnDeviceStatus {
        case installed      // prêt, fonctionne sans Internet
        case downloadable   // supporté, le pack doit être téléchargé une fois
        case unsupported    // paire non disponible sur cette version d'iOS
    }

    @available(iOS 13.0, *)
    public func onDeviceStatus(from source: String, to target: String) async -> OnDeviceStatus {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            let status = await LanguageAvailability().status(
                from: Locale.Language(identifier: source),
                to: Locale.Language(identifier: target)
            )
            switch status {
            case .installed: return .installed
            case .supported: return .downloadable
            default: return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    @available(iOS 13.0, *)
    private func translateOnDevice(_ text: String, from source: String, to target: String) async -> String? {
        #if canImport(Translation) && compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return await OnDeviceTranslator.shared.translate(text, from: source, to: target)
        }
        #endif
        return nil
    }

    // MARK: - DeepL

    @available(iOS 13.0, *)
    private func translateWithDeepL(_ text: String, from source: String, to target: String, apiKey: String) async -> String? {
        let host = apiKey.hasSuffix(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com"
        guard let url = URL(string: "\(host)/v2/translate") else { return nil }

        let targetCode: String
        switch target {
        case "en": targetCode = "EN-US"
        case "he": targetCode = "HE"
        default: targetCode = "FR"
        }

        var body: [String: Any] = [
            "text": [text],
            "target_lang": targetCode
        ]
        if ["fr", "he", "en"].contains(source) {
            body["source_lang"] = source.uppercased()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await dataTask(request),
              let http = response as? HTTPURLResponse else {
            return nil
        }
        guard http.statusCode == 200 else {
            // 403 : clé invalide · 456 : quota atteint · 429 : trop de requêtes
            print("⚠️ [Traduction] DeepL a répondu \(http.statusCode)")
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let translated = translations.first?["text"] as? String,
              !translated.isEmpty else {
            return nil
        }
        return translated
    }

    // MARK: - MyMemory (dernier recours en ligne)

    @available(iOS 13.0, *)
    private func translateWithMyMemory(_ text: String, from source: String, to target: String) async -> String? {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(source)|\(target)") else {
            return nil
        }
        guard let (data, response) = try? await dataTask(URLRequest(url: url)),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["responseData"] as? [String: Any],
              let translated = responseData["translatedText"] as? String,
              !translated.isEmpty else {
            return nil
        }
        let lower = translated.lowercased()
        if lower.contains("no query specified") || lower.contains("mymemory warning") || lower.contains("quota") {
            return nil
        }
        return translated
    }

    // MARK: - Utilitaires

    private func normalizedSource(_ sourceLang: String, text: String) -> String {
        switch sourceLang {
        case "fr", "he", "en": return sourceLang
        default: return detectLanguage(text: text)
        }
    }

    /// `URLSession.data(for:)` n'existe qu'à partir d'iOS 15 : version compatible iOS 13+.
    @available(iOS 13.0, *)
    private func dataTask(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: error ?? URLError(.badServerResponse))
                }
            }.resume()
        }
    }

    /// Repli pour les très anciennes versions d'iOS (sans async/await).
    private func legacyTranslate(text: String, sourceLang: String, targetLang: TargetLanguage) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let dictKey = targetLang == .english ? "\(lower)|en" : lower
        if let match = fastLocalDict[dictKey] { return match }
        return OfflineTranslationAssetLoader.shared.translateOffline(text: clean, from: sourceLang, to: targetLang.rawValue)
    }
}

// MARK: - Traducteur iOS sur l'appareil (iOS 26+, hébreu à partir d'iOS 27)

#if canImport(Translation) && compiler(>=6.2)
@available(iOS 26.0, *)
private actor OnDeviceTranslator {
    static let shared = OnDeviceTranslator()

    private var sessions: [String: TranslationSession] = [:]
    private var installedPairs: Set<String> = []

    func translate(_ text: String, from source: String, to target: String) async -> String? {
        let pairKey = "\(source)|\(target)"
        let sourceLanguage = Locale.Language(identifier: source)
        let targetLanguage = Locale.Language(identifier: target)

        if !installedPairs.contains(pairKey) {
            let status = await LanguageAvailability().status(from: sourceLanguage, to: targetLanguage)
            guard status == .installed else { return nil }
            installedPairs.insert(pairKey)
        }

        let session: TranslationSession
        if let existing = sessions[pairKey] {
            session = existing
        } else {
            session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            sessions[pairKey] = session
        }

        do {
            let response = try await session.translate(text)
            let output = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? nil : output
        } catch {
            sessions[pairKey] = nil
            installedPairs.remove(pairKey)
            print("⚠️ [Traduction] Moteur iOS indisponible : \(error.localizedDescription)")
            return nil
        }
    }
}
#endif
