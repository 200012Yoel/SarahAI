#if canImport(SwiftUI)
import SwiftUI

/// Style de bouton dynamique avec micro-rebond au toucher.
@available(iOS 13.0, *)
public struct ScaleBounceButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

@available(iOS 13.0, *)
extension Color {
    public static let sarahCyan = Color(red: 0.0, green: 0.78, blue: 1.0)
    public static let sarahIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)
}

/// Surface Liquid Glass de Sarah.
///
/// iOS 26+ utilise le vrai `glassEffect` du système avec une teinte volontairement
/// légère. Les versions antérieures utilisent un matériau flouté, un reflet interne
/// et une bordure lumineuse afin de conserver la même hiérarchie visuelle sans
/// transformer les contrôles en aplats colorés.
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

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glassTint = max(0.035, min(0.20, intensity * 1.25))

            content
                .glassEffect(
                    .regular
                        .tint(tint.opacity(glassTint))
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.07),
                                    tint.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.65
                        )
                        .allowsHitTesting(false)
                )
                .shadow(
                    color: Color.black.opacity(0.16),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        } else {
            legacyGlass(content: content)
        }
    }

    private func legacyGlass(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        return content
            .background(
                ZStack {
                    shape
                        .fill(.ultraThinMaterial)

                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(max(0.025, min(0.12, intensity * 0.75))),
                                    Color.white.opacity(0.045),
                                    Color.black.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    shape
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.18), location: 0),
                                    .init(color: Color.white.opacity(0.055), location: 0.30),
                                    .init(color: Color.clear, location: 0.58)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
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
                            colors: [
                                Color.white.opacity(0.24),
                                tint.opacity(0.11),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
            .shadow(
                color: Color.black.opacity(0.18),
                radius: 12,
                x: 0,
                y: 6
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
