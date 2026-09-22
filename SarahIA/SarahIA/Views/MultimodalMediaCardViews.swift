import SwiftUI
import AVFoundation
import AVKit
import WebKit

// MARK: - 1. Carte Interactive d'Image Générée (Flux / SDXL Open Source)

// MARK: - 1. Carte Interactive d'Image Générée & Carré d'Animation Futuriste

@available(iOS 14.0, *)
public struct GeneratedImageCardView: View {
    public let imageURLString: String
    public let promptDescription: String?
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var isShowingFullScreen: Bool = false
    @State private var isShowingShareSheet: Bool = false
    @State private var hasFailed: Bool = false
    
    public init(imageURLString: String, promptDescription: String? = nil) {
        self.imageURLString = imageURLString
        self.promptDescription = promptDescription
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let img = loadedImage {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fill)
                            .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 270)
                            .clipped()
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.sarahCyan.opacity(0.6), Color.purple.opacity(0.4)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: Color.sarahCyan.opacity(0.25), radius: 10, x: 0, y: 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isShowingFullScreen = true
                            }
                        
                        // Badge HD Photoréaliste
                        HStack(spacing: 4) {
                            Text("✨ HD")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(6)
                        .padding(8)
                    }
                } else if isLoading {
                    // Carré d'animation haute technologie en temps réel
                    ImageGeneratingSquareAnimationView(prompt: promptDescription)
                        .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 270)
                        .cornerRadius(16)
                } else {
                    ZStack {
                        Color(white: 0.12)
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                            .cornerRadius(16)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                            Text("Image en cours de rendu...")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Button(action: {
                                isLoading = true
                                hasFailed = false
                                loadImageAsync()
                            }) {
                                Text("🔄 Réessayer")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.sarahCyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.sarahCyan.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // Barre d'outils inférieure de l'image
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.sarahCyan)
                    Text(loadedImage != nil ? "Généré par Sarah • Flux.1 HD" : "Génération IA en cours...")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.14))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
            hasFailed = true
            return
        }
        
        // Décoder sur un thread d'arrière-plan sans bloquer l'UI
        DispatchQueue.global(qos: .userInitiated).async {
            var request = URLRequest(url: url)
            request.timeoutInterval = 25
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            self.loadedImage = image
                            self.isLoading = false
                            self.hasFailed = false
                        }
                    }
                } else {
                    // Deuxième tentative automatique après 1.5s
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
                        if let retryData = try? Data(contentsOf: url), let retryImg = UIImage(data: retryData) {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    self.loadedImage = retryImg
                                    self.isLoading = false
                                    self.hasFailed = false
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.hasFailed = true
                            }
                        }
                    }
                }
            }.resume()
        }
    }
}

@available(iOS 14.0, *)
public struct GeneratedInlineImageCardView: View {
    public let image: UIImage
    public let promptDescription: String?

    @State private var isShowingFullScreen = false

    public init(image: UIImage, promptDescription: String? = nil) {
        self.image = image
        self.promptDescription = promptDescription
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 290)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isShowingFullScreen = true
                    }

                Text("✨ HD")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.66))
                    .cornerRadius(7)
                    .padding(8)
            }

            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.sarahCyan)

                Text("Image générée par Sarah")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))

                Spacer()

                Button(action: shareImage) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 28)
                        .background(Color.white.opacity(0.10))
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(10)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .sheet(isPresented: $isShowingFullScreen) {
            FullScreenImageView(image: image, prompt: promptDescription)
        }
    }

    private func shareImage() {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if #available(iOS 13.0, *) {
            let root = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
            root?.present(controller, animated: true)
        } else {
            UIApplication.shared.keyWindow?
                .rootViewController?
                .present(controller, animated: true)
        }
    }
}

// MARK: - Indicateur Standard & Épuré de Génération d'Image

@available(iOS 14.0, *)
public struct ImageGeneratingSquareAnimationView: View {
    public let prompt: String?
    
    public init(prompt: String? = nil) {
        self.prompt = prompt
    }
    
