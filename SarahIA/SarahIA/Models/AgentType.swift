#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Énumération des 4 agents autonomes 100% hors-ligne du système Sarah AI.
public enum AgentType: String, CaseIterable, Identifiable, Codable {
    case sarah = "Sarah"
    case tom = "Tom"
    case raphael = "Raphaël"
    case yohan = "Yohan"
    
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
        }
    }
    
    public var specialtySubtitle: String {
        switch self {
        case .sarah:
            return "Centre de commandement"
        case .tom:
            return "Encyclopédie & Débats mondiaux (1948 - Aujourd'hui)"
        case .raphael:
            return "Génération Swift/Web & Ingestion Figma/Stitch"
        case .yohan:
            return "Dictionnaires locaux fusionnés (FR ⇄ HE)"
        }
    }
    
    #if canImport(SwiftUI)
    @available(iOS 13.0, *)
    public var themeColor: Color {
        switch self {
        case .sarah:
            return Color(red: 1.0, green: 0.18, blue: 0.65) // Rose Néon / Magenta
        case .tom:
            return Color(red: 0.05, green: 0.85, blue: 0.45) // Vert Émeraude
        case .raphael:
            return Color(red: 0.15, green: 0.72, blue: 1.0) // Bleu Ciel / Azur
        case .yohan:
            return Color(red: 0.0, green: 0.45, blue: 0.90) // Bleu Mer Profond
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
        }
    }
    #endif
    
    public var iconName: String {
        switch self {
        case .sarah: return "crown.fill"
        case .tom: return "globe.europe.africa.fill"
        case .raphael: return "chevron.left.forwardslash.chevron.right"
        case .yohan: return "character.book.closed.fill"
        }
    }
}
