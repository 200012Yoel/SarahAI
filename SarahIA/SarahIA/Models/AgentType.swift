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
        case .sarah:  return "Voix neuronale locale F1"
        case .nathan: return "Expert Réseaux Sociaux & IA (Violet Néon)"
        case .esther: return "Développeur : sites, apps iOS & code (Bleu ciel)"
        case .tom:    return "Voix neuronale locale M2"
        case .yohan:  return "Voix locale M3 (synthèse hébraïque non incluse)"
        case .ethel:  return "Voix neuronale locale F2"
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
    
    /// Per-agent on-device voice, independent of Apple's speech voices.
    public var neuralVoiceLabel: String {
        switch self {
        case .sarah: return "F1"
        case .ethel: return "F2"
        case .esther: return "M1"
        case .tom: return "M2"
        case .yohan: return "M3"
        case .nathan: return "M4"
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
