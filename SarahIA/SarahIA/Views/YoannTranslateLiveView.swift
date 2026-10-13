import SwiftUI
import UIKit
#if canImport(Translation)
import Translation
#endif

/// Landscape live-subtitle screen. Put the iPhone in front of the TV:
/// the translation fills most of the screen, the words actually heard are
/// shown underneath, and a slim bar shows that the microphone is working.
@available(iOS 16.2, *)
public struct YoannTranslateLiveView: View {
    private enum PickerMode: String, Identifiable {
        case source, target
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var live = YoannTranslateLiveService()
    @AppStorage("yoann_translate_live_server") private var translationServerURL = ""
    // New key: the old one defaulted to headphones, subtitles is now the default.
    @AppStorage("yoann_translate_live_output_v2") private var selectedOutput = "subtitles"
    @AppStorage("yoann_translate_live_text_scale") private var textScale = 1.0
    @State private var sourceLanguage: String
    @State private var targetLanguage: String
    @State private var pickerMode: PickerMode?
    @State private var showsSettings = false

    private let background = Color(red: 0.03, green: 0.05, blue: 0.10)
    private let panel = Color(red: 0.07, green: 0.10, blue: 0.18)

    public init(initialSource: String = "he", initialTarget: String = "fr") {
        _sourceLanguage = State(initialValue: initialSource)
        _targetLanguage = State(initialValue: initialTarget)
    }

    private var preferredOutput: AudioSessionManager.InterpreterOutputMode {
        AudioSessionManager.InterpreterOutputMode(rawValue: selectedOutput) ?? .subtitles
    }

    private func isRTL(_ code: String) -> Bool {
        ["he", "ar", "fa", "ur", "yi"].contains(TranslateLiveLanguages.engineCode(for: code))
    }

    private var sourceDisplayCode: String {
        live.showsEnglishRelay ? "en" : sourceLanguage
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topBar
                translationPane(height: geometry.size.height)
                    .frame(maxHeight: .infinity)
                sourcePane(height: geometry.size.height)
                    .frame(height: geometry.size.height * 0.22)
                statusBar
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(background.ignoresSafeArea())
        .background(alignment: .topLeading) { translationHost }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .sheet(item: $pickerMode) { mode in
            TranslateLiveLanguagePicker(
                title: mode == .source ? "Langue parlée à la télé" : "Traduire en",
                options: TranslateLiveLanguages.interpreterOptions,
                selected: mode == .source ? $sourceLanguage : $targetLanguage,
                isTarget: mode == .target
            )
        }
        .sheet(isPresented: $showsSettings) { settingsSheet }
        .onAppear {
            setLandscapeEnabled(true)
            UIApplication.shared.isIdleTimerDisabled = true
            start()
        }
        .onDisappear {
            live.stop()
            UIApplication.shared.isIdleTimerDisabled = false
            setLandscapeEnabled(false)
        }
        .onChange(of: sourceLanguage) { _ in restartIfActive() }
        .onChange(of: targetLanguage) { _ in restartIfActive() }
        .onChange(of: selectedOutput) { _ in restartIfActive() }
    }

    // MARK: - Hidden Apple Translation session

    @ViewBuilder
    private var translationHost: some View {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            if let pair = live.applePair {
                YoannNativeTranslationSessionHost(live: live, pair: pair)
                    .id(pair.id)
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
        #endif
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            iconButton("xmark", label: "Fermer") {
                live.stop()
                dismiss()
            }

            languageChip(code: sourceLanguage, caption: "Entendu") { pickerMode = .source }
            Button {
                let previous = sourceLanguage
                sourceLanguage = targetLanguage
                targetLanguage = previous
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Inverser les langues")
            .accessibilityIdentifier("translateLiveSwapLanguages")
            languageChip(code: targetLanguage, caption: "Traduction") { pickerMode = .target }

            Spacer(minLength: 6)

            Menu {
                Picker("Sortie", selection: $selectedOutput) {
                    Label("Sous-titres seulement", systemImage: "captions.bubble").tag("subtitles")
                    Label("Voix dans les écouteurs", systemImage: "headphones").tag("headphones")
                    Label("Voix sur le haut-parleur", systemImage: "speaker.wave.2").tag("speaker")
                }
            } label: {
                Image(systemName: outputIcon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .accessibilityLabel("Mode de sortie")
            .accessibilityIdentifier("translateLiveAudioOutputMode")

            iconButton("textformat.size", label: "Taille du texte") {
                textScale = textScale >= 1.4 ? 0.8 : textScale + 0.2
            }
            iconButton("gearshape", label: "Réglages") { showsSettings = true }

            Button {
                if live.isActive { live.stop() } else { start() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: live.isActive ? "stop.fill" : "play.fill")
                    Text(live.isActive ? "Arrêter" : "Démarrer")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(live.isActive ? Color.red.opacity(0.75) : Color.green.opacity(0.75)))
            }
            .accessibilityIdentifier("translateLive.startStop")
            .disabled(!live.isActive &&
                TranslateLiveLanguages.engineCode(for: sourceLanguage)
                == TranslateLiveLanguages.engineCode(for: targetLanguage))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(panel)
    }

    private var outputIcon: String {
        switch preferredOutput {
        case .subtitles: return "captions.bubble"
        case .headphones: return "headphones"
        case .speaker: return "speaker.wave.2"
        }
    }

    private func iconButton(_ systemName: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.10)))
        }
        .accessibilityLabel(label)
    }

