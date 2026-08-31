import SwiftUI
import AVFoundation

// MARK: - 1. Carte Interactive d'Image Générée (Flux / SDXL Open Source)

@available(iOS 14.0, *)
public struct GeneratedImageCardView: View {
    public let imageURLString: String
    public let promptDescription: String?
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var isShowingFullScreen: Bool = false
    @State private var isShowingShareSheet: Bool = false
    
    public init(imageURLString: String, promptDescription: String? = nil) {
        self.imageURLString = imageURLString
        self.promptDescription = promptDescription
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let img = loadedImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipped()
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isShowingFullScreen = true
                        }
                } else if isLoading {
                    ZStack {
                        Color(white: 0.12)
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                            .cornerRadius(12)
                        
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                            
                            Text("Génération du visuel HD...")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                } else {
                    ZStack {
                        Color(white: 0.15)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .cornerRadius(12)
                        
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            Text("Image non disponible")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            
            // Barre d'outils de l'image
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.sarahCyan)
                    Text("Flux.1 HD Open Source")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if let img = loadedImage {
                    Button(action: {
                        isShowingShareSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text("Partager")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            loadImageAsync()
        }
        .sheet(isPresented: $isShowingFullScreen) {
            if let img = loadedImage {
                FullScreenImageView(image: img, prompt: promptDescription)
            }
        }
    }
    
    private func loadImageAsync() {
        guard let url = URL(string: imageURLString) else {
            isLoading = false
            return
        }
        
        // Décoder sur un thread d'arrière-plan sans bloquer l'UI
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Vue Plein Écran pour l'Image

@available(iOS 14.0, *)
public struct FullScreenImageView: View {
    public let image: UIImage
    public let prompt: String?
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                }
                
                Spacer()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .padding()
                
                if let p = prompt, !p.isEmpty {
                    Text(p)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - 2. Carte Interactive de Musique Générative (OpenSourceMusicEngine)

@available(iOS 14.0, *)
public struct MusicTrackCardView: View {
    public let styleName: String
    
    @State private var isPlaying: Bool = false
    @State private var animPhase: CGFloat = 0
    @State private var timer: Timer? = nil
    
    public init(styleName: String = "Lo-Fi Chill") {
        self.styleName = styleName
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Bouton Play/Stop rond
                Button(action: {
                    togglePlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isPlaying ? Color.red.opacity(0.85) : Color.sarahCyan,
                                        isPlaying ? Color.orange.opacity(0.85) : Color(red: 0.2, green: 0.5, blue: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: isPlaying ? Color.red.opacity(0.3) : Color.sarahCyan.opacity(0.3), radius: 6, x: 0, y: 2)
                        
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sarah Music Engine")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Style : \(styleName) • 100% Local DSP")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.sarahCyan)
                }
                
                Spacer()
                
                // Onde animée DSP
                HStack(spacing: 3) {
                    ForEach(0..<6) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPlaying ? Color.sarahCyan : Color.white.opacity(0.2))
                            .frame(
                                width: 3,
                                height: isPlaying ? CGFloat(8 + (index * 4 + Int(animPhase * 8)) % 22) : 6
                            )
                            .animation(.easeInOut(duration: 0.15), value: animPhase)
                    }
                }
                .frame(height: 28)
            }
            
            // Tag statut
            HStack {
                Text(isPlaying ? "▶️ Lecture en cours sur haut-parleur" : "⏹️ Prêt à être joué")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isPlaying ? .green : .white.opacity(0.5))
                
                Spacer()
                
                Text("Zéro Quota • Synthèse PCM")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlaying ? Color.sarahCyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            self.isPlaying = OpenSourceMusicEngine.shared.isPlaying
            setupNotificationObservers()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            OpenSourceMusicEngine.shared.stopMusic()
            isPlaying = false
            timer?.invalidate()
        } else {
            let matchedStyle = OpenSourceMusicEngine.MusicStyle.allCases.first(where: { styleName.contains($0.rawValue) }) ?? .lofi
            OpenSourceMusicEngine.shared.generateAndPlayTrack(style: matchedStyle) { success, _ in
                DispatchQueue.main.async {
                    self.isPlaying = success
                    if success { self.startWaveAnimation() }
                }
            }
        }
    }
    
    private func startWaveAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            animPhase = (animPhase + 1).truncatingRemainder(dividingBy: 10)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SarahMusicPlaybackStarted"), object: nil, queue: .main) { _ in
            self.isPlaying = true
            self.startWaveAnimation()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SarahMusicPlaybackStopped"), object: nil, queue: .main) { _ in
            self.isPlaying = false
            self.timer?.invalidate()
        }
    }
}

// MARK: - 3. Carte de Rapport Visuel Enrichi (AdvancedVisionEngine)

@available(iOS 14.0, *)
public struct VisionReportCardView: View {
    public let messageContent: String
    
    @State private var isCopied: Bool = false
    
    public init(messageContent: String) {
        self.messageContent = messageContent
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.sarahCyan)
                Text("Analyse Visuelle Multimodale")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = messageContent
                    HapticService.shared.triggerNotificationSuccess()
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .bold))
                        Text(isCopied ? "Copié !" : "Copier")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isCopied ? .green : .white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            Text(messageContent)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(2)
        }
        .padding(12)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.sarahCyan.opacity(0.2), lineWidth: 1)
        )
    }
}
