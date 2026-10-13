import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Optional user-owned translation server (LibreTranslate-compatible API).
/// Translate Live normally uses Apple's on-device Translation framework;
/// this backend is only used when the user enters a server in the settings.
/// No public third-party API is ever called silently.
@available(iOS 16.2, *)
public enum TranslateLiveTranslationBackend {
    public enum Outcome {
        case translated(String)
        case unavailable(String)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(
            in: .whitespacesAndNewlines.union(.punctuationCharacters)
        )
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
        guard let url = validatedURL(serverURL)?.appendingPathComponent("translate") else {
            completion(.unavailable(
                "Adresse du serveur de traduction invalide. Vérifie ⚙️."
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
