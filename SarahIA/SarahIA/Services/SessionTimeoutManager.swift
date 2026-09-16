import Foundation
import UIKit

// ============================================================================
// SESSION TIMEOUT MANAGER — GESTION DU TIMEOUT D'INACTIVITÉ (> 1 HEURE)
// ============================================================================
// Sauvegarde le timestamp lors de la mise en arrière-plan et vérifie au réveil.
// Si le temps écoulé dépasse 3600 secondes (1h), déclenche un nouveau chat
// vierge tout en conservant l'historique complet dans la persistance locale.
// ============================================================================

public final class SessionTimeoutManager {
    
    public static let shared = SessionTimeoutManager()
    
    private let lastActiveKey = "sarah_last_active_timestamp"
    private let hasLaunchedBeforeKey = "sarah_has_launched_before"
    private let coldLaunchFreshChatKey = "sarah_cold_launch_requires_fresh_chat"
    private let timeoutInterval: TimeInterval = 3600 // 1 heure (3600 secondes)
    private var suppressInitialActivationCheck = false
    
    private init() {}

    /// Appelé une seule fois au démarrage du processus. iOS ne permet pas de distinguer de
    /// façon fiable une fermeture forcée d'une relance normale ; Sarah traite donc tout lancement
    /// à froid comme une nouvelle discussion, tout en conservant l'historique local.
    public func prepareForProcessLaunch(didResetUserStateForNewBuild: Bool) {
        let defaults = UserDefaults.standard
        let hasLaunchedBefore = defaults.bool(forKey: hasLaunchedBeforeKey)
        defaults.set(true, forKey: hasLaunchedBeforeKey)
        defaults.set(hasLaunchedBefore && !didResetUserStateForNewBuild, forKey: coldLaunchFreshChatKey)
        defaults.removeObject(forKey: lastActiveKey)
        suppressInitialActivationCheck = true
    }

    /// Consommé par le ViewModel une fois l'historique chargé.
    public func consumeColdLaunchFreshChatRequest() -> Bool {
        let defaults = UserDefaults.standard
        let required = defaults.bool(forKey: coldLaunchFreshChatKey)
        defaults.removeObject(forKey: coldLaunchFreshChatKey)
        return required
    }
    
    /// Enregistre la date exacte de mise en arrière-plan ou fermeture
    public func recordAppBackgroundTime() {
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: lastActiveKey)
        UserDefaults.standard.synchronize()
        print("🕒 [SessionTimeoutManager] Timestamp d'arrière-plan enregistré : \(now)")
    }
    
    /// Vérifie si la session a expiré lors du retour au premier plan
    public func checkAndResetSessionIfNeeded() {
        // didBecomeActive est aussi appelé lors du lancement à froid. La décision d'ouvrir
        // un nouveau chat est alors déjà prise par prepareForProcessLaunch().
        if suppressInitialActivationCheck {
            suppressInitialActivationCheck = false
            return
        }

        let lastActive = UserDefaults.standard.double(forKey: lastActiveKey)
        guard lastActive > 0 else {
            recordAppBackgroundTime()
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - lastActive
        
        print("🕒 [SessionTimeoutManager] Temps écoulé en arrière-plan : \(Int(elapsed)) secondes")
        
        if elapsed >= timeoutInterval {
            print("🔄 [SessionTimeoutManager] Timeout > 1h détecté (\(Int(elapsed))s) — Archivage et ouverture d'un nouveau chat vierge.")
            // Réinitialise le timestamp
            recordAppBackgroundTime()
            
            // Déclenche le nouveau chat sur le Main Thread via SarahActionCoordinator
            SarahActionCoordinator.shared.dispatch(.startNewChat)
        } else {
            // Met à jour la date d'activité récente
            recordAppBackgroundTime()
        }
    }
}
