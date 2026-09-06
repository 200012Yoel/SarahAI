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
    static let sarahPresentVoiceCall         = Notification.Name("SarahPresentVoiceCallModal")
    static let sarahSendTextMessage          = Notification.Name("SarahSendTextMessage")
    static let sarahToggleVoiceRecording     = Notification.Name("SarahToggleVoiceRecording")
    static let sarahWebRTCStateChanged       = Notification.Name("SarahWebRTCStateChanged")
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
    case openVoiceCall(contact: VoiceCallContact?)
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
            
        case .openVoiceCall(let contact):
            HapticService.shared.buttonTap()
            NotificationCenter.default.post(name: .sarahPresentVoiceCall, object: contact)
            
        case .showNotification(let title, let message):
            NotificationService.shared.showInAppNotification(title: title, message: message)
        }
    }
}
