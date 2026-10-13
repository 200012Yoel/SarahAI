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

    // Production interpreter: NO built-in canned sentences or word
    // substitution. Every translated caption must come from a real
    // translation model, never a predetermined answer.

    /// Qwen3 GGUF is Apache-2.0 and the app already links llama.cpp.
    /// The IPA bundles the verified Qwen3 0.6B GGUF for immediate offline
    /// Hebrew ↔ French translation; an existing downloaded Qwen may also be used.
    #if os(iOS)
    private static var bundledQwenModel: URL? {
        Bundle.main.url(forResource: "Qwen3-0.6B-Q8_0", withExtension: "gguf",
                        subdirectory: "TranslationModels")
    }

    private static var translationModelURL: URL? {
        if let bundled = bundledQwenModel { return bundled }
        guard ModelSelectionEngine.shared.isLocalGGUFAllowed(),
              BackgroundModelDownloader.isModelDownloaded else { return nil }
        return BackgroundModelDownloader.localModelURL
    }

    public static var isLocalQwenReady: Bool {
        QwenLocalCodeRuntime.shared.isRuntimeLinked
            && translationModelURL != nil
    }

    /// Translate *directly* between Hebrew and French with the on-device
    /// Qwen model, bypassing Whisper's inaccurate English bridge.
    /// This function never substitutes a phrasebook translation.
    public static func translateWithLocalQwen(
        text: String, from source: String, to target: String,
        completion: @escaping (Outcome) -> Void
    ) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLocalQwenReady,
              let modelURL = translationModelURL else {
            completion(.unavailable("Le modèle Qwen3 local n'est pas encore téléchargé sur l'iPhone."))
            return
        }
        guard (source == "he" && target == "fr") ||
              (source == "fr" && target == "he") else {
            completion(.unavailable("Ce moteur est configuré pour hébreu ↔ français."))
            return
        }
        guard !clean.isEmpty else {
            completion(.unavailable("Aucun passage à traduire."))
            return
        }
        let fromLabel = source == "he" ? "hébreu" : "français"
        let toLabel = target == "fr" ? "français" : "hébreu"
        let system = """
        /no_think
        Tu es un moteur neuronal de traduction simultanée de \(fromLabel) vers \(toLabel).
        Traduis fidèlement les paroles entendues, y compris les noms propres.
        Retourne UNIQUEMENT leur traduction, sans présentation, excuses, raisonnement ni guillemets.
        Si une expression est difficile, conserve son nom propre, mais n'invente aucun contexte.
        """
        QwenLocalCodeRuntime.shared.generate(
            modelURL: modelURL, system: system,
            user: "/no_think\n" + clean,
            maxTokens: 88, fastTranslation: true
        ) { result in
            switch result {
            case .failure(let error):
                completion(.unavailable("Qwen3 local : " + error.localizedDescription))
            case .success(let raw):
                var output = SarahResponseCleaner.clean(raw)
                output = output
                    .replacingOccurrences(of: "<|im_end|>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if output.hasPrefix("Traduction :") {
                    output = String(output.dropFirst("Traduction :".count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // Reject empty, echo, irrelevant Latin text masquerading as
                // Hebrew, and repeated model hallucinations.
                guard !output.isEmpty, normalized(output) != normalized(clean),
                      !TranslateLiveContextBuffer.isUnreliableTranscript(output),
                      (target != "he" || TranslateLiveContextBuffer.isMostlyHebrew(output)),
                      (target != "fr" || output.range(
                          of: "[A-Za-zÀ-ÿ]", options: .regularExpression
                      ) != nil) else {
                    completion(.unavailable("Qwen3 n'a pas produit une traduction fiable de cet extrait."))
                    return
                }
                completion(.translated(output))
            }
        }
    }

    #else
    public static var isLocalQwenReady: Bool { false }
    public static func translateWithLocalQwen(
        text: String, from source: String, to target: String,
        completion: @escaping (Outcome) -> Void
    ) {
        completion(.unavailable("Le moteur Qwen3 requiert un appareil iOS et llama.cpp."))
    }
    #endif

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
                "Aucun véritable moteur de traduction n'est prêt pour cette langue. "
                + "Configure un serveur neuronal privé dans ⚙️ ou utilise le relais Whisper anglais → français."
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
