import SwiftUI
import Combine
import UIKit

/// Observateur de clavier ultra-réactif garantissant une synchronisation pixel-perfect entre le clavier iOS et la barre de saisie (MessageBar).
@available(iOS 13.0, *)
public final class KeyboardObserver: ObservableObject {
    public static let shared = KeyboardObserver()
    
    @Published public var keyboardHeight: CGFloat = 0
    @Published public var isVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // 1. Détection de la montée du clavier
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> (CGFloat, Double)? in
                guard let userInfo = notification.userInfo,
                      let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return nil
                }
                return (endFrame.height, duration)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height, duration in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    self?.keyboardHeight = height
                    self?.isVisible = true
                }
            }
            .store(in: &cancellables)
        
        // 2. Détection de la descente du clavier
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { notification -> Double? in
                notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    self?.keyboardHeight = 0
                    self?.isVisible = false
                }
            }
            .store(in: &cancellables)
        
        // 3. Détection des changements de taille dynamiques (ex: prédictions, bascule langue/dictée)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification -> (CGFloat, Double)? in
                guard let userInfo = notification.userInfo,
                      let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return nil
                }
                let screenHeight = UIScreen.main.bounds.height
                let actualHeight = max(0, screenHeight - endFrame.minY)
                return (actualHeight, duration)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height, duration in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    self?.keyboardHeight = height
                    self?.isVisible = height > 20
                }
            }
            .store(in: &cancellables)
    }
    
    /// Masque le clavier de manière fluide
    public func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
