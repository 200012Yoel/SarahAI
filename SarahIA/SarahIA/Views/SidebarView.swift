import SwiftUI

/// Sidebar (Menu Latéral) Pixel-Perfect 100% Natif SwiftUI reproduisant fidèlement la maquette HTML/CSS.
@available(iOS 14.0, *)
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
        GeometryReader { geo in
            let sidebarWidth = geo.size.width * 0.78
            
            ZStack(alignment: .topLeading) {
                // Background #000
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header: Titre "Sarah IA" + Bouton Recherche Circulaire 44pt
                    HStack(alignment: .center) {
                        Text("Sarah IA")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .tracking(-0.5)
                        
                        Spacer()
                        
                        // Bouton recherche circulaire 44x44
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
                                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 50)
                    .padding(.bottom, 6)
                    
                    // Barre de Recherche Animée (.sb-search.on)
                    if viewModel.isSearchActive {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                .font(.system(size: 15))
                            
                            TextField("Rechercher", text: $viewModel.searchQuery)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            
                            if !viewModel.searchQuery.isEmpty {
                                Button(action: {
                                    viewModel.searchQuery = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                        .cornerRadius(12)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Liste Déroulante des Discussions (.sb-scroll)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Section Épinglés
                            if !viewModel.filteredPinnedConversations.isEmpty {
                                Text("Épinglés")
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(-0.3)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 10)
                                    .padding(.bottom, 6)
                                
                                ForEach(viewModel.filteredPinnedConversations) { conv in
                                    conversationRow(conv, isPinned: true)
                                }
                            }
                            
                            // Section Récents
                            Text("Récents")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(-0.3)
                                .padding(.horizontal, 24)
                                .padding(.top, viewModel.filteredPinnedConversations.isEmpty ? 10 : 26)
                                .padding(.bottom, 6)
                            
                            if viewModel.filteredRecentConversations.isEmpty {
                                Text(viewModel.searchQuery.isEmpty ? "Aucune discussion." : "Aucun résultat.")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58)) // #8e8e93
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(viewModel.filteredRecentConversations) { conv in
                                    conversationRow(conv, isPinned: false)
                                }
                            }
                            
                            // Espace pour éviter que le contenu ne soit caché par les boutons du bas
                            Spacer()
                                .frame(height: 130)
                        }
                    }
                }
                .frame(width: sidebarWidth, alignment: .leading)
                
                // Barre Inférieure (.sb-bottom) avec dégradé
                VStack {
                    Spacer()
                    
                    HStack {
                        // Bouton Pill Bleu "Chat" (#btnNewChat)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.startNewChat()
                            viewModel.switchToChat()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 20, weight: .semibold))
                                
                                Text("Chat")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.leading, 22)
                            .padding(.trailing, 26)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.04, green: 0.52, blue: 1.0)) // #0a84ff
                            .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        Spacer()
                        
                        // Bouton Circulaire Paramètres (#btnSettings)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            isShowingSettings = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "gearshape")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.95),
                                Color.black
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(width: sidebarWidth)
            }
        }
        // Modale Native de Renommage
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
            Text("Saisissez un nouveau titre.")
        }
    }
    
    // MARK: - Ligne de Discussion (.conv)
    
    @ViewBuilder
    private func conversationRow(_ conv: Conversation, isPinned: Bool) -> some View {
        let isSelected = (viewModel.currentConversationId == conv.id)
        
        Button(action: {
            HapticService.shared.buttonTap()
            viewModel.selectConversation(conv)
            viewModel.closeDrawer()
        }) {
            HStack(spacing: 20) {
                if isPinned {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Text(conv.title)
                    .font(.system(size: 19, weight: .regular))
                    .tracking(-0.2)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(isSelected ? Color.white.opacity(0.09) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        // Menu Contextuel Natif iOS (.ctxMenu)
        .contextMenu {
            Button {
                HapticService.shared.buttonTap()
                viewModel.togglePinConversation(conv)
            } label: {
                Label(conv.isPinned ? "Détacher" : "Épingler", systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            
            Button {
                HapticService.shared.buttonTap()
                conversationToRename = conv
                newTitleText = conv.title
                isShowingRenameAlert = true
            } label: {
                Label("Renommer", systemImage: "square.and.pencil")
            }
            
            Button {
                HapticService.shared.buttonTap()
                viewModel.archiveConversation(conv)
            } label: {
                Label("Archiver", systemImage: "archivebox")
            }
            
            Button(role: .destructive) {
                HapticService.shared.bargeIn()
                viewModel.deleteConversation(conv)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

/// Style de bouton interactif avec micro-animation d'échelle au toucher
public struct ScaleBounceButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
