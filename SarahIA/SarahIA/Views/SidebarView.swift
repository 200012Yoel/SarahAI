import SwiftUI

/// Sidebar (Menu Latéral) Pixel-Perfect 100% Natif SwiftUI avec accès direct à :
/// - Les 4 Agents (Sarah, Tom, Raphaël, Yohan)
/// - Le Studio VAI Coding
/// - L'Orbe Vocal Plein Écran
/// - Gestion instantanée des discussions multiples
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool
    
    @State private var conversationToRename: Conversation? = nil
    @State private var newTitleText: String = ""
    @State private var isShowingRenameAlert: Bool = false
    @State private var isShowingClearAllAlert: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width <= 360
            let sidebarWidth = max(250, min(geo.size.width * 0.82, 330))
            let horizontalPadding: CGFloat = isCompact ? 14 : 20
            
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Header: Titre "Sarah IA" + Boutons d'actions
                    HStack(alignment: .center, spacing: 8) {
                        Text("Sarah IA")
                            .font(.system(size: isCompact ? 22 : 24, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Bouton Vider tout
                        if !viewModel.conversations.isEmpty {
                            Button(action: {
                                HapticService.shared.buttonTap()
                                isShowingClearAllAlert = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.16, green: 0.12, blue: 0.12))
                                        .frame(width: isCompact ? 34 : 38, height: isCompact ? 34 : 38)
                                    
                                    Image(systemName: "trash")
                                        .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                        .foregroundColor(Color.red.opacity(0.85))
                                }
                            }
                            .buttonStyle(ScaleBounceButtonStyle())
                        }
                        
                        // Bouton recherche
                        Button(action: {
                            HapticService.shared.buttonTap()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.isSearchActive.toggle()
                                if !viewModel.isSearchActive {
                                    viewModel.searchQuery = ""
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: isCompact ? 34 : 38, height: isCompact ? 34 : 38)
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, max(16, geo.safeAreaInsets.top + 8))
                    .padding(.bottom, 8)
                    
                    // 2. Section des 4 Agents Rapides dans le Menu
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AGENTS AUTONOMES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 4)
                        
                        ForEach(AgentType.allCases) { agent in
                            Button(action: {
                                HapticService.shared.buttonTap()
                                viewModel.activeAgent = agent
                                viewModel.closeDrawer()
                            }) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(agent.themeColor)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(agent.rawValue)
                                        .font(.system(size: 14, weight: viewModel.activeAgent == agent ? .bold : .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if viewModel.activeAgent == agent {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(agent.themeColor)
                                    }
                                }
                                .padding(.horizontal, horizontalPadding)
                                .padding(.vertical, 7)
                                .background(viewModel.activeAgent == agent ? Color.white.opacity(0.08) : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal, horizontalPadding)
                    
                    // 3. Liste Déroulante des Discussions
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Section Récents
                            HStack {
                                Text("Discussions")
                                    .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(viewModel.conversations.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.gray.opacity(0.8))
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                            
                            if viewModel.conversations.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .padding(.top, 16)
                                    
                                    Text("0 discussion")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            } else {
                                ForEach(viewModel.conversations) { conv in
                                    conversationRow(conv, isCompact: isCompact, padding: horizontalPadding)
                                }
                            }
                            
                            Spacer().frame(height: 110)
                        }
                    }
                }
                .frame(width: sidebarWidth, alignment: .leading)
                
                // 4. Barre Inférieure (.sb-bottom) avec VAI Coding & Réglages
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack(spacing: isCompact ? 6 : 8) {
                        // Bouton Nouveau Chat
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.startNewChat()
                            viewModel.switchToChat()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                Text("Nouveau")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.04, green: 0.52, blue: 1.0))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        Spacer()
                        
                        let btnSize: CGFloat = isCompact ? 32 : 36
                        
                        // Bouton VAI Coding 💻
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.closeDrawer()
                            viewModel.isShowingVAICodingStudio = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "curlybraces")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        // Bouton Voice Orb 🔮
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.closeDrawer()
                            viewModel.isShowingVoiceOrbModal = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(viewModel.activeAgent.themeColor)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        // Bouton Paramètres ⚙️
                        Button(action: {
                            HapticService.shared.buttonTap()
                            isShowingSettings = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: isCompact ? 12 : 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, isCompact ? 8 : 12)
                    .background(Color.black.opacity(0.95))
                }
                .frame(width: sidebarWidth)
            }
            .frame(width: sidebarWidth)
        }
        .alert(isPresented: $isShowingClearAllAlert) {
            Alert(
                title: Text("Supprimer toutes les discussions ?"),
                message: Text("Cette action réinitialisera l'historique à 0 discussion."),
                primaryButton: .destructive(Text("Tout supprimer")) {
                    viewModel.deleteAllConversations()
                },
                secondaryButton: .cancel(Text("Annuler"))
            )
        }
    }
    
    @ViewBuilder
    private func conversationRow(_ conv: Conversation, isCompact: Bool, padding: CGFloat) -> some View {
        let isSelected = (viewModel.currentConversationId == conv.id)
        
        Button(action: {
            HapticService.shared.buttonTap()
            viewModel.selectConversation(conv)
            viewModel.closeDrawer()
        }) {
            HStack(spacing: isCompact ? 10 : 14) {
                Text(conv.title)
                    .font(.system(size: isCompact ? 14 : 15, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, padding)
            .padding(.vertical, isCompact ? 9 : 11)
            .background(isSelected ? Color.white.opacity(0.09) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
