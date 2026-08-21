import UIKit

/// Service gérant les retours haptiques immersifs (Taptic Engine) pour l'application Sarah AI.
public final class HapticService {
    
    public static let shared = HapticService()
    
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        prepareGenerators()
    }
    
    public func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    /// Retour tactile lors du démarrage de la voix
    public func speechStarted() {
        lightGenerator.impactOccurred()
    }
    
    /// Retour tactile lors de la fin de parole
    public func speechFinished() {
        lightGenerator.impactOccurred(intensity: 0.6)
    }
    
    /// Retour tactile franc lors d'une interruption (Barge-In)
    public func bargeIn() {
        mediumGenerator.impactOccurred(intensity: 0.9)
    }
    
    /// Retour tactile lors de la mémorisation réussie d'un nouveau mot
    public func memoryLearned() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    /// Retour tactile lors de la suppression d'un souvenir
    public func memoryDeleted() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    /// Retour tactile lors d'une action interactive
    public func modeToggled() {
        selectionGenerator.selectionChanged()
    }
    
    /// Retour tactile sur tap bouton
    public func buttonTap() {
        lightGenerator.impactOccurred(intensity: 0.5)
    }
}
