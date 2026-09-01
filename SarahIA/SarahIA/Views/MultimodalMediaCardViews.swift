import SwiftUI
import AVFoundation
import WebKit

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
