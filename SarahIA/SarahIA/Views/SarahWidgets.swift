import SwiftUI

// MARK: - Modèle de Données des Widgets

public struct SarahWidgetEntry: Identifiable {
    public let id = UUID()
    public let date: Date
    public let stats: WidgetStatsData
    
    public init(date: Date = Date(), stats: WidgetStatsData = WidgetStatsData()) {
        self.date = date
        self.stats = stats
    }
}

// MARK: - 1. Widget Statistiques & Graphique Allongé (Medium)

public struct SarahUsageStatsWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // COLONNE GAUCHE : Chiffres clés & Pourcentages
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("👩🏻‍💼")
                        .font(.system(size: 16))
                    Text("Sarah IA")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Badge Pourcentage d'usage
                    Text("\(entry.stats.usagePercentage)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.cyan.opacity(0.2)))
                }
                
                Spacer()
                
                // Nombre de discussions
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.stats.totalConversations)")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Text("Discussions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // Temps passé / Messages
                HStack(spacing: 8) {
                    Label("\(entry.stats.activeMinutesToday)m", systemImage: "clock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    Label("\(entry.stats.learnedMemoriesCount)", systemImage: "brain.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.purple)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // SÉPARATEUR
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
                .padding(.vertical, 4)
            
            // COLONNE DROITE : Graphique en Barres d'Activité 7 Jours
            VStack(alignment: .leading, spacing: 6) {
                Text("Activité 7j")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(alignment: .bottom, spacing: 6) {
                    let days = ["L", "M", "M", "J", "V", "S", "D"]
                    let values = entry.stats.weeklyActivity
                    let maxVal = max(1, values.max() ?? 1)
                    
                    ForEach(0..<min(7, values.count), id: \.self) { i in
                        let val = values[i]
                        let ratio = CGFloat(val) / CGFloat(maxVal)
                        let barHeight = max(8.0, ratio * 48.0)
                        let isToday = (i == 6)
                        
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    isToday
                                    ? LinearGradient(
                                        gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.4)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 10, height: barHeight)
                                .shadow(color: isToday ? Color.cyan.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
                            
                            Text(days[i])
                                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                                .foregroundColor(isToday ? .cyan : .gray)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: 115)
        }
        .padding(14)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.11),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - 2. Widget Carré Compact (Small)

public struct SarahCompactStatsWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("👩🏻‍💼")
                    .font(.system(size: 20))
                Spacer()
                Text("\(entry.stats.usagePercentage)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            Text("\(entry.stats.totalConversations)")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)
            
            Text("Discussions Sarah IA")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("IA Prête & Active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }
}

// MARK: - 3. Widget Mémoire & Brain Vault (Medium)

public struct SarahMemoryWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text("🧠")
                    Text("Mémoire de Sarah")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(entry.stats.learnedMemoriesCount) souvenirs")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.purple.opacity(0.2)))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if let trigger = entry.stats.lastMemoryTrigger, let resp = entry.stats.lastMemoryResponse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dernier apprentissage :")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Text("« \(trigger) » ➔ « \(resp) »")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                        .lineLimit(2)
                }
            } else {
                Text("Dites « Apprends [mot] » à Sarah pour lui enseigner des souvenirs personnalisés !")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - 4. Widget Statut & Avatar (Small)

public struct SarahStatusWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("👩🏻‍💼")
                    .font(.system(size: 22))
                Spacer()
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
            }
            
            Spacer()
            
            Text("Sarah IA")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text("Toujours à l'écoute")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }
}

// MARK: - 5. Widget Accès Vocal Instantané (Small)

public struct SarahQuickVoiceWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.cyan.opacity(0.4), radius: 10)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Parler à Sarah")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            Text("1-Tap Conversation")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - 6. Widget Dernier Message & Discussion (Medium)

