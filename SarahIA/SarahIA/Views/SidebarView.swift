import SwiftUI
import UIKit

/// Menu latéral moderne de Sarah, inspiré de la structure de ChatGPT
/// tout en conservant l'identité visuelle Sarah.
@available(iOS 16.0, *)
public struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool

    @State private var isSearching = false
    @State private var isShowingArchives = false
    @State private var conversationPendingDeletion: Conversation?

    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }

    public var body: some View {
        GeometryReader { geo in
            let width = max(CGFloat(280), geo.size.width)
            let horizontal = max(CGFloat(16), min(CGFloat(24), width * 0.055))
            let circle = max(CGFloat(48), min(CGFloat(58), width * 0.16))

            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(horizontal: horizontal, circle: circle)

                    if isSearching {
                        searchField(horizontal: horizontal)
                            .padding(.top, 8)
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            if isShowingArchives {
                                archivedSection(horizontal: horizontal)
                            } else {
                                activeSections(horizontal: horizontal)
                            }
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 112)
                    }
                }

                footer(horizontal: horizontal, circle: circle)
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Supprimer cette discussion ?",
            item: $conversationPendingDeletion
        ) { conversation in
            Button("Supprimer", role: .destructive) {
                viewModel.deleteConversation(conversation)
            }
            Button("Annuler", role: .cancel) {}
        } message: { _ in
            Text("Cette action est définitive.")
        }
    }

    private func header(horizontal: CGFloat, circle: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text(isShowingArchives ? "Archives" : "Sarah")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    if isShowingArchives {
                        isShowingArchives = false
                    } else {
                        isSearching.toggle()
                        if !isSearching {
                            viewModel.searchQuery = ""
                        }
                    }
                }
            } label: {
                Image(systemName: isShowingArchives ? "chevron.left" : (isSearching ? "xmark" : "magnifyingglass"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: circle, height: circle)
                    .background(Circle().fill(Color.white.opacity(0.10)))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, horizontal)
        .padding(.top, max(18, currentSafeAreaInsets.top + 8))
        .padding(.bottom, 4)
    }

    private func searchField(horizontal: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.white.opacity(0.46))

            TextField("Rechercher", text: $viewModel.searchQuery)
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
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

    @ViewBuilder
    private func activeSections(horizontal: CGFloat) -> some View {
        let pinned = viewModel.filteredPinnedConversations.sorted { $0.updatedAt > $1.updatedAt }
        let recent = viewModel.filteredRecentConversations.sorted { $0.updatedAt > $1.updatedAt }

        if !pinned.isEmpty {
            conversationSection(title: "Épinglés", conversations: pinned, horizontal: horizontal)
        }

        conversationSection(
            title: "Récents",
            conversations: recent,
            horizontal: horizontal
        )

        if !viewModel.filteredArchivedConversations.isEmpty {
            Button {
                HapticService.shared.buttonTap()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingArchives = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .frame(width: 24)
                    Text("Archives")
                        .font(.system(size: 17))
                    Spacer()
                    Text("\(viewModel.filteredArchivedConversations.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.40))
                }
                .foregroundColor(.white)
                .padding(.horizontal, horizontal)
                .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func archivedSection(horizontal: CGFloat) -> some View {
        let archived = viewModel.filteredArchivedConversations.sorted { $0.updatedAt > $1.updatedAt }

        if archived.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Archives")
                    .sectionHeader()
                Text("Aucune discussion archivée.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.42))
            }
            .padding(.horizontal, horizontal)
        } else {
            conversationSection(title: "Archives", conversations: archived, horizontal: horizontal)
        }
    }

    private func conversationSection(
        title: String,
        conversations: [Conversation],
        horizontal: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionHeader()
                .padding(.horizontal, horizontal)

            VStack(spacing: 4) {
                if conversations.isEmpty && title == "Récents" {
                    Text("Aucune discussion pour le moment.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.42))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontal)
                        .padding(.vertical, 8)
                } else {
                    ForEach(conversations) { conversation in
                        conversationRow(conversation, horizontal: horizontal)
                    }
                }
            }
        }
    }

    private func conversationRow(_ conversation: Conversation, horizontal: CGFloat) -> some View {
        HStack(spacing: 2) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.selectConversation(conversation)
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 17))
                        .frame(width: 24)

                    Text(conversation.title)
                        .font(.system(size: 17))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    viewModel.togglePinConversation(conversation)
                } label: {
                    Label(conversation.isPinned ? "Désépingler" : "Épingler",
                          systemImage: conversation.isPinned ? "pin.slash" : "pin")
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
                    conversationPendingDeletion = conversation
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.46))
                    .frame(width: 40, height: 44)
            }
        }
        .padding(.horizontal, max(8, horizontal - 8))
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    viewModel.currentConversationId == conversation.id
                    ? Color.white.opacity(0.12)
                    : Color.clear
                )
        )
    }

    private func footer(horizontal: CGFloat, circle: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.startNewChat()
                viewModel.closeDrawer()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                    Text("Chat")
                        .fontWeight(.bold)
                }
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .frame(height: circle)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                viewModel.closeDrawer()
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: circle, height: circle)
                    .background(Circle().fill(Color.white.opacity(0.10)))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, horizontal)
        .padding(.top, 10)
        .padding(.bottom, max(10, currentSafeAreaInsets.bottom + 4))
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.92), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var currentSafeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets ?? .zero
    }
}

@available(iOS 16.0, *)
private extension View {
    func sectionHeader() -> some View {
        self
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Color.white.opacity(0.90))
    }
}
