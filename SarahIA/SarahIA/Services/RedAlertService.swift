import Foundation
import UIKit

/// Service de Surveillance et Alertes Temps Réel Pikoud HaOref / Red Alert Israël (100% Compatible iOS 12 à 18) :
/// - Vérification des flux d'alertes officiels du Commandement du Front Intérieur (Pikoud HaOref)
/// - Détection d'alertes en temps réel (Tzeva Adom, roquettes, drones, etc.)
/// - Déclenchement de notifications sonores et haptiques immédiates
/// - Réponses naturelles de Sarah sur l'état de sécurité en Israël
public final class RedAlertService: NSObject {
    
    public static let shared = RedAlertService()
    
    // MARK: - Structures de Données
    public struct AlertItem: Codable {
        public let id: String
        public let title: String
        public let description: String
        public let cities: [String]
        public let timestamp: Date
        public let category: Int
        
        public var formattedCities: String {
            return cities.joined(separator: ", ")
        }
    }
    
    public private(set) var activeAlerts: [AlertItem] = []
    public private(set) var recentAlerts: [AlertItem] = []
    public private(set) var lastCheckDate: Date = Date()
    public private(set) var isMonitoring: Bool = false
    
    private var timer: Timer?
    public var onNewAlertDetected: ((AlertItem) -> Void)?
    
    public static let redAlertNotification = NSNotification.Name("SarahRedAlertDidTriggerNotification")
    
    private override init() {
        super.init()
    }
    
    // MARK: - 1. Démarrage de la Surveillance
    
    public func startMonitoring(interval: TimeInterval = 10.0) {
        guard !isMonitoring else { return }
        isMonitoring = true
        checkAlerts()
        
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkAlerts()
            }
        }
    }
    
    public func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - 2. Interrogation des Flux d'Alertes
    
    public func checkAlerts(completion: (([AlertItem]) -> Void)? = nil) {
        lastCheckDate = Date()
        
        // Endpoint officiel Pikoud HaOref (Front Intérieur)
        guard let url = URL(string: "https://www.oref.org.il/WarningMessages/alert/alerts.json") else {
            completion?([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("https://www.oref.org.il/", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 6.0
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let data = data, error == nil, !data.isEmpty else {
                DispatchQueue.main.async { completion?(self.activeAlerts) }
                return
            }
            
            // Tentative de décodage du format Pikoud HaOref
            if let jsonString = String(data: data, encoding: .utf16) ?? String(data: data, encoding: .utf8),
               !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                if let jsonData = jsonString.data(using: .utf8),
                   let alertDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    let id = alertDict["id"] as? String ?? UUID().uuidString
                    let title = alertDict["title"] as? String ?? "Alerte de Sécurité"
                    let desc = alertDict["desc"] as? String ?? "Mise à l'abri requise"
                    let cat = alertDict["cat"] as? Int ?? 1
                    let rawData = alertDict["data"] as? [String] ?? []
                    
                    if !rawData.isEmpty {
                        let newAlert = AlertItem(
                            id: id,
                            title: title,
                            description: desc,
                            cities: rawData,
                            timestamp: Date(),
                            category: cat
                        )
                        
                        DispatchQueue.main.async {
                            self.handleIncomingAlert(newAlert)
                            completion?([newAlert])
                        }
                        return
                    }
                }
            }
            
            // Pas d'alerte en cours
            DispatchQueue.main.async {
                self.activeAlerts = []
                completion?([])
            }
        }
        task.resume()
    }
    
    private func handleIncomingAlert(_ alert: AlertItem) {
        // Évite les doublons récents
        if !recentAlerts.contains(where: { $0.id == alert.id }) {
            recentAlerts.insert(alert, at: 0)
            if recentAlerts.count > 30 {
                recentAlerts.removeLast()
            }
            activeAlerts = [alert]
            
            // Retours Haptiques et Notifications
            HapticService.shared.notificationError()
            NotificationCenter.default.post(name: RedAlertService.redAlertNotification, object: alert)
            onNewAlertDetected?(alert)
        }
    }
    
    // MARK: - 3. Réponses Vocales & Synthèse pour Sarah
    
    public func getSecurityStatusSummary(completion: @escaping (String) -> Void) {
        checkAlerts { [weak self] alerts in
            guard let self = self else {
                completion("Impossible de vérifier le statut des alertes pour le moment.")
                return
            }
            
            if alerts.isEmpty {
                if let last = self.recentAlerts.first {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .full
                    let relativeTime = formatter.localizedString(for: last.timestamp, relativeTo: Date())
                    completion("🟢 Situation calme actuellement. Aucune alerte active en Israël selon Pikoud HaOref. Dernière alerte signalée \(relativeTime) à \(last.formattedCities).")
                } else {
                    completion("🟢 Situation calme. Aucune alerte active signalée par le Commandement du Front Intérieur en Israël.")
                }
            } else {
                let alert = alerts[0]
                completion("🚨 ATTENTION : Alerte en cours signalée par Pikoud HaOref dans les localités suivantes : \(alert.formattedCities). Mise à l'abri immédiate conseillée !")
            }
        }
    }
}
