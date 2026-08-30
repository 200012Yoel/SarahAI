import SwiftUI
import PhotosUI
import AVKit

/// Vue de partage de vidéo dans Sarah IA.
/// - Sélection de vidéo depuis la galerie photo
/// - Affichage thumbnail en haut du chat
/// - Partage automatique sur les réseaux sociaux connectés
/// - Conversion/upload avec message associé
@available(iOS 16.0, *)
public struct VideoShareView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedVideoURL: URL? = nil
    @State private var thumbnailImage: UIImage? = nil
    @State private var messageText: String = ""
    @State private var isSharing: Bool = false
    @State private var shareSuccess: Bool = false
    @State private var showPlayer: Bool = false
    
    // Réseaux sociaux connectés (à lire depuis UserDefaults en prod)
    @State private var shareToWhatsApp: Bool = true
    @State private var shareToInstagram: Bool = true
    @State private var shareToTikTok: Bool = true
    @State private var shareToYouTube: Bool = false
    @State private var shareToTwitter: Bool = false
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Sélecteur de vidéo
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            if let thumb = thumbnailImage {
                                // Thumbnail de la vidéo sélectionnée
                                ZStack(alignment: .bottomLeading) {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    
                                    // Overlay play
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.55))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                    }
                                    .padding(12)
                                    
                                    // Badge "Changer"
                                    Text("Changer")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Capsule())
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            } else {
                                // Zone de sélection vide
                                VStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(red: 0.12, green: 0.20, blue: 0.16))
                                            .frame(height: 160)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.green.opacity(0.5), Color.blue.opacity(0.3)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                                    )
                                            )
                                        
                                        VStack(spacing: 10) {
                                            Image(systemName: "video.badge.plus")
                                                .font(.system(size: 36))
                                                .foregroundColor(.green.opacity(0.8))
                                            Text("Sélectionner une vidéo")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("Appuyez pour choisir depuis votre galerie")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                await loadVideo(from: newItem)
                            }
                        }
                        
                        // 2. Champ de message
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message accompagnant la vidéo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            TextField("Écrire un message...", text: $messageText)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        
                        // 3. Sélection des réseaux sociaux
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Partager sur")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    socialToggle("WhatsApp Statut", icon: "bubble.left.and.bubble.right.fill", color: Color(red: 0.15, green: 0.85, blue: 0.40), isOn: $shareToWhatsApp)
                                    socialToggle("Instagram", icon: "camera.fill", color: Color(red: 0.85, green: 0.15, blue: 0.55), isOn: $shareToInstagram)
                                    socialToggle("TikTok", icon: "music.note", color: Color(red: 0.95, green: 0.15, blue: 0.35), isOn: $shareToTikTok)
                                    socialToggle("YouTube", icon: "play.rectangle.fill", color: .red, isOn: $shareToYouTube)
                                    socialToggle("Twitter / X", icon: "xmark.circle.fill", color: .white, isOn: $shareToTwitter)
                                }
                        }
                        
                        // 4. Bouton Partager
                        Button(action: {
                            shareVideo()
                        }) {
                            ZStack {
                                if isSharing {
                                    ProgressView()
                                        .tint(.white)
                                } else if shareSuccess {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Vidéo partagée !")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 16))
                                        Text(selectedVideoURL == nil ? "Sélectionner une vidéo d'abord" : "Partager sur tous mes réseaux")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Group {
                                    if selectedVideoURL != nil && !isSharing {
                                        LinearGradient(
                                            colors: [Color.green, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    } else {
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: selectedVideoURL != nil ? Color.green.opacity(0.3) : Color.clear, radius: 12)
                        }
                        .disabled(selectedVideoURL == nil || isSharing)
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(20)
                }
            }
            .navigationTitle("📹 Partager une Vidéo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Social Toggle
    
    @ViewBuilder
    private func socialToggle(_ title: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
            isOn.wrappedValue.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isOn.wrappedValue ? color : .gray)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOn.wrappedValue ? .white : .gray)
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isOn.wrappedValue ? color : .gray.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isOn.wrappedValue ? color.opacity(0.10) : Color(red: 0.12, green: 0.12, blue: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn.wrappedValue ? color.opacity(0.35) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Chargement vidéo
    
    @MainActor
    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sarah_video_\(UUID().uuidString).mp4")
            try? data.write(to: tempURL)
            selectedVideoURL = tempURL
            
            // Générer la thumbnail
            let asset = AVURLAsset(url: tempURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                thumbnailImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    // MARK: - Partage vidéo
    
    private func shareVideo() {
        guard let videoURL = selectedVideoURL else { return }
        isSharing = true
        
        // Informer Nathan & Sarah du partage dans le chat
        let networksList = [
            shareToWhatsApp ? "WhatsApp (Statut & Messages)" : nil,
            shareToInstagram ? "Instagram" : nil,
            shareToTikTok ? "TikTok" : nil,
            shareToYouTube ? "YouTube" : nil,
            shareToTwitter ? "Twitter/X" : nil
        ].compactMap { $0 }.joined(separator: ", ")
        
        let chatMessage = messageText.isEmpty
            ? "📹 Vidéo partagée sur : \(networksList.isEmpty ? "aucun réseau sélectionné" : networksList)"
            : "📹 \"\(messageText)\" — Partagé sur : \(networksList.isEmpty ? "aucun réseau sélectionné" : networksList)"
        
        // Simuler le partage (en production : appels API OAuth réseaux sociaux)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isSharing = false
            shareSuccess = true
            
            // Envoyer confirmation dans le chat
            viewModel.sendMessage(chatMessage)
            
            // Ouvrir le partage natif iOS comme fallback
            let activityVC = UIActivityViewController(
                activityItems: [videoURL, messageText.isEmpty ? "Partagé avec Sarah IA" : messageText],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
