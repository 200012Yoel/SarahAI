import Foundation
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
extension Color {
    public static let sarahWidgetCyan = Color(red: 0.0, green: 0.78, blue: 1.0)
}

// MARK: - Modèle de Données des Widgets

@available(iOS 14.0, *)
public struct SarahWidgetEntry: Identifiable {
    public let id = UUID()
    public let date: Date
    public let stats: WidgetStatsData
    
    public init(date: Date = Date(), stats: WidgetStatsData = WidgetStatsData()) {
        self.date = date
        self.stats = stats
    }
}

// MARK: - 1. WIDGET #1 — CONVERSATIONS
@available(iOS 14.0, *)
public struct SarahConversationsWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("💬")
                    .font(.system(size: 18))
                Spacer()
                Text("Sarah IA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.sarahWidgetCyan)
            }
            
            Spacer()
            
            Text(SarahWidgetBridge.formatCompactNumber(entry.stats.totalConversations))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
            
            Text(entry.stats.totalConversations <= 1 ? "discussion" : "discussions")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .widgetURL(URL(string: "sarahia://conversations"))
    }
}

// MARK: - 2. WIDGET #2 — QUESTIONS
@available(iOS 14.0, *)
public struct SarahQuestionsWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("❓")
                    .font(.system(size: 18))
                Spacer()
                Text("Questions")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
            }
            
            Spacer()
            
            Text(SarahWidgetBridge.formatCompactNumber(entry.stats.totalMessages))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
            
            Text(entry.stats.totalMessages <= 1 ? "question posée" : "questions posées")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .widgetURL(URL(string: "sarahia://newchat"))
    }
}

// MARK: - 3. WIDGET #3 — SARAH BRAIN / KNOWLEDGE
@available(iOS 14.0, *)
public struct SarahKnowledgeWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🧠")
                    .font(.system(size: 18))
                Spacer()
                Text("Cerveau IA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.sarahWidgetCyan)
            }
            
            Spacer()
            
            Text(SarahWidgetBridge.formatCompactNumber(entry.stats.knowledgeCount))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
            
            Text(entry.stats.knowledgeCount <= 1 ? "élément de savoir" : "éléments de savoir")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .widgetURL(URL(string: "sarahia://memory"))
    }
}

// MARK: - 4. WIDGET #4 — SARAH STATUS
@available(iOS 14.0, *)
public struct SarahStatusWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    private var statusColor: Color {
        switch entry.stats.sarahStatus {
        case "En réflexion": return .yellow
        case "Occupée": return .orange
        default: return .green
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("👩🏻‍💼")
                    .font(.system(size: 22))
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Spacer()
            
            Text("Sarah")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 4) {
                Text("●")
                    .font(.system(size: 8))
                    .foregroundColor(statusColor)
                Text(entry.stats.sarahStatus)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
        .widgetURL(URL(string: "sarahia://chat"))
    }
}

// MARK: - 5. WIDGET #5 — TOM VISION
@available(iOS 14.0, *)
public struct SarahTomVisionWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    private var isVisionActive: Bool {
        entry.stats.screenSharingActive || entry.stats.cameraActive || entry.stats.tomStatus != "Vision inactive"
    }
    
    private var tomColor: Color {
        if entry.stats.screenSharingActive {
            return .red
        } else if entry.stats.cameraActive {
            return .sarahWidgetCyan
        } else {
            return .gray
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.stats.screenSharingActive ? "🖥️" : (entry.stats.cameraActive ? "📷" : "👁️"))
                    .font(.system(size: 22))
                Spacer()
                Circle()
                    .fill(tomColor)
                    .frame(width: 8, height: 8)
            }
            
            Spacer()
            
            Text("Tom")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 4) {
                Text("●")
                    .font(.system(size: 8))
                    .foregroundColor(tomColor)
                Text(entry.stats.tomStatus)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .widgetURL(URL(string: entry.stats.screenSharingActive ? "sarahia://screenshare" : "sarahia://camera"))
    }
}

// MARK: - 6. WIDGET #6 — MEMORY
@available(iOS 14.0, *)
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
                    Text("Mémoire Sarah")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(SarahWidgetBridge.formatCompactNumber(entry.stats.learnedMemoriesCount)) souvenirs")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.purple.opacity(0.2)))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if let trigger = entry.stats.lastMemoryTrigger, let resp = entry.stats.lastMemoryResponse {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dernier apprentissage :")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Text("« \(trigger) » ➔ « \(resp) »")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.sarahWidgetCyan)
                        .lineLimit(2)
                }
            } else {
                Text("Dites « Apprends [mot] » à Sarah pour mémoriser des souvenirs personnalisés !")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .widgetURL(URL(string: "sarahia://memory"))
    }
}

// MARK: - 7. WIDGET #7 — ACTIVITY
@available(iOS 14.0, *)
public struct SarahActivityWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("📊")
                Text("Activité récente")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(entry.stats.usagePercentage)% actif")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.sarahWidgetCyan)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("•")
                        .foregroundColor(.sarahWidgetCyan)
                    Text("\(entry.stats.totalMessages) questions au total")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack(spacing: 6) {
                    Text("•")
                        .foregroundColor(.purple)
                    Text("\(entry.stats.learnedMemoriesCount) souvenirs mémorisés")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack(spacing: 6) {
                    Text("•")
                        .foregroundColor(.green)
                    Text("\(entry.stats.totalConversations) discussions actives")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .widgetURL(URL(string: "sarahia://activity"))
    }
}

