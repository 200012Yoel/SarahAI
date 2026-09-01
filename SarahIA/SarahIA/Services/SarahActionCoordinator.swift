import Foundation
import UIKit

// ============================================================================
// SARAH ACTION COORDINATOR — GESTIONNAIRE D'ÉTAT & D'ACTIONS CENTRALISÉ
// ============================================================================
// Fait converger 100% des actions utilisateur vers un pipeline logique unique :
// - Changement d'agent actif
// - Nouvelle discussion & Purge d'historique
// - Appels vocaux WebRTC & Talkie-Walkie WhatsApp
// - Envoi et streaming de messages
// ============================================================================

public enum SarahAppAction {
    case toggleSidebar
    case openSettings
    case selectAgent(AgentType)
    case startNewChat
    case clearCurrentChat
    case sendTextMessage(String)
    case toggleVoiceRecording
    case openVoiceCall(contact: VoiceCallContact?)
    case openWhatsAppVoiceCall(contact: VoiceCallContact?)
    case showNotification(title: String, message: String)
}

public final class SarahActionCoordinator {
    
    public static let shared = SarahActionCoordinator()
    
    private init() {}
    
    // MARK: - Point d'Entrée Unique de Dispatch
    
    public func dispatch(_ action: SarahAppAction) {
        switch action {
        case .toggleSidebar:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahToggleSidebar"), object: nil)
            
        case .openSettings:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahOpenSettings"), object: nil)
            
        case .selectAgent(let agent):
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahAgentSelected"), object: agent)
            
        case .startNewChat:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahStartNewChat"), object: nil)
            
        case .clearCurrentChat:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahClearCurrentChat"), object: nil)
            
        case .sendTextMessage(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            NotificationCenter.default.post(name: NSNotification.Name("SarahSendTextMessage"), object: text)
            
        case .toggleVoiceRecording:
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahToggleVoiceRecording"), object: nil)
            
        case .openVoiceCall(let contact):
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahPresentVoiceCallModal"), object: contact)
            
        case .openWhatsAppVoiceCall(let contact):
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: NSNotification.Name("SarahPresentWhatsAppVoiceModal"), object: contact)
            
        case .showNotification(let title, let message):
            NotificationService.shared.showInAppNotification(title: title, message: message)
        }
    }
}
