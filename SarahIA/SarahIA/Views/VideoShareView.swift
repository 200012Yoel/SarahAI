import SwiftUI
import PhotosUI
import AVKit

/// Sélecteur de vidéo utilisant PHPickerViewController (iOS 14.0+)
@available(iOS 14.0, *)
public struct VideoPickerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Binding var thumbnailImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    public init(selectedVideoURL: Binding<URL?>, thumbnailImage: Binding<UIImage?>) {
        self._selectedVideoURL = selectedVideoURL
        self._thumbnailImage = thumbnailImage
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerRepresentable
        
        init(_ parent: VideoPickerRepresentable) {
            self.parent = parent
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.hasItemConformingToTypeIdentifier("public.movie") {
                provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                    guard let url = url else { return }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    
                    let asset = AVURLAsset(url: tempURL)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    let time = CMTime(seconds: 1.0, preferredTimescale: 60)
                    let image: UIImage? = (try? generator.copyCGImage(at: time, actualTime: nil)).map { UIImage(cgImage: $0) }
                    
                    DispatchQueue.main.async {
                        self.parent.selectedVideoURL = tempURL
                        self.parent.thumbnailImage = image
                    }
                }
            }
        }
    }
}

/// Vue de partage de vidéo dans Sarah IA (iOS 14.0+)
@available(iOS 14.0, *)
public struct VideoShareView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var selectedVideoURL: URL? = nil
    @State private var thumbnailImage: UIImage? = nil
    @State private var messageText: String = ""
    @State private var isSharing: Bool = false
    @State private var shareSuccess: Bool = false
    @State private var showPlayer: Bool = false
    @State private var showPicker: Bool = false
    
    // Réseaux sociaux connectés
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
                        // 1. Zone de sélection de vidéo
                        Button(action: {
                            showPicker = true
                        }) {
                            if let thumb = thumbnailImage {
                                ZStack(alignment: .bottomLeading) {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    
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
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(red: 0.10, green: 0.14, blue: 0.12))
                                        .frame(height: 160)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.green.opacity(0.6), Color.blue.opacity(0.4)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                                )
                                        )
                                    
                                    VStack(spacing: 10) {
                                        Image(systemName: "video.badge.plus")
                                            .font(.system(size: 36))
                                            .foregroundColor(.green)
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
                        .buttonStyle(PlainButtonStyle())
                        
                        // 2. Champ de description
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Message ou description")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            TextField("Ex : Super moment en famille ! 🌟", text: $messageText)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundColor(.white)
                        }
                        
                        // 3. Réseaux cibles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Destinations de partage")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            networkToggle(name: "WhatsApp Statut & Chat", icon: "bubble.left.and.bubble.right.fill", color: .green, isOn: $shareToWhatsApp)
                            networkToggle(name: "Instagram Reels & Story", icon: "camera.fill", color: .purple, isOn: $shareToInstagram)
                            networkToggle(name: "TikTok", icon: "music.note", color: .pink, isOn: $shareToTikTok)
                            networkToggle(name: "YouTube Shorts", icon: "play.rectangle.fill", color: .red, isOn: $shareToYouTube)
                            networkToggle(name: "Twitter / X", icon: "bubble.left.fill", color: .blue, isOn: $shareToTwitter)
                        }
                        
                        // 4. Bouton Partager
                        Button(action: shareVideo) {
                            HStack(spacing: 8) {
                                if isSharing {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text(shareSuccess ? "Partagé !" : "Publier la vidéo")
                                }
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                selectedVideoURL == nil
                                ? Color.gray.opacity(0.3)
                                : Color(red: 0.15, green: 0.75, blue: 0.45)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(selectedVideoURL == nil || isSharing)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("📹 Partager une Vidéo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color.green)
                }
            }
            .sheet(isPresented: $showPicker) {
                VideoPickerRepresentable(selectedVideoURL: $selectedVideoURL, thumbnailImage: $thumbnailImage)
            }
        }
    }
    
    private func networkToggle(name: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 26)
            
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func shareVideo() {
        guard let videoURL = selectedVideoURL else { return }
        isSharing = true
        
        let networksList = [
            shareToWhatsApp ? "WhatsApp" : nil,
            shareToInstagram ? "Instagram" : nil,
            shareToTikTok ? "TikTok" : nil,
            shareToYouTube ? "YouTube" : nil,
            shareToTwitter ? "Twitter/X" : nil
        ].compactMap { $0 }.joined(separator: ", ")
        
        let chatMessage = messageText.isEmpty
            ? "📹 Vidéo partagée sur : \(networksList.isEmpty ? "aucun réseau" : networksList)"
            : "📹 \"\(messageText)\" — Partagé sur : \(networksList.isEmpty ? "aucun réseau" : networksList)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSharing = false
            shareSuccess = true
            viewModel.sendMessage(chatMessage)
            
            var rootVC: UIViewController? = nil
            if #available(iOS 13.0, *) {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
                }
            } else {
                rootVC = UIApplication.shared.keyWindow?.rootViewController
            }
            
            if let rootVC = rootVC {
                let activityVC = UIActivityViewController(
                    activityItems: [videoURL, messageText.isEmpty ? "Partagé via Sarah IA" : messageText],
                    applicationActivities: nil
                )
                rootVC.present(activityVC, animated: true)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
