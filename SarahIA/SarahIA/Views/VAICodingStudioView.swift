import SwiftUI
import WebKit

/// Studio Raphaël volontairement minimal :
/// - Code : affiche et permet d'éditer le HTML/CSS/JS généré.
/// - Vision : affiche exactement le rendu WebKit de ce code.
/// Aucun générateur de secours ni menu annexe n'est présent ici.
@available(iOS 14.0, *)
public struct VAICodingStudioView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var codeText: String = ""
    @State private var selectedTab: StudioTab = .code

    private enum StudioTab: String {
        case code
        case vision
    }

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    private var hasHTML: Bool {
        let lower = codeText.lowercased()
        return (lower.contains("<!doctype html") || lower.contains("<html")) &&
            lower.contains("<body") && lower.contains("</html>")
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabSwitcher
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Group {
                    if selectedTab == .code {
                        codeView
                    } else {
                        visionView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            codeText = viewModel.vaiCurrentCode ?? ""
            selectedTab = hasHTML ? .vision : .code
        }
        .onReceive(viewModel.$vaiCurrentCode) { newCode in
            guard let newCode = newCode,
                  !newCode.isEmpty,
                  newCode != codeText else { return }
            codeText = newCode
        }
        .onDisappear {
            persistEditedCode()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticService.shared.buttonTap()
                persistEditedCode()
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Raphaël")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(hasHTML ? "Site généré" : "Aucun site généré")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(hasHTML ? Color.green.opacity(0.85) : Color.white.opacity(0.38))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 6) {
            tabButton(.code, title: "Code", icon: "chevron.left.forwardslash.chevron.right")
            tabButton(.vision, title: "Vision", icon: "eye.fill")
        }
        .padding(5)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func tabButton(_ tab: StudioTab, title: String, icon: String) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
            if tab == .vision {
                persistEditedCode()
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(selectedTab == tab ? Color.white.opacity(0.13) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(tab == .vision && !hasHTML)
        .opacity(tab == .vision && !hasHTML ? 0.36 : 1)
    }

    private var codeView: some View {
        Group {
            if codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyState(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "Pas encore de code",
                    subtitle: "Quand Raphaël aura réellement généré un site, son fichier HTML apparaîtra ici."
                )
            } else {
                TextEditor(text: $codeText)
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.69, green: 0.95, blue: 0.77))
                    .padding(12)
                    .background(Color(red: 0.035, green: 0.038, blue: 0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
    }

    private var visionView: some View {
        Group {
            if hasHTML {
                VAIWebViewRepresentable(htmlContent: codeText)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                emptyState(
                    icon: "eye.slash",
                    title: "Aucun rendu",
                    subtitle: "Vision ne montre rien tant qu'un vrai document HTML n'a pas été généré."
                )
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.white.opacity(0.62))

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func persistEditedCode() {
        let clean = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        viewModel.vaiCurrentCode = codeText
        _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: codeText)
    }
}

/// Prévisualisation WebKit du fichier généré. Aucun contenu par défaut n'est injecté.
@available(iOS 14.0, *)
public struct VAIWebViewRepresentable: UIViewRepresentable {
    public var htmlContent: String

    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
