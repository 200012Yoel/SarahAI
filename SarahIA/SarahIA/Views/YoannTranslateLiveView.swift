import SwiftUI
import UIKit

/// Landscape-only, face-to-face interpreter screen.
/// The translated language ALWAYS occupies the upper half.
/// The words heard by the microphone ALWAYS occupy the lower half.
@available(iOS 16.2, *)
public struct YoannTranslateLiveView: View {
    private enum PickerMode: String, Identifiable {
        case source, target
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var live = YoannTranslateLiveService()
    @AppStorage("yoann_translate_live_server") private var translationServerURL = ""
    @State private var sourceLanguage: String
    @State private var targetLanguage: String
    @State private var pickerMode: PickerMode?
    @State private var showsDetails = false

    private let darkNavy = Color(red: 0.025, green: 0.048, blue: 0.12)
    private let matteBlue = Color(red: 0.105, green: 0.23, blue: 0.43)

    public init(initialSource: String = "he", initialTarget: String = "fr") {
        _sourceLanguage = State(initialValue: initialSource)
        _targetLanguage = State(initialValue: initialTarget)
    }

    private var canSpeakTarget: Bool {
        TranslateLiveLanguages.spokenOutputCodes.contains(
            TranslateLiveLanguages.engineCode(for: targetLanguage)
        )
    }

    private func isRTL(_ code: String) -> Bool {
        ["he", "ar", "fa", "ur", "yi"].contains(TranslateLiveLanguages.engineCode(for: code))
    }

    public var body: some View {
        GeometryReader { geometry in
            // Keep both regions precisely the same height in landscape.
            // No chat header, sidebar or scrollable dashboard takes up a third region.
            VStack(spacing: 0) {
                translatedHalf(paneHeight: geometry.size.height / 2)
                    .frame(height: geometry.size.height / 2)
                heardHalf(paneHeight: geometry.size.height / 2)
                    .frame(height: geometry.size.height / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(darkNavy.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
        .sheet(item: $pickerMode) { mode in
            TranslateLiveLanguagePicker(
                title: mode == .source ? "Langue entendue" : "Langue de traduction",
                options: mode == .source
                    ? TranslateLiveLanguages.sourceOptions
                    : TranslateLiveLanguages.available,
                selected: mode == .source ? $sourceLanguage : $targetLanguage,
                isTarget: mode == .target
            )
        }
        .sheet(isPresented: $showsDetails) {
            configurationSheet
        }
        .onAppear {
            setLandscapeEnabled(true)
            live.start(from: sourceLanguage, to: targetLanguage, serverURL: translationServerURL)
        }
        .onDisappear {
            live.stop()
            setLandscapeEnabled(false)
        }
        .onChange(of: sourceLanguage) { _ in restartIfActive() }
        .onChange(of: targetLanguage) { _ in restartIfActive() }
    }

    // MARK: - Upper 50%: requested translation

    private func translatedHalf(paneHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                languageButton(
                    caption: "TRADUCTION EN HAUT",
                    code: targetLanguage,
                    icon: "text.bubble.fill"
                ) { pickerMode = .target }

                Spacer(minLength: 4)

                if !canSpeakTarget {
                    Image(systemName: "speaker.slash.fill")
                        .foregroundColor(.white.opacity(0.75))
                        .accessibilityLabel("Traduction écrite uniquement")
                } else if live.isSpeakingTranslation {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.cyan)
                        .accessibilityLabel("Lecture de la traduction")
                }

                Button {
                    if live.isActive {
                        live.stop()
                    } else {
                        live.start(
                            from: sourceLanguage, to: targetLanguage,
                            serverURL: translationServerURL
                        )
                    }
                } label: {
                    Image(systemName: live.isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 29))
                        .foregroundColor(.white)
                }
                .disabled(!live.isActive &&
                    TranslateLiveLanguages.engineCode(for: sourceLanguage)
                    == TranslateLiveLanguages.engineCode(for: targetLanguage))
                .accessibilityLabel(live.isActive ? "Arrêter la traduction" : "Démarrer la traduction")

                Button {
                    showsDetails = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 23))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Réglages de la traduction")

                Button {
                    live.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 27))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Fermer Translate Live")
            }

            ScrollView {
                Text(live.lastTranslation.isEmpty
                    ? "La traduction en \(TranslateLiveLanguages.label(for: targetLanguage)) s'affichera ici."
                    : live.lastTranslation)
                    .font(.system(size: max(22, min(34, paneHeight * 0.16)), weight: .semibold))
                    .foregroundColor(live.lastTranslation.isEmpty
                        ? .white.opacity(0.62) : .white)
                    .multilineTextAlignment(isRTL(targetLanguage) ? .trailing : .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .environment(\.layoutDirection,
                        isRTL(targetLanguage) ? .rightToLeft : .leftToRight)
                    .accessibilityLabel("Traduction : " + live.lastTranslation)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                if let error = live.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.orange)
                } else {
                    Circle()
                        .fill(live.isActive ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(live.status)
                        .foregroundColor(.white.opacity(0.77))
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .medium))
            .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(matteBlue)
        .accessibilityIdentifier("translateLiveTranslatedTopHalf")
    }

