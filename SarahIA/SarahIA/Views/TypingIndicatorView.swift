import SwiftUI

/// Indicateur de frappe animé (3 points qui rebondissent).
/// Affiché dans le chat quand Sarah IA est en train de "réfléchir".
struct TypingIndicatorView: View {
    @State private var animateFirstDot = false
    @State private var animateSecondDot = false
    @State private var animateThirdDot = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar Sarah (identique à ChatBubbleView)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.55, green: 0.35, blue: 0.85),
                                Color(red: 0.35, green: 0.25, blue: 0.75)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Text("🤖")
                    .font(.system(size: 16))
            }
            
            // Bulle avec les points animés
            HStack(spacing: 6) {
                DotView(animate: $animateFirstDot)
                DotView(animate: $animateSecondDot)
                DotView(animate: $animateThirdDot)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
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
struct DotView: View {
    @Binding var animate: Bool
    
    var body: some View {
        Circle()
            .fill(
                Color(red: 0.55, green: 0.35, blue: 0.85).opacity(animate ? 1.0 : 0.3)
            )
            .frame(width: 8, height: 8)
            .offset(y: animate ? -4 : 2)
    }
}

// MARK: - Preview

struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        TypingIndicatorView()
    }
}
