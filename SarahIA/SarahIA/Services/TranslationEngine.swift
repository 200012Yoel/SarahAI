import Foundation
import Security
#if canImport(Translation)
import Translation
#endif
#if canImport(MLKitTranslate)
import MLKitTranslate
#endif

/// Moteur de traduction de Sarah (français, hébreu, anglais), entièrement dans l'application.
/// Tous les moteurs utilisés sont autorisés dans une application vendue.
///
/// Ordre des moteurs :
/// - `.fast` (sous-titres pendant que la personne parle, aucun réseau) :
///   dictionnaire → cache → Google ML Kit hors ligne → moteur iOS hors ligne.
/// - `.best` (phrase terminée, celle qui est prononcée) :
///   dictionnaire → cache → DeepL (Internet) → Google ML Kit hors ligne → moteur iOS → lexique embarqué.
///
/// Google ML Kit = le pack hors ligne de Google Traduction (hébreu et français, ~30 Mo par langue),
/// téléchargé une seule fois par Sarah. Obligation : afficher « Traduit par Google » (voir `attribution`).
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
        case googleOffline = "Google (hors ligne)"
        case onDevice = "iOS (hors ligne)"
        case phrasebook = "Lexique local"
        case none = "Aucun"

        /// Mention à afficher sous la traduction (obligatoire pour Google ML Kit).
        public var attribution: String? {
            switch self {
            case .googleOffline: return "Traduit par Google"
            case .deepL: return "Traduit par DeepL"
            default: return nil
            }
        }
    }

    /// Résultat détaillé : texte traduit + moteur utilisé.
    public struct TranslationResult {
        public let text: String
        public let engine: EngineUsed
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
        await translateDetailed(text: text, sourceLang: sourceLang, targetLang: targetLang, quality: quality)?.text
    }

    /// Traduction avec le nom du moteur utilisé (pour afficher « Traduit par Google »).
    @available(iOS 13.0, *)
    public func translateDetailed(text: String, sourceLang: String, targetLang: TargetLanguage, quality: Quality) async -> TranslationResult? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let target = targetLang.rawValue
        let source = normalizedSource(sourceLang, text: clean)
        if source == target { return TranslationResult(text: clean, engine: .none) }

        // 1. Dictionnaire instantané
        let lower = clean.lowercased()
        let dictKey = targetLang == .english ? "\(lower)|en" : lower
        if let localMatch = fastLocalDict[dictKey] {
            return record(TranslationResult(text: localMatch, engine: .dictionary))
        }

        // 2. Cache (garde le moteur d'origine pour l'attribution)
        let cacheKey = "\(source)|\(target)|\(clean)"
        if let cached = cachedResult(cacheKey) {
            return record(cached)
        }

        if quality == .best, NetworkMonitor.shared.isOnline, let key = deepLAPIKey,
           let deepL = await translateWithDeepL(clean, from: source, to: target, apiKey: key) {
            // 3. DeepL (Internet, meilleure qualité)
            return record(store(TranslationResult(text: deepL, engine: .deepL), key: cacheKey))
        }

        // 4. Google ML Kit (pack hors ligne de Google Traduction)
        if let google = await GoogleOfflineTranslator.shared.translate(clean, from: source, to: target) {
            return record(store(TranslationResult(text: google, engine: .googleOffline), key: cacheKey))
        }

        // 5. Moteur iOS hors ligne (si disponible sur l'appareil)
        if let onDevice = await translateOnDevice(clean, from: source, to: target) {
            return record(store(TranslationResult(text: onDevice, engine: .onDevice), key: cacheKey))
        }

        guard quality == .best else { return nil }

        // 6. Lexique de phrases embarqué
        let phrase = OfflineTranslationAssetLoader.shared.translateOffline(text: clean, from: source, to: target)
        if phrase.lowercased() != clean.lowercased() {
            return record(TranslationResult(text: phrase, engine: .phrasebook))
        }

        lastEngineUsed = .none
        return nil
    }

    // MARK: - Packs hors ligne

    /// Télécharge à l'avance les packs Google hors ligne des langues données (une seule fois, ~30 Mo chacun).
    public func prepareOfflinePacks(for languages: [String]) {
        GoogleOfflineTranslator.shared.prepare(languages: languages)
    }

    /// `true` si la traduction Google hors ligne est intégrée à cette version de Sarah.
    public var isGoogleOfflineAvailable: Bool {
        GoogleOfflineTranslator.isAvailable
    }

    // MARK: - Cache

    private let cacheLock = NSLock()
    private var engineCache: [String: TranslationResult] = [:]
    private var engineCacheOrder: [String] = []

    private func cachedResult(_ key: String) -> TranslationResult? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        return engineCache[key]
    }

    private func store(_ result: TranslationResult, key: String) -> TranslationResult {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if engineCache[key] == nil {
            engineCacheOrder.append(key)
            if engineCacheOrder.count > 500 {
                engineCache.removeValue(forKey: engineCacheOrder.removeFirst())
            }
        }
        engineCache[key] = result
        return result
    }

    private func record(_ result: TranslationResult) -> TranslationResult {
        lastEngineUsed = result.engine
        return result
    }

    // MARK: - Moteur iOS sur l'appareil

    /// État du moteur hors ligne iOS pour une paire de langues.
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

