import SwiftUI
import WebKit

/// Studio "VAI Coding" avec streaming direct token par token, prévisualisation interactive WKWebView,
/// ingestion de maquettes Figma/Google Stitch et exportateur de raccourcis Apple (.shortcut).
@available(iOS 14.0, *)
public struct VAICodingStudioView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var codeText: String = ""
    @State private var selectedTab: StudioTab = .preview
    @State private var projectTitle: String = "Composant VAI"
    @State private var isStreaming: Bool = false
    @State private var streamTimer: Timer?
    @State private var isShowingExportAlert: Bool = false
    @State private var exportMessage: String = ""
    @State private var figmaTokensInput: String = ""
    @State private var isShowingFigmaSheet: Bool = false
    
    enum StudioTab {
        case preview
        case editor
        case shortcuts
        case cloudDeploy
    }
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Topbar du Studio VAI Coding
                HStack(spacing: 12) {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Studio VAI Coding")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Badge Raphaël
                            HStack(spacing: 3) {
                                Circle().fill(Color(red: 0.15, green: 0.72, blue: 1.0)).frame(width: 6, height: 6)
                                Text("Raphaël Engine")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.15))
                            .cornerRadius(6)
                        }
                        
                        Text("Documents/VAI_Workspace/index.html")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Bouton Ingestion Figma / Tokens
                    Button(action: {
                        HapticService.shared.buttonTap()
                        isShowingFigmaSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                            Text("Figma / Stitch")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.25))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // 2. Sélecteur d'Onglets (Rendu Live / Éditeur Code / Raccourcis Apple / Déploiement Cloud)
                Picker("", selection: $selectedTab) {
                    Text("🌐 Rendu Live").tag(StudioTab.preview)
                    Text("💻 Code Source").tag(StudioTab.editor)
                    Text("⚡ Raccourcis").tag(StudioTab.shortcuts)
                    Text("🚀 Cloud & Déploiement").tag(StudioTab.cloudDeploy)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // 3. Contenu de l'Onglet Actif
                if selectedTab == .preview {
                    // Prévisualisation Live WebKit
                    VAIWebViewRepresentable(htmlContent: codeText)
                        .cornerRadius(16)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .shadow(color: Color.black.opacity(0.5), radius: 10)
                } else if selectedTab == .editor {
                    // Éditeur de Code avec Streaming
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Éditeur Monopage (HTML/CSS/JS)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            if isStreaming {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Génération en cours...")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        TextEditor(text: $codeText)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.6))
                            .background(Color(red: 0.03, green: 0.03, blue: 0.04))
                            .cornerRadius(12)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                } else if selectedTab == .shortcuts {
                    // Compilateur & Exportateur Apple Shortcuts (.shortcut)
                    shortcutsTabContent
                } else {
                    // Déploiement en Ligne, GitHub, Gmail & Play Console
                    cloudDeployTabContent
                }
                
                // 4. Barre d'Actions Inférieure
                HStack(spacing: 8) {
                    Button(action: {
                        startSampleStreaming(prompt: "dashboard")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Générer")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.15, green: 0.72, blue: 1.0))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        deployLiveOnline()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text("Mettre en ligne")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.10, green: 0.80, blue: 0.45))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        openGitHubAuth()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("GitHub")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            }
        }
        .onAppear {
            if let initial = viewModel.vaiCurrentCode, !initial.isEmpty {
                self.codeText = initial
            } else {
                startSampleStreaming(prompt: "dashboard")
            }
        }
        .alert(isPresented: $isShowingExportAlert) {
            Alert(
                title: Text("Exportation Apple Shortcuts"),
                message: Text(exportMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $isShowingFigmaSheet) {
            figmaSheetView
        }
    }
    
    // MARK: - Onglet Raccourcis Apple
    
    private var shortcutsTabContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Générateur de Raccourcis Apple (.shortcut)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Raphaël compile vos actions en flux d'automatisation iOS natifs exportables directement vers l'application Raccourcis.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            VStack(spacing: 12) {
                Button(action: {
                    exportShortcut(title: "Sarah Quick Torch", prompt: "Allumer/Éteindre la torche")
                }) {
                    HStack {
                        Image(systemName: "flashlight.on.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading) {
                            Text("Raccourci Torche Rapide")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Bascule matérielle instantanée")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.9))
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                }
                
                Button(action: {
                    exportShortcut(title: "Sarah Live Translate", prompt: "Traduction instantanée Yohan")
                }) {
                    HStack {
                        Image(systemName: "character.book.closed.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Raccourci Traducteur Yohan")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Traduction FR ⇄ HE depuis le presse-papier")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.9))
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Onglet Déploiement & Cloud (GitHub, Gmail, Google Play)
    
    private var cloudDeployTabContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🚀 Déploiement en Ligne & Intégrations Développeur")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Raphaël met votre projet en ligne immédiatement et le connecte à vos plateformes.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // 1. Bouton Mettre en ligne en 1 clic
                Button(action: {
                    deployLiveOnline()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.10, green: 0.80, blue: 0.45).opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "globe")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.10, green: 0.80, blue: 0.45))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mettre en Ligne Directement (Live URL)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Déploie votre page HTML/CSS/JS sur le Web mondial")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.10, green: 0.80, blue: 0.45))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.10, green: 0.80, blue: 0.45).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                
                // 2. Bouton GitHub
                Button(action: {
                    openGitHubAuth()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Se Connecter à GitHub")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Synchronise vos dépôts distants et commits Git")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 16)
                
                // 3. Bouton Google / Gmail
                Button(action: {
                    openGmail()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Google & Messagerie Gmail")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Accès rapide à votre boîte de réception et alertes")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 16)
                
                // 4. Bouton Google Play Developer Console
                Button(action: {
                    openGooglePlayConsole()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Google Play Console (Développeur)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Publication et gestion des bundles Android")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Feuille d'Ingestion Figma / Stitch
    
    private var figmaSheetView: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text("Collez ici vos Design Tokens exportés (JSON, Figma Variables, Google Stitch) :")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    TextEditor(text: $figmaTokensInput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Button(action: {
                        HapticService.shared.buttonTap()
                        let summary = VAICodeEngine.shared.ingestDesignTokens(jsonString: figmaTokensInput)
                        viewModel.sendMessage(summary)
                        isShowingFigmaSheet = false
                        startSampleStreaming(prompt: "dashboard")
                    }) {
                        Text("Ingérer les Tokens & Coder")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.15, green: 0.72, blue: 1.0))
                            .cornerRadius(14)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
            .navigationTitle("🎨 Ingestion Figma / Stitch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { isShowingFigmaSheet = false }
                }
            }
        }
    }
    
    // MARK: - Streaming Token par Token
    
    private func startSampleStreaming(prompt: String) {
        let fullCode = VAICodeEngine.shared.generateWebUI(prompt: prompt)
        _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: fullCode)
        viewModel.vaiCurrentCode = fullCode
        
        isStreaming = true
        codeText = ""
        streamTimer?.invalidate()
        
        let chars = Array(fullCode)
        var currentIndex = 0
        let chunkSize = 35 // Tokens par frame pour vitesse et fluidité
        
        streamTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { timer in
            if currentIndex < chars.count {
                let nextIndex = min(currentIndex + chunkSize, chars.count)
                let chunk = String(chars[currentIndex..<nextIndex])
                codeText += chunk
                currentIndex = nextIndex
            } else {
                timer.invalidate()
                isStreaming = false
            }
        }
    }
    
    private func exportShortcut(title: String, prompt: String) {
        HapticService.shared.buttonTap()
        let shortcutContent = VAICodeEngine.shared.generateShortcutJSON(name: title, prompt: prompt)
        _ = VAICodeEngine.shared.saveFile(filename: "\(title).json", content: shortcutContent)
        exportMessage = "Raccourci « \(title) » généré avec succès ! Vous pouvez l'importer dans Apple Shortcuts."
        isShowingExportAlert = true
    }
    
    private func deployLiveOnline() {
        HapticService.shared.buttonTap()
        let currentCode = codeText.isEmpty ? (viewModel.vaiCurrentCode ?? VAICodeEngine.shared.generateWebUI(prompt: "dashboard")) : codeText
        let (liveURL, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-Live-App", htmlCode: currentCode)
        exportMessage = status
        isShowingExportAlert = true
    }
    
    private func openGitHubAuth() {
        HapticService.shared.buttonTap()
        let url = VAICodeEngine.shared.getGitHubAuthURL()
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    private func openGmail() {
        HapticService.shared.buttonTap()
        let url = VAICodeEngine.shared.getGoogleMailURL()
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    private func openGooglePlayConsole() {
        HapticService.shared.buttonTap()
        let url = VAICodeEngine.shared.getGooglePlayConsoleURL()
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

/// Wrapper WKWebView pour l'affichage interactif en temps réel du composant web généré
@available(iOS 14.0, *)
public struct VAIWebViewRepresentable: UIViewRepresentable {
    public var htmlContent: String
    
    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