    public var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.12)
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Génération de l'image en cours...")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                
                if let p = prompt, !p.isEmpty {
                    Text("« \(p) »")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(16)
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
    public let startsGenerating: Bool
    public let audioURL: URL?
    public let requestedDuration: TimeInterval?

    @State private var isPlaying: Bool = false
    @State private var isGenerating: Bool
    @State private var progress: Double
    @State private var animPhase: CGFloat = 0
    @State private var timer: Timer? = nil
    @State private var generatedURL: URL?
    @State private var duration: TimeInterval?
    @State private var localPlayer: AVAudioPlayer?

    public init(
        styleName: String = "Lo-Fi Chill",
        startsGenerating: Bool = false,
        audioURL: URL? = nil,
        requestedDuration: TimeInterval? = nil
    ) {
        self.styleName = styleName
        self.startsGenerating = startsGenerating
        self.audioURL = audioURL
        self.requestedDuration = requestedDuration
        _isGenerating = State(initialValue: startsGenerating)
        _progress = State(initialValue: audioURL == nil && startsGenerating ? 0 : 1)
        _generatedURL = State(initialValue: audioURL)
        _duration = State(initialValue: requestedDuration)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                Button(action: {
                    togglePlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.sarahCyan,
                                        Color(red: 0.22, green: 0.45, blue: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                            .opacity(isGenerating ? 0.55 : 1)

                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 1.5)
                        }
                    }
                }
                .disabled(isGenerating)
                .buttonStyle(BorderlessButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(isGenerating ? "Musique en création…" : "Musique générée")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(styleName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.sarahCyan)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                if generatedURL != nil && !isGenerating {
                    Button(action: {
                        shareGeneratedAudio()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            // L'onde se "dessine" au fur et à mesure de la génération.
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<22, id: \.self) { index in
                    let threshold = Double(index + 1) / 22.0
                    let isBuilt = progress >= threshold || !isGenerating
                    let moving = CGFloat((index * 7 + Int(animPhase * 11)) % 19)
                    let base = CGFloat(7 + (index * 5) % 17)

                    RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                        .fill(isBuilt ? Color.sarahCyan : Color.white.opacity(0.13))
                        .frame(
                            width: 3,
                            height: isGenerating || isPlaying
                                ? min(30, base + moving * 0.55)
                                : base
                        )
                        .animation(.easeInOut(duration: 0.16), value: animPhase)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
            .padding(.horizontal, 2)

            if isGenerating {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .sarahCyan))
            }

            HStack(spacing: 8) {
                Text(statusText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(statusColor)

                Spacer()

                Text(durationText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.48))
            }
        }
        .padding(13)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isGenerating || isPlaying
                        ? Color.sarahCyan.opacity(0.42)
                        : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
        .onAppear {
            if isGenerating || isPlaying {
                startWaveAnimation()
            }
        }
        .onDisappear {
            timer?.invalidate()
            localPlayer?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahMusicGenerationProgress"))) { note in
            guard startsGenerating, matchesCurrentPrompt(note) else { return }
            isGenerating = true
            if let value = note.userInfo?["progress"] as? Double {
                progress = min(max(value, 0), 0.99)
            }
            if let seconds = note.userInfo?["duration"] as? Double {
                duration = seconds
            }
            startWaveAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedMusicReady"))) { note in
            guard startsGenerating, matchesCurrentPrompt(note),
                  let url = note.object as? URL else { return }

            generatedURL = url
            if let seconds = note.userInfo?["duration"] as? Double {
                duration = seconds
            }
            progress = 1
            isGenerating = false
            timer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahMusicGenerationCancelled"))) { _ in
            guard startsGenerating else { return }
            isGenerating = false
            timer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahMusicGenerationFailed"))) { note in
            guard startsGenerating, matchesCurrentPrompt(note) else { return }
            isGenerating = false
            timer?.invalidate()
        }
    }

    private var statusText: String {
        if isGenerating {
            return "Création \(Int(progress * 100)) %"
        }
        if isPlaying {
            return "Lecture en cours"
        }
        if generatedURL != nil {
            return "Prêt à être joué"
        }
        return "Piste locale"
    }

    private var statusColor: Color {
        if isGenerating { return .sarahCyan }
        if isPlaying { return .green }
        return .white.opacity(0.55)
    }

    private var durationText: String {
        guard let duration else { return "Local" }
        if duration >= 59.5 {
            return "1:00"
        }
        return "0:" + String(format: "%02d", Int(duration.rounded()))
    }

    private func matchesCurrentPrompt(_ note: Notification) -> Bool {
        guard let eventPrompt = note.userInfo?["prompt"] as? String else {
            return true
        }

        let lhs = styleName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = eventPrompt
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private func togglePlayback() {
        guard !isGenerating else { return }

        if let url = generatedURL {
            do {
                if localPlayer == nil || localPlayer?.url != url {
                    localPlayer = try AVAudioPlayer(contentsOf: url)
                    localPlayer?.prepareToPlay()
                }

                guard let player = localPlayer else { return }

                if player.isPlaying {
                    player.pause()
                    isPlaying = false
                    timer?.invalidate()
                } else {
                    player.play()
                    isPlaying = true
                    startWaveAnimation()
                }
            } catch {
                isPlaying = false
            }
            return
        }

        // Compatibilité avec les anciennes cartes DSP déjà présentes dans l'historique.
        if isPlaying {
            OpenSourceMusicEngine.shared.stopMusic()
            isPlaying = false
            timer?.invalidate()
        } else {
            let matchedStyle = OpenSourceMusicEngine.MusicStyle.allCases.first(
                where: { styleName.contains($0.rawValue) }
            ) ?? .lofi

            OpenSourceMusicEngine.shared.generateAndPlayTrack(style: matchedStyle) { success, _ in
                DispatchQueue.main.async {
                    self.isPlaying = success
                    if success {
                        self.startWaveAnimation()
                    }
                }
            }
        }
    }

    private func startWaveAnimation() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            animPhase = (animPhase + 1).truncatingRemainder(dividingBy: 10)

            if let player = localPlayer,
               isPlaying,
               !player.isPlaying {
                isPlaying = false
                timer?.invalidate()
                timer = nil
            }
        }
    }

    private func shareGeneratedAudio() {
        guard let url = generatedURL else { return }

        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if #available(iOS 13.0, *) {
            let root = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
            root?.present(controller, animated: true)
        } else {
            UIApplication.shared.keyWindow?
                .rootViewController?
                .present(controller, animated: true)
        }
    }
}

