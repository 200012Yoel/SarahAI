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

    /// Translate Live is a separate screen. Mentioning an agent's name alone
    /// never opens it. Spoken commands and typed commands share this resolver.
    /// Source/target are inferred by meaning, NOT the order of language names:
    /// "Il parle anglais, je veux la traduction en hébreu" => en -> he.
    public static func pairFromCommand(_ input: String) -> (from: String, to: String)? {
        let normalized = input.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "fr_FR")
        )
        .lowercased()
        .replacingOccurrences(of: "’", with: "'")
        .replacingOccurrences(of: "‐", with: "-")
        .replacingOccurrences(of: "‑", with: "-")

        let directNames = [
            "translate live", "live translate", "traduction en direct",
            "traduction live", "traduction instantanee", "traducteur en direct",
            "traduis en direct"
        ]
        let explicitMode = directNames.contains(where: normalized.contains)
        let contextualMode =
            (normalized.contains("traduction") || normalized.contains("traduis"))
            && (normalized.contains("parle") || normalized.contains("quelqu'un")
                || normalized.contains("quelqu un"))
            && (normalized.contains("je veux") || normalized.contains("j'aimerais")
                || normalized.contains("active") || normalized.contains("lance"))
        guard explicitMode || contextualMode else { return nil }

        // Exclude a question ABOUT the feature from launch commands.
        if (normalized.contains("c'est quoi") || normalized.contains("comment fonctionne")
            || normalized.contains("explique")) &&
            !["active", "lance", "ouvre", "demarre"].contains(where: normalized.contains) {
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
        terms.sort { $0.alias.count > $1.alias.count }
        var matches: [(range: Range<String.Index>, code: String)] = []
        for term in terms {
            let pattern = "(?<![\\p{L}])" +
                NSRegularExpression.escapedPattern(for: term.alias) +
                "(?![\\p{L}])"
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let all = NSRange(normalized.startIndex..., in: normalized)
            for match in expression.matches(in: normalized, range: all) {
                guard let range = Range(match.range, in: normalized),
                      !matches.contains(where: { $0.range.overlaps(range) }) else { continue }
                matches.append((range, term.code))
            }
        }
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }

        var source: String?
        var target: String?
        for match in matches {
            let prefix = String(normalized[..<match.range.lowerBound])
            let before = String(prefix.suffix(110))
            // "parle anglais", "parle en anglais", "quelqu'un parle hébreu"
            let sourceCue = before.range(
                of: #"(?:parle|parlent|s'exprime|en train de parler)\s+(?:en\s+|l'|le\s+|la\s+)?"# + "$",
                options: .regularExpression
            ) != nil
            // "traduction en hébreu", "traduction en direct en français",
            // "traduis vers l'anglais", regardless of what preceded it.
            let targetCue = before.range(
                of: #"(?:traduction|traduis|traduire|traduit|traduite)\b.{0,58}\b(?:en|vers)\s+(?:l'|le\s+|la\s+)?"# + "$",
                options: .regularExpression
            ) != nil
            let fromCue = before.range(
                of: #"(?:depuis|de|du)\s+(?:l'|le\s+|la\s+)?"# + "$",
                options: .regularExpression
            ) != nil
            let towardCue = before.range(
                of: #"(?:vers|pour)\s+(?:l'|le\s+|la\s+)?"# + "$",
                options: .regularExpression
            ) != nil

            if sourceCue || (fromCue && !targetCue) {
                if source == nil && match.code != "auto" { source = match.code }
            } else if targetCue || towardCue {
                if target == nil && match.code != "auto" { target = match.code }
            }
        }

        // For "traduction de l'hébreu en français", use the first language
        // before the explicit destination. For "je veux la traduction en hébreu",
        // let automatic source detection handle the missing source.
        let selected = matches.filter { $0.code != "auto" }.map(\.code)
        if matches.contains(where: { $0.code == "auto" }),
           selected.count == 1, target == nil, source == nil {
            // "automatique japonais" means detect the input, translate to JP.
            source = "auto"
            target = selected[0]
        }
        if target != nil && source == nil {
            source = selected.first(where: { engineCode(for: $0) != engineCode(for: target!) })
                ?? "auto"
        } else if source != nil && target == nil {
            target = selected.first(where: { engineCode(for: $0) != engineCode(for: source!) })
                ?? (engineCode(for: source!) == "fr" ? "en" : "fr")
        } else if source == nil && target == nil {
            if selected.count >= 2 {
                source = selected[0]
                target = selected.first(where: { engineCode(for: $0) != engineCode(for: source!) })
            } else if let single = selected.first {
                source = single
                target = engineCode(for: single) == "fr" ? "en" : "fr"
            }
        }

        let resolvedFrom = source ?? "he"
        let resolvedTo = target ?? "fr"
        guard isRecognized(resolvedFrom), isSelectableTarget(resolvedTo),
              engineCode(for: resolvedFrom) != engineCode(for: resolvedTo) else {
            return ("he", "fr")
        }
        return (resolvedFrom, resolvedTo)
    }

}
