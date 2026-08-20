//
//  Avatar3DView.swift
//  SarahIA
//
//  Composant allégé - L'interface principale est désormais le Chat 100% Natif SwiftUI.
//

import SwiftUI

/// Vue allégée conservée pour la compatibilité du projet. L'application principale utilise désormais MessageList et MessageBar.
public struct Avatar3DView: View {
    public var isSpeaking: Bool = false
    
    public init(isSpeaking: Bool = false) {
        self.isSpeaking = isSpeaking
    }
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
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
                        .frame(width: 80, height: 80)
                    
                    Text("👩🏻‍💼")
                        .font(.system(size: 40))
                }
                .scaleEffect(isSpeaking ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: isSpeaking)
                
                Text("Sarah IA")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}
