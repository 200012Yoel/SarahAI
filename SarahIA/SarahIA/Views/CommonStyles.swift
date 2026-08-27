#if canImport(SwiftUI)
import SwiftUI

/// Style de bouton dynamique avec micro-rebond au toucher
@available(iOS 13.0, *)
public struct ScaleBounceButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

@available(iOS 13.0, *)
extension Color {
    public static let sarahCyan = Color(red: 0.0, green: 0.78, blue: 1.0)
    public static let sarahIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)
}
#endif
