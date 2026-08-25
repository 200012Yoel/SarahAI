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
    public var learnedMemoriesCount: Int
    public var knowledgeCount: Int // Eléments de connaissance / Brain index
    public var sarahStatus: String // "Disponible", "En réflexion", "Occupée"
    public var tomStatus: String // "Vision inactive", "Caméra active", "Écran partagé"
    public var screenSharingActive: Bool
    public var cameraActive: Bool
    public var activeMinutesToday: Int
    public var usagePercentage: Int // Ex: 78% de progression
    public var weeklyActivity: [Int] // 7 barres de graphiques [Lun, Mar, Mer, Jeu, Ven, Sam, Dim]
    public var lastMemoryTrigger: String?
    public var lastMemoryResponse: String?
    public var lastMessageSnippet: String?
    public var lastUpdated: Date
    
    public init(
        totalConversations: Int = 0,
        totalMessages: Int = 0,
        learnedMemoriesCount: Int = 0,
        knowledgeCount: Int = 0,
        sarahStatus: String = "Disponible",
        tomStatus: String = "Vision inactive",
        screenSharingActive: Bool = false,
        cameraActive: Bool = false,
        activeMinutesToday: Int = 12,
        usagePercentage: Int = 68,
        weeklyActivity: [Int] = [4, 7, 12, 9, 15, 8, 14],
        lastMemoryTrigger: String? = nil,
        lastMemoryResponse: String? = nil,
        lastMessageSnippet: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.totalConversations = totalConversations
        self.totalMessages = totalMessages
        self.learnedMemoriesCount = learnedMemoriesCount
        self.knowledgeCount = knowledgeCount
        self.sarahStatus = sarahStatus
        self.tomStatus = tomStatus
        self.screenSharingActive = screenSharingActive
        self.cameraActive = cameraActive
        self.activeMinutesToday = activeMinutesToday
        self.usagePercentage = usagePercentage
        self.weeklyActivity = weeklyActivity
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
        knowledgeCount: Int? = nil,
        sarahStatus: String? = nil,
        tomStatus: String? = nil,
        screenSharingActive: Bool? = nil,
        cameraActive: Bool? = nil,
        lastMemory: (trigger: String, response: String)? = nil,
        lastMessage: String? = nil
    ) {
        var current = getStats()
        current.totalConversations = max(0, conversationsCount)
        current.totalMessages = max(0, messagesCount)
        current.learnedMemoriesCount = max(0, memoriesCount)
        
        if let kc = knowledgeCount {
            current.knowledgeCount = kc
        } else {
            current.knowledgeCount = (conversationsCount * 4) + memoriesCount + 120
        }
        
        if let ss = sarahStatus {
            current.sarahStatus = ss
        }
        if let ts = tomStatus {
            current.tomStatus = ts
        }
        if let ssa = screenSharingActive {
            current.screenSharingActive = ssa
            if ssa {
                current.tomStatus = "Écran partagé"
            } else if current.tomStatus == "Écran partagé" {
                current.tomStatus = "Vision inactive"
            }
        }
        if let ca = cameraActive {
            current.cameraActive = ca
            if ca {
                current.tomStatus = "Caméra active"
            } else if current.tomStatus == "Caméra active" {
                current.tomStatus = "Vision inactive"
            }
        }
        
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
    
    /// Enregistre les données statistiques sur tous les supports partagés (App Group prioritaire)
    public func saveStats(_ stats: WidgetStatsData) {
        let encoded = (try? JSONEncoder().encode(stats)) ?? Data()
        let summaryStr = "\(stats.totalConversations)|\(stats.totalMessages)|\(stats.learnedMemoriesCount)|\(stats.usagePercentage)|\(stats.knowledgeCount)|\(stats.sarahStatus)|\(stats.tomStatus)|\(stats.lastUpdated.timeIntervalSince1970)"
        
        // 1. Sauvegarde systématique dans l'App Group partagé group.com.sarahia.app
        if let groupDefaults = sharedDefaults {
            groupDefaults.set(stats.totalConversations, forKey: "totalConversations")
            groupDefaults.set(stats.totalMessages, forKey: "totalMessages")
            groupDefaults.set(stats.learnedMemoriesCount, forKey: "learnedMemoriesCount")
            groupDefaults.set(stats.knowledgeCount, forKey: "knowledgeCount")
            groupDefaults.set(stats.sarahStatus, forKey: "sarahStatus")
            groupDefaults.set(stats.tomStatus, forKey: "tomStatus")
            groupDefaults.set(stats.screenSharingActive, forKey: "screenSharingActive")
            groupDefaults.set(stats.cameraActive, forKey: "cameraActive")
            groupDefaults.set(stats.usagePercentage, forKey: "usagePercentage")
            groupDefaults.set(stats.weeklyActivity, forKey: "weeklyActivity")
            groupDefaults.set(stats.lastMessageSnippet ?? "", forKey: "lastMessageSnippet")
            groupDefaults.set(stats.lastMemoryTrigger ?? "", forKey: "lastMemoryTrigger")
            groupDefaults.set(stats.lastMemoryResponse ?? "", forKey: "lastMemoryResponse")
            groupDefaults.set(stats.lastUpdated.timeIntervalSince1970, forKey: "lastUpdatedTimestamp")
            
            if !encoded.isEmpty {
                groupDefaults.setValue(encoded, forKey: statsKey)
            }
            groupDefaults.synchronize()
        }
        
        // 2. Pont UIPasteboard partagé (100% fiable sur iOS 12)
        if let pasteboard = UIPasteboard(name: UIPasteboard.Name("com.sarahia.app.widgetstats"), create: true) {
            pasteboard.string = summaryStr
        }
        
        // 3. Sauvegarde Standard UserDefaults & Fichiers
        UserDefaults.standard.set(stats.totalConversations, forKey: "totalConversations")
        UserDefaults.standard.set(stats.totalMessages, forKey: "totalMessages")
        UserDefaults.standard.set(stats.learnedMemoriesCount, forKey: "learnedMemoriesCount")
        UserDefaults.standard.set(stats.knowledgeCount, forKey: "knowledgeCount")
        UserDefaults.standard.set(stats.sarahStatus, forKey: "sarahStatus")
        UserDefaults.standard.set(stats.tomStatus, forKey: "tomStatus")
        UserDefaults.standard.set(stats.screenSharingActive, forKey: "screenSharingActive")
        UserDefaults.standard.set(stats.cameraActive, forKey: "cameraActive")
        UserDefaults.standard.set(stats.usagePercentage, forKey: "usagePercentage")
        UserDefaults.standard.set(summaryStr, forKey: "com.sarahia.widget_summary")
        if !encoded.isEmpty {
            UserDefaults.standard.setValue(encoded, forKey: statsKey)
            UserDefaults.standard.synchronize()
            
            for url in fileLocations {
                try? encoded.write(to: url, options: .atomic)
            }
        }
    }
    
    /// Récupère les données statistiques pour l'affichage des widgets (lecture exclusive App Group prioritaire)
    public func getStats() -> WidgetStatsData {
        var candidates: [WidgetStatsData] = []
        
        // 1. Lecture directe et prioritaire depuis l'App Group partagé
        if let groupDefaults = sharedDefaults {
            if let data = groupDefaults.data(forKey: statsKey),
               let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
                candidates.append(decoded)
            } else if groupDefaults.object(forKey: "totalConversations") != nil || groupDefaults.object(forKey: "totalMessages") != nil {
                let convs = groupDefaults.integer(forKey: "totalConversations")
                let msgs = groupDefaults.integer(forKey: "totalMessages")
                let memories = groupDefaults.integer(forKey: "learnedMemoriesCount")
                let knowledge = groupDefaults.integer(forKey: "knowledgeCount")
                let sarahSt = groupDefaults.string(forKey: "sarahStatus") ?? "Disponible"
                let tomSt = groupDefaults.string(forKey: "tomStatus") ?? "Vision inactive"
                let screenActive = groupDefaults.bool(forKey: "screenSharingActive")
                let camActive = groupDefaults.bool(forKey: "cameraActive")
                let usage = groupDefaults.integer(forKey: "usagePercentage")
                let activity = groupDefaults.array(forKey: "weeklyActivity") as? [Int] ?? [4, 7, 12, 9, 15, 8, 14]
                let snippet = groupDefaults.string(forKey: "lastMessageSnippet")
                let trig = groupDefaults.string(forKey: "lastMemoryTrigger")
                let resp = groupDefaults.string(forKey: "lastMemoryResponse")
                let timestamp = groupDefaults.double(forKey: "lastUpdatedTimestamp")
                
                candidates.append(WidgetStatsData(
                    totalConversations: max(0, convs),
                    totalMessages: max(0, msgs),
                    learnedMemoriesCount: max(0, memories),
                    knowledgeCount: knowledge > 0 ? knowledge : ((max(1, convs) * 4) + memories + 120),
                    sarahStatus: sarahSt,
                    tomStatus: tomSt,
                    screenSharingActive: screenActive,
                    cameraActive: camActive,
                    activeMinutesToday: 12,
                    usagePercentage: usage > 0 ? usage : 68,
                    weeklyActivity: activity,
                    lastMemoryTrigger: trig?.isEmpty == false ? trig : nil,
                    lastMemoryResponse: resp?.isEmpty == false ? resp : nil,
                    lastMessageSnippet: snippet?.isEmpty == false ? snippet : nil,
                    lastUpdated: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date()
                ))
            }
        }
        
        // 2. Lecture depuis le pont UIPasteboard partagé
        if let pasteboard = UIPasteboard(name: UIPasteboard.Name("com.sarahia.app.widgetstats"), create: false) {
            if let data = pasteboard.data(forPasteboardType: "public.json"),
               let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
                candidates.append(decoded)
            } else if let str = pasteboard.string {
                let parts = str.components(separatedBy: "|")
                if parts.count >= 4 {
                    let convs = Int(parts[0]) ?? 0
                    let msgs = Int(parts[1]) ?? 0
                    let memories = Int(parts[2]) ?? 0
                    let usage = Int(parts[3]) ?? 68
                    let knowledge = parts.count >= 5 ? (Int(parts[4]) ?? 150) : 150
                    let sarahSt = parts.count >= 6 ? parts[5] : "Disponible"
                    let tomSt = parts.count >= 7 ? parts[6] : "Vision inactive"
                    let timestamp = parts.count >= 8 ? (Double(parts[7]) ?? 0) : 0
                    candidates.append(WidgetStatsData(
                        totalConversations: max(0, convs),
                        totalMessages: max(0, msgs),
                        learnedMemoriesCount: max(0, memories),
                        knowledgeCount: knowledge,
                        sarahStatus: sarahSt,
                        tomStatus: tomSt,
                        screenSharingActive: tomSt == "Écran partagé",
                        cameraActive: tomSt == "Caméra active",
                        activeMinutesToday: 12,
                        usagePercentage: usage,
                        weeklyActivity: [4, 7, 12, 9, 15, 8, max(5, msgs)],
                        lastUpdated: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date()
                    ))
                }
            }
        }
        
        // 3. Lecture Standard UserDefaults de secours
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
            candidates.append(decoded)
        } else if UserDefaults.standard.object(forKey: "totalConversations") != nil {
            let convs = UserDefaults.standard.integer(forKey: "totalConversations")
            let msgs = UserDefaults.standard.integer(forKey: "totalMessages")
            let memories = UserDefaults.standard.integer(forKey: "learnedMemoriesCount")
            let knowledge = UserDefaults.standard.integer(forKey: "knowledgeCount")
            candidates.append(WidgetStatsData(
                totalConversations: max(0, convs),
                totalMessages: max(0, msgs),
                learnedMemoriesCount: max(0, memories),
                knowledgeCount: knowledge > 0 ? knowledge : ((max(1, convs) * 4) + memories + 120),
                lastUpdated: Date()
            ))
        }
        
        // 4. Lecture Fichiers partagés de secours
        for url in fileLocations {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(WidgetStatsData.self, from: data) {
                candidates.append(decoded)
            }
        }
        
        if let newest = candidates.max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return newest
        }
        
        return WidgetStatsData()
    }
    
    /// Recharge immédiatement les timelines et l'affichage de tous les widgets
    public func reloadWidgets() {
        // 1. Today Extension iOS 10 - iOS 14+
        #if canImport(NotificationCenter)
        NCWidgetController().setHasContent(true, forWidgetWithBundleIdentifier: "com.sarahia.app.SarahIAWidgets")
        #endif
        
        // 2. WidgetKit iOS 14+
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
        
        // 3. Notification Darwin inter-processus iOS (réveille le widget Today instantanément sur iOS 12)
        let darwinNotification = "com.sarahia.app.widgetupdate" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinNotification),
            nil,
            nil,
            true
        )
        
        // 4. Notification interne instantanée pour les vues actives
        NotificationCenter.default.post(name: NSNotification.Name("SarahWidgetStatsDidUpdate"), object: nil)
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

