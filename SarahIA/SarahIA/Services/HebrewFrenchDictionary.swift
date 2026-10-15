import Foundation

/// Open Hebrew → French dictionary bundled with the app (≈60 000 entries,
/// built by `.github/workflows/build-he-fr-dictionary.yml` from Tatoeba,
/// CC BY 2.0 FR, and Wiktionary, CC BY-SA 4.0).
///
/// It is used before the neural translator for what dictionaries do best:
/// whole everyday sentences heard exactly, idioms and short phrases that a
/// neural model often translates literally. Anything else goes to MADLAD.
public final class HebrewFrenchDictionary {
    public static let shared = HebrewFrenchDictionary()

    private enum Kind: Character { case sentence = "s", expression = "e", word = "w" }

    private var sentences: [String: String] = [:]
    private var expressions: [String: String] = [:]
    private var words: [String: String] = [:]
    private var maxExpressionWords = 1
    private let lock = NSLock()
    private var loaded = false
    private var loading = false

    public var entryCount: Int {
        lock.lock(); defer { lock.unlock() }
        return sentences.count + expressions.count + words.count
    }

    private init() {}

    /// Loads the bundled file in the background (a few MB, ~100 ms).
    public func preload() {
        lock.lock()
        guard !loaded, !loading else { lock.unlock(); return }
        loading = true
        lock.unlock()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.load()
        }
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "he_fr_dictionary", withExtension: "tsv",
                                        subdirectory: "TranslationModels")
                ?? Bundle.main.url(forResource: "he_fr_dictionary", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            lock.lock(); loading = false; loaded = true; lock.unlock()
            return
        }
        var s: [String: String] = [:], e: [String: String] = [:], w: [String: String] = [:]
        var longest = 1
        text.enumerateLines { line, _ in
            guard let kind = line.first, kind != "#" else { return }
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { return }
            let key = String(parts[1]), french = String(parts[2])
            guard !key.isEmpty, !french.isEmpty else { return }
            switch Kind(rawValue: kind) {
            case .sentence: if s[key] == nil { s[key] = french }
            case .expression:
                if e[key] == nil { e[key] = french }
                longest = max(longest, key.split(separator: " ").count)
            case .word: if w[key] == nil { w[key] = french }
            case .none: break
            }
        }
        lock.lock()
        sentences = s; expressions = e; words = w
        maxExpressionWords = min(longest, 8)
        loaded = true; loading = false
        lock.unlock()
    }

    /// Same normalisation as the build script: no vowel points, no
    /// punctuation, single spaces.
    public static func key(_ hebrew: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in hebrew.precomposedStringWithCanonicalMapping.unicodeScalars {
            let v = scalar.value
            if v == 0x05BE { scalars.append(" "); continue }            // maqaf
            if (0x0591...0x05C7).contains(v) { continue }                // niqqud
            scalars.append(scalar)
        }
        return String(scalars)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// A French translation when the dictionary can give a RELIABLE one,
    /// otherwise nil (the neural translator is used instead).
    ///  * the whole heard sentence is a known sentence or expression, or
    ///  * it splits entirely into known multi-word expressions, or
    ///  * it is one or two words, each known.
    /// Word-by-word composition of longer sentences is never returned:
    /// it reads like a bad machine translation.
    public func translate(_ hebrew: String) -> String? {
        let k = Self.key(hebrew)
        guard !k.isEmpty else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard loaded else { return nil }

        if let whole = sentences[k] ?? expressions[k] { return Self.finish(whole, question: hebrew.contains("?")) }
        let tokens = k.split(separator: " ").map(String.init)
        if tokens.count == 1, let word = words[k] { return Self.finish(word, question: hebrew.contains("?")) }
        guard tokens.count <= 12 else { return nil }

        var parts: [String] = []
        var index = 0
        var usedSingleWords = 0
        while index < tokens.count {
            var matched = false
            let maxLength = min(maxExpressionWords, tokens.count - index)
            if maxLength >= 2 {
                for length in stride(from: maxLength, through: 2, by: -1) {
                    let piece = tokens[index..<(index + length)].joined(separator: " ")
                    if let french = sentences[piece] ?? expressions[piece] {
                        parts.append(french); index += length; matched = true; break
                    }
                }
            }
            // A one-word human sentence ("שלום" → "Bonjour.") is reliable.
            if !matched, let french = sentences[tokens[index]] {
                parts.append(french); index += 1; matched = true
            }
            if !matched, let french = words[tokens[index]] {
                parts.append(french); index += 1; usedSingleWords += 1; matched = true
            }
            if !matched { return nil }
        }
        // Only expressions, or a very short utterance.
        guard usedSingleWords == 0 || tokens.count <= 2 else { return nil }
        let joined = parts.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " .!?")) }
            .joined(separator: ", ")
        return Self.finish(joined, question: hebrew.contains("?"))
    }

    private static func finish(_ french: String, question: Bool) -> String {
        var text = french.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return text }
        text = first.uppercased() + text.dropFirst()
        if let last = text.last, !".!?…".contains(last) {
            text += question ? " ?" : "."
        }
        return text
    }
}
