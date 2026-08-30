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
    
    public var roleDescription: String {
        switch self {
        case .sarah:  return "Voix système principale (Rose néon)"
        case .nathan: return "Expert Réseaux Sociaux & WhatsApp (Violet Néon)"
        case .esther: return "Voix de synthèse build & code / Voice Coding (Bleu ciel)"
        case .tom:    return "Voix conversationnelle dédiée (Vert émeraude)"
        case .yohan:  return "Voix masculine bilingue FR ⇄ HE (Siri Canadien)"
        case .ethel:  return "Voix féminine dédiée (Thème Bleu & Rouge)"
        }
    }
    
    public var specialtySubtitle: String {
        switch self {
        case .sarah:  return "Patronne & Agent Pilote"
        case .nathan: return "WhatsApp (Statuts & Vidéos) · Tous Réseaux · Veille IA"
        case .esther: return "Studio VAI Coding & Automatisation Apple Shortcuts"
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
    
    // Index de la voix Siri sélectionnée
    public var voiceIndex: String {
        switch self {
        case .sarah:  return "1"
        case .nathan: return "2"
        case .esther: return "3"
        case .tom:    return "4"
        case .yohan:  return "1"
        case .ethel:  return "2"
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
}

/// Alias AgentPersona pour compatibilité directe
public typealias AgentPersona = AgentType
