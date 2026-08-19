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

// MARK: - Intégration WidgetKit Officielle iOS (TimelineProvider & Widgets)

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
        let stats = SarahWidgetBridge.shared.readStats()
        completion(SarahTimelineEntry(date: Date(), stats: stats))
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<SarahTimelineEntry>) -> Void) {
        let stats = SarahWidgetBridge.shared.readStats()
        let entry = SarahTimelineEntry(date: Date(), stats: stats)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct SarahUsageStatsWidget: Widget {
    public let kind: String = "SarahUsageStatsWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { entry in
            SarahUsageStatsWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("Statistiques Sarah IA")
        .description("Suivez vos discussions, pourcentages d'usage et graphiques d'activité.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

public struct SarahMemoryWidget: Widget {
    public let kind: String = "SarahMemoryWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { entry in
            SarahMemoryWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("Mémoire Sarah IA")
        .description("Visualisez les derniers souvenirs appris par Sarah.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct SarahStatusWidget: Widget {
    public let kind: String = "SarahStatusWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { entry in
            SarahStatusWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("Avatar & Humeur Sarah IA")
        .description("Consultez l'état et lancez une conversation avec Sarah.")
        .supportedFamilies([.systemSmall])
    }
}

public struct SarahIAWidgetsBundle: WidgetBundle {
    public init() {}
    
    public var body: some Widget {
        SarahUsageStatsWidget()
        SarahMemoryWidget()
        SarahStatusWidget()
    }
}
#endif
