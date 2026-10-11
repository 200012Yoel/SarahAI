import SwiftUI
import UIKit

/// Yoann translates audio coming FROM A COMPUTER or TV through the iPhone mic.
@available(iOS 16.2, *)
public struct YoannTranslateLiveView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var live = YoannTranslateLiveService()
    @State private var sourceLanguage: String
    @State private var targetLanguage: String

    public init(initialSource: String = "he", initialTarget: String = "fr") {
        _sourceLanguage = State(initialValue: initialSource)
        _targetLanguage = State(initialValue: initialTarget)
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 48))
                            .foregroundColor(.cyan)
                            .accessibilityHidden(true)
                        Text("Yoann · Translate Live")
                            .font(.title2.bold())
                        Text("Votre ordinateur parle. L’iPhone écoute et traduit à voix haute.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    VStack(spacing: 12) {
                        languagePicker("Langue entendue", selected: $sourceLanguage)
                        languagePicker("Traduction sur l’iPhone", selected: $targetLanguage)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                    if targetLanguage == "he" {
                        Label(
                            "La traduction vers l’hébreu est affichée en texte. La voix hébraïque n’est pas encore installée.",
                            systemImage: "text.bubble"
                        )
                        .font(.footnote)
                        .foregroundColor(.orange)
                    }

                    Label(
                        "Placez l’iPhone près des haut-parleurs du PC, puis lancez votre vidéo sur le PC. Aucune connexion à la vidéo n’est nécessaire.",
                        systemImage: "desktopcomputer"
                    )
                    .font(.subheadline)

                    Label(
                        "Pour empêcher la boucle audio, Yoann coupe temporairement le micro pendant qu’il lit la traduction, puis reprend automatiquement l’écoute.",
                        systemImage: "speaker.slash"
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Circle()
                            .fill(live.isSpeakingTranslation ? Color.orange : live.isListening ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                        Text(live.status).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)

                    if let error = live.errorMessage {
                        Text(error)
                            .foregroundColor(.orange)
                            .font(.footnote)
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    Button {
                        if live.isActive {
                            live.stop()
                        } else {
                            live.start(from: sourceLanguage, to: targetLanguage)
                        }
                    } label: {
                        Label(live.isActive ? "Arrêter Translate Live" : "Démarrer Translate Live",
                              systemImage: live.isActive ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(live.isActive ? .red : .cyan)
                    .disabled(!live.isActive && sourceLanguage == targetLanguage)

                    if !live.lastSource.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Phrase entendue").font(.caption).foregroundColor(.secondary)
                            Text(live.lastSource).font(.body)
                        }
                    }
                    if !live.lastTranslation.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Traduction de Yoann").font(.caption).foregroundColor(.secondary)
                            Text(live.lastTranslation).font(.title3.weight(.medium))
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }

                    if !live.history.isEmpty {
                        Text("Derniers passages").font(.headline)
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

                    Text("Note : le moteur de traduction existant utilise un dictionnaire local, puis peut faire appel à un service Internet pour les phrases complexes. Les autorisations de redistribution commerciale et la traduction de longues émissions doivent être validées avant publication.")
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
        }
        .onAppear {
            live.start(from: sourceLanguage, to: targetLanguage)
        }
        .onDisappear {
            live.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            live.stop()
        }
    }

    private func languagePicker(_ title: String, selected: Binding<String>) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Picker(title, selection: selected) {
                ForEach(YoannTranslateLiveService.Language.available) { item in
                    Text(item.label).tag(item.id)
                }
            }
            .labelsHidden()
            .onChange(of: selected.wrappedValue) { _ in
                if live.isActive {
                    live.start(from: sourceLanguage, to: targetLanguage)
                }
            }
        }
    }
}
