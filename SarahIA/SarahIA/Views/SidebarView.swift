import SwiftUI

/// Vue latérale (Drawer Sidebar) native iOS avec recherche, discussions épinglées/récentes et actions contextuelles.
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool
    @State private var conversationToRename: Conversation? = nil
    @State private var newTitleText: String = ""
    @State private var isShowingRenameAlert: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Titre "Sarah IA" + Bouton Recherche
            HStack {
                Text("Sarah IA")
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                
                Spacer()
                
                Button(action: {
                    HapticService.shared.buttonTap()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.isSearchActive.toggle()
                        if !viewModel.isSearchActive {
                            viewModel.searchQuery = ""
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 6)
            
            // Barre de Recherche extensible
            if viewModel.isSearchActive {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                    
                    TextField("Rechercher", text: $viewModel.searchQuery)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                .cornerRadius(12)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Liste scrollable des discussions
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    // 1. SECTION ÉPINGLÉS
                    if !viewModel.filteredPinnedConversations.isEmpty {
                        Text("Épinglés")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                            .tracking(-0.3)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                        
                        ForEach(viewModel.filteredPinnedConversations) { conv in
                            conversationRow(conv)
                        }
                    }
                    
                    // 2. SECTION RÉCENTS
                    Text("Récents")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(-0.3)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                    
                    if viewModel.filteredRecentConversations.isEmpty {
                        Text(viewModel.searchQuery.isEmpty ? "Aucune discussion." : "Aucun résultat.")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.58))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                    } else {
                        ForEach(viewModel.filteredRecentConversations) { conv in
                            conversationRow(conv)
                        }
                    }
                }
                .padding(.bottom, 120) // Espace pour la barre inférieure
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert("Renommer la discussion", isPresented: $isShowingRenameAlert) {
            TextField("Nouveau titre", text: $newTitleText)
            Button("Annuler", role: .cancel) {
                conversationToRename = nil
            }
            Button("Renommer") {
                if let conv = conversationToRename {
                    viewModel.renameConversation(conv, newTitle: newTitleText)
                }
                conversationToRename = nil
            }
        } message: {
            Text("Saisissez un nouveau titre pour cette discussion.")
        }
    }
    
    // MARK: - Ligne de discussion individuelle
    
    @ViewBuilder
    private func conversationRow(_ conv: Conversation) -> some View {
        let isSelected = (viewModel.currentConversationId == conv.id)
        
        Button(action: {
            viewModel.selectConversation(conv)
        }) {
            HStack(spacing: 16) {
                if conv.isPinned {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Text(conv.title)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(isSelected ? Color.white.opacity(0.10) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                viewModel.togglePinConversation(conv)
            } label: {
                Label(conv.isPinned ? "Détacher" : "Épingler", systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            
            Button {
                conversationToRename = conv
                newTitleText = conv.title
                isShowingRenameAlert = true
            } label: {
                Label("Renommer", systemImage: "pencil")
            }
            
            Button {
                viewModel.archiveConversation(conv)
            } label: {
                Label("Archiver", systemImage: "archivebox")
            }
            
            Button(role: .destructive) {
                viewModel.deleteConversation(conv)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Barre Inférieure (Pill Chat + Bouton Réglages)
    
    private var bottomBar: some View {
        HStack {
            // Bouton Pill Bleu "Chat" pour nouvelle discussion
            Button(action: {
                viewModel.startNewChat()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("Chat")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color(red: 0.04, green: 0.52, blue: 1.0)) // #0a84ff
                )
                .shadow(color: Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.4), radius: 10, x: 0, y: 4)
            }
            
            Spacer()
            
            // Bouton Paramètres Circulaire
            Button(action: {
                HapticService.shared.buttonTap()
                isShowingSettings = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.85),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