// MARK: - Carte de génération vidéo

@available(iOS 15.0, *)
public struct GeneratedVideoCardView: View {
    public let prompt: String
    public let startsGenerating: Bool
    public let videoURL: URL?
    public let requestedDuration: TimeInterval?

    @State private var progress: Double
    @State private var phase: String
    @State private var resolvedURL: URL?
    @State private var player: AVPlayer?
    @State private var isSharing = false

    public init(
        prompt: String,
        startsGenerating: Bool,
        videoURL: URL?,
        requestedDuration: TimeInterval?
    ) {
        self.prompt = prompt
        self.startsGenerating = startsGenerating
        self.videoURL = videoURL
        self.requestedDuration = requestedDuration
        _progress = State(initialValue: videoURL == nil && startsGenerating ? 0.02 : 1)
        _phase = State(initialValue: startsGenerating ? "Préparation de la scène" : "Vidéo prête")
        _resolvedURL = State(initialValue: videoURL)
        _player = State(initialValue: videoURL.map { AVPlayer(url: $0) })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.42))

                if let player, resolvedURL != nil {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.sarahCyan.opacity(0.13))
                                .frame(width: 64, height: 64)

                            Image(systemName: "video.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.sarahCyan)
                        }

                        Text("Génération vidéo")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text(phase)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.58))

                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .sarahCyan))
                            .frame(maxWidth: 210)

                        Text("\(Int(progress * 100)) %")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.sarahCyan)
                    }
                    .padding(22)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 270)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolvedURL == nil ? "Sarah Motion Video" : "Vidéo générée")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(prompt)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer()

                if let duration = requestedDuration {
                    Text(duration >= 59.5 ? "1:00" : "0:" + String(format: "%02d", Int(duration.rounded())))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.48))
                }

                if resolvedURL != nil {
                    Button(action: shareVideo) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            if resolvedURL != nil {
                Text("MP4 créé localement à partir d’une image clé générée par Sarah. Le moteur de diffusion vidéo dédié reste séparé tant que son runtime iPhone n’est pas validé.")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .sarahLiquidGlass(
            cornerRadius: 20,
            tint: .sarahCyan,
            intensity: 0.10
        )
        .onAppear {
            if let url = resolvedURL, player == nil {
                player = AVPlayer(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahVideoGenerationProgress"))) { note in
            guard matchesPrompt(note) else { return }
            if let value = note.userInfo?["progress"] as? Double {
                progress = min(max(value, 0), 0.99)
            }
            if let value = note.userInfo?["phase"] as? String {
                phase = value
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahGeneratedVideoReady"))) { note in
            guard matchesPrompt(note), let url = note.object as? URL else { return }
            resolvedURL = url
            player = AVPlayer(url: url)
            progress = 1
            phase = "Vidéo prête"
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahVideoGenerationFailed"))) { note in
            guard matchesPrompt(note) else { return }
            progress = 0
            phase = (note.userInfo?["error"] as? String) ?? "La génération a échoué"
        }
    }

    private func matchesPrompt(_ note: Notification) -> Bool {
        guard let eventPrompt = note.userInfo?["prompt"] as? String else {
            return true
        }

        let lhs = prompt
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = eventPrompt
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private func shareVideo() {
        guard let url = resolvedURL else { return }
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        root?.present(controller, animated: true)
    }
}

// MARK: - Carte Raccourcis Apple

@available(iOS 14.0, *)
public struct ShortcutPlanCardView: View {
    public let plan: ShortcutGenerator.ShortcutPlan

    @State private var isCopied = false
    @State private var openedShortcuts = false

    public init(plan: ShortcutGenerator.ShortcutPlan) {
        self.plan = plan
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.36, green: 0.23, blue: 0.96),
                                    Color(red: 0.78, green: 0.22, blue: 0.72)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text("\(plan.blocks.count) blocs Raccourcis")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()
            }

            Text(plan.summary)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                ForEach(0..<plan.blocks.count, id: \.self) { index in
                    let block = plan.blocks[index]
                    HStack(alignment: .top, spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.09))
                                .frame(width: 32, height: 32)

                            Image(systemName: block.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text("\(index + 1).")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.sarahCyan)

                                Text(block.title)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            if let subtitle = block.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.58))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if !block.parameters.isEmpty {
                                Text(
                                    block.parameters.keys.sorted().compactMap { key in
                                        guard let value = block.parameters[key] else { return nil }
                                        return "\(key): \(value)"
                                    }.joined(separator: "  •  ")
                                )
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(.sarahCyan.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 0)

                        Text(block.category)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.07)))
                    }
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
                }
            }

            HStack(spacing: 8) {
                Button(action: copyBlocks) {
                    HStack(spacing: 6) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Blocs copiés" : "Copier les blocs")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: copyAndOpenShortcuts) {
                    HStack(spacing: 6) {
                        Image(systemName: openedShortcuts ? "checkmark.circle.fill" : "arrow.up.forward.app.fill")
                        Text("Ouvrir Raccourcis")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.43, green: 0.27, blue: 0.95))
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Text("Sarah copie la recette et ouvre un raccourci vierge. iOS ne permet pas à une app tierce de coller automatiquement une pile arbitraire de blocs dans l’éditeur.")
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.38))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.30), lineWidth: 1)
        )
    }

    private func copyBlocks() {
        UIPasteboard.general.string = plan.copyText
        HapticService.shared.notificationSuccess()
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            isCopied = false
        }
    }

    private func copyAndOpenShortcuts() {
        UIPasteboard.general.string = plan.copyText
        HapticService.shared.buttonTap()

        guard let url = ShortcutGenerator.shared.createShortcutURL else {
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                openedShortcuts = success
            }
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
                    HapticService.shared.notificationSuccess()
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

// MARK: - 4. Optimiseur HTML & Viewport Universel Adaptatif (iPhone 5s à iPhone 17+)

public struct HTMLAdaptiveViewportOptimizer {
    
    /// Répare et adapte le code HTML pour un affichage 100% responsive et fluide sur écran d'iPhone
    public static func optimizeHTMLForIPhoneScreen(html: String, title: String = "Sarah IA App") -> String {
        var processed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let lower = processed.lowercased()
        let hasHtmlTag = lower.contains("<html")
        let hasBodyTag = lower.contains("<body")
        
        let viewportMeta = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover\">"
        
        let injectedCSS = """
        <style id="sarah-iphone-adaptive-styles">
        * {
            box-sizing: border-box !important;
            -webkit-tap-highlight-color: transparent !important;
        }
        html {
            width: 100% !important;
            height: 100% !important;
            margin: 0 !important;
            padding: 0 !important;
            -webkit-text-size-adjust: 100% !important;
        }
        body {
            width: 100% !important;
            max-width: 100vw !important;
            min-height: 100% !important;
            margin: 0 !important;
            padding: 12px !important;
            overflow-x: hidden !important;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important;
            background-color: #0d0d12 !important;
            color: #ffffff !important;
        }
        img, video, canvas, svg, iframe, table {
            max-width: 100% !important;
            height: auto !important;
        }
        button, input, select, textarea {
            font-family: inherit !important;
            font-size: 16px !important;
        }
        </style>
        """
        
        if !hasHtmlTag && !hasBodyTag {
            return """
            <!DOCTYPE html>
            <html lang="fr">
            <head>
                <meta charset="UTF-8">
                \(viewportMeta)
                <title>\(title)</title>
                \(injectedCSS)
            </head>
            <body>
                \(processed)
            </body>
            </html>
            """
        }
        
        if lower.contains("<head>") || lower.contains("<head ") {
            if !lower.contains("name=\"viewport\"") && !lower.contains("name='viewport'") {
                processed = processed.replacingOccurrences(of: "<head>", with: "<head>\n\(viewportMeta)\n\(injectedCSS)", options: .caseInsensitive)
            } else {
                processed = processed.replacingOccurrences(of: "<head>", with: "<head>\n\(injectedCSS)", options: .caseInsensitive)
            }
        } else if lower.contains("<html>") || lower.contains("<html ") {
            processed = processed.replacingOccurrences(of: "<html>", with: "<html>\n<head>\n\(viewportMeta)\n\(injectedCSS)\n</head>", options: .caseInsensitive)
        } else {
            processed = "\(viewportMeta)\n\(injectedCSS)\n" + processed
        }
        
        return processed
    }
}

// MARK: - 5. Carte Interactive de Détection HTML & Prompt de Prévisualisation

@available(iOS 14.0, *)
public struct HTMLPreviewPromptCardView: View {
    public let htmlContent: String
    
    @State private var isShowingModal: Bool = false
    @State private var selectedMode: PreviewDisplayMode = .virtualIPhone
    @State private var isCopied: Bool = false
    
    public enum PreviewDisplayMode {
        case virtualIPhone
        case standardWebView
    }
    
    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // En-tête de la carte
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                    
                    Text("Code HTML & Projet Web Détecté")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Bouton Copier le Code
                Button(action: {
                    UIPasteboard.general.string = htmlContent
                    HapticService.shared.notificationSuccess()
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .bold))
                        Text(isCopied ? "Copié" : "Copier")
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
            
            // Question de Sarah
            Text("Veux-tu que j'ouvre ce rendu dans le Simulateur iPhone Virtuel ou dans la WebView standard ?")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.92))
                .lineSpacing(2)
            
            // 2 Boutons de Choix Interactifs
            VStack(spacing: 7) {
                // Option 1 : Ouvrir dans l'iPhone Virtuel
                Button(action: {
                    HapticService.shared.buttonTap()
                    selectedMode = .virtualIPhone
                    isShowingModal = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.system(size: 14, weight: .bold))
                        Text("📱  Ouvrir dans l'iPhone Virtuel")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.15, green: 0.72, blue: 1.0),
                                Color(red: 0.70, green: 0.25, blue: 0.95)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.3), radius: 4, y: 2)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Option 2 : Ouvrir dans le WebView (Plein Écran)
                Button(action: {
                    HapticService.shared.buttonTap()
                    selectedMode = .standardWebView
                    isShowingModal = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                        Text("🌐  Ouvrir dans le WebView")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.15))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.11, blue: 0.15))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.35), lineWidth: 1.2)
        )
        .fullScreenCover(isPresented: $isShowingModal) {
            VirtualIPhoneModalView(htmlContent: htmlContent, initialMode: selectedMode)
        }
    }
}

