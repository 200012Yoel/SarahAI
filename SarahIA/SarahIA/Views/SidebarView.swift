import SwiftUI

/// Sidebar (Menu Latéral) Pixel-Perfect 100% Natif SwiftUI avec mise à l'échelle dynamique et anti-débordement sur iPhone 5s à 16 Pro Max.
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool
    
    @State private var conversationToRename: Conversation? = nil
    @State private var newTitleText: String = ""
    @State private var isShowingRenameAlert: Bool = false
    @State private var isShowingWidgets: Bool = false
    @State private var isShowingSyncQR: Bool = false
    
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
                // Background #000
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header: Titre "Sarah IA" + Bouton Recherche Circulaire
                    HStack(alignment: .center, spacing: 10) {
                        Text("Sarah IA")
                            .font(.system(size: isCompact ? 22 : 24, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Spacer()
                        
                        // Bouton recherche circulaire
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
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14)) // #1c1c1e
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
                    
                    // Barre de Recherche Animée
                    if viewModel.isSearchActive {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                .font(.system(size: 14))
                            
                            TextField("Rechercher", text: $viewModel.searchQuery)
                                .font(.system(size: isCompact ? 14 : 16))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if !viewModel.searchQuery.isEmpty {
                                Button(action: {
                                    viewModel.searchQuery = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 15))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: isCompact ? 36 : 40)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(10)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Liste Déroulante des Discussions
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Section Épinglés
                            if !viewModel.filteredPinnedConversations.isEmpty {
                                Text("Épinglés")
                                    .font(.system(size: isCompact ? 18 : 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, horizontalPadding)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                
                                ForEach(viewModel.filteredPinnedConversations) { conv in
                                    conversationRow(conv, isPinned: true, isCompact: isCompact, padding: horizontalPadding)
                                }
                            }
                            
                            // Section Récents
                            Text("Récents")
                                .font(.system(size: isCompact ? 18 : 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, viewModel.filteredPinnedConversations.isEmpty ? 8 : 20)
                                .padding(.bottom, 4)
                            
                            if viewModel.filteredRecentConversations.isEmpty {
                                Text(viewModel.searchQuery.isEmpty ? "Aucune discussion." : "Aucun résultat.")
                                    .font(.system(size: isCompact ? 14 : 15))
                                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                    .padding(.horizontal, horizontalPadding)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(viewModel.filteredRecentConversations) { conv in
                                    conversationRow(conv, isPinned: false, isCompact: isCompact, padding: horizontalPadding)
                                }
                            }
                            
                            // Marge basse pour défilement complet au-dessus de la barre
                            Spacer()
                                .frame(height: 110)
                        }
                    }
                }
                .frame(width: sidebarWidth, alignment: .leading)
                
                // Barre Inférieure (.sb-bottom) avec dégradé et boutons proportionnels
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack(spacing: isCompact ? 5 : 8) {
                        // Bouton Pill Bleu "Nouveau" (#btnNewChat)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.startNewChat()
                            viewModel.switchToChat()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                
                                Text("Nouveau")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, isCompact ? 9 : 12)
                            .padding(.vertical, isCompact ? 7 : 9)
                            .background(Color(red: 0.04, green: 0.52, blue: 1.0))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        Spacer(minLength: 2)
                        
                        let btnSize: CGFloat = isCompact ? 32 : 36
                        
                        // Bouton Circulaire Vidéos YouTube 📺
                        Button(action: {
                            HapticService.shared.buttonTap()
                            NotificationCenter.default.post(name: NSNotification.Name("SarahLaunchYouTubePlayer"), object: "musique")
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "play.tv.fill")
                                    .font(.system(size: isCompact ? 12 : 14))
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        // Bouton Circulaire Synchronisation QR 📱
                        Button(action: {
                            HapticService.shared.buttonTap()
                            isShowingSyncQR = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "qrcode")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .regular))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        // Bouton Circulaire Widgets 📊 (#btnWidgets)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            isShowingWidgets = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .regular))
                                    .foregroundColor(.sarahCyan)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                        
                        // Bouton Circulaire Paramètres (#btnSettings)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            isShowingSettings = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: btnSize, height: btnSize)
                                
                                Image(systemName: "gearshape")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .regular))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(.horizontal, isCompact ? 10 : 14)
                    .padding(.top, 12)
                    .padding(.bottom, max(14, geo.safeAreaInsets.bottom + 6))
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.92),
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
        .sheet(isPresented: $isShowingWidgets) {
            WidgetsGalleryView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingSyncQR) {
            LocalSyncQRView(viewModel: viewModel)
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
    private func conversationRow(_ conv: Conversation, isPinned: Bool, isCompact: Bool, padding: CGFloat) -> some View {
        let isSelected = (viewModel.currentConversationId == conv.id)
        
        Button(action: {
            HapticService.shared.buttonTap()
            viewModel.selectConversation(conv)
            viewModel.closeDrawer()
        }) {
            HStack(spacing: isCompact ? 10 : 14) {
                if isPinned {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: isCompact ? 14 : 16))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Text(conv.title)
                    .font(.system(size: isCompact ? 15 : 17, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                
                Spacer()
            }
            .padding(.horizontal, padding)
            .padding(.vertical, isCompact ? 10 : 12)
            .background(isSelected ? Color.white.opacity(0.09) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
@available(iOS 13.0, *)
public struct ScaleBounceButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
