import SwiftUI
import WebKit

/// Bulle de message stylisée au format natif iMessage Dark Mode avec bouton de lecture vocale TTS.
@available(iOS 14.0, *)
public struct ChatBubbleView: View {
    public let message: Message
    public var isSpeaking: Bool
    public var onSpeak: (() -> Void)?
    
    public init(
        message: Message,
        isSpeaking: Bool = false,
        isPlayingAudio: Bool = false,
        onSpeak: (() -> Void)? = nil,
        onPlayTapped: (() -> Void)? = nil
    ) {
        self.message = message
        self.isSpeaking = isSpeaking || isPlayingAudio
        self.onSpeak = onSpeak ?? onPlayTapped
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
                    Text(message.content)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
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
                
                // Carte Interactive d'Image Générée (Flux / SDXL / CoreML)
                if let imageURL = message.detectedImageURL {
                    GeneratedImageCardView(imageURLString: imageURL, promptDescription: message.imageGenerationPrompt ?? message.content)
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

@available(iOS 14.0, *)
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
