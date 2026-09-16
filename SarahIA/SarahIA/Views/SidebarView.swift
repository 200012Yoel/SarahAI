import Foundation
import SwiftUI

/// Tiroir des discussions de Sarah IA.
///
/// Conserve les discussions actives, épinglées et archivées dans une présentation
/// compacte pour iPhone, avec les actions usuelles d'une application de messagerie.
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool

    @State private var isShowingArchives = false
    @State private var conversationPendingDeletion: Conversation?
    @State private var isShowingDeleteConfirmation = false

    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            newChatButton
                .padding(.top, 18)

            searchField
                .padding(.top, 14)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if isShowingArchives {
                        archivedHistory
                    } else {
                        activeHistory
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }

            footer
        }
        .padding(.top, 12)
        .background(Color(.systemBackground).ignoresSafeArea())
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
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isShowingArchives ? "Archives" : "Discussions")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)

                Text(isShowingArchives ? "Conversations conservées" : "Vos conversations récentes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .accessibilityLabel("Fermer les discussions")
        }
        .padding(.horizontal, 16)
    }

    private var newChatButton: some View {
        Button {
            viewModel.startNewChat()
            viewModel.closeDrawer()
        } label: {
            Label("Nouveau chat", systemImage: "square.and.pencil")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .accessibilityHint("Crée une nouvelle discussion avec Sarah")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Rechercher une discussion", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .font(.body)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Historique actif

    @ViewBuilder
    private var activeHistory: some View {
        let pinned = viewModel.filteredPinnedConversations.sorted { $0.updatedAt > $1.updatedAt }
        let recent = viewModel.filteredRecentConversations.sorted { $0.updatedAt > $1.updatedAt }

        if pinned.isEmpty && recent.isEmpty {
            emptyHistory(
                icon: viewModel.searchQuery.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass",
                title: viewModel.searchQuery.isEmpty ? "Aucune discussion" : "Aucun résultat",
                message: viewModel.searchQuery.isEmpty
                    ? "Commencez un nouveau chat avec Sarah."
                    : "Essayez un autre mot-clé."
            )
            if !viewModel.filteredArchivedConversations.isEmpty {
                archivesLink
            }
        } else {
            conversationSection(
                title: "Épinglées",
                systemImage: "pin.fill",
                conversations: pinned
            )

            conversationSection(
                title: "Récentes",
                systemImage: "clock",
                conversations: recent
            )
        }

        archivesLink
    }

    // MARK: - Archives

    @ViewBuilder
    private var archivedHistory: some View {
        Button {
            HapticService.shared.buttonTap()
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingArchives = false
            }
        } label: {
            Label("Retour aux discussions", systemImage: "chevron.left")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)

        let archived = viewModel.filteredArchivedConversations
        if archived.isEmpty {
            emptyHistory(
                icon: "archivebox",
                title: "Aucune archive",
                message: "Les discussions archivées apparaîtront ici."
            )
        } else {
            conversationSection(
                title: "Archives",
                systemImage: "archivebox",
                conversations: archived
            )
        }
    }

    private var archivesLink: some View {
        Button {
            HapticService.shared.buttonTap()
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingArchives = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text("Archives")
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()

                let count = viewModel.filteredArchivedConversations.count
                if count > 0 {
                    Text("\(count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Afficher les discussions archivées")
    }

    // MARK: - Composants d'historique

    @ViewBuilder
    private func conversationSection(
        title: String,
        systemImage: String,
        conversations: [Conversation]
    ) -> some View {
        if !conversations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                ForEach(conversations) { conversation in
                    ConversationHistoryRow(
                        conversation: conversation,
                        isSelected: viewModel.currentConversationId == conversation.id,
                        viewModel: viewModel,
                        onDelete: { requestDeletion(of: conversation) }
                    )
                }
            }
        }
    }

    private func emptyHistory(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .padding(.horizontal, 24)
    }

    // MARK: - Pied

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                isShowingSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .frame(width: 24)

                    Text("Réglages")
                        .font(.body.weight(.medium))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ouvrir les réglages de Sarah IA")
        }
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

    private var relativeDate: String {
        RelativeDateTimeFormatter().localizedString(for: conversation.updatedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.selectConversation(conversation)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: conversation.isPinned ? "pin.fill" : "bubble.left")
                        .font(.body)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(conversation.title)
                            .font(.body.weight(isSelected ? .semibold : .regular))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            if conversation.isArchived {
                                Text("Archivée")
                            } else if conversation.isPinned {
                                Text("Épinglée")
                            }

                            Text(relativeDate)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(conversation.title)
            .accessibilityHint("Ouvrir cette discussion")

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions pour \(conversation.title)")
        }
        .background(
            isSelected ? Color.accentColor.opacity(0.14) : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 1)
        }
        .contextMenu {
            rowActions
        }
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