    // MARK: - Lower 50%: source language heard by the iPhone

    private func heardHalf(paneHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                languageButton(
                    caption: "PAROLES ENTENDUES EN BAS",
                    code: sourceLanguage,
                    icon: "mic.fill"
                ) { pickerMode = .source }

                Spacer(minLength: 4)

                Image(systemName: "waveform")
                    .foregroundColor(live.isListening ? .green : .white.opacity(0.50))
                    .accessibilityLabel(live.isListening
                        ? "Microphone actif" : "Microphone inactif")
            }

            ScrollView {
                VStack(spacing: 8) {
                    Text(live.lastSource.isEmpty
                        ? "Les paroles en \(TranslateLiveLanguages.label(for: sourceLanguage)) s'afficheront ici."
                        : live.lastSource)
                        .font(.system(size: max(22, min(34, paneHeight * 0.16)), weight: .semibold))
                        .foregroundColor(live.lastSource.isEmpty
                            ? .white.opacity(0.58) : .white)
                        .multilineTextAlignment(isRTL(sourceLanguage) ? .trailing : .center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .environment(\.layoutDirection,
                            isRTL(sourceLanguage) ? .rightToLeft : .leftToRight)
                        .accessibilityLabel("Paroles entendues : " + live.lastSource)
                        .accessibilityAddTraits(.updatesFrequently)

                    if !live.provisionalSource.isEmpty {
                        Text(live.provisionalSource)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(isRTL(sourceLanguage) ? .trailing : .center)
                            .environment(\.layoutDirection,
                                isRTL(sourceLanguage) ? .rightToLeft : .leftToRight)
                            .accessibilityLabel("Transcription en cours")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text(live.isListening ? "● Micro actif" : "Micro en attente")
                Spacer()
                Text("Origine · \(TranslateLiveLanguages.label(for: sourceLanguage))")
            }
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.70))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(darkNavy)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.30))
                .frame(height: 1)
        }
        .accessibilityIdentifier("translateLiveOriginalBottomHalf")
    }

    private func languageButton(
        caption: String, code: String, icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(.white.opacity(0.69))
                    HStack(spacing: 5) {
                        Text(TranslateLiveLanguages.label(for: code))
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                }
            }
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(caption + ", " + TranslateLiveLanguages.label(for: code))
        .accessibilityHint("Changer de langue")
    }

    // MARK: - Optional settings remain outside the two equal translation panes

    private var configurationSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("La moitié supérieure affiche toujours la traduction demandée ; la moitié inférieure affiche la langue parlée.")
                    Text("La reconnaissance d'une langue ne garantit pas qu'un moteur de traduction soit installé pour cette paire.")
                    TextField("Serveur de traduction local ou HTTPS", text: $translationServerURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                    if !translationServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && TranslateLiveTranslationBackend.validatedURL(translationServerURL) == nil {
                        Text("Adresse invalide : HTTPS ou HTTP privé/local uniquement.")
                            .foregroundColor(.orange)
                    }
                    Text("Si tu changes le serveur, arrête puis redémarre la traduction. Seul le texte reconnu est transmis au serveur que tu choisis.")
                    if !canSpeakTarget {
                        Text("Aucune voix neuronale intégrée pour \(TranslateLiveLanguages.label(for: targetLanguage)) : affichage du texte seulement.")
                            .foregroundColor(.orange)
                    }
                    if !live.headphoneConnected {
                        Text("Sans écouteurs, la voix émise par le haut-parleur peut être reprise par le microphone.")
                    }
                    if !live.history.isEmpty {
                        Text("Dernières traductions")
                            .font(.headline)
                        ForEach(live.history.prefix(12)) { phrase in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phrase.translation).fontWeight(.semibold)
                                Text(phrase.source).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .font(.footnote)
                .padding(20)
            }
            .navigationTitle("Réglages Translate Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") { showsDetails = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func restartIfActive() {
        guard live.isActive else { return }
        live.start(from: sourceLanguage, to: targetLanguage, serverURL: translationServerURL)
    }

    /// Request rotation for this screen only. Normal Sarah and Yoann stay portrait.
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

@available(iOS 16.2, *)
private struct TranslateLiveLanguagePicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let options: [TranslateLiveLanguages.Language]
    @Binding var selected: String
    let isTarget: Bool
    @State private var search = ""

    private var filtered: [TranslateLiveLanguages.Language] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return options }
        return options.filter {
            $0.label.localizedCaseInsensitiveContains(trimmed)
            || $0.id.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationView {
            List(filtered) { language in
                Button {
                    selected = language.id
                    dismiss()
                } label: {
                    HStack {
                        Text(language.label)
                            .foregroundColor(.primary)
                        Spacer()
                        if isTarget {
                            Text(language.hasSpokenOutput ? "Voix" : "Texte")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if language.id == selected {
                            Image(systemName: "checkmark").foregroundColor(.cyan)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Chercher une langue")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") { dismiss() }
                }
            }
        }
    }
}
