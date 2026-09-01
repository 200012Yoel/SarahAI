import SwiftUI

/// Écran d'Appel Vocal WebRTC avec Traduction Bilingue en Direct (SwiftUI)
@available(iOS 14.0, *)
public struct VoiceCallScreenView: View {
    @ObservedObject var callManager = WebRTCVoiceCallManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isShowingLanguageSheet = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Fond sombre avec lueurs d'ondes vocales
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            // Effet d'ondes néon réactives au micro
            backgroundEnergyGlow
            
            VStack(spacing: 0) {
                // 1. En-tête : Badge Chiffrement & Contact
                callHeaderView
                    .padding(.top, 14)
                
                // 2. Sélecteur Rapide de Langues & Mode Traduction
                languageControlBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // 3. Zone Centrale : Flux de Sous-Titres Bilingues en Direct
                liveTranscriptFeed
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                
                // 4. Barre de Contrôles d'Appel Inférieure
                callControlsBar
                    .padding(.bottom, 24)
                    .padding(.top, 12)
            }
        }
        .onChange(of: callManager.callState) { state in
            if state == .idle {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // MARK: - Lueurs d'Énergie Audio
    private var backgroundEnergyGlow: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(Double(callManager.micEnergy) * 0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 50)
                .offset(y: -80)
            
            Circle()
                .fill(Color(red: 0.55, green: 0.40, blue: 1.0).opacity(Double(callManager.micEnergy) * 0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(y: 120)
        }
    }
    
    // MARK: - En-tête d'Appel
    private var callHeaderView: some View {
        VStack(spacing: 8) {
            // Badge Chiffrement WebRTC
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                Text("WebRTC P2P Sécurisé · Chiffré de bout en bout")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.12))
            .cornerRadius(12)
            
            // Avatar & Ondes
            ZStack {
                Circle()
                    .stroke(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.4), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(1.0 + CGFloat(callManager.micEnergy) * 0.3)
                    .animation(.easeInOut(duration: 0.15), value: callManager.micEnergy)
                
                Circle()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    .frame(width: 70, height: 70)
                
                Text(callManager.currentContact?.avatarEmoji ?? "👤")
                    .font(.system(size: 32))
            }
            
            // Nom du Contact & Rôle
            Text(callManager.currentContact?.name ?? "Correspondant")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            // État & Durée
            HStack(spacing: 6) {
                Circle()
                    .fill(callStateColor)
                    .frame(width: 8, height: 8)
                
                Text(callStateText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                
                if callManager.callState.isCallActive {
                    Text("•")
                        .foregroundColor(.gray)
                    Text(callManager.formattedDuration)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Barre de Sélection des Langues & Traduction
    private var languageControlBar: some View {
        HStack(spacing: 10) {
            // Langue Source
            Menu {
                Button("🇫🇷 Français") { callManager.setLocalLanguage("fr") }
                Button("🇬🇧 English") { callManager.setLocalLanguage("en") }
                Button("🇮🇱 עברית") { callManager.setLocalLanguage("he") }
            } label: {
                HStack(spacing: 4) {
                    Text(callManager.languagePair.localFlag)
                    Text(callManager.languagePair.localLanguage.uppercased())
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
            
            Image(systemName: "arrow.right.arrow.left")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
            
            // Langue Cible
            Menu {
                Button("🇬🇧 English") { callManager.setTargetLanguage("en") }
                Button("🇮🇱 עברית") { callManager.setTargetLanguage("he") }
                Button("🇫🇷 Français") { callManager.setTargetLanguage("fr") }
            } label: {
                HStack(spacing: 4) {
                    Text(callManager.languagePair.remoteFlag)
                    Text(callManager.languagePair.remoteLanguage.uppercased())
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // Toggle Traduction Vocale Injectée
            Button(action: {
                callManager.toggleVoiceTranslation()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: callManager.languagePair.isVoiceTranslationEnabled ? "waveform.badge.magnifyingglass" : "waveform.slash")
                        .font(.system(size: 11))
                    Text(callManager.languagePair.isVoiceTranslationEnabled ? "Voix IA Active" : "Bypass Direct")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    callManager.languagePair.isVoiceTranslationEnabled ?
                    Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.20) :
                    Color.white.opacity(0.08)
                )
                .foregroundColor(
                    callManager.languagePair.isVoiceTranslationEnabled ?
                    Color(red: 0.0, green: 0.85, blue: 1.0) :
                    .gray
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            callManager.languagePair.isVoiceTranslationEnabled ?
                            Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.4) :
                            Color.clear,
                            lineWidth: 1
                        )
                )
            }
        }
        .padding(8)
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        .cornerRadius(12)
    }
    
    // MARK: - Flux des Sous-Titres Bilingues
    private var liveTranscriptFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if callManager.transcriptItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("Parlez naturellement...\nLa traduction vocale en temps réel est active.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(callManager.transcriptItems) { item in
                            transcriptBubble(for: item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: callManager.transcriptItems.count) { _ in
                if let last = callManager.transcriptItems.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Bulle de Transcription Bilingue
    private func transcriptBubble(for item: CallTranscriptItem) -> some View {
        HStack {
            if item.isLocalSpeaker { Spacer() }
            
            VStack(alignment: item.isLocalSpeaker ? .trailing : .leading, spacing: 4) {
                // Tag Locuteur & Langues
                HStack(spacing: 4) {
                    Text(item.isLocalSpeaker ? "🇫🇷 Vous" : "🌐 \(callManager.currentContact?.name ?? "Contact")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if item.isLocalSpeaker && callManager.languagePair.isVoiceTranslationEnabled {
                        Text("• Voix Synthétisée 🔊")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
                    }
                }
                
                // Texte Original
                Text(item.originalText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(item.isLocalSpeaker ? .trailing : .leading)
                
                // Texte Traduit (Mise en avant)
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(item.isLocalSpeaker ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color(red: 0.85, green: 0.55, blue: 1.0))
                    Text(item.translatedText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item.isLocalSpeaker ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color(red: 0.85, green: 0.55, blue: 1.0))
                        .multilineTextAlignment(item.isLocalSpeaker ? .trailing : .leading)
                }
            }
            .padding(10)
            .background(
                item.isLocalSpeaker ?
                Color(red: 0.12, green: 0.16, blue: 0.24) :
                Color(red: 0.15, green: 0.12, blue: 0.22)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        item.isLocalSpeaker ?
                        Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.3) :
                        Color(red: 0.85, green: 0.55, blue: 1.0).opacity(0.3),
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: 280, alignment: item.isLocalSpeaker ? .trailing : .leading)
            
            if !item.isLocalSpeaker { Spacer() }
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - Barre de Contrôles d'Appel (Mute, Speaker, Traduction, Raccrocher)
    private var callControlsBar: some View {
        HStack(spacing: 24) {
            // Bouton Mute Micro
            Button(action: {
                callManager.toggleMute()
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(callManager.isMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.12))
                            .frame(width: 54, height: 54)
                        Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(callManager.isMuted ? .red : .white)
                    }
                    Text(callManager.isMuted ? "Micro Muet" : "Micro")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            // Bouton Haut-Parleur
            Button(action: {
                callManager.toggleSpeaker()
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(callManager.isSpeakerOn ? Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.2) : Color.white.opacity(0.12))
                            .frame(width: 54, height: 54)
                        Image(systemName: callManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 20))
                            .foregroundColor(callManager.isSpeakerOn ? Color(red: 0.0, green: 0.85, blue: 1.0) : .white)
                    }
                    Text("Haut-Parleur")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            // Bouton Raccrocher
            Button(action: {
                callManager.endCall()
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.red.opacity(0.4), radius: 8)
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                    Text("Raccrocher")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var callStateColor: Color {
        switch callManager.callState {
        case .connected:
            return Color(red: 0.15, green: 0.85, blue: 0.40)
        case .dialing, .ringing:
            return .orange
        case .translating:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .reconnecting:
            return .yellow
        case .ended, .idle:
            return .gray
        }
    }
    
    private var callStateText: String {
        switch callManager.callState {
        case .dialing:
            return "Numérotation..."
        case .ringing:
            return "Sonnerie WebRTC..."
        case .connected:
            return "En communication"
        case .translating:
            return "Traduction en cours"
        case .reconnecting:
            return "Reconnexion..."
        case .ended(let reason):
            return reason
        case .idle:
            return "Prêt"
        }
    }
}
