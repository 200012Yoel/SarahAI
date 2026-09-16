#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Énumération des 6 agents de l'écosystème Sarah AI (Sarah, Nathan, Esther, Tom, Yohan, Ethel)
public enum AgentType: String, CaseIterable, Identifiable, Codable {
    case sarah   = "Sarah"
    case nathan  = "Nathan"
    case esther  = "Esther"
    case tom     = "Tom"
    case yohan   = "Yohan"
    case ethel   = "Ethel"
    
    // Rétrocompatibilité / Alias
    public static let raphael = AgentType.esther
    
    public var id: String { rawValue }

    /// Nom présenté dans l'interface. L'identifiant historique `Esther` est conservé pour
    /// ne pas casser les conversations déjà sauvegardées, mais l'agent développeur s'appelle
    /// bien Raphaël côté utilisateur.
    public var displayName: String {
        self == .esther ? "Raphaël" : rawValue
    }

    public var capabilitiesSummary: String {
        switch self {
        case .sarah:
            return "Assistant principal pour organiser, expliquer et vous accompagner."
        case .nathan:
            return "Réseaux sociaux, idées de contenus et veille IA."
        case .esther:
            return "Développeur : sites web, apps iOS, SwiftUI, code et prototypes."
        case .tom:
            return "Recherche, actualités, voyages et explications documentées."
        case .yohan:
            return "Assistant bilingue français–hébreu et aide à la traduction."
        case .ethel:
            return "Création, design et idées visuelles."
        }
    }
    
    public var roleDescription: String {
        switch self {
        case .sarah:  return "Voix système principale (Rose néon)"
        case .nathan: return "Expert Réseaux Sociaux & IA (Violet Néon)"
        case .esther: return "Développeur : sites, apps iOS & code (Bleu ciel)"
        case .tom:    return "Voix conversationnelle dédiée (Vert émeraude)"
        case .yohan:  return "Voix masculine bilingue FR ⇄ HE (Siri Canadien)"
        case .ethel:  return "Voix féminine dédiée (Thème Bleu & Rouge)"
        }
    }
    
    public var specialtySubtitle: String {
        switch self {
        case .sarah:  return "Patronne & Agent Pilote"
        case .nathan: return "Réseaux Sociaux · Vidéos · Veille IA"
        case .esther: return "Développeur · Web · iOS · SwiftUI · Code"
        case .tom:    return "Encyclopédie & Débats mondiaux (1948 - Aujourd'hui)"
        case .yohan:  return "Dictionnaires locaux fusionnés (FR ⇄ HE)"
        case .ethel:  return "Intelligence Créative Polyvalente · Design Bleu & Rouge"
        }
    }
    
    // Code langue ciblé (France vs Canada)
    public var localeCode: String {
        switch self {
        case .sarah, .nathan, .esther, .tom:
            return "fr-FR"
        case .yohan, .ethel:
            return "fr-CA"
        }
    }
    
    // Numéro de voix affiché dans les réglages Siri d'iOS.
    // Apple ne publie pas d'identifiant stable reliant ce numéro à une voix de
    // synthèse : il sert donc uniquement de préférence lisible par l'utilisateur.
    public var siriVoiceNumber: String {
        switch self {
        case .sarah:  return "1" // France Voix 1
        case .nathan: return "2" // France Voix 2
        case .esther: return "3" // France Voix 3
        case .tom:    return "4" // France Voix 4
        case .yohan:  return "1" // Canada Voix 1
        case .ethel:  return "2" // Canada Voix 2
        }
    }
    
    // Index de la voix Siri sélectionnée (1-based String)
    public var voiceIndex: String {
        return siriVoiceNumber
    }

    /// Libellé de la préférence de voix choisie dans les réglages Apple.
    /// Ne jamais déduire cette préférence de l'ordre de `speechVoices()`, car cet
    /// ordre peut changer selon l'iPhone, la version d'iOS et les voix téléchargées.
    public var systemVoicePreferenceLabel: String {
        switch self {
        case .sarah:  return "France — Voix 1"
        case .nathan: return "France — Voix 2"
        case .esther: return "France — Voix 3"
        case .tom:    return "France — Voix 4"
        case .yohan:  return "Canada — Voix 1"
        case .ethel:  return "Canada — Voix 2"
        }
    }
    
    // Index dans la liste des voix du système pour cette région (0-based Int)
    public var voiceIndexOrder: Int {
        switch self {
        case .sarah:  return 0 // Voix 1 France
        case .nathan: return 1 // Voix 2 France
        case .esther: return 2 // Voix 3 France
        case .tom:    return 3 // Voix 4 France
        case .yohan:  return 0 // Voix 1 Canada
        case .ethel:  return 1 // Voix 2 Canada
        }
    }
    
