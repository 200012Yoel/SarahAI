import SwiftUI

/// Vue Interactive de Gestion de la Passerelle WhatsApp Locale & QR Code
@available(iOS 14.0, *)
public struct WhatsAppGatewayView: View {
    @ObservedObject var gateway = WhatsAppGatewayManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var testPhoneNumber: String = ""
    @State private var testMessageText: String = "Bonjour depuis Sarah IA !"
    @State private var isShowingTestAlert: Bool = false
    @State private var alertMessage: String = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Barre de navigation supérieure
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
                            Text("Passerelle WhatsApp Locale")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Badge Baileys WebSocket
                            Text("Baileys WS")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        Text("100% Autonome sur l'iPhone · Sans Serveur Cloud")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticService.shared.buttonTap()
                        gateway.reloadGateway()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.sarahCyan)
                            .padding(8)
                            .background(Color.sarahCyan.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                
                // 2. Contenu Scrollable
                ScrollView {
                    VStack(spacing: 18) {
                        // A. Carte de Statut & QR Code
                        statusAndQRCodeSection
                        
                        // B. Paramètres d'Automatisation IA
                        automationSettingsSection
                        
                        // C. Console de Test d'Envoi Direct
                        if gateway.status.isConnected {
                            testSenderSection
                        }
                        
                        // D. Statistiques d'Activité
                        activityStatsSection
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            if gateway.status == .disconnected {
                gateway.startGateway()
            }
        }
        .alert(isPresented: $isShowingTestAlert) {
            Alert(title: Text("WhatsApp Passerelle"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Section Statut & QR Code
    private var statusAndQRCodeSection: some View {
        VStack(spacing: 14) {
            // Statut Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                Text(statusText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if gateway.status.isConnected {
                    Text("Session Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.15))
                        .cornerRadius(6)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Affichage du QR Code ou de la session connectée
            if case .connected(let phone, let name) = gateway.status {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.15))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                    }
                    
                    Text("Connecté à WhatsApp")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Numéro : +\(phone)\nNom : \(name)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        HapticService.shared.buttonTap()
                        gateway.logoutAndReset()
                    }) {
                        Text("Déconnecter cette session")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 10)
            } else if let qr = gateway.qrImage {
                VStack(spacing: 12) {
                    Text("Scannez ce QR Code avec WhatsApp")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Conteneur QR avec bordure néon
                    Image(uiImage: qr)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(10)
                        .background(Color.black)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.15, green: 0.72, blue: 1.0), lineWidth: 2)
                        )
                        .shadow(color: Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.3), radius: 10)
                    
                    VStack(spacing: 4) {
                        Text("1. Ouvrez WhatsApp sur votre téléphone")
                        Text("2. Allez dans Réglages > Appareils connectés")
                        Text("3. Touchez « Connecter un appareil » et scannez")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .sarahCyan))
                        .scaleEffect(1.3)
                    
                    Text("Génération des clés de session locales...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Section Automatisation
    private var automationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUTOMATISATION INTELLIGENTE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.sarahCyan)
            
            Toggle(isOn: $gateway.isAutoReplyEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Réponse Automatique par Sarah & Nathan")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Sarah infère en local et répond instantanément aux messages reçus")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .sarahCyan))
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                Text("Stockage sécurisé des clés dans Documents/WhatsAppAuth/")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Section Test d'Envoi
    private var testSenderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEST D'ENVOI DIRECT DEPUIS L'IPHONE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
            
            TextField("Numéro du destinataire (ex: 33612345678)", text: $testPhoneNumber)
                .font(.system(size: 13))
                .padding(10)
                .background(Color(white: 0.16))
                .cornerRadius(8)
                .foregroundColor(.white)
                .keyboardType(.phonePad)
            
            TextField("Message à envoyer", text: $testMessageText)
                .font(.system(size: 13))
                .padding(10)
                .background(Color(white: 0.16))
                .cornerRadius(8)
                .foregroundColor(.white)
            
            Button(action: {
                let cleanPhone = testPhoneNumber.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " ", with: "")
                guard !cleanPhone.isEmpty else {
                    alertMessage = "Veuillez entrer un numéro valide"
                    isShowingTestAlert = true
                    return
                }
                let jid = cleanPhone.contains("@") ? cleanPhone : "\(cleanPhone)@s.whatsapp.net"
                gateway.sendMessage(to: jid, text: testMessageText)
                HapticService.shared.buttonTap()
                alertMessage = "Message transmis au socket WhatsApp !"
                isShowingTestAlert = true
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "paperplane.fill")
                    Text("Envoyer sur WhatsApp")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .background(Color(red: 0.15, green: 0.72, blue: 1.0))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Section Statistiques
    private var activityStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITÉ DE LA PASSERELLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack {
                Text("Messages traités :")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(gateway.processedMessagesCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            if let last = gateway.lastMessageReceivedText {
                HStack(alignment: .top) {
                    Text("Dernier message :")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(last)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers Visuels
    private var statusColor: Color {
        switch gateway.status {
        case .connected:
            return Color(red: 0.15, green: 0.85, blue: 0.40)
        case .qrReady:
            return Color(red: 0.15, green: 0.72, blue: 1.0)
        case .initializing, .reconnecting:
            return Color.orange
        case .disconnected, .error:
            return Color.red
        }
    }
    
    private var statusText: String {
        switch gateway.status {
        case .connected(let phone, _):
            return "Connecté (+ \((phone)))"
        case .qrReady:
            return "QR Code Prêt pour Connexion"
        case .initializing:
            return "Initialisation du Socket..."
        case .reconnecting(let attempt):
            return "Reconnexion (tentative \(attempt))..."
        case .disconnected:
            return "Déconnecté"
        case .error(let err):
            return "Erreur: \(err)"
        }
    }
}