    private func languageChip(code: String, caption: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(caption.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.55))
                HStack(spacing: 4) {
                    Text(TranslateLiveLanguages.label(for: code))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(caption + " : " + TranslateLiveLanguages.label(for: code))
        .accessibilityHint("Changer de langue")
    }

    // MARK: - Translation (main area)

    private func translationPane(height: CGFloat) -> some View {
        let mainSize = max(24, min(44, height * 0.085)) * CGFloat(textScale)
        let lines = Array(live.history.prefix(6).reversed())
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    if lines.isEmpty {
                        emptyState
                    }
                    ForEach(lines) { phrase in
                        let isLatest = phrase.id == live.history.first?.id
                        Text(phrase.translation)
                            .font(.system(size: isLatest ? mainSize : mainSize * 0.62,
                                          weight: isLatest ? .bold : .medium))
                            .foregroundColor(.white.opacity(isLatest ? 1 : 0.45))
                            .multilineTextAlignment(isRTL(targetLanguage) ? .trailing : .center)
                            .frame(maxWidth: .infinity)
                            .environment(\.layoutDirection,
                                         isRTL(targetLanguage) ? .rightToLeft : .leftToRight)
                            .id(phrase.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .animation(.easeOut(duration: 0.25), value: live.history.first?.id)
            }
            .onChange(of: live.history.first?.id) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Traduction : " + live.lastTranslation)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("translateLiveTranslatedTopHalf")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: live.errorMessage == nil ? "tv" : "exclamationmark.triangle")
                .font(.system(size: 34))
                .foregroundColor(live.errorMessage == nil ? .white.opacity(0.5) : .orange)
            Text(live.errorMessage ?? (live.isActive
                ? "Pose l'iPhone devant la télé, micro tourné vers le son.\nLa traduction en \(TranslateLiveLanguages.label(for: targetLanguage).lowercased()) s'affichera ici."
                : "Appuie sur Démarrer pour lancer la traduction."))
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(live.errorMessage == nil ? .white.opacity(0.6) : .orange)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Words heard

    private func sourcePane(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(live.showsEnglishRelay
                 ? "COMPRIS PAR WHISPER (RELAIS ANGLAIS)"
                 : "ENTENDU · \(TranslateLiveLanguages.label(for: sourceLanguage).uppercased())")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.5))
            ScrollView {
                Text(live.lastSource.isEmpty ? "…" : live.lastSource)
                    .font(.system(size: max(15, min(22, height * 0.045)) * CGFloat(textScale),
                                  weight: .regular))
                    .foregroundColor(.white.opacity(live.lastSource.isEmpty ? 0.35 : 0.8))
                    .multilineTextAlignment(isRTL(sourceDisplayCode) ? .trailing : .leading)
                    .frame(maxWidth: .infinity,
                           alignment: isRTL(sourceDisplayCode) ? .trailing : .leading)
                    .environment(\.layoutDirection,
                                 isRTL(sourceDisplayCode) ? .rightToLeft : .leftToRight)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(panel.opacity(0.6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paroles entendues : " + live.lastSource)
        .accessibilityIdentifier("translateLiveOriginalBottomHalf")
    }

    // MARK: - Status

    private var statusBar: some View {
        HStack(spacing: 10) {
            MicLevelBars(level: live.microphoneLevel, active: live.isListening)
                .accessibilityIdentifier("translateLive.micStatus")
            if live.isTranslating {
                ProgressView().scaleEffect(0.7).tint(.white)
            }
            Text(live.status)
                .foregroundColor(.white.opacity(0.75))
            if let warning = live.audioRouteWarning {
                Text("· " + warning).foregroundColor(.orange)
            } else if let error = live.errorMessage, !live.history.isEmpty {
                Text("· " + error).foregroundColor(.orange)
            } else if let hint = live.hint {
                Text("· " + hint).foregroundColor(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(panel)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("translateLive.pipelineStatus")
    }

    // MARK: - Settings

    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section("Sortie") {
                    Picker("Mode", selection: $selectedOutput) {
                        Text("Sous-titres seulement").tag("subtitles")
                        Text("Voix dans les écouteurs").tag("headphones")
                        Text("Voix sur le haut-parleur").tag("speaker")
                    }
                    Text("Sous-titres seulement : idéal devant la télé, sans écouteurs. Le micro capte le son sans filtre « appel téléphonique ».")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Section("Moteur") {
                    Text(live.engineDescription)
                    Text(live.audioInputDescription + " · " + live.audioOutputDescription)
                        .foregroundColor(.secondary)
                    Text("Si la traduction ne démarre pas : Réglages iPhone › Apps › Traduire › Langues téléchargées, puis installe Anglais et Français (et Hébreu s'il est proposé).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Section("Avancé : serveur personnel (facultatif)") {
                    TextField("http://192.168.1.10:5000", text: $translationServerURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                    if !translationServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && TranslateLiveTranslationBackend.validatedURL(translationServerURL) == nil {
                        Text("Adresse invalide : HTTPS, ou HTTP sur le réseau local uniquement.")
                            .foregroundColor(.orange)
                    }
                    Text("Laisse vide pour utiliser la traduction d'Apple sur l'iPhone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                if !live.history.isEmpty {
                    Section("Historique") {
                        ForEach(live.history.prefix(30)) { phrase in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(phrase.translation).fontWeight(.semibold)
                                if !phrase.source.isEmpty {
                                    Text(phrase.source)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Traduction en direct")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        showsSettings = false
                        restartIfActive()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func start() {
        live.start(from: sourceLanguage, to: targetLanguage,
                   serverURL: translationServerURL, outputMode: preferredOutput)
    }

    private func restartIfActive() {
        guard live.isActive else { return }
        start()
    }

    /// Request rotation for this screen only. Normal Sarah stays portrait.
    private func setLandscapeEnabled(_ enabled: Bool) {
        AppDelegate.translateLiveLandscapeOnly = enabled
        let mask: UIInterfaceOrientationMask = enabled ? .landscape : .portrait
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            guard scene.activationState == .foregroundActive else { continue }
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                window.rootViewController?.presentedViewController?
                    .setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                print("Translate Live orientation: \(error.localizedDescription)")
            }
        }
    }
}

/// Five small bars that follow the real microphone level.
@available(iOS 16.2, *)
private struct MicLevelBars: View {
    let level: Float
    let active: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let lit = active && level > Float(index) * 0.18
                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? Color.green : Color.white.opacity(0.2))
                    .frame(width: 3, height: CGFloat(5 + index * 3))
            }
        }
        .frame(height: 18)
        .accessibilityLabel(active ? "Micro actif" : "Micro arrêté")
        .accessibilityValue("\(Int(level * 100)) pour cent")
    }
}

@available(iOS 16.2, *)
private struct TranslateLiveLanguagePicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let options: [TranslateLiveLanguages.Language]
    @Binding var selected: String
    let isTarget: Bool

    var body: some View {
        NavigationView {
            List(options) { language in
                Button {
                    selected = language.id
                    dismiss()
                } label: {
                    HStack {
                        Text(language.label)
                            .foregroundColor(.primary)
                        Spacer()
                        if language.id == selected {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

#if canImport(Translation)
/// The system owns this task and its TranslationSession; the service only
/// uses the session while this task is running.
@available(iOS 18.0, *)
private struct YoannNativeTranslationSessionHost: View {
    @ObservedObject var live: YoannTranslateLiveService
    let pair: YoannTranslateLiveService.ApplePair

    var body: some View {
        Color.clear
            .translationTask(
                source: Locale.Language(identifier: pair.source),
                target: Locale.Language(identifier: pair.target)
            ) { session in
                await live.attach(session, pair: pair)
            }
    }
}
#endif
