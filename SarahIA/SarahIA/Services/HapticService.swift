import UIKit
import AudioToolbox

/// Service gérant les retours haptiques immersifs (Taptic Engine) pour l'application Sarah AI.
/// Rétrocompatible et 100% sécurisé sur tous les appareils (de l'iPhone 5s à l'iPhone 17+).
public final class HapticService {
    
    public static let shared = HapticService()
    
    // Détection de support matériel haptique pour éviter tout avertissement runtime sur iPhone 5s/6
    private let supportsHaptics: Bool
    
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var heavyGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    
    private init() {
        // iPhone 7 et supérieur disposent d'un Taptic Engine (Feedback Support Level >= 2)
        let isSimulator: Bool
        #if targetEnvironment(simulator)
        isSimulator = true
        #else
        isSimulator = false
        #endif
        
        if isSimulator {
            self.supportsHaptics = false
        } else {
            // Sur les appareils physiques, on initialise de façon protégée
            self.supportsHaptics = true
            self.lightGenerator = UIImpactFeedbackGenerator(style: .light)
            self.mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
            self.heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            self.selectionGenerator = UISelectionFeedbackGenerator()
            self.notificationGenerator = UINotificationFeedbackGenerator()
        }
        
        prepareGenerators()
    }
    
    public func prepareGenerators() {
        guard supportsHaptics else { return }
        lightGenerator?.prepare()
        mediumGenerator?.prepare()
        selectionGenerator?.prepare()
        notificationGenerator?.prepare()
    }
    
    /// Retour tactile lors du démarrage de la voix
    public func speechStarted() {
        guard supportsHaptics else { return }
        lightGenerator?.impactOccurred()
    }
    
    /// Retour tactile lors de la fin de parole
    public func speechFinished() {
        guard supportsHaptics else { return }
        lightGenerator?.impactOccurred()
    }
    
    /// Retour tactile franc lors d'une interruption (Barge-In)
    public func bargeIn() {
        guard supportsHaptics else { return }
        mediumGenerator?.impactOccurred()
    }
    
    /// Retour tactile lors de la mémorisation réussie d'un nouveau mot
    public func memoryLearned() {
        guard supportsHaptics else { return }
        notificationGenerator?.notificationOccurred(.success)
    }
    
    /// Retour tactile lors de la suppression d'un souvenir
    public func memoryDeleted() {
        guard supportsHaptics else { return }
        notificationGenerator?.notificationOccurred(.warning)
    }
    
    /// Retour tactile lors d'une action interactive
    public func modeToggled() {
        guard supportsHaptics else { return }
        selectionGenerator?.selectionChanged()
    }
    
    /// Retour tactile sur tap bouton (avec protection silencieuse)
    public func buttonTap() {
        guard supportsHaptics else { return }
        lightGenerator?.impactOccurred()
    }
    
    /// Retour tactile de succès de notification / synchronisation
    public func notificationSuccess() {
        guard supportsHaptics else { return }
        notificationGenerator?.notificationOccurred(.success)
    }
    
    public func triggerNotificationSuccess() {
        notificationSuccess()
    }
    
    /// Retour tactile d'erreur de notification
    public func notificationError() {
        guard supportsHaptics else { return }
        notificationGenerator?.notificationOccurred(.error)
    }
    
    public func triggerNotificationError() {
        notificationError()
    }
}
