import Foundation
import SwiftUI

/// Tiroir latéral principal de Sarah IA.
/// Design sombre moderne inspiré de la maquette validée :
/// titre, recherche permanente, discussions sous forme de cartes,
// puis actions principales fixes en bas.
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool

    @State private var conversationPendingDeletion: Conversation?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingHelp = false

    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }

    public var body: some View {
        GeometryReader { geo in
            let width = max(280, geo.size.width)
            let horizontal = max(18, min(24, width * 0.055))
            let insets = currentSafeAreaInsets

            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(red: 0.045, green: 0.050, blue: 0.065),
                        Color(red: 0.028, green: 0.031, blue: 0.041)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(horizontal: horizontal, topInset: insets.top)
                    searchField(horizontal: horizontal)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if !viewModel.filteredPinnedConversations.isEmpty {
                                conversationSection(
                                    title: "Épinglés",
                                    conversations: viewModel.filteredPinnedConversations,
                                    horizontal: horizontal
                                )
                            }

                            conversationSection(
                                title: "Récents",
                                conversations: viewModel.filteredRecentConversations,
                                horizontal: horizontal
                            )
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 210)
                    }
                }

                footer(
                    horizontal: horizontal,
                    bottomInset: insets.bottom
                )
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Supprimer cette discussion ?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let conversationPendingDeletion {
                    viewModel.deleteConversation(conversationPendingDeletion)
                }
                conversationPendingDeletion = nil
            }

            Button("Annuler", role: .cancel) {
                conversationPendingDeletion = nil
            }
        } message: {
            Text("Cette action est définitive.")
        }
        .alert("Aide et support", isPresented: $isShowingHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Retrouve ici les fonctions d’aide de Sarah IA. Cette section pourra être reliée au centre d’aide complet.")
        }
    }

    // MARK: - Header

    private func header(horizontal: CGFloat, topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("Sarah IA")
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "sparkles")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(Color(red: 0.37, green: 0.47, blue: 1.0))

                Spacer(minLength: 0)
            }

            Text("Toujours là pour vous 💙")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.white.opacity(0.58))
        }
        .padding(.horizontal, horizontal)
        .padding(.top, max(18, topInset + 14))
        .padding(.bottom, 20)
    }

    private func searchField(horizontal: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(Color.white.opacity(0.82))

            TextField("Rechercher une conversation...", text: $viewModel.searchQuery)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color.white.opacity(0.34))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
        .padding(.horizontal, horizontal)
    }

    // MARK: - Conversations

    @ViewBuilder
    private func conversationSection(
        title: String,
        conversations: [Conversation],
        horizontal: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if title == "Récents" {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.72))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.07))
                        )
                }
            }
            .padding(.horizontal, horizontal)

            if conversations.isEmpty {
                Text(
                    viewModel.searchQuery.isEmpty
                        ? "Aucune discussion pour le moment."
                        : "Aucune discussion trouvée."
                )
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.38))
                .padding(.horizontal, horizontal)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(conversations) { conversation in
                        ConversationHistoryRow(
                            conversation: conversation,
                            isSelected: viewModel.currentConversationId == conversation.id,
                            viewModel: viewModel,
                            onDelete: { requestDeletion(of: conversation) }
                        )
                    }
                }
                .padding(.horizontal, max(12, horizontal - 4))
            }
        }
    }

    // MARK: - Footer

    private func footer(horizontal: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 10) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.startNewChat()
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 19, weight: .semibold))

                    Text("Nouveau chat")
                        .font(.system(size: 17, weight: .bold))

                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.48, blue: 1.0),
                            Color(red: 0.14, green: 0.36, blue: 0.95)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.blue.opacity(0.18), radius: 16, y: 8)
            }
            .buttonStyle(PlainButtonStyle())

            footerRow(
                systemName: "gearshape",
                title: "Paramètres"
            ) {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                isShowingSettings = true
            }

            footerRow(
                systemName: "questionmark.circle",
                title: "Aide et support"
            ) {
                HapticService.shared.buttonTap()
                isShowingHelp = true
            }
        }
        .padding(.horizontal, horizontal)
        .padding(.top, 16)
        .padding(.bottom, max(16, bottomInset + 10))
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.030, green: 0.034, blue: 0.044).opacity(0.10),
                    Color(red: 0.030, green: 0.034, blue: 0.044).opacity(0.97),
                    Color(red: 0.030, green: 0.034, blue: 0.044)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
    }

    private func footerRow(
        systemName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.42))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var currentSafeAreaInsets: UIEdgeInsets {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .safeAreaInsets ?? .zero
        }

        return UIApplication.shared.keyWindow?.safeAreaInsets ?? .zero
    }

    private func requestDeletion(of conversation: Conversation) {
        conversationPendingDeletion = conversation
        isShowingDeleteConfirmation = true
    }
}

@available(iOS 15.0, *)
private struct ConversationHistoryRow: View {
    let conversation: Conversation
    let isSelected: Bool

    @ObservedObject var viewModel: ChatViewModel
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.selectConversation(conversation)
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(
                            isSelected
                                ? Color(red: 0.42, green: 0.70, blue: 1.0)
                                : Color.white.opacity(0.84)
                        )
                        .frame(width: 26)

                    Text(conversation.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Text(timeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.42))
                }
                .padding(.horizontal, 15)
                .frame(height: 62)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.48))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isSelected
                        ? Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.92)
                        : Color.white.opacity(0.052)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                        ? Color(red: 0.20, green: 0.53, blue: 1.0)
                        : Color.white.opacity(0.035),
                    lineWidth: isSelected ? 1.2 : 0.7
                )
        )
        .shadow(
            color: isSelected ? Color.blue.opacity(0.10) : Color.clear,
            radius: 12,
            y: 4
        )
        .contextMenu {
            rowActions
        }
    }

    private var timeLabel: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(conversation.updatedAt) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: conversation.updatedAt)
        }

        if calendar.isDateInYesterday(conversation.updatedAt) {
            return "Hier"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: conversation.updatedAt).capitalized
    }

    @ViewBuilder
    private var rowActions: some View {
        Button {
            viewModel.togglePinConversation(conversation)
        } label: {
            Label(
                conversation.isPinned ? "Désépingler" : "Épingler",
                systemImage: conversation.isPinned ? "pin.slash" : "pin"
            )
        }

        if conversation.isArchived {
            Button {
                viewModel.unarchiveConversation(conversation)
            } label: {
                Label("Désarchiver", systemImage: "tray.and.arrow.up")
            }
        } else {
            Button {
                viewModel.archiveConversation(conversation)
            } label: {
                Label("Archiver", systemImage: "archivebox")
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Supprimer", systemImage: "trash")
        }
    }
}
