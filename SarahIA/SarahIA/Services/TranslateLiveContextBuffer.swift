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