    // Identifiant de repli pour les voix de synthèse Apple classiques.
    public var speechIdentifier: String {
        switch self {
        case .sarah:  return "com.apple.voice.compact.fr-FR.Amelie"
        case .nathan: return "com.apple.voice.compact.fr-FR.Thomas"
        case .esther: return "com.apple.voice.compact.fr-FR.Audrey"
        case .tom:    return "com.apple.voice.compact.fr-FR.Remi"
        case .yohan:  return "com.apple.voice.compact.fr-CA.Jean"
        case .ethel:  return "com.apple.voice.compact.fr-CA.Chantal"
        }
    }

    /// Identifiants préférés des voix Apple quand elles sont disponibles sur
    /// l'iPhone. Les identifiants sont testés au moment de l'exécution : aucun
    /// n'est utilisé si la voix n'a pas été téléchargée sur l'appareil.
    public var preferredSpeechVoiceIdentifiers: [String] {
        switch self {
        case .sarah:
            return [
                "com.apple.ttsbundle.siri_female_fr-FR_compact",
                speechIdentifier
            ]
        case .nathan:
            return [
                "com.apple.ttsbundle.siri_male_fr-FR_compact",
                speechIdentifier
            ]
        case .tom:
            // Tom est fixé à France — Voix 4. On teste d'abord l'identifiant
            // TTS Apple historique de Rémi, puis le repli compatible du projet.
            return [
                "com.apple.ttsbundle.Remi-compact",
                speechIdentifier
            ]
        case .esther:
            // Esther (affichée comme Raphaël) est fixée à France — Voix 3.
            return [
                "com.apple.ttsbundle.Audrey-compact",
                speechIdentifier
            ]
        case .ethel:
            // Ethel est fixée à Canada — Voix 2.
            return [
                "com.apple.ttsbundle.Chantal-compact",
                speechIdentifier
            ]
        case .yohan:
            // Yoann est fixé à Canada — Voix 1. L'identifiant interne
            // historique reste `yohan` afin de conserver les données déjà
            // enregistrées par l'application.
            return [
                "com.apple.ttsbundle.Jean-compact",
                speechIdentifier
            ]
        default:
            return [speechIdentifier]
        }
    }
    
    #if canImport(SwiftUI)
    @available(iOS 13.0, *)
    public var themeColor: Color {
        switch self {
        case .sarah:
            return Color(red: 1.0, green: 0.18, blue: 0.65)   // Rose Néon / Magenta
        case .tom:
            return Color(red: 0.05, green: 0.85, blue: 0.45)  // Vert Émeraude
        case .esther:
            return Color(red: 0.15, green: 0.72, blue: 1.0)   // Bleu Ciel / Azur
        case .yohan:
            return Color(red: 0.0, green: 0.45, blue: 0.90)   // Bleu Mer Profond
        case .nathan:
            return Color(red: 0.85, green: 0.55, blue: 1.0)   // Violet Électrique IA
        case .ethel:
            return Color(red: 0.95, green: 0.15, blue: 0.35)   // Rouge Écarlate / Bleu Lumineux
        }
    }
    
    @available(iOS 13.0, *)
    public var gradientColors: [Color] {
        switch self {
        case .sarah:
            return [Color.white, Color(red: 1.0, green: 0.25, blue: 0.70), Color(red: 0.95, green: 0.05, blue: 0.55)]
        case .tom:
            return [Color.white, Color(red: 0.20, green: 0.90, blue: 0.55), Color(red: 0.02, green: 0.75, blue: 0.38)]
        case .esther:
            return [Color.white, Color(red: 0.35, green: 0.80, blue: 1.0), Color(red: 0.05, green: 0.60, blue: 0.98)]
        case .yohan:
            return [Color.white, Color(red: 0.70, green: 0.88, blue: 1.0), Color(red: 0.0, green: 0.40, blue: 0.85)]
        case .nathan:
            return [Color.white, Color(red: 0.90, green: 0.65, blue: 1.0), Color(red: 0.65, green: 0.15, blue: 0.95)]
        case .ethel:
            return [Color(red: 0.15, green: 0.75, blue: 1.0), Color(red: 0.60, green: 0.10, blue: 0.80), Color(red: 0.95, green: 0.10, blue: 0.30)]
        }
    }
    #endif
    
    public var iconName: String {
        switch self {
        case .sarah:   return "crown.fill"
        case .tom:     return "globe.europe.africa.fill"
        case .esther:  return "chevron.left.forwardslash.chevron.right"
        case .yohan:   return "character.book.closed.fill"
        case .nathan:  return "bubble.left.and.bubble.right.fill"
        case .ethel:   return "wand.and.stars"
        }
    }
    
    #if canImport(UIKit)
    public var uiColor: UIColor {
        switch self {
        case .sarah:   return UIColor(red: 1.0, green: 0.18, blue: 0.65, alpha: 1.0)
        case .tom:     return UIColor(red: 0.05, green: 0.85, blue: 0.45, alpha: 1.0)
        case .esther:  return UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        case .yohan:   return UIColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0)
        case .nathan:  return UIColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1.0)
        case .ethel:   return UIColor(red: 0.95, green: 0.15, blue: 0.35, alpha: 1.0)
        }
    }
    #endif
}

/// Alias AgentPersona pour compatibilité directe
public typealias AgentPersona = AgentType