// MARK: - 8. WIDGET #8 — QUICK SARAH
@available(iOS 14.0, *)
public struct SarahQuickActionsWidgetView: View {
    public let entry: SarahWidgetEntry
    
    public init(entry: SarahWidgetEntry = SarahWidgetEntry()) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("⚡ Quick Sarah")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Accès rapide")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.sarahWidgetCyan)
            }
            
            HStack(spacing: 8) {
                Link(destination: URL(string: "sarahia://voice")!) {
                    actionTile(icon: "mic.fill", label: "Parler", color: .sarahWidgetCyan)
                }
                Link(destination: URL(string: "sarahia://newchat")!) {
                    actionTile(icon: "plus.bubble.fill", label: "Nouveau", color: .purple)
                }
                Link(destination: URL(string: "sarahia://camera")!) {
                    actionTile(icon: "camera.fill", label: "Tom Vision", color: .blue)
                }
                Link(destination: URL(string: "sarahia://screenshare")!) {
                    actionTile(icon: "display", label: "Écran", color: .red)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
    
    private func actionTile(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.18))
                    .frame(height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
    }
}

// MARK: - Intégration WidgetKit Officielle iOS (TimelineProvider & 8 Widgets Dédiés)

#if canImport(WidgetKit)
import WidgetKit

@available(iOS 14.0, *)
public struct SarahTimelineEntry: TimelineEntry {
    public let date: Date
    public let stats: WidgetStatsData
    
    public init(date: Date = Date(), stats: WidgetStatsData = WidgetStatsData()) {
        self.date = date
        self.stats = stats
    }
}

@available(iOS 14.0, *)
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

// 1. WIDGET #1 — CONVERSATIONS
@available(iOS 14.0, *)
public struct SarahConversationsWidget: Widget {
    public let kind: String = "SarahConversationsWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahConversationsWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("1. Discussions")
        .description("Affiche le nombre total de discussions actives avec Sarah IA.")
        .supportedFamilies([.systemSmall])
    }
}

// 2. WIDGET #2 — QUESTIONS
@available(iOS 14.0, *)
public struct SarahQuestionsWidget: Widget {
    public let kind: String = "SarahQuestionsWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahQuestionsWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("2. Questions")
        .description("Affiche le nombre de questions et messages posés à Sarah.")
        .supportedFamilies([.systemSmall])
    }
}

// 3. WIDGET #3 — SARAH BRAIN / KNOWLEDGE
@available(iOS 14.0, *)
public struct SarahKnowledgeWidget: Widget {
    public let kind: String = "SarahKnowledgeWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahKnowledgeWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("3. Cerveau & Connaissances")
        .description("Affiche le nombre d'éléments de savoir mémorisés dans le cerveau de Sarah.")
        .supportedFamilies([.systemSmall])
    }
}

// 4. WIDGET #4 — SARAH STATUS
@available(iOS 14.0, *)
public struct SarahStatusWidget: Widget {
    public let kind: String = "SarahStatusWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahStatusWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("4. Statut Sarah")
        .description("Consultez en direct l'état de disponibilité de Sarah.")
        .supportedFamilies([.systemSmall])
    }
}

// 5. WIDGET #5 — TOM VISION
@available(iOS 14.0, *)
public struct SarahTomVisionWidget: Widget {
    public let kind: String = "SarahTomVisionWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahTomVisionWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("5. Tom Vision")
        .description("Consultez l'état visuel de Tom (Caméra ou Partage d'écran).")
        .supportedFamilies([.systemSmall])
    }
}

// 6. WIDGET #6 — MEMORY
@available(iOS 14.0, *)
public struct SarahMemoryWidget: Widget {
    public let kind: String = "SarahMemoryWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahMemoryWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("6. Mémoire Sarah")
        .description("Visualisez le coffre de souvenirs et derniers apprentissages.")
        .supportedFamilies([.systemMedium])
    }
}

// 7. WIDGET #7 — ACTIVITY
@available(iOS 14.0, *)
public struct SarahActivityWidget: Widget {
    public let kind: String = "SarahActivityWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahActivityWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("7. Activité Récente")
        .description("Consultez le récapitulatif d'activité récente de Sarah IA.")
        .supportedFamilies([.systemMedium])
    }
}

// 8. WIDGET #8 — QUICK SARAH
@available(iOS 14.0, *)
public struct SarahQuickActionsWidget: Widget {
    public let kind: String = "SarahQuickActionsWidget"
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { (entry: SarahTimelineEntry) in
            SarahQuickActionsWidgetView(entry: SarahWidgetEntry(date: entry.date, stats: entry.stats))
        }
        .configurationDisplayName("8. Quick Sarah")
        .description("Accès direct 1-tap au vocal, nouveau chat, Tom Vision et partage d'écran.")
        .supportedFamilies([.systemMedium])
    }
}
#endif
#endif
