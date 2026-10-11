import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Translation remains separate from Whisper ASR and neural TTS.
/// Production does NOT silently use a third-party free public API.
/// An explicitly configured user-owned LibreTranslate/Argos endpoint is used
/// for long sentences and non-English targets (AGPL-3.0 server obligations).
@available(iOS 16.2, *)
public enum TranslateLiveTranslationBackend {
    public enum Outcome {
        case translated(String)
        case unavailable(String)
    }

    /// Only exact short phrases are recognized by this local demo dictionary.
    /// Partial word-for-word replacement is intentionally disabled: it can
    /// mistranslate TV news and produce confidently wrong spoken results.
    private static let exactPhrases: [[String: String]] = [
        ["he": "שלום", "fr": "Bonjour", "en": "Hello"],
        ["he": "תודה", "fr": "Merci", "en": "Thank you"],
        ["he": "תודה רבה", "fr": "Merci beaucoup", "en": "Thank you very much"],
        ["he": "בבקשה", "fr": "S'il vous plaît", "en": "Please"],
        ["he": "להתראות", "fr": "Au revoir", "en": "Goodbye"],
        ["he": "כן", "fr": "Oui", "en": "Yes"],
        ["he": "לא", "fr": "Non", "en": "No"],
        ["he": "לילה טוב", "fr": "Bonne nuit", "en": "Good night"],
        ["he": "ערב טוב", "fr": "Bonsoir", "en": "Good evening"],
        ["he": "מה נשמע", "fr": "Comment ça va ?", "en": "How are you?"]
    ]

    private static func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(
            in: .whitespacesAndNewlines.union(.punctuationCharacters)
        )
    }

    public static func exactLocalTranslation(_ text: String, from: String, to: String) -> String? {
        guard from != "auto", from != to else { return nil }
        let key = normalized(text)
        return exactPhrases.first(where: { pair in
            pair[from].map { normalized($0) == key } ?? false
        })?[to]
    }

    public static func translate(
        text: String, from source: String, to target: String,
        serverURL: String, completion: @escaping (Outcome) -> Void
    ) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            completion(.unavailable("Aucun texte à traduire."))
            return
        }
        guard source != target else {
            completion(.unavailable("La langue source est identique à la destination."))
            return
        }
        if let local = exactLocalTranslation(cleaned, from: source, to: target) {
            completion(.translated(local))
            return
        }
        guard let url = validatedURL(serverURL)?.appendingPathComponent("translate") else {
            completion(.unavailable(
                "Traduction complète indisponible. Configure ton serveur neuronal dans les réglages ⚙️. "
                + "Whisper traduit également certaines langues directement en anglais."
            ))
            return
        }
        let parameters: [String: String] = [
            "q": cleaned, "source": source, "target": target, "format": "text"
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: parameters) else {
            completion(.unavailable("Erreur de préparation de la traduction."))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = json
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        let session = URLSession(configuration: configuration)
        session.dataTask(with: request) { data, response, error in
            defer { session.finishTasksAndInvalidate() }
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data,
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let translation = value["translatedText"] as? String
            else {
                let detail = error?.localizedDescription ?? "Langue indisponible ou erreur du serveur."
                completion(.unavailable("Serveur de traduction : " + detail))
                return
            }
            let final = translation.trimmingCharacters(in: .whitespacesAndNewlines)
            // A source-identical fallback is not evidence of actual translation.
            guard !final.isEmpty, normalized(final) != normalized(cleaned) else {
                completion(.unavailable("Ce passage n'a pas été traduit par le serveur."))
                return
            }
            completion(.translated(final))
        }.resume()
    }

    /// The HTTP endpoint is only ever selected by the user, never a public
    /// free endpoint wired into the app. HTTP is permitted only on private LANs.
    public static func validatedURL(_ userInput: String) -> URL? {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil
        else { return nil }
        if scheme == "https" {
            return components.url
        }
        guard scheme == "http" else { return nil }
        let localHost = host == "localhost" || host == "127.0.0.1"
            || host.hasPrefix("192.168.") || host.hasPrefix("10.")
            || host.hasSuffix(".local")
            || (host.hasPrefix("172.") && {
                let octets = host.split(separator: ".")
                return octets.count == 4
                    && (octets.count > 1 && (16...31).contains(Int(octets[1]) ?? -1))
            }())
        guard localHost else { return nil }
        return components.url
    }
}
