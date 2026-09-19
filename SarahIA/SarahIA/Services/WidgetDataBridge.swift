import Foundation
import HealthKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Pont de données entre Sarah IA, HealthKit et l'extension WidgetKit.
/// Les widgets ne lisent jamais directement l'historique complet HealthKit :
/// l'app principale calcule un résumé puis l'écrit dans l'App Group.
public final class WidgetDataBridge {

    public static let shared = WidgetDataBridge()

    public struct HealthSnapshot: Codable {
        public var stepsToday: Double
        public var stepsMonth: Double
        public var stepsPreviousMonth: Double
        public var distanceTodayKM: Double
        public var activeEnergyTodayKcal: Double
        public var exerciseMinutesToday: Double
        public var standMinutesToday: Double
        public var restingHeartRate: Double
        public var dailySteps: [Double]
        public var monthTrendPercent: Double
        public var updatedAt: Date

        public static let empty = HealthSnapshot(
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

    public struct UsageSnapshot: Codable {
        public var questionsToday: Int
        public var questions7Days: Int
        public var questions30Days: Int
        public var totalQuestions: Int
        public var conversationCount: Int
        public var dailyQuestions: [Int]
        public var updatedAt: Date

        public static let empty = UsageSnapshot(
            questionsToday: 0,
            questions7Days: 0,
            questions30Days: 0,
            totalQuestions: 0,
            conversationCount: 0,
            dailyQuestions: Array(repeating: 0, count: 7),
            updatedAt: Date()
        )
    }

    private enum Key {
        static let health = "sarah.widget.health.v1"
        static let usage = "sarah.widget.usage.v1"
        static let timestamps = "sarah.widget.question.timestamps.v1"
        static let totalQuestions = "sarah.widget.question.total.v1"
        static let conversationCount = "sarah.widget.conversation.count.v1"
        static let healthEnabled = "sarah.widget.health.enabled.v1"
    }

    private let appGroup = "group.com.sarahia.app"
    private let healthStore = HKHealthStore()
    private let queue = DispatchQueue(label: "com.sarahia.widgetdata", qos: .utility)

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private init() {}

    // MARK: - Usage Sarah

    public func recordQuestion() {
        queue.async {
            let now = Date().timeIntervalSince1970
            var timestamps = self.sharedDefaults.array(forKey: Key.timestamps) as? [Double] ?? []
            timestamps.append(now)

            let cutoff = Date().addingTimeInterval(-35 * 24 * 3600).timeIntervalSince1970
            timestamps.removeAll { $0 < cutoff }

            self.sharedDefaults.set(timestamps, forKey: Key.timestamps)
            let total = self.sharedDefaults.integer(forKey: Key.totalQuestions) + 1
            self.sharedDefaults.set(total, forKey: Key.totalQuestions)
            self.rebuildUsageSnapshot(timestamps: timestamps, totalQuestions: total)
        }
    }

    public func updateConversationCount(_ count: Int) {
        queue.async {
            self.sharedDefaults.set(max(0, count), forKey: Key.conversationCount)
            let timestamps = self.sharedDefaults.array(forKey: Key.timestamps) as? [Double] ?? []
            let total = self.sharedDefaults.integer(forKey: Key.totalQuestions)
            self.rebuildUsageSnapshot(timestamps: timestamps, totalQuestions: total)
        }
    }

    private func rebuildUsageSnapshot(timestamps: [Double], totalQuestions: Int) {
        let calendar = Calendar.current
        let now = Date()
        let dates = timestamps.map(Date.init(timeIntervalSince1970:))

        let today = dates.filter { calendar.isDateInToday($0) }.count
        let sevenStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let thirtyStart = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now

        let week = dates.filter { $0 >= sevenStart }.count
        let month = dates.filter { $0 >= thirtyStart }.count

        let daily = (0..<7).map { offset -> Int in
            let target = calendar.date(byAdding: .day, value: offset - 6, to: now) ?? now
            return dates.filter { calendar.isDate($0, inSameDayAs: target) }.count
        }

        let snapshot = UsageSnapshot(
            questionsToday: today,
            questions7Days: week,
            questions30Days: month,
            totalQuestions: totalQuestions,
            conversationCount: sharedDefaults.integer(forKey: Key.conversationCount),
            dailyQuestions: daily,
            updatedAt: now
        )

        store(snapshot, key: Key.usage)
        reloadWidgets()
    }

    // MARK: - HealthKit

    public var isHealthWidgetEnabled: Bool {
        get { sharedDefaults.bool(forKey: Key.healthEnabled) }
        set {
            sharedDefaults.set(newValue, forKey: Key.healthEnabled)
            reloadWidgets()
        }
    }

    public func requestHealthAuthorization(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.success(false))
            return
        }

