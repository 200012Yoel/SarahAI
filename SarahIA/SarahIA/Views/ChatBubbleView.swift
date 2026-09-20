import Foundation
import SwiftUI
import WebKit
import Photos
import UIKit

/// Bulle de message stylisée au format natif iMessage Dark Mode avec bouton de lecture vocale TTS.
@available(iOS 15.0, *)
public struct ChatBubbleView: View {
    public let message: Message
    public var isSpeaking: Bool
    public var onSpeak: (() -> Void)?
    public var onRetry: (() -> Void)?
    public var onOpenStudio: (() -> Void)?

    @State private var isShowingImageViewer = false
    @State private var selectedImage: UIImage?
    
    public init(
        message: Message,
        isSpeaking: Bool = false,
        isPlayingAudio: Bool = false,
        onSpeak: (() -> Void)? = nil,
        onPlayTapped: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        onOpenStudio: (() -> Void)? = nil
    ) {
        self.message = message
        self.isSpeaking = isSpeaking || isPlayingAudio
        self.onSpeak = onSpeak ?? onPlayTapped
        self.onRetry = onRetry
        self.onOpenStudio = onOpenStudio
    }
    
    public var body: some View {
        Group {
            if !message.isFromUser && message.isInternalEngineLeak {
                EmptyView()
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    if message.isFromUser {
                        Spacer(minLength: 40)
                        userBubble
                    } else {
                        aiBubble
                        Spacer(minLength: 40)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
        .fullScreenCover(isPresented: $isShowingImageViewer) {
            if let selectedImage {
                SarahFullscreenImageViewer(
                    image: selectedImage,
                    prompt: message.imageGenerationPrompt ?? message.content
                )
            }
        }
    }
    
    // MARK: - Bulle Utilisateur (iMessage Bleu)
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .trailing, spacing: 6) {
                if let data = message.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 220, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                if !message.content.isEmpty && message.content != "📷 [Photo analysée]" {
                    Text(message.content)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, message.imageData != nil ? 6 : 16)
            .padding(.vertical, message.imageData != nil ? 6 : 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.12, green: 0.53, blue: 0.98), // Apple iMessage Blue
                        Color(red: 0.05, green: 0.45, blue: 0.90)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
            
            Text(message.formattedTime)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.trailing, 4)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
                HapticService.shared.buttonTap()
            } label: {
                Label("Copier", systemImage: "doc.on.doc")
            }

            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    HapticService.shared.buttonTap()
                    onRetry?()
                } label: {
                    Label("Réitérer", systemImage: "arrow.clockwise")
                }
            }
        }
    }
    
    private func safeAssistantContent(_ raw: String) -> String {
        let decoded = raw.decodingHTMLEntities()
        let leaked =
            decoded.localizedCaseInsensitiveContains("<|im_start|>") ||
            decoded.localizedCaseInsensitiveContains("<|im_end|>") ||
            decoded.localizedCaseInsensitiveContains("RÈGLES ABSOLUES") ||
            decoded.localizedCaseInsensitiveContains("REGLES ABSOLUES") ||
            decoded.localizedCaseInsensitiveContains("Tu es Sarah, l'intelligence artificielle intégrée à Sarah Engine")
        
        if leaked {
            return ""
        }
        
        return decoded
    }
    
    @ViewBuilder
    private func renderedAssistantText(_ content: String) -> some View {
        if #available(iOS 15.0, *),
           let attributed = try? AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
           ) {
            Text(attributed)
        } else {
            Text(
                content
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "__", with: "")
            )
        }
    }

    // MARK: - Bulle Sarah AI (Gris Charcoal Sombre Haute Lisibilité + Bouton Écouter)
    
    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Badge Assistant Sarah
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
            
            VStack(alignment: .leading, spacing: 6) {
                // Contenu du message
                if !message.isVisionReport {
                    let rawContent = message.content
                    let displayContent: String = {
                        let safe = safeAssistantContent(rawContent)
                        if let imgURL = message.detectedImageURL, safe.contains(imgURL) {
                            let cleaned = safe
                                .replacingOccurrences(of: imgURL, with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            return cleaned.isEmpty ? "🎨 Image générée" : cleaned
                        }
                        return safe
                    }()
                    
                    if !displayContent.isEmpty {
                        renderedAssistantText(displayContent)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .textSelection(.enabled)
                            .foregroundColor(.white)
                            .lineSpacing(3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                Color(red: 0.16, green: 0.16, blue: 0.18) // Apple Dark Bubble Gray
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 19, style: .continuous)
                                    .stroke(
                                        isSpeaking ? Color.sarahCyan.opacity(0.6) : Color.white.opacity(0.08),
                                        lineWidth: isSpeaking ? 1.5 : 0.5
                                    )
                            )
                            .shadow(color: isSpeaking ? Color.sarahCyan.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
                    }
                }
                
                // Image locale : afficher directement les octets du rendu.
                if let data = message.imageData, let uiImage = UIImage(data: data) {
                    Button {
                        selectedImage = uiImage
                        isShowingImageViewer = true
                        HapticService.shared.buttonTap()
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Ouvrir l’image en plein écran")
                } else if let imageURL = message.detectedImageURL {
                    GeneratedImageCardView(
                        imageURLString: imageURL,
                        promptDescription: message.imageGenerationPrompt ?? message.content
                    )
                    .frame(maxWidth: 290)
                }
                
                // Carte Interactive Musicale Générative (DSP Synth)
                if let musicStyle = message.detectedMusicStyle {
                    MusicTrackCardView(styleName: musicStyle)
                        .frame(maxWidth: 280)
                }
                
                // Carte de Rapport d'Analyse Visuelle Poussée (OCR & Objets)
                if message.isVisionReport {
                    VisionReportCardView(messageContent: message.content)
                        .frame(maxWidth: 280)
                }
                
                // Carte Interactive de Détection HTML (iPhone Virtuel vs WebView)
                if let htmlCode = message.detectedHTMLCode {
                    HTMLPreviewPromptCardView(htmlContent: htmlCode)
                        .frame(maxWidth: 290)
                }

                // Raphaël peut proposer une prévisualisation sans emprisonner la personne
                // dans un écran plein format : l'ouverture devient volontaire.
                if message.content.contains("Ouvrir le Studio") {
                    Button(action: { onOpenStudio?() }) {
                        Label("Ouvrir le Studio", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.15, green: 0.52, blue: 0.96))
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .accessibilityLabel("Ouvrir le Studio Raphaël")
                }
                
                // Carte d'alerte interactive HTML / Map (si présente)
                if let alert = message.alertEvent {
                    AlertCardSwiftUIView(alert: alert)
                        .frame(height: 240)
                        .cornerRadius(14)
                }
                
                // Barre d'action inférieure : Heure + Bouton Écouter la réponse
                HStack(spacing: 8) {
                    Text(message.formattedTime)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.leading, 4)
                    
                    // 🔊 Bouton Écouter / Relire la réponse de Sarah
                    Button(action: {
                        onSpeak?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isSpeaking ? .sarahCyan : .white.opacity(0.8))
                            
                            Text(isSpeaking ? "En lecture..." : "Écouter")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(isSpeaking ? .sarahCyan : .white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSpeaking ? Color.sarahCyan.opacity(0.2) : Color.white.opacity(0.08))
                                .overlay(
                                    Capsule().stroke(isSpeaking ? Color.sarahCyan.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    }
}

// MARK: - Viewer d'image plein écran

@available(iOS 15.0, *)
private struct SarahFullscreenImageViewer: View {
    let image: UIImage
    let prompt: String

    @Environment(\.presentationMode) private var presentationMode
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isSharing = false
    @State private var statusText: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .contentShape(Rectangle())
                    .gesture(zoomGesture)
                    .simultaneousGesture(panGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                                lastScale = 2
                            }
                        }
                    }
            }
            .ignoresSafeArea()

            VStack {
                HStack(spacing: 10) {
                    viewerButton("xmark") {
                        presentationMode.wrappedValue.dismiss()
                    }

                    Spacer()

                    viewerButton("square.and.arrow.up") {
                        isSharing = true
                    }

                    Button {
                        saveToPhotos()
                    } label: {
                        Label("Télécharger", systemImage: "arrow.down.to.line")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 13)
                            .frame(height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if let statusText {
                    Text(statusText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.72))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSharing) {
            SarahShareSheet(items: [image])
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func viewerButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    showStatus("Autorisation Photos refusée")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                DispatchQueue.main.async {
                    showStatus(success ? "Image enregistrée dans Photos" : "Échec de l’enregistrement")
                }
            }
        }
    }

    private func showStatus(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            statusText = text
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.18)) {
                statusText = nil
            }
        }
    }
}

