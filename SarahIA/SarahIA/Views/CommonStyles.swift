#if canImport(SwiftUI)
import SwiftUI

/// Style de bouton dynamique avec micro-rebond au toucher.
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

/// Surface "Liquid Glass" maison, compatible avec le déploiement iOS 16+.
///
/// Elle reprend les codes de l'interface Liquid Glass moderne : matériau flouté,
/// reflet supérieur, bord lumineux très fin, teinte contextuelle et profondeur.
/// Elle évite de dépendre d'une API SwiftUI toute récente qui casserait les
/// appareils encore supportés par Sarah IA.
@available(iOS 15.0, *)
public struct SarahLiquidGlassModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let tint: Color
    public let intensity: Double

    public init(
        cornerRadius: CGFloat = 22,
        tint: Color = .white,
        intensity: Double = 0.14
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        content
            .background(
                ZStack {
                    shape
                        .fill(.ultraThinMaterial)

                    shape
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    tint.opacity(intensity),
                                    Color.white.opacity(0.055),
                                    Color.black.opacity(0.06)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    shape
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.16),
                                    Color.clear,
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.screen)
                }
            )
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.24),
                                tint.opacity(0.18),
                                Color.white.opacity(0.055)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(0.26),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

@available(iOS 15.0, *)
extension View {
    public func sarahLiquidGlass(
        cornerRadius: CGFloat = 22,
        tint: Color = .white,
        intensity: Double = 0.14
    ) -> some View {
        modifier(
            SarahLiquidGlassModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                intensity: intensity
            )
        )
    }
}
#endif
