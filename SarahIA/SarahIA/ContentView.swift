import SwiftUI

/// Vue principale de l'application — interface de conversation avec Sarah IA.
struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Namespace private var bottomAnchor
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fond avec dégradé subtil
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95),
                        Color(red: 0.93, green: 0.95, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Historique des messages
                    messagesScrollView
                    
                    // Séparateur
                    Divider()
                        .opacity(0.3)
                    
                    // Barre de saisie
                    MessageInputView(
                        text: $viewModel.inputText,
                        isTyping: viewModel.isTyping,
                        onSend: viewModel.sendMessage
                    )
                }
            }
            .navigationTitle("Sarah IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    headerLogo
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    backgroundTestButton
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Composants
    
    /// Logo dans la barre de navigation.
    private var headerLogo: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.55, green: 0.35, blue: 0.85),
                                Color(red: 0.35, green: 0.25, blue: 0.75)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                Text("🤖")
                    .font(.system(size: 14))
            }
            
            Text("En ligne")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.green)
        }
    }
    
    /// Bouton de test de notification en arrière-plan.
    private var backgroundTestButton: some View {
        Button {
            viewModel.sendBackgroundTest()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 14))
                Text("Test")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(Color(red: 0.0, green: 0.34, blue: 0.64))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(red: 0.0, green: 0.34, blue: 0.64).opacity(0.1))
            )
        }
        .disabled(viewModel.isTyping)
        .opacity(viewModel.isTyping ? 0.5 : 1.0)
    }
    
    /// Liste scrollable des messages avec auto-scroll.
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // En-tête de bienvenue
                    welcomeHeader
                    
                    // Messages
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                            .id(message.id)
                    }
                    
                    // Indicateur de frappe
                    if viewModel.isTyping {
                        TypingIndicatorView()
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id("typing")
                    }
                    
                    // Ancre invisible pour le scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isTyping) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
    
    /// En-tête de bienvenue affiché en haut de la conversation.
    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.55, green: 0.35, blue: 0.85).opacity(0.2),
                                Color(red: 0.35, green: 0.25, blue: 0.75).opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Text("🤖")
                    .font(.system(size: 36))
            }
            
            Text("Sarah IA")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Assistante IA • Toujours disponible")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("En ligne")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.1))
            )
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
