import Foundation
import SwiftUI

/// Menu latéral épuré de Sarah IA.
/// Les actions secondaires des discussions restent accessibles par appui long,
/// afin de garder l'interface quotidienne légère.
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool

    @State private var conversationPendingDeletion: Conversation?
    @State private var isShowingDeleteConfirmation = false
    @State private var conversationPendingRename: Conversation?
    @State private var renameText = ""
    @State private var isShowingRenamePrompt = false

    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }

    public var body: some View {
        GeometryReader { geo in
            let horizontal: CGFloat = geo.size.width < 310 ? 14 : 16

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.020, green: 0.022, blue: 0.029),
                        Color(red: 0.032, green: 0.035, blue: 0.046)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(horizontal: horizontal, topInset: geo.safeAreaInsets.top)

                    if shouldShowSearch {
                        searchField
                            .padding(.horizontal, horizontal)
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }

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
                        .padding(.top, 4)
                        .padding(.bottom, 14)
                    }
                    .frame(maxHeight: .infinity)

                    footer(horizontal: horizontal, bottomInset: geo.safeAreaInsets.bottom)
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
        .alert("Renommer la discussion", isPresented: $isShowingRenamePrompt) {
            TextField("Nom de la discussion", text: $renameText)

            Button("Annuler", role: .cancel) {
                conversationPendingRename = nil
                renameText = ""
            }

            Button("Renommer") {
                if let conversationPendingRename {
                    viewModel.renameConversation(
                        conversationPendingRename,
                        newTitle: renameText
                    )
                }
                conversationPendingRename = nil
                renameText = ""
            }
        } message: {
            Text("Choisis un nom court pour retrouver facilement cette discussion.")
        }
    }

    private var shouldShowSearch: Bool {
        true
    }

    private func header(horizontal: CGFloat, topInset: CGFloat) -> some View {
        HStack(spacing: 10) {
            Text("Sarah IA")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.39, green: 0.55, blue: 1.0))

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                viewModel.startNewChat()
                viewModel.closeDrawer()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(viewModel.activeAgent.themeColor.opacity(0.92))
                    )
            }
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel("Nouveau chat")
        }
        .padding(.horizontal, horizontal)
        .padding(.top, max(12, topInset + 7))
        .padding(.bottom, shouldShowSearch ? 11 : 15)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.42))

            TextField("Rechercher", text: $viewModel.searchQuery)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.28))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 39)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    @ViewBuilder
    private func conversationSection(
        title: String,
        conversations: [Conversation],
        horizontal: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.38))
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal, horizontal + 3)

            if conversations.isEmpty {
                Text(viewModel.searchQuery.isEmpty ? "Aucune discussion" : "Aucun résultat")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.28))
                    .padding(.horizontal, horizontal + 3)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 2) {
                    ForEach(conversations) { conversation in
                        ConversationHistoryRow(
                            conversation: conversation,
                            isSelected: viewModel.currentConversationId == conversation.id,
                            viewModel: viewModel,
                            onRename: { requestRename(of: conversation) },
                            onDelete: { requestDeletion(of: conversation) }
                        )
                    }
                }
                .padding(.horizontal, horizontal - 5)
            }
        }
    }

    private func footer(horizontal: CGFloat, bottomInset: CGFloat) -> some View {
        HStack(spacing: 8) {
            compactFooterAction(
                icon: "waveform",
                title: "Vocal",
                tint: viewModel.activeAgent.themeColor
            ) {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    viewModel.isShowingVoiceOrbModal = true
                }
            }

            compactFooterAction(
                icon: "gearshape",
                title: "Réglages",
                tint: Color.white.opacity(0.76)
            ) {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isShowingSettings = true
                }
            }
        }
        .padding(.horizontal, horizontal)
        .padding(.top, 9)
        .padding(.bottom, max(9, bottomInset + 4))
        .background(
            Color(red: 0.018, green: 0.020, blue: 0.026)
                .opacity(0.96)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
        }
    }

    private func compactFooterAction(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(tint)

                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.88))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.6)
            )
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }

    private func requestRename(of conversation: Conversation) {
        conversationPendingRename = conversation
        renameText = conversation.title
        isShowingRenamePrompt = true
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
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            HapticService.shared.buttonTap()
            viewModel.selectConversation(conversation)
            viewModel.closeDrawer()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: conversation.isPinned ? "pin.fill" : "bubble.left")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? viewModel.activeAgent.themeColor
                            : Color.white.opacity(0.34)
                    )
                    .frame(width: 18)

                Text(conversation.title)
                    .font(.system(size: 13.8, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(Color.white.opacity(isSelected ? 0.96 : 0.82))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 5)

                Text(timeLabel)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.22))
            }
            .padding(.horizontal, 10)
            .frame(height: 43)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                            ? viewModel.activeAgent.themeColor.opacity(0.115)
                            : Color.clear
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Renommer", systemImage: "pencil")
            }

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
        .accessibilityHint("Appui long pour les actions de la discussion")
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
}
