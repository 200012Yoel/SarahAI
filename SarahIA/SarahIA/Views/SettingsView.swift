import SwiftUI
import AVFoundation

@available(iOS 16.0, *)
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ChatViewModel

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        engineHeader

                        settingsCard {
                            NavigationLink {
                                SarahVoiceSettingsView(viewModel: viewModel)
                            } label: {
                                settingsRow(
                                    icon: "waveform",
                                    tint: .purple,
                                    title: "Voix et parole",
                                    detail: "Voix de Sarah, vitesse, hauteur et micro"
                                )
                            }

                            divider

                            NavigationLink {
                                SarahLocalCreationSettingsView()
                            } label: {
                                settingsRow(
                                    icon: "wand.and.stars",
                                    tint: .pink,
                                    title: "Création locale",
                                    detail: "Images, vidéo et musique sur l’iPhone"
                                )
                            }

                            divider

                            NavigationLink {
                                SarahDataSettingsView(viewModel: viewModel)
                            } label: {
                                settingsRow(
                                    icon: "bubble.left.and.bubble.right.fill",
                                    tint: .orange,
                                    title: "Données et discussions",
                                    detail: "Historique, mémoire et nouveau chat"
                                )
                            }

                            divider

                            NavigationLink {
                                SarahAboutView()
                            } label: {
                                settingsRow(
                                    icon: "info.circle.fill",
                                    tint: .gray,
                                    title: "À propos",
                                    detail: "Version, modèles, licences et notices"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var engineHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cyan.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Sarah Engine")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Base stable Xcode 26.6 · création locale à la demande")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.50))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
    }

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
    }

    private func settingsRow(
        icon: String,
        tint: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.28))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 70)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 64)
    }
}

@available(iOS 16.0, *)
private struct SarahVoiceSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @AppStorage("sarahVoiceIdentifier") private var selectedVoiceIdentifier = ""

    @State private var speechRate: Double = 0.50
    @State private var speechPitch: Double = 1.02
    @State private var vadSensitivity: Double = 0.65

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("fr") }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    settingCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Voix de Sarah", systemImage: "person.wave.2.fill")
                                .font(.headline)
                                .foregroundColor(.white)

                            Picker("Voix", selection: $selectedVoiceIdentifier) {
                                Text("Automatique")
                                    .tag("")

                                ForEach(voices, id: \.identifier) { voice in
                                    Text("\(voice.name) · \(voice.language)")
                                        .tag(voice.identifier)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.pink)

                            Button {
                                viewModel.testVoiceSettings(
                                    rate: Float(speechRate),
                                    pitch: Float(speechPitch)
                                )
                            } label: {
                                Label("Tester cette voix", systemImage: "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                        }
                    }

                    settingCard {
                        VStack(alignment: .leading, spacing: 16) {
                            slider(
                                title: "Vitesse",
                                value: $speechRate,
                                range: 0.35...0.65
                            )

                            slider(
                                title: "Hauteur",
                                value: $speechPitch,
                                range: 0.8...1.25
                            )

                            slider(
                                title: "Sensibilité micro",
                                value: $vadSensitivity,
                                range: 0.25...0.95
                            )
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Voix et parole")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let defaults = UserDefaults.standard
            speechRate = defaults.object(forKey: "sarahVoiceRate") as? Double ?? 0.50
            speechPitch = defaults.object(forKey: "sarahVoicePitch") as? Double ?? 1.02
            vadSensitivity = defaults.object(forKey: "sarahVADSensitivity") as? Double ?? 0.65
        }
        .onDisappear {
            UserDefaults.standard.set(speechRate, forKey: "sarahVoiceRate")
            UserDefaults.standard.set(speechPitch, forKey: "sarahVoicePitch")
            UserDefaults.standard.set(vadSensitivity, forKey: "sarahVADSensitivity")
            viewModel.saveVoiceSettings(
                rate: Float(speechRate),
                pitch: Float(speechPitch),
                vadSensitivity: Float(vadSensitivity)
            )
        }
    }

    private func slider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Slider(value: value, in: range)
                .tint(.pink)
        }
    }

    private func settingCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.075))
            )
    }
}

@available(iOS 16.0, *)
private struct SarahLocalCreationSettingsView: View {
    @StateObject private var models = GenerativeModelManager.shared
    @State private var musicProgress = 0.0
    @State private var musicStatus = ""
    @State private var isPreparingMusic = false

    private let image = SarahGenerativeModelCatalog.imageProfile()
    private let video = SarahGenerativeModelCatalog.videoProfile()
    private let music = SarahGenerativeModelCatalog.musicProfile()
    private let vocals = SarahGenerativeModelCatalog.vocalSongProfile()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    modelCard(
                        icon: "photo.fill",
                        tint: .purple,
                        title: "Images",
                        profile: image,
                        installed: models.isImageInstalled,
                        buttonTitle: "Télécharger le modèle"
                    ) {
                        models.downloadImageModel()
                    }

                    modelCard(
                        icon: "video.fill",
                        tint: .orange,
                        title: "Vidéo",
                        profile: video,
                        installed: models.isVideoCheckpointInstalled,
                        buttonTitle: "Télécharger le checkpoint"
                    ) {
                        models.downloadVideoCheckpoint()
                    }