public struct SarahLastMessageWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("💬")
                Text("Dernier échange")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Il y a un instant")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Text(entry.stats.lastMessageSnippet ?? "« Bonjour ! Je suis là pour vous aider à tout moment. »")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            
            Spacer()
            
            HStack {
                Text("👩🏻‍💼 Sarah IA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                
                Spacer()
                
                Text("\(entry.stats.totalMessages) messages")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - 7. Widget Actions Rapides (Medium)

public struct SarahQuickActionsWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("⚡ Raccourcis Sarah")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(entry.stats.usagePercentage)% actif")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            HStack(spacing: 10) {
                actionTile(icon: "mic.fill", label: "Vocal", color: .cyan)
                actionTile(icon: "plus.bubble.fill", label: "Nouveau", color: .purple)
                actionTile(icon: "brain.head.profile", label: "Mémoire", color: .indigo)
                actionTile(icon: "person.crop.circle.fill", label: "Avatar", color: .pink)
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
    
    private func actionTile(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - 8. Widget Santé & Latence Système (Small)

public struct SarahSystemHealthWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🟢")
                    .font(.system(size: 12))
                Text("Système")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("60 FPS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Reconnaissance")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text("100% Locale")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Latence IA")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text("< 0.2s")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.purple)
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - 9. Widget Conseil & Astuce Quotidienne (Medium)

public struct SarahDailyTipWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🌟 Conseil du jour")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Sarah IA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.yellow)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Text("« Parlez-moi naturellement comme à une amie, je mémorise tout ce que vous me dites ! »")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .italic()
                .lineLimit(2)
            
            Spacer()
            
            HStack {
                Text("💡 Astuce : dites « Apprends que... »")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - Intégration WidgetKit Officielle iOS (TimelineProvider & 8 Widgets)

#if canImport(WidgetKit)
import WidgetKit

public struct SarahTimelineEntry: TimelineEntry {
    public let date: Date
    public let stats: WidgetStatsData
    
    public init(date: Date = Date(), stats: WidgetStatsData = WidgetStatsData()) {
        self.date = date
        self.stats = stats
    }
}

public struct SarahWidgetProvider: TimelineProvider {
    public typealias Entry = SarahTimelineEntry
    
    public init() {}
    
    public func placeholder(in context: Context) -> SarahTimelineEntry {
        SarahTimelineEntry(date: Date(), stats: WidgetStatsData())
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (SarahTimelineEntry) -> Void) {
        let stats = SarahWidgetBridge.shared.getStats()
        completion(SarahTimelineEntry(date: Date(), stats: stats))
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<SarahTimelineEntry>) -> Void) {
        let stats = SarahWidgetBridge.shared.getStats()
        let entry = SarahTimelineEntry(date: Date(), stats: stats)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// 1. Widget Statistiques
@available(iOS 14.0, *)
public struct SarahUsageStatsWidget: Widget {
    public let kind: String = "SarahUsageStatsWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahUsageStatsWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("1. Statistiques Sarah IA")
        .description("Suivez vos discussions, pourcentages d'usage et graphiques d'activité.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// 2. Widget Statut Avatar
@available(iOS 14.0, *)
public struct SarahStatusWidget: Widget {
    public let kind: String = "SarahStatusWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahStatusWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("2. Avatar & Statut")
        .description("Consultez l'état et lancez une conversation avec Sarah.")
        .supportedFamilies([.systemSmall])
    }
}

// 3. Widget Mémoire
@available(iOS 14.0, *)
public struct SarahMemoryWidget: Widget {
    public let kind: String = "SarahMemoryWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahMemoryWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("3. Coffre Mémoire")
        .description("Visualisez les derniers souvenirs appris par Sarah.")
        .supportedFamilies([.systemMedium])
    }
}

// 4. Widget Accès Vocal Rapide
@available(iOS 14.0, *)
public struct SarahQuickVoiceWidget: Widget {
    public let kind: String = "SarahQuickVoiceWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahQuickVoiceWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("4. Bouton Vocal Instantané")
        .description("Lancez instantanément une conversation vocale avec Sarah.")
        .supportedFamilies([.systemSmall])
    }
}

// 5. Widget Dernier Message
@available(iOS 14.0, *)
public struct SarahLastMessageWidget: Widget {
    public let kind: String = "SarahLastMessageWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahLastMessageWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("5. Dernier Échange")
        .description("Consultez le dernier message et la réponse de Sarah.")
        .supportedFamilies([.systemMedium])
    }
}

// 6. Widget Raccourcis Rapides
@available(iOS 14.0, *)
public struct SarahQuickActionsWidget: Widget {
    public let kind: String = "SarahQuickActionsWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahQuickActionsWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("6. Actions Rapides")
        .description("Accédez directement au vocal, nouveau chat, mémoire et avatar.")
        .supportedFamilies([.systemMedium])
    }
}

// 7. Widget Santé Système
@available(iOS 14.0, *)
public struct SarahSystemHealthWidget: Widget {
    public let kind: String = "SarahSystemHealthWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahSystemHealthWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("7. Santé & Performance")
        .description("Vérifiez l'état de l'IA locale, des FPS et de la latence.")
        .supportedFamilies([.systemSmall])
    }
}

// 8. Widget Conseil Quotidien
@available(iOS 14.0, *)
public struct SarahDailyTipWidget: Widget {
    public let kind: String = "SarahDailyTipWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahDailyTipWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("8. Conseil du Jour")
        .description("Recevez une astuce ou une citation inspirante de Sarah chaque jour.")
        .supportedFamilies([.systemMedium])
    }
}
#endif
