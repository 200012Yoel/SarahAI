import SwiftUI
import UIKit

/// External-computer/TV audio is picked up by the phone microphone.
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

    public init(initialSource: String = "he", initialTarget: String = "fr") {
        _sourceLanguage = State(initialValue: initialSource)
        _targetLanguage = State(initialValue: initialTarget)
    }

    private let deepNavy = Color(red: 0.025, green: 0.048, blue: 0.12)
    private let matteBlue = Color(red: 0.105, green: 0.23, blue: 0.43)

    private var canSpeakTarget: Bool {
        TranslateLiveLanguages.spokenOutputCodes.contains(
            TranslateLiveLanguages.engineCode(for: targetLanguage)
        )
    }

    private func isRTL(_ code: String) -> Bool {
        ["he", "ar", "fa", "ur", "yi"].contains(TranslateLiveLanguages.engineCode(for: code))
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.008, green: 0.021, blue: 0.065)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.cyan)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.cyan.opacity(0.12)))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Traduction en direct")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.white)
                                Text("Yoann écoute et restitue chaque passage traduit.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.68))
                            }
                        }
                        .padding(.top, 10)

                        HStack(spacing: 12) {
                            selector("Langue entendue", value: sourceLanguage) {
                                pickerMode = .source
                            }
                            Image(systemName: "arrow.right")
                                .foregroundColor(.cyan)
                            selector("Traduction", value: targetLanguage) {
                                pickerMode = .target
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.075))
                        )

                        // Original above, translation below. Direction follows
                        // the chosen language, never an assumed French layout.
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(TranslateLiveLanguages.label(for: sourceLanguage),
                                      systemImage: "mic.fill")
                                    .font(.headline)
                                    .foregroundColor(.cyan)
                                Spacer()
                                Text(live.isListening ? "● Écoute active" : "En attente du micro")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(live.isListening ? .green : .white.opacity(0.64))
                            }
                            Text(live.lastSource.isEmpty
                                ? "Les paroles originales apparaîtront ici…"
                                : live.lastSource)
                                .font(.title3.weight(.semibold))
                                .foregroundColor(live.lastSource.isEmpty ? .white.opacity(0.55) : .white)
                                .frame(maxWidth: .infinity, minHeight: 68,
                                       alignment: isRTL(sourceLanguage) ? .trailing : .leading)
                                .multilineTextAlignment(isRTL(sourceLanguage) ? .trailing : .leading)
                                .environment(\.layoutDirection,
                                             isRTL(sourceLanguage) ? .rightToLeft : .leftToRight)
                                .accessibilityLabel("Paroles originales")

                            if !live.provisionalSource.isEmpty {
                                Text("En cours : " + live.provisionalSource)
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.64))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("Transcription provisoire")
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 23)
                                .fill(deepNavy)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 23)
                                        .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
                                )
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(TranslateLiveLanguages.label(for: targetLanguage),
                                      systemImage: "text.bubble.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Label(
                                    canSpeakTarget
                                        ? (live.isSpeakingTranslation ? "Yoann parle" : "Voix française ou sélectionnée")
                                        : "Texte uniquement",
                                    systemImage: canSpeakTarget
                                        ? "speaker.wave.2.fill" : "speaker.slash.fill"
                                )
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                            }

                            Text(live.lastTranslation.isEmpty
                                ? "La traduction apparaîtra ici, puis sera lue à voix haute si une voix est disponible."
                                : live.lastTranslation)
                                .font(.title2.weight(.semibold))
                                .foregroundColor(live.lastTranslation.isEmpty ? .white.opacity(0.70) : .white)
                                .frame(maxWidth: .infinity, minHeight: 82,
                                       alignment: isRTL(targetLanguage) ? .trailing : .leading)
                                .multilineTextAlignment(isRTL(targetLanguage) ? .trailing : .leading)
                                .environment(\.layoutDirection,
                                             isRTL(targetLanguage) ? .rightToLeft : .leftToRight)
                                .accessibilityLabel("Traduction")
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 23)
                                .fill(matteBlue)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 23)
                                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                )
                        )

                        HStack(spacing: 10) {
                            Circle()
                                .fill(live.isListening ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            Text(live.status)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.84))
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                        if live.waitingTranslations > 0 {
                            Text("Passages en attente : \(live.waitingTranslations)")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                        if let error = live.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.footnote)
                        }

                        Button {
                            if live.isActive {
                                live.stop()
                            } else {
                                live.start(
                                    from: sourceLanguage,
                                    to: targetLanguage,
                                    serverURL: translationServerURL
                                )
                            }
                        } label: {
                            Label(live.isActive ? "Arrêter l'interprétation" : "Commencer l'interprétation",
                                  systemImage: live.isActive ? "stop.fill" : "mic.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(live.isActive ? Color(red: 0.62, green: 0.15, blue: 0.23) : .blue)
                        .disabled(
                            !live.isActive && TranslateLiveLanguages.engineCode(for: sourceLanguage)
                                == TranslateLiveLanguages.engineCode(for: targetLanguage)
                        )

                        if !canSpeakTarget {
                            Label("La traduction en \(TranslateLiveLanguages.label(for: targetLanguage)) s'affiche, mais une voix neuronale compatible n'est pas installée.",
                                  systemImage: "text.bubble")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                        if !live.headphoneConnected {
                            Label("Sans écouteurs, l'iPhone peut écouter et parler, mais sa propre voix peut être reprise par le micro malgré l'annulation d'écho.",
                                  systemImage: "speaker.wave.2")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.70))
                        }

                        DisclosureGroup("Langues, serveur et limites") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tu peux sélectionner toutes les langues reconnues dans le catalogue. Une langue détectée n'est pas forcément traduisible : le sens dépend du moteur installé.")
                                Text("Pour l'hébreu, le français et d'autres traductions vers une langue différente de l'anglais, un moteur de traduction réellement disponible est nécessaire pour les phrases longues.")
                                Text("L'écoute est sans minuterie interne, mais une session n'est ni instantanée ni garantie en arrière-plan. Teste la latence et le risque d'écho sur un vrai iPhone.")
                                if TranslateLiveLanguages.isEnglish(sourceLanguage) ||
                                    TranslateLiveLanguages.isEnglish(targetLanguage) {
                                    Text("Les choix anglais britannique et américain sont disponibles, mais la voix ne garantit pas encore deux accents distincts.")
                                }
                                TextField("Serveur personnel HTTPS ou local (facultatif)",
                                          text: $translationServerURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .keyboardType(.URL)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(.white)
                                if !translationServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && TranslateLiveTranslationBackend.validatedURL(translationServerURL) == nil {
                                    Text("Adresse invalide : HTTPS ou HTTP privé/local uniquement.")
                                        .foregroundColor(.orange)
                                }
                                Text("Seul le texte reconnu est envoyé au serveur choisi. Le serveur doit disposer des modèles correspondant à chaque paire.")
                                if live.isActive {
                                    Text("Après modification du serveur, redémarre l'interprétation.")
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.74))
                            .padding(.top, 10)
                        }
                        .tint(.cyan)

                        if !live.history.isEmpty {
                            Text("Derniers passages")
                                .font(.headline)
                                .foregroundColor(.white)
                            ForEach(live.history.prefix(12)) { phrase in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(phrase.source)
                                        .foregroundColor(.white.opacity(0.70))
                                    Text(phrase.translation)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.07))
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Translate Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        live.stop()
                        dismiss()
                    }
                }
            }
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
        }
        .preferredColorScheme(.dark)
        .onAppear {
            live.start(from: sourceLanguage, to: targetLanguage, serverURL: translationServerURL)
        }
        .onDisappear { live.stop() }
        .onChange(of: sourceLanguage) { _ in restartIfActive() }
        .onChange(of: targetLanguage) { _ in restartIfActive() }
    }

    private func restartIfActive() {
        guard live.isActive else { return }
        live.start(from: sourceLanguage, to: targetLanguage, serverURL: translationServerURL)
    }

    private func selector(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundColor(.secondary)
                    Text(TranslateLiveLanguages.label(for: value))
                        .font(.headline).foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.cyan)
            }
        }
        .buttonStyle(.plain)
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
