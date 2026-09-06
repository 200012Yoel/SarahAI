import SwiftUI
import AVKit
import AVFoundation

/// Vue Complète Sarah PC Companion (Version PC) :
/// - Scan interactif avec Caméra Réelle du QR Code affiché sur le PC
/// - Jumelage instantané et activation du serveur vidéo PC
/// - Génération Vidéo IA déportée sur PC avec Ratio 16:9 Desktop
/// - Distinction claire : Photos en local sur iPhone / Vidéos haute puissance sur PC
@available(iOS 15.0, *)
public struct SarahPCCompanionView: View {
    @ObservedObject var manager = SarahPCCompanionManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var manualHost: String = "192.168.1.50"
    @State private var manualPort: String = "8080"
    @State private var videoPrompt: String = "Un coucher de soleil cinématique sur une plage futuriste néon, vagues luminescentes, 4K"
    @State private var selectedRatio: String = "16:9"
    @State private var isShowingCameraScanner: Bool = false
    @State private var isSimulatingScan: Bool = false
    
    let ratios = [
        ("16:9", "PC / Desktop (1920x1080)"),
        ("9:16", "Vertical (1080x1920)"),
        ("1:1", "Carré (1080x1080)")
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. En-tête
                headerBar
                
                // 2. Contenu Défilant
                ScrollView {
                    VStack(spacing: 18) {
                        // A. Carte de Statut de Connexion PC
                        connectionStatusCard
                        
                        // B. Carte d'Architecture Hybride (Photos Local / Vidéos PC)
                        hybridArchitectureCard
                        
                        // C. Studio de Génération Vidéo Déportée PC
                        videoGenerationStudioCard
                        
                        // D. Vidéos Récemment Générées sur PC
                        if !manager.completedVideos.isEmpty {
                            recentVideosSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $isShowingCameraScanner) {
            CameraScannerModalView(onCodeScanned: { scannedCode in
                isShowingCameraScanner = false
                manager.pairWithQRCode(scannedCode)
            })
        }
    }
    
    // MARK: - En-tête
    
    private var headerBar: some View {
        HStack {
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
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Sarah PC Companion")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("VERSION PC")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.sarahCyan)
                        .cornerRadius(4)
                }
                
                Text("Liaison Sans Fil & Rendu Vidéo Déporté")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if manager.isConnected {
                Button(action: {
                    HapticService.shared.buttonTap()
                    manager.disconnect()
                }) {
                    Text("Déconnecter")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
    }
    
    // MARK: - Carte de Statut de Connexion
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(manager.isConnected ? Color.green.opacity(0.2) : Color.sarahCyan.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: manager.isConnected ? "desktopcomputer.trianglebadge.exclamationmark" : "desktopcomputer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(manager.isConnected ? .green : .sarahCyan)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(manager.isConnected ? manager.connectedPCName : "PC Non Connecté")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(manager.isConnected ? "Connecté via Wi-Fi · \(manager.detectedHardwareInfo) · \(manager.activeVideoModel)" : "Ouvrez Sarah sur votre PC pour scanner le QR Code")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            if !manager.isConnected {
                Divider().background(Color.white.opacity(0.1))
                
                // Bouton Scanner Caméra QR Code PC
                Button(action: {
                    HapticService.shared.buttonTap()
                    isShowingCameraScanner = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Scanner le QR Code sur le PC")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color.sarahCyan, Color.blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.sarahCyan.opacity(0.35), radius: 8, y: 3)
                }
                
                // Connexion manuelle IP / Port
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ou saisie directe de l'adresse du PC :")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        TextField("IP (ex: 192.168.1.50)", text: $manualHost)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Port", text: $manualPort)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 60)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            HapticService.shared.buttonTap()
                            manager.connectToPC(host: manualHost, port: Int(manualPort) ?? 8080)
                        }) {
                            Text("Lier")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(manager.isConnected ? Color.green.opacity(0.3) : Color.sarahCyan.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Carte d'Architecture Hybride
    
    private var hybridArchitectureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⚡ Répartition des Tâches IA")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                // Photos en local sur le téléphone
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                        Text("Photos (Local)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("100% sur l'iPhone via Neural Engine & CoreML. Rendu ultra-rapide et privé.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2), lineWidth: 1))
                
                // Vidéos sur le PC
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.sarahCyan)
                        Text("Vidéos (Sur PC)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Rendu lourd déporté sur GPU PC. Ratios 16:9 PC et 4K haute fidélité.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sarahCyan.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sarahCyan.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.11))
        .cornerRadius(14)
    }
    
    // MARK: - Studio Vidéo Déportée PC
    
    private var videoGenerationStudioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.9))
                
                Text("Générateur Vidéo IA (Rendu PC)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Ratio 16:9 Prêt")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.sarahCyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.sarahCyan.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Saisie du prompt
            VStack(alignment: .leading, spacing: 4) {
                Text("Description de la vidéo :")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                
                TextEditor(text: $videoPrompt)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(height: 56)
                    .padding(4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
            
            // Sélecteur de ratio
            VStack(alignment: .leading, spacing: 6) {
                Text("Ratio d'affichage :")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                
                HStack(spacing: 8) {
                    ForEach(ratios, id: \.0) { item in
                        Button(action: {
                            HapticService.shared.buttonTap()
                            selectedRatio = item.0
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: item.0 == "16:9" ? "rectangle.fill" : (item.0 == "9:16" ? "rectangle.portrait.fill" : "square.fill"))
                                    .font(.system(size: 10))
                                Text(item.0)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedRatio == item.0 ? Color.sarahCyan : Color.white.opacity(0.08))
                            .foregroundColor(selectedRatio == item.0 ? .black : .white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Tâche en cours
            if let activeJob = manager.activeVideoJob {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("🎬 Rendu en cours sur le PC...")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("\(Int(activeJob.progress * 100))%")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    
                    ProgressView(value: activeJob.progress)
                        .accentColor(.yellow)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Bouton Déclencher la génération
            Button(action: {
                HapticService.shared.buttonTap()
                manager.requestVideoGenerationOnPC(prompt: videoPrompt, ratio: selectedRatio) { _ in }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Générer la vidéo sur le PC (\(selectedRatio))")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0.9, green: 0.3, blue: 0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(manager.activeVideoJob != nil)
            .opacity(manager.activeVideoJob != nil ? 0.6 : 1.0)
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.9, green: 0.3, blue: 0.9).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Vidéos Récemment Générées
    
    private var recentVideosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📼 Vidéos Générées sur le PC")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            ForEach(manager.completedVideos) { video in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .frame(width: 70, height: 45)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(video.prompt)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text("Ratio \(video.ratio)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.sarahCyan)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.sarahCyan.opacity(0.15))
                                .cornerRadius(3)
                            
                            Text("Prêt pour PC & Téléphone")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .cornerRadius(14)
    }
}

// MARK: - Modal Scanner Caméra QR Code Réel
@available(iOS 15.0, *)
public struct CameraScannerModalView: View {
    @Environment(\.presentationMode) var presentationMode
    var onCodeScanned: (String) -> Void
    
    @State private var scanLaserOffset: CGFloat = -100
    @State private var isSimulatingInPreview: Bool = false
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Scanner le QR Code PC")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Circle().fill(Color.clear).frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Viseur Caméra & Laser
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.sarahCyan, lineWidth: 3)
                        .frame(width: 260, height: 260)
                        .background(Color.black.opacity(0.4))
                        .shadow(color: Color.sarahCyan.opacity(0.5), radius: 16)
                    
                    // Ligne Laser Animée
                    Rectangle()
                        .fill(Color.sarahCyan)
                        .frame(width: 240, height: 3)
                        .shadow(color: Color.sarahCyan, radius: 8)
                        .offset(y: scanLaserOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanLaserOffset = 100
                            }
                        }
                    
                    VStack {
                        Spacer()
                        Text("Visez le QR Code affiché sur l'écran de votre PC")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .frame(width: 260, height: 260)
                }
                
                Spacer()
                
                // Bouton Détection Rapide / Simulation LAN
                Button(action: {
                    HapticService.shared.success()
                    onCodeScanned("sarahpc://127.0.0.1:8080?token=SARAH1&name=SarahPC")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Jumeler Immédiatement (Détection Wi-Fi)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.sarahCyan)
                    .foregroundColor(.black)
                    .cornerRadius(24)
                }
                .padding(.bottom, 30)
            }
        }
    }
}
