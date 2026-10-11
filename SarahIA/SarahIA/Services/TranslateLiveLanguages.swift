import Foundation

/// Language catalog for OpenAI Whisper Base (input) and Supertonic 3 (spoken output).
/// Whisper recognizes this catalog; a translation backend must actually support
/// a pair before Yoann can translate it. Distinguish availability from selection.
@available(iOS 16.2, *)
public enum TranslateLiveLanguages {
    public struct Language: Identifiable, Hashable {
        public let id: String
        public let label: String
        public var hasSpokenOutput: Bool {
            TranslateLiveLanguages.spokenOutputCodes.contains(TranslateLiveLanguages.engineCode(for: id))
        }
    }

    // Exactly the 31 language codes advertised by the Supertonic 3 model.
    public static let spokenOutputCodes: Set<String> = Set(
        "en ko ja ar bg cs da de el es et fi fr hi hr hu id it lt lv nl pl pt ro ru sk sl sv tr uk vi"
            .split(separator: " ").map(String.init)
    )

    // OpenAI Whisper tokenizer.py (October 2026). The value "auto" is a source-only
    // setting, not a target language. Some uncommon languages are less accurate.
    private static let whisperCodes =
        "en zh de es ru ko fr ja pt tr pl ca nl ar sv it id hi fi vi he uk el ms cs ro da hu ta no th ur hr bg lt la mi ml cy sk te fa lv bn sr az sl kn et mk br eu is hy ne mn bs kk sq sw gl mr pa si km sn yo so af oc ka be tg sd gu am yi lo uz fo ht ps tk nn mt sa lb my bo tl mg as tt haw ln ha ba jw su yue"
            .split(separator: " ").map(String.init)

    private static let frenchLocale = Locale(identifier: "fr_FR")

    /// English variants are real choices of SOURCE locale. OpenAI Whisper
    /// uses language code "en" for both and does NOT expose a guaranteed
    /// British vs American accent classification in the Base model.
    /// Supertonic 3 also uses "en" for output: accent is not guaranteed.
    public static func engineCode(for selection: String) -> String {
        switch selection {
        case "en-GB", "en-US": return "en"
        default: return selection
        }
    }

    public static func isEnglish(_ selection: String) -> Bool {
        engineCode(for: selection) == "en"
    }
    private static let overrides: [String: String] = [
        "he": "Hébreu", "en": "Anglais (générique)", "fr": "Français",
        "en-GB": "Anglais (Royaume-Uni)", "en-US": "Anglais (États-Unis)",
        "yue": "Cantonais", "zh": "Chinois (mandarin)",
        "nn": "Norvégien nynorsk", "jw": "Javanais",
        "auto": "Détection automatique"
    ]

    public static let available: [Language] = (
        whisperCodes.map { code in
            Language(id: code, label: overrides[code] ??
                frenchLocale.localizedString(forLanguageCode: code)?.capitalized ??
                code.uppercased())
        } + [
            Language(id: "en-GB", label: "Anglais (Royaume-Uni)"),
            Language(id: "en-US", label: "Anglais (États-Unis)")
        ]
    ).sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }

    public static let sourceOptions: [Language] = [
        Language(id: "auto", label: "Détection automatique")
    ] + available

    public static let favorites: [Language] = ["he", "fr", "en-GB", "en-US", "en", "es", "ar", "de", "it", "pt"]
        .compactMap { code in available.first(where: { $0.id == code }) }

    public static func label(for code: String) -> String {
        if code == "auto" { return "Détection automatique" }
        return available.first(where: { $0.id == code })?.label ?? code.uppercased()
    }

    public static func isRecognized(_ code: String) -> Bool {
        code == "auto" || whisperCodes.contains(engineCode(for: code))
    }

    public static func isSelectableTarget(_ code: String) -> Bool {
        whisperCodes.contains(engineCode(for: code))
    }

    /// French language names and common synonyms for natural activation.
    /// The matching is limited to entire words, avoiding accidental hits.
    public static func pairFromCommand(_ input: String) -> (from: String, to: String)? {
        let normalized = input.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "fr_FR")
        ).lowercased()
        guard normalized.contains("translate live"),
              ["active", "lance", "demarre", "ouvre", "mets"].contains(where: normalized.contains) else {
            return nil
        }

        var terms: [(alias: String, code: String)] = available.map {
            ($0.label.folding(options: [.caseInsensitive, .diacriticInsensitive],
                             locale: Locale(identifier: "fr_FR")).lowercased(), $0.id)
        }
        terms += [
            ("hebreu", "he"), ("anglais", "en"), ("francais", "fr"),
            ("anglais britannique", "en-GB"), ("anglais americain", "en-US"),
            ("anglais du royaume-uni", "en-GB"), ("anglais des etats-unis", "en-US"),
            ("anglais d'angleterre", "en-GB"), ("anglais de l'angleterre", "en-GB"),
            ("anglais des etatsunis", "en-US"), ("anglais des usa", "en-US"),
            ("anglais uk", "en-GB"), ("anglais us", "en-US"),
            ("espagnol", "es"), ("allemand", "de"), ("arabe", "ar"),
            ("italien", "it"), ("portugais", "pt"), ("russe", "ru"),
            ("japonais", "ja"), ("chinois", "zh"), ("hindi", "hi"),
            ("coreen", "ko"), ("automatique", "auto")
        ]
        // Longest names first, so "chinois mandarin" beats "chinois".
        terms.sort { $0.alias.count > $1.alias.count }
        var matches: [(offset: Int, code: String)] = []
        var occupied: [Range<String.Index>] = []
        for term in terms {
            let escaped = NSRegularExpression.escapedPattern(for: term.alias)
            let pattern = "(?<![\\p{L}])" + escaped + "(?![\\p{L}])"
            guard let exp = try? NSRegularExpression(pattern: pattern) else { continue }
            let all = NSRange(normalized.startIndex..., in: normalized)
            for m in exp.matches(in: normalized, range: all) {
                guard let range = Range(m.range, in: normalized) else { continue }
                guard !occupied.contains(where: { $0.overlaps(range) }) else { continue }
                occupied.append(range)
                matches.append((
                    offset: normalized.distance(from: normalized.startIndex, to: range.lowerBound),
                    code: term.code
                ))
            }
        }
        matches.sort { $0.offset < $1.offset }
        if matches.count >= 2, matches[0].code != matches[1].code,
           matches[1].code != "auto" {
            return (matches[0].code, matches[1].code)
        }
        if matches.count == 1 && matches[0].code != "auto" {
            return (matches[0].code, "fr")
        }
        return ("he", "fr")
    }
}
