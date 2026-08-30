import SwiftUI

/// Menu Latéral (Sidebar) Épuré, Élégant et Fluide :
/// - En-tête bien dégagé sous la barre de statut (Dynamic Island / Encoche / Horloge)
/// - Titre "Discussions" + Bouton "＋ Nouveau"
/// - Cartes de discussions modernes avec indicateur actif et suppression au toucher long
/// - Fond sombre pleine hauteur avec bordure subtile
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool
    
    @State private var isShowingClearAllAlert: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    public var body: some View {
        GeometryReader { geo in
            let topInset = max(geo.safeAreaInsets.top, 44)
            let bottomInset = max(geo.safeAreaInsets.bottom, 20)
            
            VStack(alignment: .leading, spacing: 18) {
                // 1. En-tête avec dégagement sécurisé sous la barre de statut
                HStack(spacing: 12) {
                    // Logo Sarah — dégradé néon
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.18, blue: 0.65),
                                Color(red: 0.55, green: 0.10, blue: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(width: 36, height: 36)
                        
                        Text("S")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sarah IA")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Multi-Agents Intelligents")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Bouton fermer le menu (✕)
                    Button(action: {
                        HapticService.shared.buttonTap()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            viewModel.closeDrawer()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(8)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.top, max(safeTopPadding, topInset) + 10)
                .padding(.horizontal, 16)
                
                // 2. Titre de section & Bouton Nouveau
                HStack {
                    Text("Discussions")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.startNewChat()
                        viewModel.closeDrawer()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Nouveau")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.horizontal, 16)
                
                // 3. Liste des discussions
                if viewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 38))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Aucune discussion")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.conversations) { conv in
                                let isSelected = (viewModel.currentConversationId == conv.id)
                                let firstQuestion = conv.messages.first(where: { $0.isFromUser })?.content ?? conv.title
                                
                                Button(action: {
                                    HapticService.shared.buttonTap()
                                    viewModel.selectConversation(conv)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        viewModel.closeDrawer()
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: isSelected ? "bubble.left.fill" : "bubble.left")
                                            .font(.system(size: 13))
                                            .foregroundColor(isSelected ? Color(red: 0.15, green: 0.72, blue: 1.0) : .gray)
                                        
                                        Text(firstQuestion)
                                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 11)
                                    .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
                
                Spacer()
                
                // 4. Pied de menu : Accès Réglages
                HStack {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.closeDrawer()
                        isShowingSettings = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Réglages & Modes")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, bottomInset + 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()
            )
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity),
                alignment: .trailing
            )
        }
    }
    
    private var safeTopPadding: CGFloat {
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                let top = window.safeAreaInsets.top
                if top > 0 { return top }
            }
        }
        return 50
    }
}