                    musicCard

                    modelCard(
                        icon: "music.mic",
                        tint: .cyan,
                        title: "Chanson avec paroles",
                        profile: vocals,
                        installed: false,
                        buttonTitle: nil,
                        action: {}
                    )

                    if models.isDownloading {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: models.progress)
                                .tint(.pink)

                            Text(models.statusText)
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.52))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Création locale")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            modelHeader(
                icon: "music.note.list",
                tint: .pink,
                title: "Musique",
                profile: music,
                installed: SarahLocalMusicGenEngine.shared.isInstalled
            )

            Text(music.note)
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.52))

            if isPreparingMusic {
                ProgressView(value: musicProgress)
                    .tint(.pink)

                Text(musicStatus)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.50))
            } else if !SarahLocalMusicGenEngine.shared.isInstalled {
                Button {
                    isPreparingMusic = true
                    musicStatus = "Préparation…"

                    SarahLocalMusicGenEngine.shared.prepareModel(
                        progress: { value, status in
                            DispatchQueue.main.async {
                                musicProgress = value
                                musicStatus = status
                            }
                        },
                        completion: { result in
                            DispatchQueue.main.async {
                                isPreparingMusic = false
                                switch result {
                                case .success:
                                    musicProgress = 1
                                    musicStatus = "Modèle musical prêt"
                                case .failure(let error):
                                    musicStatus = error.localizedDescription
                                }
                            }
                        }
                    )
                } label: {
                    Label("Télécharger Stable Audio (~580 Mo)", systemImage: "arrow.down.circle.fill")
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.pink)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
    }

    private func modelCard(
        icon: String,
        tint: Color,
        title: String,
        profile: SarahGenerativeModelProfile,
        installed: Bool,
        buttonTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            modelHeader(
                icon: icon,
                tint: tint,
                title: title,
                profile: profile,
                installed: installed
            )

            Text(profile.note)
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.52))

            Text("Licence : \(profile.licenseName)")
                .font(.caption2)
                .foregroundColor(Color.white.opacity(0.34))

            if let buttonTitle,
               profile.runtimeState != .unsupported,
               !installed {
                Button(action: action) {
                    Label(buttonTitle, systemImage: "arrow.down.circle.fill")
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(tint)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
    }

    private func modelHeader(
        icon: String,
        tint: Color,
        title: String,
        profile: SarahGenerativeModelProfile,
        installed: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.46))

                Text(profile.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer()

            if installed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct SarahDataSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        List {
            Section("Discussions") {
                Button {
                    viewModel.startNewChat()
                } label: {
                    Label("Nouvelle discussion", systemImage: "square.and.pencil")
                }

                HStack {
                    Label("Discussions enregistrées", systemImage: "bubble.left.and.bubble.right")
                    Spacer()
                    Text("\(viewModel.conversations.count)")
                        .foregroundColor(.secondary)
                }
            }

            Section("Mémoire") {
                HStack {
                    Label("Souvenirs appris", systemImage: "brain.head.profile")
                    Spacer()
                    Text("\(viewModel.learnedMemories.count)")
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    viewModel.clearAllLearnedMemories()
                } label: {
                    Label("Effacer les souvenirs appris", systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Données et discussions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 16.0, *)
private struct SarahAboutView: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sarah IA")
                        .font(.title2.bold())
                    Text(versionText)
                        .foregroundColor(.secondary)
                    Text("Édition stable compilée avec Xcode 26.6. Les gros modèles sont téléchargés après installation.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Modèles") {
                aboutModel(SarahGenerativeModelCatalog.imageProfile())
                aboutModel(SarahGenerativeModelCatalog.videoProfile())
                aboutModel(SarahGenerativeModelCatalog.musicProfile())
                aboutModel(SarahGenerativeModelCatalog.vocalSongProfile())
            }

            Section("Licences et notices") {
                Link("Stable Diffusion · OpenRAIL", destination: URL(string: "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL")!)
                Link("Apple ml-stable-diffusion · MIT", destination: URL(string: "https://github.com/apple-aiml-research/ml-stable-diffusion")!)
                Link("Stable Audio · Stability AI Community License", destination: URL(string: "https://stability.ai/license")!)
                Link("MobileI2V · Apache-2.0 / poids séparés", destination: URL(string: "https://github.com/hustvl/MobileI2V")!)
                Link("ACE-Step 1.5 · MIT", destination: URL(string: "https://github.com/ace-step/ACE-Step-1.5")!)
                Link("ZIPFoundation · MIT", destination: URL(string: "https://github.com/weichsel/ZIPFoundation")!)
            }

            Section("Commercialisation") {
                Text("Avant publication commerciale, vérifie toujours les conditions en vigueur des poids distribués et des modèles téléchargés. Une licence permissive du code ne remplace pas la licence des poids.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("À propos")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutModel(_ profile: SarahGenerativeModelProfile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(profile.displayName)
                .font(.headline)
            Text(profile.licenseName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
    }
}
