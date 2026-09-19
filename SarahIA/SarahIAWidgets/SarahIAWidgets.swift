import WidgetKit
import SwiftUI

private let sarahWidgetAppGroup = "group.com.sarahia.app"

private struct WidgetHealthSnapshot: Codable {
    var stepsToday: Double
    var stepsMonth: Double
    var stepsPreviousMonth: Double
    var distanceTodayKM: Double
    var activeEnergyTodayKcal: Double
    var exerciseMinutesToday: Double
    var standMinutesToday: Double
    var restingHeartRate: Double
    var dailySteps: [Double]
    var monthTrendPercent: Double
    var updatedAt: Date

    static let empty = WidgetHealthSnapshot(
        stepsToday: 0,
        stepsMonth: 0,
        stepsPreviousMonth: 0,
        distanceTodayKM: 0,
        activeEnergyTodayKcal: 0,
        exerciseMinutesToday: 0,
        standMinutesToday: 0,
        restingHeartRate: 0,
        dailySteps: Array(repeating: 0, count: 7),
        monthTrendPercent: 0,
        updatedAt: Date()
    )
}

private struct WidgetUsageSnapshot: Codable {
    var questionsToday: Int
    var questions7Days: Int
    var questions30Days: Int
    var totalQuestions: Int
    var conversationCount: Int
    var dailyQuestions: [Int]
    var updatedAt: Date

    static let empty = WidgetUsageSnapshot(
        questionsToday: 0,
        questions7Days: 0,
        questions30Days: 0,
        totalQuestions: 0,
        conversationCount: 0,
        dailyQuestions: Array(repeating: 0, count: 7),
        updatedAt: Date()
    )
}

private enum WidgetStore {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: sarahWidgetAppGroup) ?? .standard
    }

    static var healthEnabled: Bool {
        defaults.bool(forKey: "sarah.widget.health.enabled.v1")
    }

    static func health() -> WidgetHealthSnapshot {
        guard let data = defaults.data(forKey: "sarah.widget.health.v1"),
              let snapshot = try? JSONDecoder().decode(WidgetHealthSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func usage() -> WidgetUsageSnapshot {
        guard let data = defaults.data(forKey: "sarah.widget.usage.v1"),
              let snapshot = try? JSONDecoder().decode(WidgetUsageSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

private struct SarahWidgetEntry: TimelineEntry {
    let date: Date
    let health: WidgetHealthSnapshot
    let usage: WidgetUsageSnapshot
    let healthEnabled: Bool
}

private struct SarahWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SarahWidgetEntry {
        SarahWidgetEntry(
            date: Date(),
            health: WidgetHealthSnapshot(
                stepsToday: 6842,
                stepsMonth: 124_000,
                stepsPreviousMonth: 111_000,
                distanceTodayKM: 4.9,
                activeEnergyTodayKcal: 418,
                exerciseMinutesToday: 24,
                standMinutesToday: 510,
                restingHeartRate: 61,
                dailySteps: [4200, 6800, 7100, 5100, 9200, 7600, 6842],
                monthTrendPercent: 11.7,
                updatedAt: Date()
            ),
            usage: WidgetUsageSnapshot(
                questionsToday: 18,
                questions7Days: 112,
                questions30Days: 403,
                totalQuestions: 1860,
                conversationCount: 47,
                dailyQuestions: [9, 14, 21, 17, 11, 22, 18],
                updatedAt: Date()
            ),
            healthEnabled: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SarahWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SarahWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> SarahWidgetEntry {
        SarahWidgetEntry(
            date: Date(),
            health: WidgetStore.health(),
            usage: WidgetStore.usage(),
            healthEnabled: WidgetStore.healthEnabled
        )
    }
}

private struct WidgetShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 0.035, green: 0.045, blue: 0.075),
                        Color(red: 0.018, green: 0.020, blue: 0.030)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}

private struct RingMetric: View {
    let value: Double
    let goal: Double
    let icon: String
    let label: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 47, height: 47)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
        }
    }
}

private struct SparkBars: View {
    let values: [Double]

    private var maximum: Double {
        max(values.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.55), .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: max(5, 38 * (value / maximum)))
            }
        }
        .frame(height: 40)
    }
}