        let readTypes = healthReadTypes()
        healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes) { success, error in
            if let error {
                completion(.failure(error))
                return
            }

            self.isHealthWidgetEnabled = success
            if success {
                self.refreshHealthSnapshot {
                    completion(.success(true))
                }
            } else {
                completion(.success(false))
            }
        }
    }

    public func refreshHealthSnapshot(completion: (() -> Void)? = nil) {
        guard isHealthWidgetEnabled, HKHealthStore.isHealthDataAvailable() else {
            completion?()
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? startToday
        let startPreviousMonth = calendar.date(byAdding: .month, value: -1, to: startMonth) ?? startMonth
        let startSevenDays = calendar.date(byAdding: .day, value: -6, to: startToday) ?? startToday

        let group = DispatchGroup()
        let lock = NSLock()

        var stepsToday = 0.0
        var stepsMonth = 0.0
        var stepsPreviousMonth = 0.0
        var distanceToday = 0.0
        var energyToday = 0.0
        var exerciseToday = 0.0
        var standToday = 0.0
        var restingHR = 0.0
        var dailySteps = Array(repeating: 0.0, count: 7)

        func sum(
            _ identifier: HKQuantityTypeIdentifier,
            start: Date,
            end: Date,
            unit: HKUnit,
            assign: @escaping (Double) -> Void
        ) {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                lock.lock()
                assign(value)
                lock.unlock()
                group.leave()
            }
            healthStore.execute(query)
        }

        func average(
            _ identifier: HKQuantityTypeIdentifier,
            start: Date,
            end: Date,
            unit: HKUnit,
            assign: @escaping (Double) -> Void
        ) {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
                lock.lock()
                assign(value)
                lock.unlock()
                group.leave()
            }
            healthStore.execute(query)
        }

        sum(.stepCount, start: startToday, end: now, unit: .count()) { stepsToday = $0 }
        sum(.stepCount, start: startMonth, end: now, unit: .count()) { stepsMonth = $0 }
        sum(.stepCount, start: startPreviousMonth, end: startMonth, unit: .count()) { stepsPreviousMonth = $0 }
        sum(.distanceWalkingRunning, start: startToday, end: now, unit: .meterUnit(with: .kilo)) { distanceToday = $0 }
        sum(.activeEnergyBurned, start: startToday, end: now, unit: .kilocalorie()) { energyToday = $0 }
        sum(.appleExerciseTime, start: startToday, end: now, unit: .minute()) { exerciseToday = $0 }
        sum(.appleStandTime, start: startToday, end: now, unit: .minute()) { standToday = $0 }
        average(.restingHeartRate, start: startSevenDays, end: now, unit: HKUnit.count().unitDivided(by: .minute())) { restingHR = $0 }

        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            var components = DateComponents()
            components.day = 1
            let predicate = HKQuery.predicateForSamples(withStart: startSevenDays, end: now, options: .strictStartDate)
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startToday,
                intervalComponents: components
            )
            query.initialResultsHandler = { _, collection, _ in
                var values = Array(repeating: 0.0, count: 7)
                collection?.enumerateStatistics(from: startSevenDays, to: now) { stats, _ in
                    let days = calendar.dateComponents([.day], from: startSevenDays, to: stats.startDate).day ?? 0
                    if (0..<7).contains(days) {
                        values[days] = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    }
                }
                lock.lock()
                dailySteps = values
                lock.unlock()
                group.leave()
            }
            healthStore.execute(query)
        }

        group.notify(queue: queue) {
            let trend: Double
            if stepsPreviousMonth > 0 {
                trend = ((stepsMonth - stepsPreviousMonth) / stepsPreviousMonth) * 100
            } else {
                trend = 0
            }

            let snapshot = HealthSnapshot(
                stepsToday: stepsToday,
                stepsMonth: stepsMonth,
                stepsPreviousMonth: stepsPreviousMonth,
                distanceTodayKM: distanceToday,
                activeEnergyTodayKcal: energyToday,
                exerciseMinutesToday: exerciseToday,
                standMinutesToday: standToday,
                restingHeartRate: restingHR,
                dailySteps: dailySteps,
                monthTrendPercent: trend,
                updatedAt: Date()
            )

            self.store(snapshot, key: Key.health)
            self.reloadWidgets()
            DispatchQueue.main.async { completion?() }
        }
    }

    private func healthReadTypes() -> Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleStandTime,
            .restingHeartRate
        ]

        return Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
    }

    // MARK: - Shared storage

    private func store<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            sharedDefaults.set(data, forKey: key)
        }
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
