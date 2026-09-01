import SwiftUI

/// Écran Talkie-Walkie & Vocal WhatsApp avec Traduction Vocale Trilatérale (FR ⇄ EN ⇄ HE)
/// - Piloté par **Nathan** pour l'envoi sécurisé WhatsApp (anti-ban) et prononcé par **Yoann** en hébreu/français
@available(iOS 14.0, *)
public struct WhatsAppVoiceCallView: View {
    @ObservedObject var walkieManager = OpenWAVoiceWalkieTalkieManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isPressingTalkie: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Fond sombre néon
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            // Halo lumineux réactif au micro
            backgroundAura
            
            VStack(spacing: 0) {
                // 1. Barre Supérieure & Badge Multi-Agents (Nathan & Yoann)
                topHeaderView
                    .padding(.top, 14)
                
                // 2. Sélecteur de Langues Tri-Directionnel (FR / EN / HE)
                languageSelectorBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // 3. Zone Centrale : Flux des Vocaux & Sous-Titres Bilingues
                transcriptFeedView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                
                // 4. Zone Inférieure : Bouton Talkie-Walkie & Envoi Nathan
                walkieTalkieControlsView
                    .padding(.bottom, 24)
                    .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Halo d'Énergie Audio
    private var backgroundAura: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.15, green: 0.85, blue: 0.40).opacity(Double(walkieManager.micEnergy) * 0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 50)
                .offset(y: -60)
            
            Circle()
                .fill(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(Double(walkieManager.micEnergy) * 0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(y: 140)
        }
    }
    
    // MARK: - En-tête Supérieur
    private var topHeaderView: some View {
        VStack(spacing: 8) {
            // Barre d'actions Fermer
            HStack {
                Button(action: {
                    HapticService.shared.buttonTap()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Badge Dual-Agent Nathan + Yoann
                HStack(spacing: 6) {
                    Text("🤖 Nathan (Envoi WA)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 1.0))
                    Text("•")
                        .foregroundColor(.gray)
                    Text("🇮🇱 Yoann (Voix & Traduction)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 16)
            
            // Avatar & Info Contact
            ZStack {
                Circle()
                    .stroke(Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.4), lineWidth: 2)
                    .frame(width: 76, height: 76)
                    .scaleEffect(1.0 + CGFloat(walkieManager.micEnergy) * 0.3)
                    .animation(.easeInOut(duration: 0.12), value: walkieManager.micEnergy)
                
                Circle()
                    .fill(Color(red: 0.12, green: 0.16, blue: 0.14))
                    .frame(width: 66, height: 66)
                
                Text(walkieManager.activeContact?.avatarEmoji ?? "💬")
                    .font(.system(size: 30))
            }
            
            Text(walkieManager.activeContact?.name ?? "Contact WhatsApp")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                Text(walkieManager.lastStatusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Sélecteur de Langues Tri-Directionnel
    private var languageSelectorBar: some View {
        HStack(spacing: 8) {
            // Source
            Menu {
                Button("🇫🇷 Français") { walkieManager.languagePair.localLanguage = "fr" }
                Button("🇬🇧 English") { walkieManager.languagePair.localLanguage = "en" }
                Button("🇮🇱 עברית") { walkieManager.languagePair.localLanguage = "he" }
            } label: {
                HStack(spacing: 4) {
                    Text(walkieManager.languagePair.localFlag)
                    Text(walkieManager.languagePair.localLanguage.uppercased())
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
                .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
            
            // Cible
            Menu {
                Button("🇮🇱 עברית") { walkieManager.languagePair.remoteLanguage = "he" }
                Button("🇬🇧 English") { walkieManager.languagePair.remoteLanguage = "en" }
                Button("🇫🇷 Français") { walkieManager.languagePair.remoteLanguage = "fr" }
            } label: {
                HStack(spacing: 4) {
                    Text(walkieManager.languagePair.remoteFlag)
                    Text(walkieManager.languagePair.remoteLanguage.uppercased())
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
            
            // Badge Vocal Yoann
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
                Text("Voix de Yoann")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.15))
            .cornerRadius(6)
        }
        .padding(8)
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        .cornerRadius(12)
    }
    
    // MARK: - Flux des Vocaux & Sous-Titres Bilingues
    private var transcriptFeedView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if walkieManager.transcriptFeed.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mic.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Maintenez le bouton Talkie-Walkie ci-dessous.\nNathan transmettra le vocal traduit sur WhatsApp.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(walkieManager.transcriptFeed) { item in
                            transcriptCard(for: item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: walkieManager.transcriptFeed.count) { _ in
                if let last = walkieManager.transcriptFeed.last {
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
    
    // Carte de Message Vocal
    private func transcriptCard(for item: CallTranscriptItem) -> some View {
        HStack {
            if item.isLocalSpeaker { Spacer() }
            
            VStack(alignment: item.isLocalSpeaker ? .trailing : .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(item.isLocalSpeaker ? "🇫🇷 Vous" : "🌐 \(walkieManager.activeContact?.name ?? "Contact")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if item.isLocalSpeaker {
                        Text("• Vocal WhatsApp PTT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.40))
                    }
                }
                
                Text(item.originalText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                
                // Traduction par Yoann
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
                    Text(item.translatedText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0))
                }
                
                Button(action: {
                    walkieManager.playTranslatedAudio(text: item.translatedText, language: item.targetLanguage)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("Écouter la voix de Yoann")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(
                item.isLocalSpeaker ?
                Color(red: 0.10, green: 0.18, blue: 0.14) :
                Color(red: 0.14, green: 0.12, blue: 0.20)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        item.isLocalSpeaker ?
                        Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.4) :
                        Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.3),
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: 280, alignment: item.isLocalSpeaker ? .trailing : .leading)
            
            if !item.isLocalSpeaker { Spacer() }
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - Contrôles Talkie-Walkie
    private var walkieTalkieControlsView: some View {
        VStack(spacing: 8) {
            // Bouton Push-To-Talk Principal
            Button(action: {
                if walkieManager.isRecording {
                    walkieManager.stopAndSendPushToTalk()
                } else {
                    walkieManager.startPushToTalk()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(
                            walkieManager.isRecording ?
                            Color.red.opacity(0.5) :
                            Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.4),
                            lineWidth: 4
                        )
                        .frame(width: 86, height: 86)
                        .scaleEffect(walkieManager.isRecording ? 1.0 + CGFloat(walkieManager.micEnergy) * 0.4 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: walkieManager.micEnergy)
                    
                    Circle()
                        .fill(
                            walkieManager.isRecording ?
                            Color.red :
                            Color(red: 0.15, green: 0.85, blue: 0.40)
                        )
                        .frame(width: 72, height: 72)
                        .shadow(
                            color: walkieManager.isRecording ? Color.red.opacity(0.5) : Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.5),
                            radius: 10
                        )
                    
                    Image(systemName: walkieManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(walkieManager.isRecording ? "Enregistrement... Touchez pour envoyer" : "Touchez pour parler (Talkie-Walkie WhatsApp)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(walkieManager.isRecording ? .red : .gray)
        }
    }
}
