import SwiftUI
import WebKit
import SceneKit

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
    @State private var sceneWidth: Double = 8
    @State private var sceneLength: Double = 10
    @State private var sceneFloors: Double = 2
    @State private var sceneFloorHeight: Double = 2.7
    
    enum StudioTab {
        case preview
        case editor
        case shortcuts
        case scene3D
        case cloudDeploy
    }
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    private var isWebPreviewAvailable: Bool {
        let lowercased = codeText.lowercased()
        return lowercased.contains("<!doctype html") || lowercased.contains("<html")
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
                        
                        Text(isWebPreviewAvailable ? "Prévisualisation web locale" : "Code source local")
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
                    Text("🧊 3D").tag(StudioTab.scene3D)
                    Text("🚀 Cloud & Déploiement").tag(StudioTab.cloudDeploy)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // 3. Contenu de l'Onglet Actif
                if selectedTab == .preview {
                    if isWebPreviewAvailable {
                        // Prévisualisation Live WebKit réservée aux projets HTML.
                        VAIWebViewRepresentable(htmlContent: codeText)
                            .cornerRadius(16)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .shadow(color: Color.black.opacity(0.5), radius: 10)
                    } else {
                        nonWebPreviewPlaceholder
                    }
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
                } else if selectedTab == .scene3D {
                    scene3DTabContent
                } else {
                    // Déploiement en Ligne, GitHub, Gmail & Play Console
                    cloudDeployTabContent
                }
                
                // 4. Barre d'Actions Inférieure
                HStack(spacing: 8) {
                    Button(action: {
                        if viewModel.websiteDraft != nil {
                            presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                viewModel.isShowingWebsiteBuilder = true
                            }
                        } else {
                            startSampleStreaming(prompt: "dashboard")
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.websiteDraft == nil ? "sparkles" : "slider.horizontal.3")
                            Text(viewModel.websiteDraft == nil ? "Générer" : "Améliorer")
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
                            Text("Préparer")
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
                if !isWebPreviewAvailable {
                    selectedTab = .editor
                }
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

    private var nonWebPreviewPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
            Text("Ce projet est prêt en code source")
                .font(.headline)
                .foregroundColor(.white)
            Text("La prévisualisation intégrée est réservée aux pages web. Pour SwiftUI ou Python, ouvre le code source puis demande à Raphaël les améliorations souhaitées.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button(action: {
                selectedTab = .editor
            }) {
                Text("Voir le code source")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.15, green: 0.52, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
    
    // MARK: - Studio 3D paramétrique

    private var scene3DTabContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VAI3DPreviewRepresentable(
                    width: sceneWidth,
                    length: sceneLength,
                    floors: max(1, Int(sceneFloors.rounded())),
                    floorHeight: sceneFloorHeight
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .sarahLiquidGlass(cornerRadius: 18, tint: Color(red: 0.15, green: 0.72, blue: 1.0), intensity: 0.08)

                VStack(spacing: 12) {
                    parameterSlider(title: "Largeur", value: $sceneWidth, range: 3...25, suffix: "m")
                    parameterSlider(title: "Longueur", value: $sceneLength, range: 3...35, suffix: "m")
                    parameterSlider(title: "Étages", value: $sceneFloors, range: 1...5, step: 1, suffix: "")
                    parameterSlider(title: "Hauteur sous plafond", value: $sceneFloorHeight, range: 2.2...4.5, step: 0.1, suffix: "m")
                }
                .padding(14)
                .sarahLiquidGlass(cornerRadius: 18, tint: Color(red: 0.15, green: 0.72, blue: 1.0), intensity: 0.06)

                Button(action: send3DBriefToRaphael) {
                    HStack {
                        Image(systemName: "cube.transparent")
                        Text("Envoyer le brief 3D à Raphaël")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color(red: 0.15, green: 0.72, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
        }
    }

    private func parameterSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.5,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text((step < 1
                ? String(format: "%.1f", value.wrappedValue)
                : String(format: "%.0f", value.wrappedValue)) + suffix)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray)
            }
            Slider(value: value, in: range, step: step)
                .tint(Color(red: 0.15, green: 0.72, blue: 1.0))
        }
    }

    private func send3DBriefToRaphael() {
        HapticService.shared.buttonTap()
        let floors = max(1, Int(sceneFloors.rounded()))
        let prompt = """
        Raphaël, crée une scène 3D paramétrique éditable avec ce brief :
        - largeur : \(String(format: "%.1f", sceneWidth)) m
        - longueur : \(String(format: "%.1f", sceneLength)) m
        - étages : \(floors)
        - hauteur sous plafond : \(String(format: "%.1f", sceneFloorHeight)) m
        Commence par confirmer les paramètres manquants utiles (pièces, ouvertures, matériaux, éclairage et style), puis génère une structure exploitable par le Studio 3D.
        """
        viewModel.activeAgent = .esther
        viewModel.sendMessage(prompt)
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
                    Text("📦 Publication & intégrations développeur")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Raphaël prépare le fichier localement. Une publication réelle nécessite ensuite un dépôt ou un hébergeur connecté.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // 1. Préparation locale, sans fausse promesse d'URL publique
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
                            Text("Préparer pour publication")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Enregistre le fichier avant une vraie publication GitHub ou hébergeur")
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

/// Aperçu SceneKit local du brief 3D. Il reste volontairement paramétrique :
/// l'interface HTML future pourra piloter les mêmes dimensions sans changer la logique Raphaël.
@available(iOS 14.0, *)
public struct VAI3DPreviewRepresentable: UIViewRepresentable {
    public var width: Double
    public var length: Double
    public var floors: Int
    public var floorHeight: Double

    public init(width: Double, length: Double, floors: Int, floorHeight: Double) {
        self.width = width
        self.length = length
        self.floors = floors
        self.floorHeight = floorHeight
    }

    public func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        return view
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        let scene = SCNScene()
        let root = scene.rootNode

        let safeWidth = max(3.0, width)
        let safeLength = max(3.0, length)
        let safeFloors = max(1, floors)
        let safeHeight = max(2.2, floorHeight)
        let wallThickness = 0.12

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        material.roughness.contents = 0.62

        let accent = SCNMaterial()
        accent.diffuse.contents = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.95)
        accent.roughness.contents = 0.38

        for floor in 0..<safeFloors {
            let baseY = Double(floor) * safeHeight

            let slab = SCNBox(width: safeWidth, height: 0.14, length: safeLength, chamferRadius: 0.04)
            slab.materials = [floor == 0 ? material : accent]
            let slabNode = SCNNode(geometry: slab)
            slabNode.position = SCNVector3(0, Float(baseY), 0)
            root.addChildNode(slabNode)

            let wallH = safeHeight - 0.15
            let frontBack = SCNBox(width: safeWidth, height: wallH, length: wallThickness, chamferRadius: 0.03)
            frontBack.materials = [material]
            for z in [-safeLength / 2, safeLength / 2] {
                let node = SCNNode(geometry: frontBack.copy() as? SCNGeometry)
                node.position = SCNVector3(0, Float(baseY + safeHeight / 2), Float(z))
                root.addChildNode(node)
            }

            let side = SCNBox(width: wallThickness, height: wallH, length: safeLength, chamferRadius: 0.03)
            side.materials = [material]
            for x in [-safeWidth / 2, safeWidth / 2] {
                let node = SCNNode(geometry: side.copy() as? SCNGeometry)
                node.position = SCNVector3(Float(x), Float(baseY + safeHeight / 2), 0)
                root.addChildNode(node)
            }
        }

        let roof = SCNBox(width: safeWidth + 0.18, height: 0.18, length: safeLength + 0.18, chamferRadius: 0.05)
        roof.materials = [accent]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, Float(Double(safeFloors) * safeHeight), 0)
        root.addChildNode(roofNode)

        let camera = SCNCamera()
        camera.fieldOfView = 48
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        let extent = max(safeWidth, safeLength)
        cameraNode.position = SCNVector3(Float(extent * 1.15), Float(Double(safeFloors) * safeHeight * 0.85 + 2), Float(extent * 1.35))
        cameraNode.look(at: SCNVector3(0, Float(Double(safeFloors) * safeHeight * 0.45), 0))
        root.addChildNode(cameraNode)

        let key = SCNLight()
        key.type = .omni
        key.intensity = 900
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(6, 10, 8)
        root.addChildNode(keyNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 480
        ambient.color = UIColor(white: 0.72, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        uiView.scene = scene
        uiView.pointOfView = cameraNode
    }
}
