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
        // 1. Détection universelle du changement de taille / apparition du clavier
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification -> (CGFloat, Double, UInt)? in
                guard let userInfo = notification.userInfo,
                      let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return nil
                }
                let screenHeight = UIScreen.main.bounds.height
                let height = max(0, screenHeight - endFrame.minY)
                let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
                return (height, duration, curve)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height, duration, _ in
                let animDuration = duration > 0 ? duration : 0.25
                withAnimation(.easeOut(duration: animDuration)) {
                    self?.keyboardHeight = height
                    self?.isVisible = height > 20
                }
            }
            .store(in: &cancellables)
        
        // 2. Détection explicite de disparition
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { notification -> Double in
                (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                withAnimation(.easeOut(duration: duration > 0 ? duration : 0.25)) {
                    self?.keyboardHeight = 0
                    self?.isVisible = false
                }
            }
            .store(in: &cancellables)
    }
    
    /// Masque le clavier de manière fluide
    public func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

