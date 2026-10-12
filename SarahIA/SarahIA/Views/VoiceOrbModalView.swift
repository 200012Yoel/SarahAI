import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

/// Interface vocale Sarah.
/// Pas de bouton X : la vue se réduit ou se ferme naturellement par glissement.
@available(iOS 15.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel

    private let onOpenMenu: () -> Void
    private let onOpenSettings: () -> Void

    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingCamera = false
    @State private var isShowingFileImporter = false

    public init(
        viewModel: ChatViewModel,
        onOpenMenu: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onOpenMenu = onOpenMenu
        self.onOpenSettings = onOpenSettings
    }

    private var accent: Color {
        viewModel.activeAgent.themeColor
    }

    private var normalizedLevel: CGFloat {
        min(max(CGFloat(viewModel.micInputLevel), 0), 1)
    }

    private var statusTitle: String {
        switch viewModel.voiceStatus {
        case .processing:
            if viewModel.isPreparingVoiceReply {
                return "\(viewModel.activeAgent.displayName) prépare sa voix…"
            }
            if viewModel.isTyping {
                return "\(viewModel.activeAgent.displayName) réfléchit…"
            }
            return WhisperService.shared.isModelLoading
                ? "Chargement de Whisper…" : "Transcription en cours…"
        case .starting:
            return "Activation du microphone…"
        case .speaking:
            return "\(viewModel.activeAgent.displayName) parle"
        case .error:
            return "Micro indisponible"
        case .listening:
            return "Je t'écoute"
        case .idle:
            return viewModel.isVoiceMicrophoneMuted || !viewModel.isContinuousConversationActive
                ? "Micro coupé" : "Micro en attente…"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.voiceStatus {
        case .error(let reason):
            return reason
        case .starting:
            return WhisperService.shared.isModelLoading
                ? "Initialisation du modèle Whisper sur l'iPhone…"
                : "Autorise le micro si iOS te le demande."
        case .processing:
            if viewModel.isPreparingVoiceReply {
                return "Génération locale de la réponse audio…"
            }
            if viewModel.isTyping {
                return "Réponse en cours de préparation."
            }
            return WhisperService.shared.isModelLoading
                ? "Le modèle Whisper démarre sur l'iPhone."
                : "Whisper analyse la dernière phrase."
        case .speaking:
            return "\(viewModel.activeAgent.displayName) répond à voix haute."
        case .listening:
            return "Parle normalement, \(viewModel.activeAgent.displayName) écoute."
        case .idle:
            return viewModel.isVoiceMicrophoneMuted
                ? "Touche le micro pour reprendre."
                : "Touche le micro pour parler."
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 430

            ZStack {
                Color(red: 0.006, green: 0.014, blue: 0.041)
                    .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        accent.opacity(compact ? 0.08 : 0.14),
                        accent.opacity(0.025),
                        Color.clear
                    ]),
                    center: compact ? .bottom : .center,
                    startRadius: 40,
                    endRadius: compact ? 260 : 430
                )
                .ignoresSafeArea()

                if compact {
                    compactLayout
                } else {
                    expandedLayout
                }
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { item in
            analyzeSelectedPhoto(item)
        }
        .sheet(isPresented: $isShowingCamera) {
            VoiceCameraPicker { image in
                isShowingCamera = false
                if let image { analyzeCameraImage(image) }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { viewModel.appendImportedFile(url: url) }
            case .failure(let error):
                viewModel.inputText = "Impossible d'ouvrir le fichier : \(error.localizedDescription)"
            }
        }
        .onAppear {
            // Reopening the sheet must not restart speech or unmute the mic.
            if !viewModel.isContinuousConversationActive {
                viewModel.startVoiceConversation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Sarah ne doit jamais conserver une route audio active quand
            // l'utilisateur quitte l'app ou ouvre Siri / un appel.
            viewModel.stopVoiceConversation()
        }
    }

    private func analyzeSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run {
                        viewModel.inputText = "Impossible de lire cette image."
                    }
                    return
                }
                analyzeCameraImage(image)
            } catch {
                await MainActor.run {
                    viewModel.inputText = "Impossible d'ouvrir la photo : \(error.localizedDescription)"
                }
            }
        }
    }

    private func analyzeCameraImage(_ image: UIImage) {
        LocalVisionEngine.shared.recognizeObject(in: image) { result in
            DispatchQueue.main.async {
                viewModel.appendVisionAnalysis(image: image, result: result)
            }
        }
    }

    // MARK: - Grand mode vocal

    private var expandedLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer(minLength: 20)

            orb(size: 292)
                .frame(width: 320, height: 320)

            Spacer(minLength: 22)

            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(viewModel.liveTranscriptionText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                } else {
                    Text(statusSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.46))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minHeight: 76)

            if let voiceError = viewModel.voicePlaybackError {
                Label("Voix neuronale : \(voiceError)", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            if case .error = viewModel.voiceStatus {
                HStack(spacing: 16) {
                    Button("Réessayer") { viewModel.retryVoiceMicrophone() }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                    if AVAudioSession.sharedInstance().recordPermission == .denied {
                        Button("Réglages micro") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
                .font(.subheadline)
                .padding(.top, 8)
            }

            Spacer(minLength: 24)

            composer
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
    }

    // MARK: - Mode réduit quand la feuille est baissée

    private var compactLayout: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)

            orb(size: 86)
                .frame(width: 112, height: 112)

            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.82))
                .lineLimit(1)

            composer
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 14) {
            circleButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                closeVoiceSurface()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    onOpenMenu()
                }
            }

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                closeVoiceSurface()
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(viewModel.activeAgent.displayName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)

                    Text("Réduire · écoute maintenue")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.62))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Réduire le mode vocal sans couper l'écoute")

            Spacer()

            circleButton(systemName: "slider.horizontal.3") {
                HapticService.shared.buttonTap()
                closeVoiceSurface()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    onOpenSettings()
                }
            }
        }
    }

    private func closeVoiceSurface() {
        // Dismiss the sheet only. The ChatScreenView bubble owns explicit Stop.
        // Swipe-to-dismiss, opening the menu and opening settings all preserve
        // the current conversation while Sarah stays in the foreground.
        withAnimation(.easeOut(duration: 0.16)) {
            viewModel.isShowingVoiceOrbModal = false
        }
    }

    // MARK: - Orbe Sarah

    private var isSarahSpeaking: Bool {
        if case .speaking = viewModel.voiceStatus { return true }
        return false
    }

    private func orb(size: CGFloat) -> some View {
        SarahReactiveVoiceOrb(
            diameter: size,
            level: normalizedLevel,
            isSpeaking: isSarahSpeaking,
            isMuted: viewModel.isVoiceMicrophoneMuted,
            accentColor: accent
        )
        .contentShape(Circle())
        .onTapGesture {
            HapticService.shared.buttonTap()
            if viewModel.isContinuousConversationActive {
                // A muted microphone must unmute without resetting an active reply.
                viewModel.toggleMicrophone()
            } else {
                viewModel.startVoiceConversation()
            }
        }
        .accessibilityLabel("Orbe vocal \(viewModel.activeAgent.displayName). " + statusTitle)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Barre inférieure

    private var composer: some View {
        HStack(spacing: 10) {
            Menu {
                Button {
                    HapticService.shared.buttonTap()
                    selectedPhotoItem = nil
                    isShowingPhotoPicker = true
                } label: {
                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                }

                Button {
                    HapticService.shared.buttonTap()
                    isShowingCamera = true
                } label: {
                    Label("Appareil photo", systemImage: "camera")
                }

                Button {
                    HapticService.shared.buttonTap()
                    isShowingFileImporter = true
                } label: {
                    Label("Fichier", systemImage: "doc")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 50, height: 50)
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 50, height: 50)
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")

            HStack(spacing: 10) {
                TextField("Demander à Sarah…", text: $viewModel.inputText)
                    .foregroundColor(.white)
                    .accentColor(accent)
                    .font(.system(size: 16))
                    .submitLabel(.send)
                    .onSubmit {
                        sendTextIfNeeded()
                    }

                Button(action: {
                    HapticService.shared.buttonTap()
                    if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if viewModel.isMicRunning {
                            viewModel.toggleMicrophone()
                        } else {
                            viewModel.startVoiceConversation()
                        }
                    } else {
                        sendTextIfNeeded()
                    }
                }) {
                    Image(systemName: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "waveform" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(accent.opacity(0.11)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.leading, 14)
            .padding(.trailing, 7)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            circleButton(
                systemName: viewModel.isMicRunning ? "mic.fill" : "mic.slash.fill",
                size: 50,
                highlighted: viewModel.isMicRunning
            ) {
                HapticService.shared.buttonTap()
                viewModel.toggleMicrophone()
            }
        }
    }

    private func sendTextIfNeeded() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.sendMessage(text)
    }

    private func circleButton(
        systemName: String,
        size: CGFloat = 48,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(highlighted ? accent.opacity(0.24) : Color.white.opacity(0.10))
                    .frame(width: size, height: size)

                Circle()
                    .stroke(
                        highlighted ? accent.opacity(0.44) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
                    .frame(width: size, height: size)

                Image(systemName: systemName)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(highlighted ? accent : .white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Orbe partagé entre le mode vocal plein écran et la bulle du chat.
/// Écoute et synthèse utilisent le même rendu, mais l'activité vocale est
/// visualisée différemment selon l'état. Aucun arrêt du microphone ici.
@available(iOS 15.0, *)
public struct SarahReactiveVoiceOrb: View {
    public let diameter: CGFloat
    public let level: CGFloat
    public let isSpeaking: Bool
    public let isMuted: Bool
    public let accentColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    public init(diameter: CGFloat, level: CGFloat, isSpeaking: Bool = false, isMuted: Bool = false, accentColor: Color = .blue) {
        self.diameter = diameter
        self.level = level
        self.isSpeaking = isSpeaking
        self.isMuted = isMuted
        self.accentColor = accentColor
    }

    private var activity: CGFloat {
        guard !isMuted else { return 0 }
        return max(min(level, 1), isSpeaking ? 0.45 : 0)
    }

    public var body: some View {
        let core = diameter * 0.73

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(isMuted ? 0.12 : 0.35),
                            accentColor.opacity(0.16),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: core * 0.15,
                        endRadius: diameter * 0.54
                    )
                )
                .frame(width: diameter, height: diameter)
                .blur(radius: diameter * 0.065)

            // La bordure réagit à la voix, même lorsque le texte est en cours
            // de synthèse et que le niveau microphone est momentanément faible.
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.48),
                                accentColor.opacity(0.22),
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, diameter * 0.006)
                    )
                    .frame(
                        width: core + CGFloat(index + 1) * diameter * 0.06,
                        height: core + CGFloat(index + 1) * diameter * 0.06
                    )
                    .scaleEffect(1 + activity * (0.045 + CGFloat(index) * 0.032)
                                 + (breathe ? 0.025 : 0))
                    .opacity(isMuted ? 0.25 : 0.78 - Double(index) * 0.16)
                    .animation(.easeOut(duration: 0.16), value: activity)
                    .animation(
                        reduceMotion ? .none :
                            .easeInOut(duration: 1.5 + Double(index) * 0.35)
                                .repeatForever(autoreverses: true),
                        value: breathe
                    )
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.90),
                            accentColor.opacity(0.84),
                            accentColor,
                            accentColor.opacity(0.48)
                        ],
                        center: UnitPoint(x: 0.31, y: 0.22),
                        startRadius: 0,
                        endRadius: core * 0.78
                    )
                )
                .frame(width: core, height: core)
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.86), accentColor.opacity(0.45), .white.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, core * 0.008)
                    )
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: core * 0.45, height: core * 0.45)
                        .blur(radius: core * 0.12)
                        .offset(x: breathe ? -core * 0.16 : -core * 0.07,
                                y: breathe ? -core * 0.15 : -core * 0.05)
                        .mask(Circle().frame(width: core, height: core))
                        .animation(
                            reduceMotion ? .none :
                                .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                            value: breathe
                        )
                )
                .overlay(
                    Image(systemName: "sparkle")
                        .font(.system(size: max(12, core * 0.25), weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.65), radius: core * 0.06)
                )
                .shadow(
                    color: accentColor.opacity(isMuted ? 0.12 : 0.54),
                    radius: diameter * 0.075
                )
                .scaleEffect(1 + activity * 0.025 + (breathe && !reduceMotion ? 0.012 : 0))
                .animation(.easeOut(duration: 0.16), value: activity)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
        .onAppear { breathe = !reduceMotion }
        .onChange(of: reduceMotion) { value in breathe = !value }
    }
}

@available(iOS 15.0, *)
private struct VoiceCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            onImage(info[.originalImage] as? UIImage)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
            picker.dismiss(animated: true)
        }
    }
}