private struct SarahHealthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SarahWidgetEntry

    var body: some View {
        WidgetShell {
            if !entry.healthEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Santé Sarah", systemImage: "heart.text.square.fill")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text("Active Santé dans Sarah IA")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("Réglages → Widgets et Santé")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                }
            } else if family == .systemLarge {
                largeHealth
            } else {
                mediumHealth
            }
        }
        .widgetURL(URL(string: "sarahia://widgets"))
        .redacted(reason: .privacy)
        .unredacted()
    }

    private var mediumHealth: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Santé", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.cyan)

                Text("\(Int(entry.health.stepsToday))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("pas aujourd’hui")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.55))

                Text(trendLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(entry.health.monthTrendPercent >= 0 ? .green : .orange)
            }

            Spacer(minLength: 0)

            VStack(spacing: 9) {
                HStack(spacing: 9) {
                    RingMetric(value: entry.health.stepsToday, goal: 10_000, icon: "figure.walk", label: "Pas")
                    RingMetric(value: entry.health.exerciseMinutesToday, goal: 30, icon: "figure.run", label: "Exercice")
                    RingMetric(value: entry.health.activeEnergyTodayKcal, goal: 500, icon: "flame.fill", label: "Énergie")
                }

                SparkBars(values: normalizedDailySteps)
            }
            .frame(maxWidth: 190)
        }
    }

    private var largeHealth: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Tableau Santé", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("Sarah")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 12) {
                statCard(value: "\(Int(entry.health.stepsToday))", label: "Pas")
                statCard(value: String(format: "%.1f km", entry.health.distanceTodayKM), label: "Distance")
                statCard(value: "\(Int(entry.health.activeEnergyTodayKcal))", label: "kcal")
            }

            HStack(spacing: 16) {
                RingMetric(value: entry.health.stepsToday, goal: 10_000, icon: "figure.walk", label: "Pas")
                RingMetric(value: entry.health.exerciseMinutesToday, goal: 30, icon: "figure.run", label: "Exercice")
                RingMetric(value: entry.health.standMinutesToday, goal: 720, icon: "figure.stand", label: "Debout")
                RingMetric(value: entry.health.activeEnergyTodayKcal, goal: 500, icon: "flame.fill", label: "Énergie")
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("7 derniers jours")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.68))
                    Spacer()
                    Text(trendLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(entry.health.monthTrendPercent >= 0 ? .green : .orange)
                }

                SparkBars(values: normalizedDailySteps)
            }

            HStack {
                Label(
                    entry.health.restingHeartRate > 0 ? "\(Int(entry.health.restingHeartRate)) bpm repos" : "FC repos indisponible",
                    systemImage: "heart.fill"
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.58))

                Spacer()

                Text("Mis à jour \(entry.health.updatedAt, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var normalizedDailySteps: [Double] {
        let values = entry.health.dailySteps
        if values.count == 7 { return values }
        return Array(values.prefix(7)) + Array(repeating: 0, count: max(0, 7 - values.count))
    }

    private var trendLabel: String {
        let value = entry.health.monthTrendPercent
        if abs(value) < 0.5 {
            return "≈ mois précédent"
        }
        return value >= 0
            ? String(format: "+%.0f%% vs mois précédent", value)
            : String(format: "%.0f%% vs mois précédent", value)
    }
}

private struct SarahUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SarahWidgetEntry

    var body: some View {
        WidgetShell {
            if family == .systemSmall {
                smallUsage
            } else {
                mediumUsage
            }
        }
        .widgetURL(URL(string: "sarahia://chat"))
    }

    private var smallUsage: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.cyan)
                Text("Sarah")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            Spacer()

            Text("\(entry.usage.questionsToday)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("questions aujourd’hui")
                .font(.caption)
                .foregroundColor(.white.opacity(0.58))

            Text("\(entry.usage.questions7Days) cette semaine")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.cyan)
        }
    }

    private var mediumUsage: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Activité Sarah", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.cyan)

                Text("\(entry.usage.questionsToday)")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("questions aujourd’hui")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.55))

                HStack(spacing: 10) {
                    miniStat("\(entry.usage.questions7Days)", "7 j")
                    miniStat("\(entry.usage.questions30Days)", "30 j")
                    miniStat("\(entry.usage.conversationCount)", "chats")
                }
            }

            Spacer(minLength: 0)

            UsageBars(values: entry.usage.dailyQuestions)
                .frame(width: 115)
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.42))
        }
    }
}

private struct UsageBars: View {
    let values: [Int]

    private var maximum: Int {
        max(values.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.prefix(7).enumerated()), id: \.offset) { index, value in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(index == min(values.count, 7) - 1 ? Color.cyan : Color.blue.opacity(0.5))
                        .frame(height: max(7, 72 * CGFloat(value) / CGFloat(maximum)))

                    Text(dayLetter(index))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 90)
    }

    private func dayLetter(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        let date = Calendar.current.date(byAdding: .day, value: index - 6, to: Date()) ?? Date()
        return String(formatter.shortWeekdaySymbols[Calendar.current.component(.weekday, from: date) - 1].prefix(1)).uppercased()
    }
}

private struct SarahQuickWidgetView: View {
    let entry: SarahWidgetEntry

    var body: some View {
        WidgetShell {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.cyan)
                    Text("Sarah rapide")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }

                Link(destination: URL(string: "sarahia://chat")!) {
                    quickRow("Nouveau chat", icon: "square.and.pencil")
                }

                Link(destination: URL(string: "sarahia://voice")!) {
                    quickRow("Mode vocal", icon: "waveform.circle.fill")
                }

                Link(destination: URL(string: "shortcuts://")!) {
                    quickRow("Raccourcis", icon: "square.stack.3d.up.fill")
                }
            }
        }
    }

    private func quickRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .opacity(0.45)
        }
        .foregroundColor(.white)
        .padding(.vertical, 5)
    }
}

struct SarahHealthWidget: Widget {
    let kind = "SarahHealthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { entry in
            SarahHealthWidgetView(entry: entry)
        }
        .configurationDisplayName("Sarah · Santé")
        .description("Pas, activité, énergie, distance et tendance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct SarahUsageWidget: Widget {
    let kind = "SarahUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { entry in
            SarahUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Sarah · Activité")
        .description("Nombre de questions et discussions avec Sarah.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SarahQuickWidget: Widget {
    let kind = "SarahQuickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SarahWidgetProvider()) { entry in
            SarahQuickWidgetView(entry: entry)
        }
        .configurationDisplayName("Sarah · Rapide")
        .description("Accès rapide au chat, à la voix et à Raccourcis.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct SarahIAWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SarahHealthWidget()
        SarahUsageWidget()
        SarahQuickWidget()
    }
}
