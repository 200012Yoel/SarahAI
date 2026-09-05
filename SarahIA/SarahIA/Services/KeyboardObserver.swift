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
        // 1. Détection universelle de l'apparition du clavier
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> (CGFloat, Double, UInt)? in
                guard let userInfo = notification.userInfo,
                      let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return nil
                }
                let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
                return (endFrame.height, duration, curve)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height, duration, _ in
                withAnimation(.easeOut(duration: duration > 0 ? duration : 0.25)) {
                    self?.keyboardHeight = height
                    self?.isVisible = true
                }
            }
            .store(in: &cancellables)
        
        // 2. Détection universelle de la disparition du clavier
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

