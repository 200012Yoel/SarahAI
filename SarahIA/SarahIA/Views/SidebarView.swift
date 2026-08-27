import SwiftUI

/// Menu Latéral (Sidebar) Épuré et Fluide :
/// - 1. En-tête : Avatar 'S' bleu + Titre "Sarah IA" + Bouton Fermer '✕'
/// - 2. Titre de section "Discussions"
/// - 3. Cartes de discussions affichant directement la première question
/// - 4. Fond sombre pleine hauteur avec respiration sous la barre d'état
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
        VStack(alignment: .leading, spacing: 20) {
            // 1. En-tête (Descendu automatiquement sous la barre d'état)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Text("S")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }

                Text("Sarah IA")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    HapticService.shared.buttonTap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.closeDrawer()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleBounceButtonStyle())
            }
            .padding(.top, 12) // Marge de respiration sous l'encoche

            // 2. Titre de section & Bouton Nouveau Tchat
            HStack {
                Text("Discussions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    HapticService.shared.buttonTap()
                    viewModel.startNewChat()
                    viewModel.closeDrawer()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Nouveau")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleBounceButtonStyle())
            }

            // 3. Liste des carrés / cartes
            if viewModel.conversations.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Aucune discussion")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.conversations) { conv in
                            let isSelected = (viewModel.currentConversationId == conv.id)
                            let firstQuestion = conv.messages.first(where: { $0.isFromUser })?.content ?? conv.title
                            
                            Button(action: {
                                HapticService.shared.buttonTap()
                                viewModel.selectConversation(conv)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.closeDrawer()
                                }
                            }) {
                                HStack {
                                    Text(firstQuestion)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(12)
                                .background(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.07))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Color.blue.opacity(0.6) : Color.white.opacity(0.04), lineWidth: 1)
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
                }
                
                // Effacer l'historique en bas
                Button(role: .destructive, action: {
                    HapticService.shared.buttonTap()
                    isShowingClearAllAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Effacer l'historique")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.red.opacity(0.75))
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .frame(width: UIScreen.main.bounds.width * 0.80)
        .frame(maxHeight: .infinity)
        .background(
            Color(red: 0.08, green: 0.08, blue: 0.09)
                .ignoresSafeArea()
        )
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
