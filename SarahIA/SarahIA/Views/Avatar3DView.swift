import SwiftUI
import SceneKit

/// Vue SwiftUI intégrant le moteur 3D SceneKit avec support tactile et affichage plein écran.
public struct Avatar3DView: View {
    @ObservedObject var avatarEngine = AvatarEngine.shared
    @State private var dragOffset: CGSize = .zero
    
    public init() {}
    
    public var body: some View {
        SceneKitContainerView()
            .background(Color.black)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        avatarEngine.setLookAtOffset(
                            deltaX: Float(dragOffset.width),
                            deltaY: Float(dragOffset.height)
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                            dragOffset = .zero
                            avatarEngine.setLookAtOffset(deltaX: 0, deltaY: 0)
                        }
                    }
            )
            .edgesIgnoringSafeArea(.all)
    }
}

/// Conteneur UIViewRepresentable pour SCNView optimisé Metal 60/120 FPS
struct SceneKitContainerView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let engine = AvatarEngine.shared
        
        scnView.scene = engine.scene
        scnView.pointOfView = engine.cameraNode
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Mises à jour d'état si nécessaire
    }
}
