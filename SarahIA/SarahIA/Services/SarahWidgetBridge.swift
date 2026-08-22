import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(NotificationCenter)
import NotificationCenter
#endif

/// Données statistiques partagées avec les Widgets iOS
public struct WidgetStatsData: Codable {
    public var totalConversations: Int
    public var totalMessages: Int
    public var activeMinutesToday: Int
    public var usagePercentage: Int // Ex: 78% de progression
    public var weeklyActivity: [Int] // 7 barres de graphiques [Lun, Mar, Mer, Jeu, Ven, Sam, Dim]
    public var learnedMemoriesCount: Int
    public var lastMemoryTrigger: String?
    public var lastMemoryResponse: String?
    public var lastMessageSnippet: String?
    public var lastUpdated: Date
    
    public init(
        totalConversations: Int = 0,
        totalMessages: Int = 0,
        activeMinutesToday: Int = 12,
        usagePercentage: Int = 68,
        weeklyActivity: [Int] = [4, 7, 12, 9, 15, 8, 14],
        learnedMemoriesCount: Int = 0,
        lastMemoryTrigger: String? = nil,
        lastMemoryResponse: String? = nil,
        lastMessageSnippet: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.totalConversations = totalConversations
        self.totalMessages = totalMessages
        self.activeMinutesToday = activeMinutesToday
        self.usagePercentage = usagePercentage
        self.weeklyActivity = weeklyActivity
        self.learnedMemoriesCount = learnedMemoriesCount
        self.lastMemoryTrigger = lastMemoryTrigger
        self.lastMemoryResponse = lastMemoryResponse
        self.lastMessageSnippet = lastMessageSnippet
        self.lastUpdated = lastUpdated
    }
}

/// Pont de Contrôle Dynamique des Widgets iOS (WidgetKit Bridge & Today Extension Sync)
public final class SarahWidgetBridge {
    
    public static let shared = SarahWidgetBridge()
    
    private let appGroupSuite = "group.com.sarahia.app"
    private let statsKey = "sarah_widget_stats_v2"
    private let fileName = "sarah_widget_stats.json"
    
    private init() {}
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }
    
    private var fileLocations: [URL] {
        var urls: [URL] = []
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite) {
            urls.append(groupURL.appendingPathComponent(fileName))
        }
        if let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            urls.append(docURL.appendingPathComponent(fileName))
        }
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            urls.append(cacheURL.appendingPathComponent(fileName))
        }
        urls.append(URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName))
        return urls
    }
    
    /// Synchronise les statistiques actuelles de l'application avec les Widgets iOS
    public func syncStats(
        conversationsCount: Int,
        messagesCount: Int,
        memoriesCount: Int,
        lastMemory: (trigger: String, response: String)? = nil,
        lastMessage: String? = nil
    ) {
        var current = getStats()
        current.totalConversations = max(1, conversationsCount)
        current.totalMessages = messagesCount
        current.learnedMemoriesCount = memoriesCount
        
        if let memory = lastMemory {
            current.lastMemoryTrigger = memory.trigger
            current.lastMemoryResponse = memory.response
        }
        if let msg = lastMessage {
            current.lastMessageSnippet = msg
        }
        
        // Calcul du pourcentage d'usage basé sur l'activité
        let score = min(100, max(15, (conversationsCount * 6) + (messagesCount * 3) + (memoriesCount * 5)))
        current.usagePercentage = score
        
        // Mettre à jour l'activité hebdomadaire
        if current.weeklyActivity.isEmpty {
            current.weeklyActivity = [2, 4, 7, 9, 12, 8, max(5, messagesCount)]
        } else {
            var activity = current.weeklyActivity
            if activity.count >= 7 {
                activity[activity.count - 1] = max(activity[activity.count - 1], messagesCount)
            }
            current.weeklyActivity = activity
        }
        
        current.lastUpdated = Date()
        
        saveStats(current)
        reloadWidgets()
    }
    
    /// Enregistre les données statistiques sur tous les supports partagés
    public func saveStats(_ stats: WidgetStatsData) {
        guard let encoded = try? JSONEncoder().encode(stats) else { return }
        
        // 1. UserDefaults (App Group + Standard)
        sharedDefaults?.setValue(encoded, forKey: statsKey)
        UserDefaults.standard.setValue(encoded, forKey: statsKey)
        sharedDefaults?.synchronize()
        UserDefaults.standard.synchronize()
        
        // 2. Fichiers partagés multi-répertoires
        for url in fileLocations {
            try? encoded.write(to: url, options: .atomic)
        }
    }
    
    /// Récupère les données statistiques pour l'affichage des widgets
    public func getStats() -> WidgetStatsData {
        var candidates: [WidgetStatsData] = []
        
        // Lecture App Group UserDefaults
        if let data = sharedDefaults?.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
            candidates.append(decoded)
        }
        
        // Lecture Standard UserDefaults
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
            candidates.append(decoded)
        }
        
        // Lecture Fichiers partagés
        for url in fileLocations {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
                candidates.append(decoded)
            }
        }
        
        // Sélectionner la version la plus récente
        if let newest = candidates.max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return newest
        }
        
        return WidgetStatsData()
    }
    
    /// Recharge les timelines de tous les widgets (iOS 12 Today + iOS 14 WidgetKit)
    public func reloadWidgets() {
        #if canImport(NotificationCenter)
        NCWidgetController().setHasContent(true, forWidgetWithBundleIdentifier: "com.sarahia.app.SarahIAWidgets")
        #endif
        
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    
    // MARK: - Formatage des Grands Nombres (1K, 2M...)
    
    /// Formate un nombre pour un affichage compact et harmonisé sur les widgets :
    /// - Si < 1 000 : affichage direct (ex: 850)
    /// - Si >= 1 000 et < 1 000 000 : suffixe K (ex: 1.5K, 12K)
    /// - Si >= 1 000 000 : suffixe M (ex: 2M, 3.4M)
    public static func formatCompactNumber(_ number: Int) -> String {
        let absNum = abs(number)
        let sign = number < 0 ? "-" : ""
        
        if absNum >= 1_000_000 {
            let millions = Double(absNum) / 1_000_000.0
            if millions.truncatingRemainder(dividingBy: 1.0) == 0 {
                return "\(sign)\(Int(millions))M"
            } else {
                let formatted = String(format: "%.1f", millions)
                let cleaned = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
                return "\(sign)\(cleaned)M"
            }
        } else if absNum >= 1_000 {
            let thousands = Double(absNum) / 1_000.0
            if thousands.truncatingRemainder(dividingBy: 1.0) == 0 {
                return "\(sign)\(Int(thousands))K"
            } else {
                let formatted = String(format: "%.1f", thousands)
                let cleaned = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
                return "\(sign)\(cleaned)K"
            }
        } else {
            return "\(number)"
        }
    }
}

