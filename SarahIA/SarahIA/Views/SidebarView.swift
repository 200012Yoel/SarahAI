import Foundation
import SwiftUI

/// Menu latéral Sarah IA, volontairement compact : plus de place aux discussions,
/// moins de grosses cartes et des actions proches des conventions iOS.
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
            let horizontal: CGFloat = geo.size.width < 310 ? 14 : 16

            ZStack {
                Color(red: 0.025, green: 0.028, blue: 0.036)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(horizontal: horizontal, topInset: geo.safeAreaInsets.top)

                    searchField
                        .padding(.horizontal, horizontal)
                        .padding(.bottom, 12)

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
                        .padding(.bottom, 12)
                    }
                    .frame(maxHeight: .infinity)

                    Divider()
                        .overlay(Color.white.opacity(0.07))

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
        .alert("Aide et support", isPresented: $isShowingHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Retrouve ici les fonctions d’aide de Sarah IA.")
        }
    }

    private func header(horizontal: CGFloat, topInset: CGFloat) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Sarah IA")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.39, green: 0.55, blue: 1.0))
                }

                Text("Toujours là pour vous 💙")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.42))
            }

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
                        Circle().fill(viewModel.activeAgent.themeColor.opacity(0.92))
                    )
            }
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel("Nouveau chat")
        }
        .padding(.horizontal, horizontal)
        .padding(.top, max(12, topInset + 6))
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.48))

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
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 0.7)
        )
    }

    @ViewBuilder
    private func conversationSection(
        title: String,
        conversations: [Conversation],
        horizontal: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.90))

                Spacer()

                Text("\(conversations.count)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.28))
            }
            .padding(.horizontal, horizontal + 2)

            if conversations.isEmpty {
                Text(viewModel.searchQuery.isEmpty ? "Aucune discussion" : "Aucun résultat")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color.white.opacity(0.30))
                    .padding(.horizontal, horizontal + 2)
                    .padding(.vertical, 5)
            } else {
                VStack(spacing: 4) {
                    ForEach(conversations) { conversation in
                        ConversationHistoryRow(
                            conversation: conversation,
                            isSelected: viewModel.currentConversationId == conversation.id,
                            viewModel: viewModel,
                            onDelete: { requestDeletion(of: conversation) }
                        )
                    }
                }
                .padding(.horizontal, horizontal - 4)
            }
        }
    }

    private func footer(horizontal: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 2) {
            menuAction(
                systemName: "waveform",
                title: "Mode vocal",
                tint: viewModel.activeAgent.themeColor
            ) {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    viewModel.isShowingVoiceOrbModal = true
                }
            }

            menuAction(
                systemName: "gearshape",
                title: "Paramètres",
                tint: Color.white.opacity(0.72)
            ) {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isShowingSettings = true
                }
            }

            menuAction(
                systemName: "questionmark.circle",
                title: "Aide et support",
                tint: Color.white.opacity(0.64)
            ) {
                HapticService.shared.buttonTap()
                isShowingHelp = true
            }
        }
        .padding(.horizontal, horizontal - 4)
        .padding(.top, 7)
        .padding(.bottom, max(8, bottomInset + 3))
    }

    private func menuAction(
        systemName: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 25)

                Text(title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.88))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.22))
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
                HStack(spacing: 9) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(
                            isSelected
                                ? viewModel.activeAgent.themeColor
                                : Color.white.opacity(0.46)
                        )
                        .frame(width: 19)

                    Text(conversation.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.90))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 5)

                    Text(timeLabel)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.25))
                }
                .padding(.leading, 10)
                .padding(.trailing, 2)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.31))
                    .frame(width: 31, height: 40)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    isSelected
                        ? viewModel.activeAgent.themeColor.opacity(0.11)
                        : Color.white.opacity(0.025)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    isSelected
                        ? viewModel.activeAgent.themeColor.opacity(0.26)
                        : Color.clear,
                    lineWidth: 0.7
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
