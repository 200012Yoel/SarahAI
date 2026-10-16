import Foundation

/// Paire de langues de la traduction en direct.
public struct LiveLanguagePair: Equatable {
    /// Langue parlée devant l'iPhone (ex : "he").
    public var sourceLanguage: String
    /// Langue de la traduction affichée et prononcée (ex : "fr").
    public var targetLanguage: String
    /// Si activé, Sarah prononce la traduction à voix haute.
    public var isVoiceEnabled: Bool

    public init(sourceLanguage: String = "he", targetLanguage: String = "fr", isVoiceEnabled: Bool = true) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.isVoiceEnabled = isVoiceEnabled
    }

    public var sourceFlag: String { Self.flag(for: sourceLanguage) }
    public var targetFlag: String { Self.flag(for: targetLanguage) }

    public var sourceName: String { Self.name(for: sourceLanguage) }
    public var targetName: String { Self.name(for: targetLanguage) }

    /// Inverse les deux langues (hébreu → français devient français → hébreu).
    public var swapped: LiveLanguagePair {
        LiveLanguagePair(sourceLanguage: targetLanguage, targetLanguage: sourceLanguage, isVoiceEnabled: isVoiceEnabled)
    }

    public static func flag(for code: String) -> String {
        switch code {
        case "fr": return "🇫🇷"
        case "en": return "🇬🇧"
        case "he": return "🇮🇱"
        default: return "🌐"
        }
    }

    public static func name(for code: String) -> String {
        switch code {
        case "fr": return "Français"
        case "en": return "Anglais"
        case "he": return "Hébreu"
        default: return code.uppercased()
        }
    }

    /// Les langues de droite à gauche s'affichent alignées à droite.
    public static func isRightToLeft(_ code: String) -> Bool {
        code == "he" || code == "ar"
    }
}

/// Une phrase de la traduction en direct : texte entendu + traduction.
public struct LiveTranscriptItem: Identifiable, Equatable {
    public let id: String
    /// `false` pour un message d'information de Sarah (ex : mode hors ligne).
    public let isSpeech: Bool
    public let originalText: String
    public let originalLanguage: String
    public let translatedText: String
    public let targetLanguage: String
    public let timestamp: Date
    public var isFinal: Bool
    /// Mention du moteur à afficher sous la traduction (ex. « Traduit par Google », obligatoire pour ML Kit).
    public let attribution: String?

    public init(
        id: String = UUID().uuidString,
        isSpeech: Bool = true,
        originalText: String,
        originalLanguage: String,
        translatedText: String,
        targetLanguage: String,
        timestamp: Date = Date(),
        isFinal: Bool = false,
        attribution: String? = nil
    ) {
        self.id = id
        self.isSpeech = isSpeech
        self.originalText = originalText
        self.originalLanguage = originalLanguage
        self.translatedText = translatedText
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.isFinal = isFinal
        self.attribution = attribution
    }
}
