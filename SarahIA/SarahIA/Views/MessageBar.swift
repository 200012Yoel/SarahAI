import SwiftUI

/// Barre de saisie inspirée du comportement ChatGPT :
/// - micro = dictée locale dans la barre ;
/// - le carré arrête la dictée et remet le texte dans le champ ;
/// - la flèche envoie directement la transcription ;
/// - le bouton waveform ouvre le vrai mode vocal Sarah.
@available(iOS 14.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void

    // IMPORTANT : ne jamais instancier ObservableSpeechRecognizer/AVAudioEngine
    // pendant la construction de la vue. Sur certaines versions iOS 27, créer le
    // pipeline Speech avant toute action utilisateur peut fermer le processus au
    // démarrage. Le moteur vocal est donc créé uniquement quand on touche le micro.
    @State private var isDictating = false
    @State private var textBeforeDictation = ""
    @State private var dictationMicLevel: Float = 0.0
    @State private var dictationLiveText: String = ""

    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onOpenVoiceOrb: @escaping () -> Void,
        onOpenVAICoding: @escaping () -> Void
    ) {
        self._text = text
        self._activeAgent = activeAgent
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
    }

    public var body: some View {
        Group {
            if isDictating {
                dictationBar
            } else {
                standardBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerListeningChanged"))) { _ in
            guard isDictating else { return }
            let recognizer = AppleSpeechRecognizer.shared
            dictationLiveText = recognizer.currentLiveText
            dictationMicLevel = recognizer.micEnergyLevel

            // Une interruption système ne doit jamais laisser l'interface bloquée
            // en « transcription en cours ».
            if !recognizer.isListening {
                commitDictationToComposer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"))) { _ in
            guard isDictating else { return }
            let recognizer = AppleSpeechRecognizer.shared
            dictationMicLevel = recognizer.micEnergyLevel
            dictationLiveText = recognizer.currentLiveText
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerStateChanged"))) { _ in
            guard isDictating else { return }
            let recognizer = AppleSpeechRecognizer.shared
            dictationLiveText = recognizer.currentLiveText
            if case .error = recognizer.state {
                // Autorisation refusée, route audio indisponible, etc. : on sort
                // immédiatement de l'état dictée sans effacer le texte existant.
                recognizer.stopListening()
                isDictating = false
                dictationMicLevel = 0.0
                text = textBeforeDictation
            }
        }
        .onDisappear {
            if isDictating {
                AppleSpeechRecognizer.shared.stopListening()
                isDictating = false
                dictationMicLevel = 0.0
            }
        }
    }

    private var standardBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Demander à \(activeAgent.displayName)...", text: $text, onCommit: {
                    submitMessage()
                })
                .foregroundColor(.white)
                .accentColor(.blue)
                .font(.system(size: 15))

                Button(action: startDictation) {
                    Image(systemName: "mic")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Dicter un message")
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(white: 0.15))
            .clipShape(Capsule())

            let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(action: {
                if hasText {
                    submitMessage()
                } else {
                    HapticService.shared.buttonTap()
                    onOpenVoiceOrb()
                }
            }) {
                Image(systemName: hasText ? "arrow.up" : "waveform")
                    .font(.system(size: 18, weight: hasText ? .bold : .regular))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .background(hasText ? Color.blue : Color(white: 0.15))
            .clipShape(Circle())
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(hasText ? "Envoyer" : "Mode vocal Sarah")
        }
    }

    /// État compact affiché pendant la dictée, calqué sur la logique montrée dans
    /// la capture : annuler, vraie onde micro, terminer, envoyer.
    private var dictationBar: some View {
        HStack(spacing: 10) {
            Button(action: cancelDictation) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Annuler la dictée")

            VStack(spacing: 3) {
                LiveMicrophoneWaveform(level: dictationMicLevel)
                    .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)

                Text(currentRecognizedText.isEmpty ? "Transcription en cours" : "Je t’écoute…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button(action: { finishDictation(sendImmediately: false) }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Terminer la dictée")

            Button(action: { finishDictation(sendImmediately: true) }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.orange))
            }
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel("Envoyer la dictée")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var currentRecognizedText: String {
        let live = AppleSpeechRecognizer.shared.currentLiveText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return dictationLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startDictation() {
        HapticService.shared.buttonTap()

        // C'est volontairement le premier accès au moteur Speech depuis MessageBar.
        // Rien de vocal n'est créé tant que l'utilisateur n'appuie pas sur le micro.
        let recognizer = AppleSpeechRecognizer.shared
        if recognizer.isListening {
            recognizer.stopListening()
        }

        textBeforeDictation = text.trimmingCharacters(in: .whitespacesAndNewlines)
        dictationLiveText = ""
        dictationMicLevel = 0.0
        isDictating = true
        recognizer.startListening(autoFinalizeOnSilence: false)
    }

    private func finishDictation(sendImmediately: Bool) {
        HapticService.shared.buttonTap()
        let recognized = currentRecognizedText
        AppleSpeechRecognizer.shared.stopListening()
        isDictating = false
        dictationMicLevel = 0.0

        let finalText = mergedText(prefix: textBeforeDictation, dictated: recognized)
        text = finalText

        if sendImmediately && !finalText.isEmpty {
            onSend(finalText)
            text = ""
        }
    }

    private func commitDictationToComposer() {
        let recognized = currentRecognizedText
        let finalText = mergedText(prefix: textBeforeDictation, dictated: recognized)
        text = finalText
        isDictating = false
        dictationMicLevel = 0.0
    }

    private func cancelDictation() {
        HapticService.shared.buttonTap()
        AppleSpeechRecognizer.shared.stopListening()
        isDictating = false
        dictationMicLevel = 0.0
        text = textBeforeDictation
    }

    private func mergedText(prefix: String, dictated: String) -> String {
        let lhs = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = dictated.trimmingCharacters(in: .whitespacesAndNewlines)
        if lhs.isEmpty { return rhs }
        if rhs.isEmpty { return lhs }
        return lhs + " " + rhs
    }

    private func submitMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HapticService.shared.buttonTap()
            onSend(trimmed)
            text = ""
        }
    }
}

/// Visualisation basée uniquement sur le niveau RMS réel du microphone.
/// Aucune barre aléatoire : quand la voix monte, les barres montent réellement.
@available(iOS 14.0, *)
private struct LiveMicrophoneWaveform: View {
    let level: Float

    private let weights: [CGFloat] = [
        0.38, 0.62, 0.90, 0.55, 0.74, 1.00, 0.66, 0.44,
        0.82, 0.58, 0.96, 0.70, 0.48, 0.88, 0.64, 1.00,
        0.60, 0.78, 0.50, 0.92, 0.68, 0.42
    ]

    var body: some View {
        GeometryReader { geo in
            let normalized = CGFloat(max(0.0, min(1.0, level)))
            HStack(alignment: .center, spacing: 3) {
                ForEach(weights.indices, id: \.self) { index in
                    let height = max(4, min(geo.size.height, 4 + normalized * geo.size.height * weights[index]))
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 3, height: height)
                        .animation(.linear(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
