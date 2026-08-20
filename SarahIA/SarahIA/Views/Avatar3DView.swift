//
//  Avatar3DView.swift
//  SarahIA
//
//  Rendu 3D 100% Natif SceneKit / Metal pour Sarah IA
//  ZÉRO WebView, ZÉRO HTML/JS - Performances et réactivité maximales
//

import SwiftUI
import SceneKit

/// Vue 3D native représentant l'avatar de Sarah avec rendu Metal SceneKit temps réel
public struct Avatar3DView: View {
    @ObservedObject var avatarEngine = AvatarEngine.shared
    @ObservedObject var speechManager = SpeechManager.shared
    public var isSpeaking: Bool = false
    
    @State private var dragOffset: CGSize = .zero
    
    public init(isSpeaking: Bool = false) {
        self.isSpeaking = isSpeaking
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond sombre texturé pour faire ressortir l'éclairage 3D
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Rendu SceneKit Natif Haute Performance (Metal)
                NativeSceneKitContainerView(scene: avatarEngine.scene)
                    .edgesIgnoringSafeArea(.all)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                avatarEngine.setLookAtOffset(
                                    deltaX: Float(value.translation.width),
                                    deltaY: Float(value.translation.height)
                                )
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    dragOffset = .zero
                                }
                                avatarEngine.setLookAtOffset(deltaX: 0, deltaY: 0)
                            }
                    )
                
                // Effet de halo ambiant réactif à l'élocution de Sarah
                if isSpeaking || speechManager.isSpeaking {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.12),
                            Color.purple.opacity(0.06),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 350
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
        }
    }
}

/// Conteneur UIViewRepresentable encapsulant un SCNView natif configuré pour Metal
struct NativeSceneKitContainerView: UIViewRepresentable {
    let scene: SCNScene
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        
        scnView.scene = scene
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        scnView.rendersContinuously = true
        scnView.isOpaque = true
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene != scene {
            uiView.scene = scene
        }
    }
}

