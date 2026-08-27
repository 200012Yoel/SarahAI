import SwiftUI

/// Menu Latéral (Sidebar) Épuré, Fluide et Moderne style Gemini / ChatGPT
/// Intégrant le bouton Nouveau Tchat en haut, la liste des conversations récentes,
/// et le bouton d'effacement de l'historique en pied de page.
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
            let sidebarWidth = UIScreen.main.bounds.width * 0.78
            
            VStack(alignment: .leading, spacing: 16) {
                
                // 1. En-tête : Nouveau Tchat style ChatGPT / Gemini
                Button(action: {
                    HapticService.shared.buttonTap()
                    viewModel.startNewChat()
                    viewModel.closeDrawer()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Nouveau tchat")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(ScaleBounceButtonStyle())
                .padding(.top, max(20, geo.safeAreaInsets.top + 8))
                
                // Titre de section Récents
                HStack {
                    Text("Récents")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    if !viewModel.conversations.isEmpty {
                        Text("\(viewModel.conversations.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 6)
                
                // 2. Liste fluide des discussions
                if viewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 32))
                            .foregroundColor(Color.gray.opacity(0.35))
                        Text("Aucune discussion")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.conversations) { chat in
                                let isSelected = (viewModel.currentConversationId == chat.id)
                                Button(action: {
                                    HapticService.shared.buttonTap()
                                    viewModel.selectConversation(chat)
                                    viewModel.closeDrawer()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: isSelected ? "bubble.left.fill" : "bubble.left")
                                            .font(.system(size: 14))
                                            .foregroundColor(isSelected ? Color(red: 0.15, green: 0.72, blue: 1.0) : Color.white.opacity(0.6))
                                        
                                        Text(chat.title)
                                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive, action: {
                                        HapticService.shared.memoryDeleted()
                                        viewModel.deleteConversation(chat)
                                    }) {
                                        Label("Supprimer la discussion", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 3. Pied de page épuré avec Divider et Bouton Effacer l'historique
                if !viewModel.conversations.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button(role: .destructive, action: {
                        HapticService.shared.buttonTap()
                        isShowingClearAllAlert = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("Effacer l'historique")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                    }
                    .padding(.bottom, max(16, geo.safeAreaInsets.bottom + 8))
                }
            }
            .padding(.horizontal, 16)
            .frame(width: sidebarWidth, alignment: .leading)
            .background(Color(red: 0.10, green: 0.10, blue: 0.11).ignoresSafeArea())
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
}
