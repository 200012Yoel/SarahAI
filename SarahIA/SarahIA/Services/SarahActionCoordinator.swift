import Foundation
import UIKit

// ============================================================================
// EXTENSIONS NOTIFICATION.NAME TYPÉES (Zéro Chaînes Magiques)
// ============================================================================

public extension Notification.Name {
    static let sarahToggleSidebar            = Notification.Name("SarahToggleSidebar")
    static let sarahOpenSettings             = Notification.Name("SarahOpenSettings")
    static let sarahClearCurrentChat         = Notification.Name("SarahClearCurrentChat")
    static let sarahStartNewChat             = Notification.Name("SarahStartNewChat")
    static let sarahAgentSelected            = Notification.Name("SarahAgentSelected")
    static let sarahPresentLiveTranslation   = Notification.Name("SarahPresentLiveTranslation")
    static let sarahSendTextMessage          = Notification.Name("SarahSendTextMessage")
    static let sarahToggleVoiceRecording     = Notification.Name("SarahToggleVoiceRecording")
}

/// Reconnaît les commandes de traduction avant tout routage vers un modèle ou un dictionnaire.
/// Les caractères de ponctuation sont traités comme des séparateurs : "Translate. Live."
/// et "Translate Live" déclenchent exactement la même action.
public enum LiveTranslationCommand {
    public static func normalize(_ text: String) -> String {
        let folded = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        let words = folded.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }
        return words.joined().split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    public static func isActivationRequest(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return false }

        // Ces deux variantes ont déjà été produites par la dictée multilingue.
        // Elles ne doivent pas partir vers le dictionnaire français-hébreu.
        if normalized == "トランスレートライブ" || normalized == "トンスライトルライト" {
            return true
        }

        let commands = [
            "translate live", "live translate", "traduction en direct",
            "traduction directe", "traduis en direct", "traduit en direct",
            "traduire en direct", "traduction en temps reel",
            "traduction live", "traduis la tele", "traduis l hebreu"
        ]
        return commands.contains {
            normalized == $0 || normalized.hasPrefix($0 + " ") ||
            normalized.hasSuffix(" " + $0) || normalized.contains(" " + $0 + " ")
        }
    }
}

// ============================================================================
// SARAH ACTION COORDINATOR — GESTIONNAIRE D'ÉTAT & D'ACTIONS THREAD-SAFE
// ============================================================================

public enum SarahAppAction {
    case toggleSidebar
    case openSettings
    case selectAgent(AgentType)
    case startNewChat
    case clearCurrentChat
    case sendTextMessage(String)
    case toggleVoiceRecording
    case openLiveTranslation
    case showNotification(title: String, message: String)
}

public final class SarahActionCoordinator {
    
    public static let shared = SarahActionCoordinator()
    
    private init() {}
    
    // MARK: - Point d'Entrée Unique de Dispatch (100% Thread-Safe sur Main Thread)
    
    public func dispatch(_ action: SarahAppAction) {
        if Thread.isMainThread {
            self.handleAction(action)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleAction(action)
            }
        }
    }
    
    private func handleAction(_ action: SarahAppAction) {
        switch action {
        case .toggleSidebar:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahToggleSidebar, object: nil)
            
        case .openSettings:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahOpenSettings, object: nil)
            
        case .selectAgent(let agent):
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahAgentSelected, object: agent)
            
        case .startNewChat:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahStartNewChat, object: nil)
            
        case .clearCurrentChat:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahClearCurrentChat, object: nil)
            
        case .sendTextMessage(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            NotificationCenter.default.post(name: .sarahSendTextMessage, object: text)
            
        case .toggleVoiceRecording:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahToggleVoiceRecording, object: nil)
            
        case .openLiveTranslation:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahPresentLiveTranslation, object: nil)
            
        case .showNotification(let title, let message):
            NotificationService.shared.showInAppNotification(title: title, message: message)
        }
    }
}
