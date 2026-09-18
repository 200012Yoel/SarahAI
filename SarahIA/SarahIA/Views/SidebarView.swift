import Foundation
import SwiftUI

/// Menu latéral principal de Sarah.
/// Inspiré d'un tiroir de messagerie moderne : titre, recherche, épinglés,
/// récents, puis deux actions fixes en bas. L'interface s'adapte à toutes
/// les largeurs d'iPhone sans tailles rigides.
@available(iOS 15.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool

    @State private var isSearching = false
    @State private var isShowingArchives = false
    @State private var conversationPendingDeletion: Conversation?
    @State private var isShowingDeleteConfirmation = false

    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }

    public var body: some View {
        GeometryReader { geo in
            let width = max(280, geo.size.width)
            let horizontal = max(16, min(24, width * 0.055))
            let titleSize = max(25, min(31, width * 0.085))
            let rowFont = max(16, min(19, width * 0.052))
            let circleSize = max(48, min(58, width * 0.16))

            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(
                        horizontal: horizontal,
                        titleSize: titleSize,
                        circleSize: circleSize
                    )

                    if isSearching {
                        searchField(horizontal: horizontal)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            if isShowingArchives {
                                archivedHistory(
                                    horizontal: horizontal,
                                    rowFont: rowFont
                                )
                            } else {
                                activeHistory(
                                    horizontal: horizontal,
                                    rowFont: rowFont
                                )
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 112)
                    }
                }

                footer(
                    horizontal: horizontal,
                    circleSize: circleSize
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
    }

    // MARK: - Header

    private func header(
        horizontal: CGFloat,
        titleSize: CGFloat,
        circleSize: CGFloat
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(isShowingArchives ? "Archives" : "Sarah")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 12)

            if isShowingArchives {
                circularButton(
                    systemName: "chevron.left",
                    size: circleSize
                ) {
                    HapticService.shared.buttonTap()
                    withAnimation(.easeInOut(duration: 0.20)) {
                        isShowingArchives = false
                    }
                }
                .accessibilityLabel("Retour aux discussions")
            } else {
                circularButton(
                    systemName: isSearching ? "xmark" : "magnifyingglass",
                    size: circleSize
                ) {
                    HapticService.shared.buttonTap()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        isSearching.toggle()
                        if !isSearching {
                            viewModel.searchQuery = ""
                        }
                    }
                }
                .accessibilityLabel(isSearching ? "Fermer la recherche" : "Rechercher")
            }
        }
        .padding(.horizontal, horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func searchField(horizontal: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color.white.opacity(0.50))

            TextField("Rechercher", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 17))
                .foregroundColor(.white)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.38))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .padding(.horizontal, horizontal)
    }

    // MARK: - Active conversations

    @ViewBuilder
    private func activeHistory(
        horizontal: CGFloat,
        rowFont: CGFloat
    ) -> some View {
        let pinned = viewModel.filteredPinnedConversations
            .sorted { $0.updatedAt > $1.updatedAt }
        let recent = viewModel.filteredRecentConversations
            .sorted { $0.updatedAt > $1.updatedAt }

        if pinned.isEmpty && recent.isEmpty {
            if viewModel.searchQuery.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Récents")
                        .sectionTitleStyle()

                    Text("Aucune discussion pour le moment.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.42))
                        .padding(.top, 2)
                }
                .padding(.horizontal, horizontal)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Résultats")
                        .sectionTitleStyle()

                    Text("Aucune discussion trouvée.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.42))
                }
                .padding(.horizontal, horizontal)
            }
        } else {
            if !pinned.isEmpty {
                conversationSection(
                    title: "Épinglés",
                    conversations: pinned,
                    horizontal: horizontal,
                    rowFont: rowFont
                )
            }

            if !recent.isEmpty {
                conversationSection(
                    title: "Récents",
                    conversations: recent,
                    horizontal: horizontal,
                    rowFont: rowFont
                )
            }
        }

        if !viewModel.filteredArchivedConversations.isEmpty {
            Button {
                HapticService.shared.buttonTap()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingArchives = true
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 24)

                    Text("Archives")
                        .font(.system(size: rowFont, weight: .regular))

                    Spacer()

                    Text("\(viewModel.filteredArchivedConversations.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.40))
                }
                .foregroundColor(.white)
                .padding(.horizontal, horizontal)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Archives

    @ViewBuilder
    private func archivedHistory(
        horizontal: CGFloat,
        rowFont: CGFloat
    ) -> some View {
        let archived = viewModel.filteredArchivedConversations
            .sorted { $0.updatedAt > $1.updatedAt }

        if archived.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Archives")
                    .sectionTitleStyle()

                Text("Aucune discussion archivée.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.42))
            }
            .padding(.horizontal, horizontal)
        } else {
            conversationSection(
                title: "Archives",
                conversations: archived,
                horizontal: horizontal,
                rowFont: rowFont
            )
        }
    }

    // MARK: - Sections / rows

    private func conversationSection(
        title: String,
        conversations: [Conversation],
        horizontal: CGFloat,
        rowFont: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionTitleStyle()
                .padding(.horizontal, horizontal)

            VStack(spacing: 3) {
                ForEach(conversations) { conversation in
                    ConversationHistoryRow(
                        conversation: conversation,
                        isSelected: viewModel.currentConversationId == conversation.id,
                        rowFont: rowFont,
                        viewModel: viewModel,
                        onDelete: { requestDeletion(of: conversation) }
                    )
                }
            }
            .padding(.horizontal, max(8, horizontal - 8))
        }
    }

    // MARK: - Bottom bar

    private func footer(
        horizontal: CGFloat,
        circleSize: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.startNewChat()
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Chat")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .frame(height: circleSize)
                .background(
                    Capsule(style: .continuous)
                        .fill(viewModel.activeAgent.themeColor)
                )
                .shadow(
                    color: viewModel.activeAgent.themeColor.opacity(0.22),
                    radius: 14,
                    y: 5
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Nouveau chat")

            Spacer()

            circularButton(
                systemName: "gearshape",
                size: circleSize
            ) {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                isShowingSettings = true
            }
            .accessibilityLabel("Réglages")
        }
        .padding(.horizontal, horizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.90),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func circularButton(
        systemName: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))

                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)

                Image(systemName: systemName)
                    .font(.system(size: size * 0.37, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
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
    let rowFont: CGFloat

    @ObservedObject var viewModel: ChatViewModel
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.selectConversation(conversation)
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color.white.opacity(isSelected ? 0.95 : 0.82))
                        .frame(width: 24)

                    Text(conversation.title)
                        .font(.system(size: rowFont, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.50))
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
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

@available(iOS 15.0, *)
private extension View {
    func sectionTitleStyle() -> some View {
        self
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Color.white.opacity(0.88))
    }
}