@available(iOS 15.0, *)
private struct SarahShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Vue SwiftUI pour Carte d'Alerte Interactive avec WebView & Plans
@available(iOS 14.0, *)
public struct AlertCardSwiftUIView: View {
    public let alert: AlertEvent
    @State private var isShowingFullMap: Bool = false
    
    public var body: some View {
        ZStack {
            AlertCardWebRepresentable(alert: alert)
            
            // Bouton invisible pour ouvrir la carte complète au toucher
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isShowingFullMap = true
                    }) {
                        Text("📍 Agrandir la carte")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(8)
                    }
                    .padding(8)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingFullMap) {
            AlertMapRepresentable(alert: alert)
                .ignoresSafeArea()
        }
    }
}

@available(iOS 14.0, *)
public struct AlertCardWebRepresentable: UIViewRepresentable {
    public let alert: AlertEvent
    
    public func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        let html = AlertCardRenderer.shared.renderAlertHTML(for: alert)
        wv.loadHTMLString(html, baseURL: nil)
        return wv
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@available(iOS 14.0, *)
public struct AlertMapRepresentable: UIViewControllerRepresentable {
    public let alert: AlertEvent
    
    public func makeUIViewController(context: Context) -> AlertMapViewController {
        return AlertMapViewController(alert: alert)
    }
    
    public func updateUIViewController(_ uiViewController: AlertMapViewController, context: Context) {}
}

// MARK: - Preview

@available(iOS 15.0, *)
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ChatBubbleView(message: Message(content: "Bonjour Sarah !", isFromUser: true))
            ChatBubbleView(
                message: Message(content: "Bonjour ! Je suis Sarah, comment puis-je vous aider ?", isFromUser: false),
                isSpeaking: true
            )
            ChatBubbleView(
                message: Message(content: "Voici votre réponse personnalisée.", isFromUser: false),
                isSpeaking: false
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