// MARK: - 6. Vue Modale Simulateur iPhone Virtuel & Plein Écran WebView

@available(iOS 14.0, *)
public struct VirtualIPhoneModalView: View {
    public let htmlContent: String
    public let initialMode: HTMLPreviewPromptCardView.PreviewDisplayMode
    
    @Environment(\.presentationMode) var presentationMode
    @State private var currentMode: HTMLPreviewPromptCardView.PreviewDisplayMode
    @State private var isShowingShareSheet: Bool = false
    
    public init(htmlContent: String, initialMode: HTMLPreviewPromptCardView.PreviewDisplayMode = .virtualIPhone) {
        self.htmlContent = htmlContent
        self.initialMode = initialMode
        _currentMode = State(initialValue: initialMode)
    }
    
    private var optimizedHTML: String {
        return HTMLAdaptiveViewportOptimizer.optimizeHTMLForIPhoneScreen(html: htmlContent)
    }
    
    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Barre Supérieure de Navigation
                HStack(spacing: 12) {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    // Sélecteur de Mode
                    Picker("", selection: $currentMode) {
                        Text("📱 iPhone Virtuel").tag(HTMLPreviewPromptCardView.PreviewDisplayMode.virtualIPhone)
                        Text("🌐 Plein Écran WebView").tag(HTMLPreviewPromptCardView.PreviewDisplayMode.standardWebView)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Bouton Partager
                    Button(action: {
                        isShowingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                
                // 2. Contenu selon le mode sélectionné
                if currentMode == .virtualIPhone {
                    // Rendu dans le Châssis iPhone Virtuel (Inspiré de index.html)
                    GeometryReader { geo in
                        let availableWidth = geo.size.width
                        let availableHeight = geo.size.height
                        
                        // Dimensions standard iPhone (390 x 844)
                        let targetW: CGFloat = 390
                        let targetH: CGFloat = 844
                        let scale = min((availableWidth - 24) / targetW, (availableHeight - 16) / targetH, 1.0)
                        
                        ZStack {
                            Color.clear
                            
                            VStack(spacing: 0) {
                                // Cadre Externe de l'iPhone
                                ZStack {
                                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                                        .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 48, style: .continuous)
                                                .stroke(Color(white: 0.25), lineWidth: 3.5)
                                        )
                                        .shadow(color: Color.black.opacity(0.8), radius: 24, x: 0, y: 10)
                                    
                                    // Écran Interne de l'iPhone
                                    VStack(spacing: 0) {
                                        // Dynamic Island & Status Bar
                                        ZStack {
                                            Color(red: 0.07, green: 0.07, blue: 0.09)
                                            
                                            HStack {
                                                Text("9:41")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.leading, 24)
                                                
                                                Spacer()
                                                
                                                // Dynamic Island Pill
                                                Capsule()
                                                    .fill(Color.black)
                                                    .frame(width: 100, height: 26)
                                                    .overlay(
                                                        HStack(spacing: 6) {
                                                            Circle().fill(Color(red: 0.15, green: 0.72, blue: 1.0)).frame(width: 5, height: 5)
                                                            Text("Sarah Web")
                                                                .font(.system(size: 9, weight: .bold))
                                                                .foregroundColor(.white)
                                                        }
                                                    )
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 4) {
                                                    Image(systemName: "wifi")
                                                    Image(systemName: "battery.100")
                                                }
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.trailing, 24)
                                            }
                                        }
                                        .frame(height: 44)
                                        
                                        // Barre d'adresse Safari Virtuelle
                                        HStack(spacing: 6) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                            Text("sarah.local / app.html")
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.85))
                                            Spacer()
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color(white: 0.14))
                                        .cornerRadius(8)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 4)
                                        
                                        // WebView Responsive
                                        VirtualIPhoneWebViewRepresentable(htmlContent: optimizedHTML)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        
                                        // Home Bar Indicative
                                        ZStack {
                                            Color(red: 0.07, green: 0.07, blue: 0.09)
                                            Capsule()
                                                .fill(Color.white.opacity(0.6))
                                                .frame(width: 130, height: 4)
                                        }
                                        .frame(height: 20)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                                    .padding(6)
                                }
                                .frame(width: targetW, height: targetH)
                                .scaleEffect(scale)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    // Mode Plein Écran WebView Standard
                    VirtualIPhoneWebViewRepresentable(htmlContent: optimizedHTML)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewController(activityItems: [htmlContent])
        }
    }
}

// MARK: - 7. Representable WKWebView pour Rendu HTML

@available(iOS 14.0, *)
public struct VirtualIPhoneWebViewRepresentable: UIViewRepresentable {
    public let htmlContent: String
    
    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        webView.scrollView.bounces = true
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// MARK: - Helper UIActivityViewController pour Partage
@available(iOS 14.0, *)
public struct ActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
