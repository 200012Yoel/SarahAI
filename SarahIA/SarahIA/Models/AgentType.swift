#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Énumération des 5 agents autonomes du système Sarah AI.
/// Nathan est le nouvel agent expert IA, connecté à Internet, spécialisé dans
/// les derniers modèles d'intelligence artificielle, la génération vidéo et musicale.
public enum AgentType: String, CaseIterable, Identifiable, Codable {
    case sarah = "Sarah"
    case tom = "Tom"
    case raphael = "Raphaël"
    case yohan = "Yohan"
    case nathan = "Nathan"
    case ethel = "Ethel"
    
    public var id: String { rawValue }
    
    public var roleDescription: String {
        switch self {
        case .sarah:
            return "Patronne & Agent Pilote"
        case .tom:
            return "Conversation, Histoire & Géopolitique"
        case .raphael:
            return "Développeur & Code Engine (Shortcuts / Web)"
        case .yohan:
            return "Traducteur Universel (Français ⇄ Hébreu)"
        case .nathan:
            return "Expert Réseaux Sociaux (WhatsApp, Insta, TikTok) & IA"
        case .ethel:
            return "Intelligence Créative & Spécialisée (Ethel)"
        }
    }
    
    public var specialtySubtitle: String {
        switch self {
        case .sarah:
            return "Patronne & Agent Pilote"
        case .tom:
            return "Encyclopédie & Débats mondiaux (1948 - Aujourd'hui)"
        case .raphael:
            return "Génération Swift/Web & Ingestion Figma/Stitch"
        case .yohan:
            return "Dictionnaires locaux fusionnés (FR ⇄ HE)"
        case .nathan:
            return "WhatsApp (Statuts & Vidéos) · Tous Réseaux · Veille IA"
        case .ethel:
            return "Agent Féminin Polyvalent · Design Bleu & Rouge"
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
        case .raphael:
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
        case .raphael:
            return [Color.white, Color(red: 0.35, green: 0.80, blue: 1.0), Color(red: 0.05, green: 0.60, blue: 0.98)]
        case .yohan:
            return [Color.white, Color(red: 0.70, green: 0.88, blue: 1.0), Color(red: 0.0, green: 0.40, blue: 0.85)]
        case .nathan:
            return [Color.white, Color(red: 0.90, green: 0.65, blue: 1.0), Color(red: 0.65, green: 0.15, blue: 0.95)]
        case .ethel:
            // Centre Bleu électrique entouré de Rouge flamboyant
            return [Color(red: 0.15, green: 0.75, blue: 1.0), Color(red: 0.60, green: 0.10, blue: 0.80), Color(red: 0.95, green: 0.10, blue: 0.30)]
        }
    }
    #endif
    
    public var iconName: String {
        switch self {
        case .sarah:   return "crown.fill"
        case .tom:     return "globe.europe.africa.fill"
        case .raphael: return "chevron.left.forwardslash.chevron.right"
        case .yohan:   return "character.book.closed.fill"
        case .nathan:  return "bubble.left.and.bubble.right.fill"
        case .ethel:   return "wand.and.stars"
        }
    }
}
