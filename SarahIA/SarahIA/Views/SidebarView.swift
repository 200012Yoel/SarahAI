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
    
    @State private var conversationToDelete: Conversation? = nil
    @State private var isShowingDeleteOneAlert: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width <= 360
            let sidebarWidth = max(220, min(geo.size.width * 0.55, 290))
            let horizontalPadding: CGFloat = isCompact ? 12 : 14
            
            ZStack(alignment: .topLeading) {
                Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Header: Titre "Sarah IA" avec icône étincelle
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                        
                        Text("Sarah IA")
                            .font(.system(size: isCompact ? 20 : 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, max(28, geo.safeAreaInsets.top + 18))
                    .padding(.bottom, 14)
                    
                    // 2. Liste Déroulante des Discussions (Boutons grands, aérés et confortables)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Discussions")
                                    .font(.system(size: isCompact ? 15 : 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.85))
                                
                                Spacer()
                                
                                Text("\(viewModel.conversations.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.8))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                            
                            if viewModel.conversations.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color.gray.opacity(0.35))
                                        .padding(.top, 24)
                                    
                                    Text("Aucune discussion")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                ForEach(viewModel.conversations) { conv in
                                    conversationRow(conv, isCompact: isCompact, padding: horizontalPadding)
                                }
                                
                                // Bouton "Tout effacer" en bas de la liste des discussions
                                Button(action: {
                                    HapticService.shared.buttonTap()
                                    isShowingClearAllAlert = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Effacer l'historique")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(Color.red.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(ScaleBounceButtonStyle())
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, 8)
                            }
                            
                            Spacer().frame(height: 110)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(width: sidebarWidth, alignment: .leading)
                
                // 3. Bas de page : Bouton bleu "Nouveau Tchat" remonté, élégant et très arrondi
                VStack(spacing: 0) {
                    Spacer()
                    
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.startNewChat()
                        viewModel.switchToChat()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Nouveau Tchat")
                                .font(.system(size: isCompact ? 14 : 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 13 : 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.0, green: 0.40, blue: 0.90)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.45), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, max(36, geo.safeAreaInsets.bottom + 28))
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.0), Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.95), Color(red: 0.07, green: 0.07, blue: 0.09)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(red: 0.04, green: 0.52, blue: 1.0) : Color.white.opacity(0.08))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.7))
                }
                
                Text(conv.title)
                    .font(.system(size: isCompact ? 15 : 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, padding)
        // Menu contextuel et appui long pour supprimer la discussion
        .contextMenu {
            Button(role: .destructive, action: {
                HapticService.shared.memoryDeleted()
                viewModel.deleteConversation(conv)
            }) {
                Label("Supprimer la discussion", systemImage: "trash")
            }
        }
    }
}
