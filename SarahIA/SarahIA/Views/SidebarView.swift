import SwiftUI

/// Menu Latéral (Sidebar) Épuré, Fluide et Moderne style ChatGPT / Gemini
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
            
            VStack(alignment: .leading, spacing: 14) {
                // 1. En-tête : Nouveau tchat (espacé de la Status Bar)
                Button(action: {
                    HapticService.shared.buttonTap()
                    viewModel.startNewChat()
                    viewModel.closeDrawer()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Nouveau tchat")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(ScaleBounceButtonStyle())
                .padding(.top, max(12, geo.safeAreaInsets.top + 8))

                // 2. Titre de section
                HStack {
                    Text("Récents")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(viewModel.conversations.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)

                // 3. Liste des discussions style ChatGPT
                if viewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 30))
                            .foregroundColor(Color.gray.opacity(0.35))
                        Text("Aucune discussion")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 3) {
                            ForEach(viewModel.conversations) { chat in
                                let isSelected = (viewModel.currentConversationId == chat.id)
                                Button(action: {
                                    HapticService.shared.buttonTap()
                                    viewModel.selectConversation(chat)
                                    viewModel.closeDrawer()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: isSelected ? "bubble.left.fill" : "bubble.left")
                                            .font(.system(size: 13))
                                            .foregroundColor(isSelected ? .white : .gray)

                                        Text(chat.title)
                                            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                                            .lineLimit(1)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
                                    .cornerRadius(8)
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

                // 4. Bas de page : Nettoyage discret
                if !viewModel.conversations.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    Button(role: .destructive, action: {
                        HapticService.shared.buttonTap()
                        isShowingClearAllAlert = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("Effacer l'historique")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                    .padding(.bottom, max(12, geo.safeAreaInsets.bottom + 6))
                }
            }
            .padding(.horizontal, 14)
            .frame(width: sidebarWidth, alignment: .leading)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea())
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
