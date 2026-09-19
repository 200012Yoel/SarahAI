import Foundation
import SwiftUI

/// Tiroir latéral compact et adaptatif de Sarah IA.
/// Aucun bloc ne flotte par-dessus la liste : le contenu se répartit selon la hauteur disponible.
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
            let horizontal = max(14, min(20, width * 0.05))
            let safeInsets = currentSafeAreaInsets

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.038, green: 0.043, blue: 0.056),
                        Color(red: 0.022, green: 0.025, blue: 0.034)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(
                        horizontal: horizontal,
                        topInset: safeInsets.top
                    )

                    searchField(horizontal: horizontal)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
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
                        .padding(.top, 18)
                        .padding(.bottom, 14)
                    }
                    .frame(maxHeight: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.065))
                        .frame(height: 0.5)

                    footer(
                        horizontal: horizontal,
                        bottomInset: safeInsets.bottom
                    )
                }
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
            Text("Retrouve ici les fonctions d’aide de Sarah IA.")
        }
    }

    // MARK: - En-tête

    private func header(horizontal: CGFloat, topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Sarah IA")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.37, green: 0.52, blue: 1.0))

                Spacer(minLength: 0)
            }

            Text("Toujours là pour vous 💙")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.48))
        }
        .padding(.horizontal, horizontal)
        .padding(.top, max(14, topInset + 8))
        .padding(.bottom, 14)
    }

    private func searchField(horizontal: CGFloat) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.70))

            TextField("Rechercher une conversation…", text: $viewModel.searchQuery)
                .font(.system(size: 14.5))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.32))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.7)
        )
        .padding(.horizontal, horizontal)
    }

    // MARK: - Discussions

    @ViewBuilder
    private func conversationSection(
        title: String,
        conversations: [Conversation],
        horizontal: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if title == "Récents" {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.58))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(Color.white.opacity(0.055))
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
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.34))
                .padding(.horizontal, horizontal)
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 7) {
                    ForEach(conversations) { conversation in
                        ConversationHistoryRow(
                            conversation: conversation,
                            isSelected: viewModel.currentConversationId == conversation.id,
                            viewModel: viewModel,
                            onDelete: { requestDeletion(of: conversation) }
                        )
                    }
                }
                .padding(.horizontal, max(10, horizontal - 3))
            }
        }
    }

    // MARK: - Bas du menu

    private func footer(horizontal: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 7) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.startNewChat()
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Nouveau chat")
                        .font(.system(size: 15.5, weight: .bold))

                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.47, blue: 1.0),
                            Color(red: 0.19, green: 0.36, blue: 0.94)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(ScaleBounceButtonStyle())

            HStack(spacing: 8) {
                compactAction(
                    systemName: "waveform",
                    title: "Mode vocal",
                    emphasized: true
                ) {
                    HapticService.shared.buttonTap()
                    viewModel.closeDrawer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        viewModel.isShowingVoiceOrbModal = true
                    }
                }

                compactAction(
                    systemName: "gearshape",
                    title: "Paramètres",
                    emphasized: false
                ) {
                    HapticService.shared.buttonTap()
                    viewModel.closeDrawer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isShowingSettings = true
                    }
                }
            }

            Button {
                HapticService.shared.buttonTap()
                isShowingHelp = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 22)

                    Text("Aide et support")
                        .font(.system(size: 14.5, weight: .medium))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.34))
                }
                .foregroundColor(Color.white.opacity(0.84))
                .padding(.horizontal, 8)
                .frame(height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, horizontal)
        .padding(.top, 10)
        .padding(.bottom, max(10, bottomInset + 5))
        .background(Color(red: 0.024, green: 0.027, blue: 0.036).opacity(0.96))
    }

    private func compactAction(
        systemName: String,
        title: String,
        emphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))

                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
            .foregroundColor(emphasized ? .white : Color.white.opacity(0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        emphasized
                            ? viewModel.activeAgent.themeColor.opacity(0.18)
                            : Color.white.opacity(0.055)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        emphasized
                            ? viewModel.activeAgent.themeColor.opacity(0.28)
                            : Color.white.opacity(0.045),
                        lineWidth: 0.7
                    )
            )
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }

    private var currentSafeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets ?? .zero
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
        HStack(spacing: 0) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.selectConversation(conversation)
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(
                            isSelected
                                ? Color(red: 0.42, green: 0.70, blue: 1.0)
                                : Color.white.opacity(0.70)
                        )
                        .frame(width: 22)

                    Text(conversation.title)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 6)

                    Text(timeLabel)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.34))
                }
                .padding(.leading, 13)
                .padding(.trailing, 5)
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.42))
                    .frame(width: 34, height: 42)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    isSelected
                        ? Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.88)
                        : Color.white.opacity(0.045)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    isSelected
                        ? Color(red: 0.20, green: 0.53, blue: 1.0).opacity(0.85)
                        : Color.white.opacity(0.03),
                    lineWidth: isSelected ? 1 : 0.6
                )
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
