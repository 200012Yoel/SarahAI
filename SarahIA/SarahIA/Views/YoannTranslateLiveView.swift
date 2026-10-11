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

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 46))
                            .foregroundColor(.cyan)
                            .accessibilityHidden(true)
                        Text("Yoann · Translate Live")
                            .font(.title2.bold())
                        Text("Interprète en direct : l'iPhone écoute sans interruption et traduit par petits passages.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                    VStack(alignment: .leading, spacing: 16) {
                        selector(
                            "Langue de la vidéo / du PC",
                            value: sourceLanguage,
                            action: { pickerMode = .source }
                        )
                        Image(systemName: "arrow.down")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                        selector(
                            "Langue de traduction",
                            value: targetLanguage,
                            action: { pickerMode = .target }
                        )
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                    if targetLanguage == "en" && sourceLanguage != "en" {
                        Label(
                            "Vers l'anglais : Whisper traduit directement la voix en local, sans serveur.",
                            systemImage: "checkmark.shield"
                        )
                        .font(.subheadline)
                        .foregroundColor(.green)
                    } else {
                        Label(
                            "Pour une émission entière vers cette langue : un serveur de traduction est nécessaire. "
                                + "Quelques expressions françaises, anglaises et hébraïques sont connues localement.",
                            systemImage: "network"
                        )
                        .font(.footnote)
                    }

                    if !TranslateLiveLanguages.spokenOutputCodes.contains(targetLanguage) {
                        Label(
                            "Traduction écrite uniquement en \(TranslateLiveLanguages.label(for: targetLanguage)). "
                                + "La voix neuronale intégrée couvre 31 autres langues.",
                            systemImage: "text.bubble"
                        )
                        .font(.footnote)
                        .foregroundColor(.orange)
                    }

                    Label(
                        "Place ton iPhone près de la personne ou des haut-parleurs de ton ordinateur.",
                        systemImage: "waveform"
                    )
                    .font(.subheadline)

                    Label(
                        "L'écoute reste active quand Yoann traduit et parle. "
                        + "Branche des écouteurs pour entendre la traduction sans qu'elle repasse dans le micro.",
                        systemImage: "earbuds"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if !live.headphoneConnected {
                        Label(
                            "Aucun écouteur détecté. En haut-parleur, une boucle sonore "
                            + "reste possible malgré la réduction d'écho iOS.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                        .foregroundColor(.orange)
                    } else {
                        Label("Écouteurs détectés : écoute et traduction peuvent se chevaucher.",
                              systemImage: "checkmark.circle")
                            .font(.footnote)
                            .foregroundColor(.green)
                    }

                    DisclosureGroup("Serveur de traduction open source (facultatif)") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("https://mon-serveur.example ou http://192.168.1.2:5000",
                                      text: $translationServerURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Adresse de votre serveur LibreTranslate")
                            if !translationServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                TranslateLiveTranslationBackend.validatedURL(translationServerURL) == nil {
                                Text("Adresse refusée : HTTPS ou HTTP sur le réseau local seulement.")
                                    .foregroundColor(.orange)
                                    .font(.footnote)
                            }
                            Text("Tu peux héberger LibreTranslate / Argos sur ton ordinateur ou ton serveur. "
                                 + "Seul le texte transcrit est envoyé à l'adresse que TU configures. "
                                 + "Aucune API publique payante n'est imposée par Sarah.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text("Les langues réellement traduites dépendent des modèles installés sur ce serveur. "
                                 + "Le serveur et ses modèles doivent respecter leurs licences commerciales.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            if live.isActive {
                                Text("Redémarre Translate Live pour appliquer la nouvelle adresse.")
                                    .font(.caption)
                            }
                        }.padding(.top, 6)
                    }

                    HStack(spacing: 10) {
                        Circle()
                            .fill(live.isListening ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                        Text(live.status).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)

                    if live.waitingTranslations > 0 {
                        Text("Passages en attente de traduction : \(live.waitingTranslations)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if let error = live.errorMessage {
                        Text(error)
                            .foregroundColor(.orange)
                            .font(.footnote)
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
                        Label(
                            live.isActive ? "Arrêter Translate Live" : "Démarrer Translate Live",
                            systemImage: live.isActive ? "stop.circle.fill" : "mic.circle.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(live.isActive ? .red : .cyan)
                    .disabled(!live.isActive && sourceLanguage == targetLanguage)

                    if !live.lastSource.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Texte capté ou converti par Whisper")
                                .font(.caption).foregroundColor(.secondary)
                            Text(live.lastSource)
                        }
                    }

                    if !live.lastTranslation.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Traduction de Yoann")
                                .font(.caption).foregroundColor(.secondary)
                            Text(live.lastTranslation)
                                .font(.title3.weight(.medium))
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }

                    if !live.history.isEmpty {
                        Text("Passages récents").font(.headline)
                        ForEach(live.history) { phrase in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(phrase.source).foregroundColor(.secondary)
                                Text(phrase.translation).fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }

                    Text("Écoute continue tant que le mode est activé, sans minuterie ni quota interne. "
                         + "Traduction segmentée, pas instantanée à zéro milliseconde : le temps varie "
                         + "selon le modèle et l'appareil. Pour hébreu → français au-delà des expressions "
                         + "locales, il faut un véritable modèle de traduction ou un serveur configuré. "
                         + "Les langues et licences doivent être vérifiées avant publication.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
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
        .onAppear {
            live.start(from: sourceLanguage, to: targetLanguage, serverURL: translationServerURL)
        }
        .onDisappear { live.stop() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification
        )) { _ in live.stop() }
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
