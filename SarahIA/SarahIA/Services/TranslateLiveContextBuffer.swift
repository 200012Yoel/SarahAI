import Foundation

/// Short contextual buffer for the live interpreter.
/// Whisper can revise hypotheses when the next segment arrives. This buffer
/// keeps a provisional caption and only speaks committed clauses.
/// Note: linguistic coherence still depends on the actual translation model.
@available(iOS 16.2, *)
public struct TranslateLiveContextBuffer {
    public struct Update {
        public let provisional: String
        public let committed: [String]
        public let recentContext: String
    }

    public private(set) var provisional = ""
    public private(set) var committedHistory: [String] = []
    private let contextLimit = 400
    private let historyLimit = 6

    public init() {}

    /// Whisper can output captioning labels when hearing radio music.
    /// These are NOT dialogue and must never be sent to translation or TTS.
    public static func isNonSpeechCaption(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let caption = trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "[](){}♬♪♫ "))
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        let labels: Set<String> = [
            "musique", "music", "applaudissements", "applause",
            "rires", "laughter", "bruit", "noise", "silence",
            "inaudible", "instrumental", "sous-titres", "subtitles"
        ]
        return labels.contains(caption) || caption.isEmpty
    }

    /// A short TV segment containing four or more exact repetitions of a
    /// one-to-eight-word fragment is very likely a Whisper decode loop.
    /// Reject rather than display or pronounce an invented broadcast.
    public static func isRepeatingHallucination(_ text: String) -> Bool {
        let words = text.lowercased().split { char in
            char.isWhitespace || ".,!?;:،؛。！؟".contains(char)
        }.map(String.init)
        guard words.count >= 6 else { return false }

        // Whisper Base can also get stuck on a *single* frequent word after
        // a few changing prefix words ("האז כתב ... כתב כתב כתב").
        // The old prefix-only detector let these false captions through.
        if words.count >= 9 {
            var counts: [String: Int] = [:]
            for word in words { counts[word, default: 0] += 1 }
            if let largest = counts.values.max(),
               largest >= 6,
               largest * 10 >= words.count * 5 {
                return true
            }
        }

        for size in 1...min(8, words.count / 4) {
            let unit = Array(words.prefix(size))
            var repeats = 0
            while (repeats + 1) * size <= words.count {
                let offset = repeats * size
                guard Array(words[offset..<(offset + size)]) == unit else { break }
                repeats += 1
            }
            if repeats >= 4 && repeats * size * 10 >= words.count * 7 {
                return true
            }
        }
        return false
    }

    /// Check the *English* hypothesis from Whisper against its paired Hebrew
    /// caption. On TV/music the bilingual decoder sometimes hallucinates
    /// "I'm sorry. I'm sorry." for a short Hebrew name or silence. Such a
    /// string is NOT valid evidence of a translation and must never reach TTS.
    /// Reject hallucinated Latin captions from a recognizer explicitly
    /// locked to Hebrew. Music/noise sometimes gives Whisper English tokens
    /// despite a Hebrew-language setting.
    public static func isMostlyHebrew(_ text: String) -> Bool {
        var hebrew = 0
        var letters = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.letters.contains(scalar) { letters += 1 }
            if (0x05D0...0x05EA).contains(scalar.value) { hebrew += 1 }
        }
        return hebrew >= 2 && hebrew * 5 >= max(1, letters) * 3
    }

    public static func isSuspiciousEnglishPivot(
        _ english: String, hebrewSource: String
    ) -> Bool {
        let cleaned = english.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isUnreliableTranscript(cleaned) { return true }
        let sentences = cleaned.split(whereSeparator: { ".!?;".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }
        if sentences.count >= 2,
           Set(sentences).count == 1 {
            return true
        }
        let englishWords = cleaned.split(whereSeparator: {
            $0.isWhitespace || ".,!?;:".contains($0)
        }).map(String.init)
        let sourceWords = hebrewSource.split(whereSeparator: { $0.isWhitespace })
        // A short Hebrew proper noun turning into a long stock apology
        // is an especially common Whisper fallback when audio is unclear.
        let apologetic = cleaned.contains("i'm sorry") || cleaned.contains("i am sorry")
        if sourceWords.count <= 3 && apologetic && englishWords.count >= 4 {
            return true
        }
        return false
    }

    public static func isUnreliableTranscript(_ text: String) -> Bool {
        isNonSpeechCaption(text) || isRepeatingHallucination(text)
    }

    public mutating func reset() {
        provisional = ""
        committedHistory.removeAll()
    }

    /// A detected pause commits immediately, even a single-word greeting.
    public mutating func receive(_ recognized: String, paused: Bool) -> Update {
        let text = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            if paused { return flush() }
            return snapshot(committed: [])
        }

        var emitted: [String] = []
        if provisional.isEmpty {
            provisional = deOverlap(text)
        } else if normalized(provisional) == normalized(text) {
            // The same hypothesis was returned twice.
        } else if extendsPrevious(text, previous: provisional) {
            provisional = text
        } else if extendsPrevious(provisional, previous: text) {
            // Preserve the longer existing hypothesis.
        } else {
            emitted += commitPending()
            provisional = deOverlap(text)
        }

        if paused { emitted += commitPending() }
        return snapshot(committed: emitted)
    }

    public mutating func flush() -> Update {
        let committed = commitPending()
        return snapshot(committed: committed)
    }

    private mutating func commitPending() -> [String] {
        let value = provisional.trimmingCharacters(in: .whitespacesAndNewlines)
        provisional = ""
        guard !value.isEmpty else { return [] }
        committedHistory.append(value)
        if committedHistory.count > historyLimit {
            committedHistory.removeFirst(committedHistory.count - historyLimit)
        }
        return [value]
    }

    private func snapshot(committed: [String]) -> Update {
        let history = committedHistory.joined(separator: " ")
        return Update(provisional: provisional, committed: committed,
                      recentContext: String(history.suffix(contextLimit)))
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
    }

    private func extendsPrevious(_ candidate: String, previous: String) -> Bool {
        let a = normalized(candidate)
        let b = normalized(previous)
        guard !b.isEmpty else { return false }
        return a.hasPrefix(b + " ") || a.hasPrefix(b + ",")
    }

    private func deOverlap(_ candidate: String) -> String {
        // Never suppress a one-word repetition that might be intentional.
        guard let last = committedHistory.last else { return candidate }
        let previousWords = last.split(separator: " ")
        let words = candidate.split(separator: " ")
        guard previousWords.count >= 2, words.count >= 3 else { return candidate }
        let longest = min(5, previousWords.count, words.count - 1)
        guard longest >= 2 else { return candidate }
        for size in stride(from: longest, through: 2, by: -1) {
            let lhs = previousWords.suffix(size).map { normalized(String($0)) }
            let rhs = words.prefix(size).map { normalized(String($0)) }
            if lhs == rhs {
                return words.dropFirst(size).joined(separator: " ")
            }
        }
        return candidate
    }
}