// MARK: - Google ML Kit : pack hors ligne de Google Traduction

/// Traduction hors ligne avec Google ML Kit (Pod `GoogleMLKit/Translate`).
/// Si le Pod n'est pas installé, ce traducteur est simplement inactif et l'app compile quand même.
private final class GoogleOfflineTranslator {
    static let shared = GoogleOfflineTranslator()

    static var isAvailable: Bool {
        #if canImport(MLKitTranslate)
        return true
        #else
        return false
        #endif
    }

    #if canImport(MLKitTranslate)
    private let lock = NSLock()
    private var translators: [String: Translator] = [:]
    private var readyPairs: Set<String> = []
    private var downloadingPairs: Set<String> = []

    private static func mlLanguage(_ code: String) -> TranslateLanguage? {
        switch code {
        case "fr": return .french
        case "he": return .hebrew
        case "en": return .english
        default: return nil
        }
    }

    private func translator(from source: String, to target: String) -> Translator? {
        guard let sourceLanguage = Self.mlLanguage(source),
              let targetLanguage = Self.mlLanguage(target) else { return nil }
        let key = "\(source)|\(target)"
        lock.lock(); defer { lock.unlock() }
        if let existing = translators[key] { return existing }
        let options = TranslatorOptions(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        let created = Translator.translator(options: options)
        translators[key] = created
        return created
    }

    /// Vrai si les packs des deux langues sont déjà sur l'iPhone.
    private func packsAreDownloaded(from source: String, to target: String) -> Bool {
        let manager = ModelManager.modelManager()
        for code in [source, target] where code != "en" {
            guard let language = Self.mlLanguage(code) else { return false }
            let model = TranslateRemoteModel.translateRemoteModel(language: language)
            if !manager.isModelDownloaded(model) { return false }
        }
        return true
    }

    func prepare(languages: [String]) {
        let codes = Array(Set(languages)).filter { Self.mlLanguage($0) != nil }
        for source in codes {
            for target in codes where source != target {
                ensureDownloaded(from: source, to: target)
            }
        }
    }

    private func ensureDownloaded(from source: String, to target: String) {
        let key = "\(source)|\(target)"
        lock.lock()
        if readyPairs.contains(key) || downloadingPairs.contains(key) {
            lock.unlock()
            return
        }
        downloadingPairs.insert(key)
        lock.unlock()

        guard let translator = translator(from: source, to: target) else {
            lock.lock(); downloadingPairs.remove(key); lock.unlock()
            return
        }

        // Packs d'environ 30 Mo : autorisés en 4G/5G pour que la traduction marche partout.
        let conditions = ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: true)
        translator.downloadModelIfNeeded(with: conditions) { [weak self] error in
            guard let self = self else { return }
            self.lock.lock()
            self.downloadingPairs.remove(key)
            if error == nil { self.readyPairs.insert(key) }
            self.lock.unlock()
            if let error = error {
                print("⚠️ [Traduction] Pack Google \(source) → \(target) non téléchargé : \(error.localizedDescription)")
            } else {
                print("✅ [Traduction] Pack Google hors ligne \(source) → \(target) prêt")
            }
        }
    }

    @available(iOS 13.0, *)
    func translate(_ text: String, from source: String, to target: String) async -> String? {
        let key = "\(source)|\(target)"

        lock.lock()
        var isReady = readyPairs.contains(key)
        lock.unlock()

        if !isReady && packsAreDownloaded(from: source, to: target) {
            lock.lock(); readyPairs.insert(key); lock.unlock()
            isReady = true
        }

        guard isReady, let translator = translator(from: source, to: target) else {
            // Pas encore téléchargé : on lance le téléchargement, les autres moteurs prennent le relais.
            ensureDownloaded(from: source, to: target)
            return nil
        }

        return await withCheckedContinuation { continuation in
            translator.translate(text) { translated, error in
                let output = translated?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: (error == nil && !output.isEmpty) ? output : nil)
            }
        }
    }
    #else
    func prepare(languages: [String]) {}

    @available(iOS 13.0, *)
    func translate(_ text: String, from source: String, to target: String) async -> String? {
        nil
    }
    #endif
}
