import SwiftUI

/// Écran principal de discussion 100% natif SwiftUI avec synchronisation dynamique du clavier au-dessus de MessageBar.
@available(iOS 14.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    
    @State private var isShowingCamera: Bool = false
    @State private var isShowingYouTubePlayer: Bool = false
    @State private var youTubeInitialQuery: String = "musique"
    @State private var isShowingActionSheet: Bool = false
    @State private var isShowingWidgetsGallery: Bool = false
    @State private var isShowingSyncQR: Bool = false
    @State private var isMirrorDocked: Bool = false
    @State private var isDockedToRight: Bool = true
    @State private var mirrorDragOffset: CGSize = .zero
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            
            ZStack(alignment: isMirrorDocked ? (isDockedToRight ? .trailing : .leading) : .topTrailing) {
                VStack(spacing: 0) {
                    // 1. Topbar Native
                    topBar
                    
                    // 1.1 Bandeau Live Partage d'Écran Actif (Temps Réel)
                    if viewModel.isScreenSharingActive {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(viewModel.screenShareStatus == .active ? Color.red : Color.green)
                                .frame(width: 8, height: 8)
                            
                            Text(viewModel.screenShareStatus == .active ? "🔴 Partage d'écran en direct" : "🟢 Connecté au partage d'écran")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Arrêter") {
                                viewModel.stopLiveScreenSharing()
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.8)))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.15, green: 0.05, blue: 0.05))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 2. Fil de discussion (MessageList)
                    MessageList(
                        messages: viewModel.messages,
                        isTyping: viewModel.isTyping,
                        isKeyboardVisible: keyboard.isVisible,
                        onToggleSpeech: { message in
                            viewModel.toggleSpeechForMessage(message.content)
                        },
                        onSelectSuggestion: { suggestionText in
                            viewModel.sendQuickSuggestion(suggestionText)
                        },
                        onIntroduceSarah: {
                            viewModel.introduceSarah()
                        },
                        onDismissKeyboard: {
                            keyboard.dismiss()
                        }
                    )
                    
                    // 3. Barre de saisie (MessageBar) synchronisée au-dessus du clavier
                    MessageBar(
                        text: $viewModel.inputText,
                        isRecording: viewModel.isMicRunning,
                        onSend: { text in
                            viewModel.sendMessage(text)
                        },
                        onToggleMic: {
                            viewModel.toggleMicrophone()
                        },
                        onCamera: {
                            isShowingCamera = true
                        },
                        onPlusTapped: {
                            isShowingActionSheet = true
                        },
                        onPikudHaOref: {
                            viewModel.fetchPikudHaOrefAlerts()
                        },
                        onI24News: {
                            viewModel.fetchI24NewsHeadlines()
                        }
                    )
                    .padding(.bottom, keyboard.keyboardHeight > 0 ? (keyboard.keyboardHeight + 8) : max(16, bottomInset + 8))
                    .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: keyboard.keyboardHeight)
                }
                .background(Color.black)
                
                // 4. Overlay Flottant de Rendu Miroir d'Écran en Direct (Silhouette Smartphone Réelle)
                if viewModel.isScreenSharingActive {
                    if isMirrorDocked {
                        // Poignée / Onglet Latéral de Réapparition (Docké sur le bord)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                isMirrorDocked = false
                                mirrorDragOffset = .zero
                            }
                        }) {
                            HStack(spacing: 4) {
                                if !isDockedToRight {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 7, height: 7)
                                }
                                Text(isDockedToRight ? "‹" : "›")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                                if isDockedToRight {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 7, height: 7)
                                }
                            }
                            .frame(width: 38, height: 46)
                            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.85), lineWidth: 1.8)
                            )
                            .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 3)
                        }
                        .padding(.top, 140)
                        .padding(.horizontal, 2)
                        .transition(.move(edge: isDockedToRight ? .trailing : .leading).combined(with: .opacity))
                    } else {
                        VStack(spacing: 4) {
                            // Mini Dynamic Island
                            Capsule()
                                .fill(Color.black)
                                .frame(width: 32, height: 6)
                                .padding(.top, 4)
                            
                            HStack {
                                Circle()
                                    .fill(viewModel.screenShareStatus == .active ? Color.red : (viewModel.screenShareStatus == .connected ? Color.green : Color.yellow))
                                    .frame(width: 7, height: 7)
                                Text("● LIVE — Tom")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { viewModel.stopLiveScreenSharing() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.85))
                                        .font(.system(size: 13))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 2)
                            
                            if let img = viewModel.lastScreenShareImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 124, height: 184)
                                    .cornerRadius(10)
                                    .clipped()
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(white: 0.12))
                                        .frame(width: 124, height: 184)
                                    VStack(spacing: 6) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("En direct...")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            
                            if !viewModel.lastScreenShareAnalysis.isEmpty {
                                Text("👁️ \(viewModel.lastScreenShareAnalysis)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 2)
                            }
                            
                            Button(action: {
                                viewModel.stopLiveScreenSharing()
                            }) {
                                Text("⏹ Arrêter le partage")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.red.opacity(0.88)))
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                        }
                        .frame(width: 140)
                        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.85), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 5)
                        .offset(mirrorDragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    mirrorDragOffset = value.translation
                                }
                                .onEnded { value in
                                    if value.translation.width > 80 {
                                        HapticService.shared.buttonTap()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            isMirrorDocked = true
                                            isDockedToRight = true
                                            mirrorDragOffset = .zero
                                        }
                                    } else if value.translation.width < -80 {
                                        HapticService.shared.buttonTap()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            isMirrorDocked = true
                                            isDockedToRight = false
                                            mirrorDragOffset = .zero
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            mirrorDragOffset = .zero
                                        }
                                    }
                                }
                        )
                        .padding(.top, 60)
                        .padding(.trailing, 16)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .actionSheet(isPresented: $isShowingActionSheet) {
            ActionSheet(
                title: Text("Actions Rapides"),
                buttons: [
                    .default(Text("🌤️ Météo GPS en direct")) {
                        viewModel.sendMessage("Quel temps fait-il ?")
                    },
                    .default(Text("🚨 Alertes Pikoud HaOref (Israël)")) {
                        viewModel.sendMessage("Y a-t-il des alertes en Israël ?")
                    },
                    .default(Text("📰 Actualités (Franceinfo & i24)")) {
                        viewModel.sendMessage("Donne-moi les actualités")
                    },
                    .default(Text("📺 Sarah Vidéos (YouTube)")) {
                        youTubeInitialQuery = "musique"
                        isShowingYouTubePlayer = true
                    },
                    .default(Text("🖥️ Lancer le partage d'écran")) {
                        viewModel.startLiveScreenSharing()
                    },
                    .default(Text("📊 8 Widgets Sarah IA")) {
                        isShowingWidgetsGallery = true
                    },
                    .default(Text("📱 Synchronisation QR Code (P2P)")) {
                        isShowingSyncQR = true
                    },
                    .default(Text("📷 Vision par caméra")) {
                        isShowingCamera = true
                    },
                    .default(Text("🌐 Recherche sur Internet")) {
                        viewModel.inputText = "Cherche sur internet : "
                    },
                    .cancel(Text("Annuler"))
                ]
            )
        }
        .sheet(isPresented: $isShowingWidgetsGallery) {
            WidgetsGalleryView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingSyncQR) {
            LocalSyncQRView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraRepresentable(onPhotoAnalyzed: { image, result in
                let processedData = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 800, quality: 0.7)?.data ?? image.jpegData(compressionQuality: 0.7)
                let userMsg = Message(
                    content: "📷 [Photo analysée]",
                    isFromUser: true,
                    timestamp: Date(),
                    imageData: processedData
                )
                viewModel.sendMessage("Photo analysée : \(result.objectLabel)")
            }, onScreenShare: {
                isShowingCamera = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.startLiveScreenSharing()
                }
            })
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingYouTubePlayer) {
            YouTubePlayerRepresentable(query: youTubeInitialQuery)
                .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahLaunchCamera"))) { _ in
            isShowingCamera = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahLaunchYouTubePlayer"))) { notif in
            let query = (notif.object as? String) ?? ""
            youTubeInitialQuery = query
            isShowingYouTubePlayer = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahLaunchScreenShare"))) { _ in
            viewModel.startLiveScreenSharing()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahReadScreenTextRequested"))) { _ in
            viewModel.readScreenTextOCR()
        }
    }
    
    // MARK: - Topbar
    
    private var topBar: some View {
        HStack(alignment: .center) {
            // Bouton Menu Tiroir (Sidebar)
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
            
            Spacer()
            
            // Titre & Indicateur d'état Sarah IA
            VStack(spacing: 2) {
                Text("Sarah IA")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Bouton Nouvelle Discussion
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.startNewChat()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
        .padding(.bottom, 6)
    }
    
    private var statusColor: Color {
        if viewModel.isScreenSharingActive {
            return viewModel.screenShareStatus == .active ? .red : .green
        } else if viewModel.isMicRunning {
            return .red
        } else if viewModel.isSpeaking {
            return .sarahCyan
        } else if viewModel.isTyping {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if viewModel.isScreenSharingActive {
            return viewModel.screenShareStatus == .active ? "Écran partagé (En direct)" : "Écran partagé (Connecté)"
        } else if viewModel.isMicRunning {
            return "Écoute en direct..."
        } else if viewModel.isSpeaking {
            return "Parle..."
        } else if viewModel.isTyping {
            return "Réflexion..."
        } else {
            return "Prête"
        }
    }
}

/// Wrapper UIKit pour afficher LiveCameraViewController en SwiftUI
@available(iOS 14.0, *)
public struct CameraRepresentable: UIViewControllerRepresentable {
    public var onPhotoAnalyzed: (UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void
    public var onScreenShare: () -> Void
    
    public init(
        onPhotoAnalyzed: @escaping (UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void,
        onScreenShare: @escaping () -> Void
    ) {
        self.onPhotoAnalyzed = onPhotoAnalyzed
        self.onScreenShare = onScreenShare
    }
    
    public func makeUIViewController(context: Context) -> LiveCameraViewController {
        let vc = LiveCameraViewController()
        vc.onPhotoAnalyzed = onPhotoAnalyzed
        vc.onScreenShareRequested = onScreenShare
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: LiveCameraViewController, context: Context) {}
}

/// Wrapper UIKit pour afficher YouTubePlayerViewController en SwiftUI
@available(iOS 14.0, *)
public struct YouTubePlayerRepresentable: UIViewControllerRepresentable {
    public var query: String?
    
    public init(query: String? = nil) {
        self.query = query
    }
    
    public func makeUIViewController(context: Context) -> YouTubePlayerViewController {
        let vc = YouTubePlayerViewController()
        vc.initialQuery = query
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: YouTubePlayerViewController, context: Context) {}
}

