import Foundation

/// Modèle de Contact pour les Appels Vocaux WebRTC & Téléphoniques
public struct VoiceCallContact: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let role: String
    public let phoneNumber: String
    public let sipUri: String
    public let defaultLanguage: String // "fr", "en", "he"
    public let avatarEmoji: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        role: String = "Contact",
        phoneNumber: String = "",
        sipUri: String = "",
        defaultLanguage: String = "fr",
        avatarEmoji: String = "👤"
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.phoneNumber = phoneNumber
        self.sipUri = sipUri.isEmpty ? "sip:\(name.lowercased().replacingOccurrences(of: " ", with: "."))@sarah.webrtc.local" : sipUri
        self.defaultLanguage = defaultLanguage
        self.avatarEmoji = avatarEmoji
    }
}

/// État de la Session d'Appel WebRTC
public enum VoiceCallState: Equatable {
    case idle
    case dialing(contact: VoiceCallContact)
    case ringing
    case connected(contact: VoiceCallContact, duration: TimeInterval)
    case translating(sourceLanguage: String, targetLanguage: String)
    case reconnecting
    case ended(reason: String)
    
    public var isCallActive: Bool {
        switch self {
        case .connected, .translating, .reconnecting:
            return true
        default:
            return false
        }
    }
}

/// Paire Linguistique de Traduction Vocale en Direct
public struct CallLanguagePair: Equatable {
    public var localLanguage: String   // Langue parlée par l'utilisateur iPhone (ex: "fr")
    public var remoteLanguage: String  // Langue parlée par le correspondant (ex: "en" ou "he")
    public var isVoiceTranslationEnabled: Bool // Si activé, remplace l'audio brut par la voix synthétisée traduite
    
    public init(localLanguage: String = "fr", remoteLanguage: String = "en", isVoiceTranslationEnabled: Bool = true) {
        self.localLanguage = localLanguage
        self.remoteLanguage = remoteLanguage
        self.isVoiceTranslationEnabled = isVoiceTranslationEnabled
    }
    
    public var localFlag: String {
        switch localLanguage {
        case "fr": return "🇫🇷"
        case "en": return "🇬🇧"
        case "he": return "🇮🇱"
        default: return "🌐"
        }
    }
    
    public var remoteFlag: String {
        switch remoteLanguage {
        case "fr": return "🇫🇷"
        case "en": return "🇬🇧"
        case "he": return "🇮🇱"
        default: return "🌐"
        }
    }
}

/// Segment de Transcription et Traduction Temps Réel pour l'affichage en direct (Sous-titres bilingues)
public struct CallTranscriptItem: Identifiable, Equatable {
    public let id: String
    public let isLocalSpeaker: Bool
    public let originalText: String
    public let originalLanguage: String
    public let translatedText: String
    public let targetLanguage: String
    public let timestamp: Date
    public var isFinal: Bool
    
    public init(
        id: String = UUID().uuidString,
        isLocalSpeaker: Bool,
        originalText: String,
        originalLanguage: String,
        translatedText: String,
        targetLanguage: String,
        timestamp: Date = Date(),
        isFinal: Bool = false
    ) {
        self.id = id
        self.isLocalSpeaker = isLocalSpeaker
        self.originalText = originalText
        self.originalLanguage = originalLanguage
        self.translatedText = translatedText
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.isFinal = isFinal
    }
}
