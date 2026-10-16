import SwiftUI

/// Écran « Traduction en direct ».
/// - En haut, en grand : la traduction (ex. français).
/// - En bas : ce qui est entendu, dans sa langue (ex. hébreu, aligné à droite).
/// L'écoute est continue ; Sarah ne retraduit jamais sa propre voix.
@available(iOS 15.0, *)
public struct LiveTranslationView: View {
    @ObservedObject private var session = LiveTranslationSession.shared
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.0, green: 0.85, blue: 1.0)
    private let accentSecondary = Color(red: 0.85, green: 0.55, blue: 1.0)
    private let panelBackground = Color.white.opacity(0.06)

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 12) {
                header
                languageBar

                // Traduction (haut, en grand)
                transcriptPanel(
                    title: "\(session.languagePair.targetFlag) \(session.languagePair.targetName)",
                    showsTranslation: true
                )
                .frame(maxHeight: .infinity)

                // Texte entendu (bas)
                transcriptPanel(
                    title: "\(session.languagePair.sourceFlag) \(session.languagePair.sourceName) — entendu",
                    showsTranslation: false
                )
                .frame(maxHeight: .infinity)

                controls
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .onAppear { session.start() }
        .onDisappear { session.stop() }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                HapticService.shared.buttonTap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .accessibilityLabel("Fermer")

            VStack(alignment: .leading, spacing: 2) {
                Text("Traduction en direct")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                session.clearTranscript()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Effacer")
        }
        .padding(.top, 8)
    }

    private var statusText: String {
        if let error = session.lastError { return error }
        guard session.isActive else { return "Démarrage…" }
        if session.isMuted { return "Micro coupé" }
        return "À l'écoute · \(session.recognitionModeLabel)"
    }

    // MARK: - Langues

    private var languageBar: some View {
        HStack(spacing: 10) {
            languageChip(session.languagePair.sourceFlag, session.languagePair.sourceName)
            Button {
                session.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 40, height: 36)
                    .background(Capsule().fill(accent.opacity(0.15)))
            }
            .accessibilityLabel("Inverser les langues")
            languageChip(session.languagePair.targetFlag, session.languagePair.targetName)
        }
    }

    private func languageChip(_ flag: String, _ name: String) -> some View {
        HStack(spacing: 6) {
            Text(flag)
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(panelBackground))
    }

    // MARK: - Panneaux de texte

    private func transcriptPanel(title: String, showsTranslation: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if session.items.isEmpty {
                            Text(showsTranslation
                                 ? "Parle normalement, la traduction s'affiche ici."
                                 : "Ce que Sarah entend s'affiche ici.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        }

                        ForEach(session.items) { item in
                            line(for: item, showsTranslation: showsTranslation, isLatest: item.id == session.items.last?.id)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .onChange(of: session.items.last?.id) { _ in
                    scrollToLatest(proxy)
                }
                .onChange(of: session.items.last?.translatedText) { _ in
                    scrollToLatest(proxy)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(panelBackground))
    }

    @ViewBuilder
    private func line(for item: LiveTranscriptItem, showsTranslation: Bool, isLatest: Bool) -> some View {
        if !item.isSpeech {
            // Message d'information de Sarah (ex. mode hors ligne) : seulement dans le panneau du haut
            if showsTranslation {
                Label(item.originalText, systemImage: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.orange.opacity(0.9))
            }
        } else {
            let language = showsTranslation ? item.targetLanguage : item.originalLanguage
            let text = showsTranslation ? item.translatedText : item.originalText
            let isRTL = LiveLanguagePair.isRightToLeft(language)

            VStack(alignment: isRTL ? .trailing : .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: fontSize(showsTranslation: showsTranslation, isLatest: isLatest),
                                  weight: isLatest ? .semibold : .regular))
                    .foregroundColor(textColor(showsTranslation: showsTranslation, item: item, isLatest: isLatest))
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                    .animation(.easeOut(duration: 0.15), value: text)

                if showsTranslation, let attribution = item.attribution {
                    Text(attribution)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
    }

    private func fontSize(showsTranslation: Bool, isLatest: Bool) -> CGFloat {
        switch (showsTranslation, isLatest) {
        case (true, true): return 26
        case (true, false): return 17
        case (false, true): return 19
        case (false, false): return 14
        }
    }

    private func textColor(showsTranslation: Bool, item: LiveTranscriptItem, isLatest: Bool) -> Color {
        let base = showsTranslation ? accent : accentSecondary
        if !isLatest { return .white.opacity(0.55) }
        return item.isFinal ? .white : base
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let last = session.items.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }

    // MARK: - Contrôles

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton(
                icon: session.isMuted ? "mic.slash.fill" : "mic.fill",
                label: session.isMuted ? "Micro coupé" : "Micro",
                active: !session.isMuted
            ) {
                session.toggleMute()
            }

            // Indicateur d'écoute (réagit à la voix)
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18 + Double(session.micEnergy) * 0.5))
                    .frame(width: 64 + CGFloat(session.micEnergy) * 18, height: 64 + CGFloat(session.micEnergy) * 18)
                    .animation(.easeOut(duration: 0.08), value: session.micEnergy)
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 84, height: 84)
            .accessibilityHidden(true)

            controlButton(
                icon: session.languagePair.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: session.languagePair.isVoiceEnabled ? "Voix" : "Muet",
                active: session.languagePair.isVoiceEnabled
            ) {
                session.toggleVoice()
            }
        }
        .padding(.top, 4)
    }

    private func controlButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(active ? .white : .red)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.white.opacity(active ? 0.12 : 0.08)))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .accessibilityLabel(label)
    }
}
