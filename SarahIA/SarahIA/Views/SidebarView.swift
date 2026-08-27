import SwiftUI

/// Menu Latéral (Sidebar) Pixel-Perfect conforme à la maquette :
/// - Header avec Logo Avatar "S" lumineux bleu, Titre "Sarah IA", et Bouton Fermer "✕"
/// - Titre de section "Discussion"
/// - Cartes modernes pour chaque discussion avec icône bulle bleue, Heure & Date en haut, et Première question en gros
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
            
            VStack(alignment: .leading, spacing: 18) {
                
                // 1. En-tête : Avatar 'S' lumineux + "Sarah IA" + Bouton Fermer '✕'
                HStack(alignment: .center, spacing: 12) {
                    // Avatar 'S' avec anneau lumineux bleu
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.10, green: 0.12, blue: 0.18))
                            .frame(width: 42, height: 42)
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.20, green: 0.65, blue: 1.0), Color(red: 0.10, green: 0.40, blue: 0.90)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 42, height: 42)
                            .shadow(color: Color(red: 0.20, green: 0.65, blue: 1.0).opacity(0.6), radius: 6, x: 0, y: 0)
                        
                        Text("S")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text("Sarah IA")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Bouton Fermer '✕'
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.closeDrawer()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, max(24, geo.safeAreaInsets.top + 12))
                
                // 2. Titre de section "Discussion"
                HStack {
                    Text("Discussion")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.60))
                    
                    Spacer()
                    
                    // Bouton discret "Nouveau Tchat"
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.startNewChat()
                        viewModel.closeDrawer()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Nouveau")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.25, green: 0.70, blue: 1.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.25, green: 0.70, blue: 1.0).opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                
                // 3. Liste des cartes de discussions (Exactement comme la capture d'écran)
                if viewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 34))
                            .foregroundColor(Color.gray.opacity(0.35))
                        Text("Aucune discussion")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.conversations) { conv in
                                conversationCard(conv: conv)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
                
                Spacer()
                
                // 4. Bas de page : Nettoyage d'historique
                if !viewModel.conversations.isEmpty {
                    Button(role: .destructive, action: {
                        HapticService.shared.buttonTap()
                        isShowingClearAllAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                            Text("Effacer l'historique")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.80))
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(16, geo.safeAreaInsets.bottom + 8))
                    }
                }
            }
            .frame(width: sidebarWidth, alignment: .leading)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea())
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
    
    // MARK: - Carte de Discussion Pixel-Perfect
    
    @ViewBuilder
    private func conversationCard(conv: Conversation) -> some View {
        let isSelected = (viewModel.currentConversationId == conv.id)
        let firstMessageText = conv.messages.first(where: { $0.isUser })?.content ?? conv.title
        
        Button(action: {
            HapticService.shared.buttonTap()
            viewModel.selectConversation(conv)
            viewModel.closeDrawer()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Ligne du haut : Bulle bleue + Heure + Date
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.25, green: 0.65, blue: 1.0))
                    
                    Text(formatTime(date: conv.updatedAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                    
                    Spacer()
                    
                    Text(formatDate(date: conv.updatedAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                
                // Corps : Première question de l'utilisateur
                Text(firstMessageText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.25, green: 0.65, blue: 1.0).opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
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
    
    // MARK: - Formatage d'Heure & Date
    
    private func formatTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDate(date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Aujourd'hui"
        } else if calendar.isDateInYesterday(date) {
            return "Hier"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}
