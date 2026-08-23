import SwiftUI

/// Vue Galerie & Centre de Contrôle des 8 Widgets de Sarah IA (SwiftUI iOS 14+) :
/// Affiche l'ensemble des 8 widgets avec données synchronisées en temps réel et actions interactives.
@available(iOS 14.0, *)
public struct WidgetsGalleryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    @State private var widgetStats = SarahWidgetBridge.shared.getStats()
    @State private var isLiveRefreshing = false
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // En-tête descriptif
                        headerBanner
                        
                        // 1. Widget Statistiques & Graphique 7 jours (Largeur Moyenne)
                        widgetCard(
                            number: 1,
                            title: "Statistiques d'Usage & Graphique 7j",
                            description: "Suivez vos interactions et l'activité hebdomadaire."
                        ) {
                            SarahUsageStatsWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                .frame(height: 130)
                                .cornerRadius(16)
                        }
                        
                        // 2 & 3. Grille de 2 Widgets Carrés (Statut & Vocal)
                        HStack(spacing: 14) {
                            widgetCard(
                                number: 2,
                                title: "Statut Sarah",
                                description: "Disponibilité IA"
                            ) {
                                SarahStatusWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                    .frame(height: 140)
                                    .cornerRadius(16)
                            }
                            
                            widgetCard(
                                number: 3,
                                title: "Bouton Vocal",
                                description: "1-Tap Écoute"
                            ) {
                                SarahQuickVoiceWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                    .frame(height: 140)
                                    .cornerRadius(16)
                                    .onTapGesture {
                                        presentationMode.wrappedValue.dismiss()
                                        viewModel.toggleMicrophone()
                                    }
                            }
                        }
                        
                        // 4. Widget Coffre Mémoire (Medium)
                        widgetCard(
                            number: 4,
                            title: "Coffre Mémoire & Souvenirs",
                            description: "Visualisez les derniers souvenirs appris par Sarah."
                        ) {
                            SarahMemoryWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                .frame(height: 130)
                                .cornerRadius(16)
                        }
                        
                        // 5. Widget Dernier Échange & Message (Medium)
                        widgetCard(
                            number: 5,
                            title: "Dernier Échange & Reprise",
                            description: "Dernier message reçu et historique condensé."
                        ) {
                            SarahLastMessageWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                .frame(height: 130)
                                .cornerRadius(16)
                        }
                        
                        // 6. Widget Raccourcis d'Actions Rapides (Medium)
                        widgetCard(
                            number: 6,
                            title: "Raccourcis d'Actions Rapides",
                            description: "Torche, Batterie, Vocal et Mémoire en 1 clic."
                        ) {
                            SarahQuickActionsWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                .frame(height: 130)
                                .cornerRadius(16)
                        }
                        
                        // 7 & 8. Grille Santé Système & Conseil Quotidien
                        HStack(spacing: 14) {
                            widgetCard(
                                number: 7,
                                title: "Santé Système",
                                description: "Latence & FPS"
                            ) {
                                SarahSystemHealthWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                    .frame(height: 140)
                                    .cornerRadius(16)
                            }
                            
                            widgetCard(
                                number: 8,
                                title: "Compact Stats",
                                description: "Compteur brut"
                            ) {
                                SarahCompactStatsWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                    .frame(height: 140)
                                    .cornerRadius(16)
                            }
                        }
                        
                        // Conseil Quotidien (Pleine Largeur)
                        widgetCard(
                            number: 8,
                            title: "Conseil & Astuce du Jour",
                            description: "Suggestions quotidiennes d'utilisation."
                        ) {
                            SarahDailyTipWidgetView(entry: SarahWidgetEntry(date: Date(), stats: widgetStats))
                                .frame(height: 120)
                                .cornerRadius(16)
                        }
                        
                        // Instructions d'installation écran d'accueil
                        homeScreenGuide
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("📊 8 Widgets Sarah IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Fermer")
                            .fontWeight(.semibold)
                            .foregroundColor(.sarahWidgetCyan)
                    }
                }
            }
            .onAppear {
                refreshStats()
            }
        }
    }
    
    // MARK: - Composants UI
    
    private var headerBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sarahWidgetCyan.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.sarahWidgetCyan)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Centre des 8 Widgets")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Actifs en temps réel sur tous vos appareils (iPhone 5S à 16).")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                refreshStats()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.sarahWidgetCyan)
                    .rotationEffect(.degrees(isLiveRefreshing ? 360 : 0))
                    .animation(isLiveRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isLiveRefreshing)
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    @ViewBuilder
    private func widgetCard<Content: View>(
        number: Int,
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("#\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.sarahWidgetCyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.sarahWidgetCyan.opacity(0.18)))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Contenu du Widget
            content()
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.55))
                .lineLimit(1)
        }
    }
    
    private var homeScreenGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.sarahWidgetCyan)
                Text("Comment ajouter un widget à l'écran d'accueil ?")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("1. Sur l'écran d'accueil, maintenez le doigt appuyé sur une zone vide.\n2. Appuyez sur le « + » en haut à gauche.\n3. Recherchez « Sarah IA » et choisissez parmi les 8 widgets !")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineSpacing(3)
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private func refreshStats() {
        isLiveRefreshing = true
        SarahWidgetBridge.shared.syncStats(
            conversationsCount: max(1, viewModel.conversations.count),
            messagesCount: max(4, viewModel.messages.count),
            memoriesCount: viewModel.learnedMemories.count,
            lastMessage: viewModel.messages.last?.content
        )
        self.widgetStats = SarahWidgetBridge.shared.getStats()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLiveRefreshing = false
        }
    }
}
