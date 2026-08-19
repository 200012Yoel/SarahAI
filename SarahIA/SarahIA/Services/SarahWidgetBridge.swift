import Foundation
#if canImport(WidgetKit)
import WidgetKit
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

/// Pont de Contrôle Dynamique des Widgets iOS (WidgetKit Bridge)
public final class SarahWidgetBridge {
    
    public static let shared = SarahWidgetBridge()
    
    private let appGroupSuite = "group.com.sarahia.app"
    private let statsKey = "sarah_widget_stats_v2"
    
    private init() {}
    
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
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
        current.totalConversations = conversationsCount
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
        let score = min(100, max(15, (conversationsCount * 8) + (messagesCount * 2) + (memoriesCount * 5)))
        current.usagePercentage = score
        current.lastUpdated = Date()
        
        saveStats(current)
        reloadWidgets()
    }
    
    /// Enregistre les données statistiques
    public func saveStats(_ stats: WidgetStatsData) {
        if let encoded = try? JSONEncoder().encode(stats) {
            sharedDefaults.setValue(encoded, forKey: statsKey)
        }
    }
    
    /// Récupère les données statistiques pour l'affichage des widgets
    public func getStats() -> WidgetStatsData {
        if let data = sharedDefaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
            return decoded
        }
        return WidgetStatsData()
    }
    
    /// Recharge les timelines de tous les widgets
    public func reloadWidgets() {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
