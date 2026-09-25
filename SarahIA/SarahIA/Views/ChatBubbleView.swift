import SwiftUI
import WebKit

/// Bulle de message native avec actions compactes façon ChatGPT.
@available(iOS 14.0, *)
public struct ChatBubbleView: View {
    public let message: Message
    public var isSpeaking: Bool
    public var onSpeak: (() -> Void)?
    public var onOpenStudio: (() -> Void)?

    public init(
        message: Message,
        isSpeaking: Bool = false,
        isPlayingAudio: Bool = false,
        onSpeak: (() -> Void)? = nil,
        onPlayTapped: (() -> Void)? = nil,
        onOpenStudio: (() -> Void)? = nil
    ) {
        self.message = message
        self.isSpeaking = isSpeaking || isPlayingAudio
        self.onSpeak = onSpeak ?? onPlayTapped
        self.onOpenStudio = onOpenStudio
    }

    public var body: some View {
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
                }
            }
            .padding(.horizontal, message.imageData != nil ? 6 : 16)
            .padding(.vertical, message.imageData != nil ? 6 : 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.12, green: 0.53, blue: 0.98),
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
    }

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image("SarahAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 6) {
                if !message.isVisionReport {
                    let rawContent = message.content
                    let displayContent: String = {
                        if let imgURL = message.detectedImageURL, rawContent.contains(imgURL) {
                            let cleaned = rawContent.replacingOccurrences(of: imgURL, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            return cleaned.isEmpty ? "🎨 Photo Photoréaliste HD en cours de création..." : cleaned
                        }
                        return rawContent
                    }()

                    if !displayContent.isEmpty {
                        Text(displayContent)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                            .lineSpacing(3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.16, green: 0.16, blue: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 19, style: .continuous)
                                    .stroke(
                                        isSpeaking ? Color.sarahCyan.opacity(0.6) : Color.white.opacity(0.08),
                                        lineWidth: isSpeaking ? 1.5 : 0.5
                                    )
                            )
                            .shadow(color: isSpeaking ? Color.sarahCyan.opacity(0.2) : Color.clear, radius: 8)
                    }
                }

                if let imageURL = message.detectedImageURL {
                    GeneratedImageCardView(imageURLString: imageURL, promptDescription: message.imageGenerationPrompt ?? message.content)
                        .frame(maxWidth: 290)
                }

                if let musicStyle = message.detectedMusicStyle {
                    MusicTrackCardView(styleName: musicStyle)
                        .frame(maxWidth: 280)
                }

                if message.isVisionReport {
                    VisionReportCardView(messageContent: message.content)
                        .frame(maxWidth: 280)
                }

                // Un seul rendu web. Plus de choix « iPhone virtuel / WebView ».
                if let htmlCode = message.detectedHTMLCode {
                    ResponsiveHTMLPreviewCardView(htmlContent: htmlCode)
                        .frame(maxWidth: 290)
                }

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

                if let alert = message.alertEvent {
                    AlertCardSwiftUIView(alert: alert)
                        .frame(height: 240)
                        .cornerRadius(14)
                }

                // Heure + lecture à voix haute, compact comme dans ChatGPT.
                HStack(spacing: 8) {
                    Text(message.formattedTime)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.leading, 4)

                    Button(action: { onSpeak?() }) {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSpeaking ? .sarahCyan : .white.opacity(0.75))
                            .frame(width: 30, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSpeaking ? Color.sarahCyan.opacity(0.16) : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .accessibilityLabel(isSpeaking ? "Arrêter la lecture" : "Lire à voix haute")
                }
            }
        }
    }
}

// MARK: - Rendu web unique et responsive

@available(iOS 14.0, *)
private struct ResponsiveHTMLPreviewCardView: View {
    let htmlContent: String
    @State private var isShowingPreview = false
    @State private var isCopied = false

    private var optimizedHTML: String {
        HTMLAdaptiveViewportOptimizer.optimizeHTMLForIPhoneScreen(html: htmlContent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "safari")
                    .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                Text("Rendu responsive")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: copyCode) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isCopied ? .green : .white.opacity(0.75))
                }
                .buttonStyle(BorderlessButtonStyle())
                .accessibilityLabel("Copier le code")
            }

            Text("Un seul aperçu, automatiquement adapté à la largeur de ton iPhone.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.65))

            Button(action: {
                HapticService.shared.buttonTap()
                isShowingPreview = true
            }) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                    Text("Ouvrir le rendu")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(red: 0.15, green: 0.52, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .fullScreenCover(isPresented: $isShowingPreview) {
            ResponsiveHTMLPreviewScreen(htmlContent: optimizedHTML)
        }
    }

    private func copyCode() {
        UIPasteboard.general.string = htmlContent
        HapticService.shared.notificationSuccess()
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}

@available(iOS 14.0, *)
private struct ResponsiveHTMLPreviewScreen: View {
    let htmlContent: String
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    Spacer()
                    Text("Rendu")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                VirtualIPhoneWebViewRepresentable(htmlContent: htmlContent)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// MARK: - Vue SwiftUI pour Carte d'Alerte Interactive avec WebView & Plans

@available(iOS 14.0, *)
public struct AlertCardSwiftUIView: View {
    public let alert: AlertEvent
    @State private var isShowingFullMap: Bool = false

    public var body: some View {
        ZStack {
            AlertCardWebRepresentable(alert: alert)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isShowingFullMap = true }) {
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
        AlertMapViewController(alert: alert)
    }

    public func updateUIViewController(_ uiViewController: AlertMapViewController, context: Context) {}
}

@available(iOS 14.0, *)
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ChatBubbleView(message: Message(content: "Bonjour Sarah !", isFromUser: true))
            ChatBubbleView(
                message: Message(content: "Bonjour ! Je suis Sarah, comment puis-je vous aider ?", isFromUser: false),
                isSpeaking: true
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
