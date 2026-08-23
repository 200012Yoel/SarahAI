import SwiftUI

/// Vue SwiftUI de Synchronisation & Transfert par QR Code (P2P Local) :
/// Permet de partager instantanément toutes ses discussions et ses souvenirs entre 2 iPhone via un QR Code.
@available(iOS 14.0, *)
public struct LocalSyncQRView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var qrImage: UIImage? = nil
    @State private var qrURLString: String = ""
    @State private var isServerActive: Bool = false
    @State private var localIP: String = "Recherche..."
    @State private var isScanningMode: Bool = false
    @State private var syncStatusMessage: String? = nil
    @State private var isSuccess: Bool = false
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // En-tête explicatif
                        headerCard
                        
                        // Carte QR Code avec dégradé et cadre néon
                        qrCodeCard
                        
                        // Informations de Connexion Réseau Local
                        networkInfoCard
                        
                        // Boutons d'Action Rapide
                        actionButtons
                        
                        // Message de confirmation / état
                        if let status = syncStatusMessage {
                            statusBanner(text: status, isSuccess: isSuccess)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("📱 Synchronisation QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.sarahCyan)
                }
            }
            .onAppear {
                startLocalSyncServer()
            }
            .onDisappear {
                LocalSyncServerService.shared.stopServer()
            }
            .fullScreenCover(isPresented: $isScanningMode) {
                CameraRepresentable(onPhotoAnalyzed: { image, result in
                    isScanningMode = false
                    // Traitement du résultat de scan
                    if !result.detectedText.isEmpty && (result.detectedText.contains("sarahsync://") || result.detectedText.contains("sarahpayload://") || result.detectedText.contains("sarah://sync")) {
                        handleScannedQRCode(result.detectedText)
                    }
                }, onScreenShare: {
                    isScanningMode = false
                })
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Composants UI
    
    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.sarahCyan.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.sarahCyan)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Transfert P2P Ultra-Rapide")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Scannez ce QR Code avec l'appareil photo Sarah d'un autre iPhone pour transférer toutes vos discussions !")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private var qrCodeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .frame(width: 250, height: 250)
                    .shadow(color: Color.sarahCyan.opacity(0.35), radius: 20, x: 0, y: 8)
                
                if let img = qrImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        Text("Génération du QR Code...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.top, 8)
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isServerActive ? Color.green : Color.yellow)
                    .frame(width: 8, height: 8)
                Text(isServerActive ? "Serveur local actif & prêt à synchroniser" : "Démarrage du serveur...")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isServerActive ? .green : .yellow)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.sarahCyan.opacity(0.3), lineWidth: 1.2))
    }
    
    private var networkInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🌐 Réseau Local Wi-Fi")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Port \(LocalSyncServerService.shared.serverPort)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.sarahCyan)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                Text("Adresse IP :")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text(localIP)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Discussions à transférer :")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(viewModel.conversations.count) discussion(s)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                HapticService.shared.buttonTap()
                isScanningMode = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Scanner un QR Code sur l'autre appareil")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(red: 0.04, green: 0.52, blue: 1.0))
                .cornerRadius(16)
                .shadow(color: Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(ScaleBounceButtonStyle())
            
            Button(action: {
                HapticService.shared.buttonTap()
                startLocalSyncServer()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Régénérer le QR Code")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
            }
        }
    }
    
    @ViewBuilder
    private func statusBanner(text: String, isSuccess: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? .green : .orange)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(14)
        .background(isSuccess ? Color(red: 0.05, green: 0.20, blue: 0.05) : Color(red: 0.20, green: 0.10, blue: 0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSuccess ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1))
    }
    
    // MARK: - Logique Métier
    
    private func startLocalSyncServer() {
        self.localIP = LocalSyncServerService.shared.getLocalIPAddress() ?? "Wi-Fi local"
        LocalSyncServerService.shared.startServer { success, qrString, image in
            self.isServerActive = success
            self.qrURLString = qrString ?? ""
            self.qrImage = image
        }
    }
    
    private func handleScannedQRCode(_ scannedCode: String) {
        syncStatusMessage = "⚡ Synchronisation en cours..."
        isSuccess = false
        
        LocalSyncServerService.shared.performSync(with: scannedCode) { success, message in
            self.isSuccess = success
            self.syncStatusMessage = message
            
            if success {
                HapticService.shared.notificationSuccess()
                viewModel.restorePersistedState()
                SpeechManager.shared.speak(text: "Synchronisation terminée avec succès ! Vos discussions ont été transférées.")
            } else {
                HapticService.shared.bargeIn()
            }
        }
    }
}
