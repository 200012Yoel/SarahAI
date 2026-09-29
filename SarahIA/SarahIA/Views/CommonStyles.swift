#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

/// Surface vitrée de Sarah orientée stabilité.
///
/// Tant que l'interaction iOS 26/27 n'est pas validée par le test simulateur,
/// on évite complètement `glassEffect`. Le rendu reste proche grâce aux
/// Materials SwiftUI, mais aucune couche native supplémentaire ne participe au
/// hit testing des Button, Menu ou TextField.
@available(iOS 15.0, *)
public struct SarahLiquidGlassModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let tint: Color
    public let intensity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = 22, tint: Color = .white, intensity: Double = 0.14) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.intensity = intensity
    }

    private var isCompactPhone: Bool {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width <= 375
        #else
        return false
        #endif
    }

    private var prefersReducedEffects: Bool {
        reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled || isCompactPhone
    }

    private var effectiveIntensity: Double {
        let clamped = max(0.02, min(0.22, intensity))
        return prefersReducedEffects ? clamped * 0.72 : clamped
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if reduceTransparency {
            opaqueAccessibleGlass(content: content)
        } else {
            stableMaterialGlass(content: content)
        }
    }

    private func opaqueAccessibleGlass(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(
                shape
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.97))
                    .overlay(
                        shape
                            .fill(tint.opacity(min(0.08, effectiveIntensity * 0.45)))
                            .allowsHitTesting(false)
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                    .allowsHitTesting(false)
            )
    }

    private func stableMaterialGlass(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let highlightOpacity = prefersReducedEffects ? 0.11 : 0.18
        let shadowRadius: CGFloat = prefersReducedEffects ? 7 : 12
        let shadowY: CGFloat = prefersReducedEffects ? 3 : 6

        return content
            .background(
                ZStack {
                    shape.fill(prefersReducedEffects ? .thinMaterial : .ultraThinMaterial)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(max(0.02, min(0.10, effectiveIntensity * 0.70))),
                                Color.white.opacity(prefersReducedEffects ? 0.025 : 0.045),
                                Color.black.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    if !prefersReducedEffects {
                        shape.fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(highlightOpacity), location: 0),
                                    .init(color: Color.white.opacity(0.055), location: 0.30),
                                    .init(color: Color.clear, location: 0.58)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.screen)
                    }
                }
                .allowsHitTesting(false)
            )
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(prefersReducedEffects ? 0.16 : 0.24),
                                tint.opacity(0.10),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
                    .allowsHitTesting(false)
            )
            .shadow(
                color: Color.black.opacity(prefersReducedEffects ? 0.11 : 0.18),
                radius: shadowRadius,
                x: 0,
                y: shadowY
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
