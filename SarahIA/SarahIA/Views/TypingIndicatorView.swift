import SwiftUI

/// Indicateur de frappe animé (3 points qui rebondissent).
@available(iOS 13.0, *)
public struct TypingIndicatorView: View {
    @State private var animateFirstDot = false
    @State private var animateSecondDot = false
    @State private var animateThirdDot = false
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Miniature Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.35, green: 0.55, blue: 1.0),
                                Color(red: 0.70, green: 0.30, blue: 0.95)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                Text("👩🏻‍💼")
                    .font(.system(size: 14))
            }
            
            // Bulle avec les points animés
            HStack(spacing: 6) {
                DotView(animate: $animateFirstDot)
                DotView(animate: $animateSecondDot)
                DotView(animate: $animateThirdDot)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.16, green: 0.16, blue: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            animateFirstDot = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animateSecondDot = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animateThirdDot = true
            }
        }
    }
}

/// Un seul point animé de l'indicateur de frappe.
@available(iOS 13.0, *)
struct DotView: View {
    @Binding var animate: Bool
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.35, green: 0.65, blue: 1.0),
                        Color(red: 0.70, green: 0.40, blue: 0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 7, height: 7)
            .opacity(animate ? 1.0 : 0.35)
            .offset(y: animate ? -3 : 2)
    }
}

// MARK: - Preview

@available(iOS 13.0, *)
struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        TypingIndicatorView()
            .background(Color.black)
            .preferredColorScheme(.dark)
    }
}

