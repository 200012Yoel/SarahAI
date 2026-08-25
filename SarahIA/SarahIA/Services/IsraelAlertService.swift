import Foundation
import CoreLocation

// MARK: - 1. Structure Universelle d'Événement d'Alerte (AlertEvent)

public struct AlertEvent: Codable, Equatable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let type: String // Ex: "Tir de roquettes", "Infiltration de drone"
    public let affectedAreas: [String]
    public let source: String // "Commandement du Front intérieur" ou "SARAH_TEST_ENGINE"
    public let isOfficial: Bool
    public let isTest: Bool
    public let status: String // "active", "cleared", "test"
    public let coordinates: [Double] // [latitude, longitude]
    public let descriptionText: String
    public let cityName: String
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        type: String = "Alerte de Sécurité",
        affectedAreas: [String] = [],
        source: String = "Commandement du Front intérieur",
        isOfficial: Bool = true,
        isTest: Bool = false,
        status: String = "active",
        coordinates: [Double] = [32.0853, 34.7818],
        descriptionText: String = "Mise à l'abri requise dans la zone concernée",
        cityName: String = "Tel Aviv"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.affectedAreas = affectedAreas
        self.source = source
        self.isOfficial = isOfficial
        self.isTest = isTest
        self.status = status
        self.coordinates = coordinates
        self.descriptionText = descriptionText
        self.cityName = cityName
    }
    
    public var latitude: Double {
        coordinates.first ?? 32.0853
    }
    
    public var longitude: Double {
        coordinates.count > 1 ? coordinates[1] : 34.7818
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: timestamp)
    }
}

// MARK: - 2. Service Officiel d'Alertes d'Israël (IsraelAlertService)

public final class IsraelAlertService: NSObject {
    public static let shared = IsraelAlertService()
    
    public private(set) var activeAlerts: [AlertEvent] = []
    public private(set) var recentAlerts: [AlertEvent] = []
    public private(set) var isMonitoring: Bool = false
    public private(set) var lastAlertIDs: Set<String> = []
    
    private var monitoringTimer: Timer?
    private var autoStopTimer: Timer?
    
    public var onNewOfficialAlertDetected: ((AlertEvent) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Surveillance Temporaire (Mode "C'est chaud en Israël" - 10 min max)
    
    public func activateTemporaryMonitoring(durationMinutes: Double = 10.0, pollingIntervalSeconds: Double = 60.0) {
        stopMonitoring()
        isMonitoring = true
        checkOfficialAlerts()
        
        DispatchQueue.main.async { [weak self] in
            // Polling régulier de 60s
            self?.monitoringTimer = Timer.scheduledTimer(withTimeInterval: pollingIntervalSeconds, repeats: true) { [weak self] _ in
                self?.checkOfficialAlerts()
            }
            
            // Arrêt automatique garanti après 10 minutes
            self?.autoStopTimer = Timer.scheduledTimer(withTimeInterval: durationMinutes * 60.0, repeats: false) { [weak self] _ in
                self?.stopMonitoring()
            }
        }
    }
    
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        autoStopTimer?.invalidate()
        autoStopTimer = nil
    }
    
    // MARK: - Interrogation Directe des Alertes Officielles
    
    public func checkOfficialAlerts(completion: (([AlertEvent]) -> Void)? = nil) {
        guard let url = URL(string: "https://www.oref.org.il/WarningMessages/alert/alerts.json") else {
            completion?([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("https://www.oref.org.il/", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            guard let data = data, error == nil, !data.isEmpty else {
                DispatchQueue.main.async { completion?(self.activeAlerts) }
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf16) ?? String(data: data, encoding: .utf8),
               !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                if let jsonData = jsonString.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    let id = dict["id"] as? String ?? UUID().uuidString
                    let title = dict["title"] as? String ?? "Alerte de Sécurité"
                    let desc = dict["desc"] as? String ?? "Mise à l'abri requise"
                    let rawAreas = dict["data"] as? [String] ?? []
                    
                    if !rawAreas.isEmpty {
                        let primaryCityName = rawAreas.first ?? "Tel Aviv"
                        let resolvedCity = IsraelCityDatabase.shared.resolveCity(from: primaryCityName)
                        let coords = [resolvedCity?.latitude ?? 32.0853, resolvedCity?.longitude ?? 34.7818]
                        
                        let officialAlert = AlertEvent(
                            id: id,
                            timestamp: Date(),
                            type: title,
                            affectedAreas: rawAreas,
                            source: "Commandement du Front intérieur",
                            isOfficial: true,
                            isTest: false,
                            status: "active",
                            coordinates: coords,
                            descriptionText: desc,
                            cityName: resolvedCity?.name ?? primaryCityName
                        )
                        
                        DispatchQueue.main.async {
                            self.handleIncomingOfficialAlert(officialAlert)
                            completion?([officialAlert])
                        }
                        return
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.activeAlerts = []
                completion?([])
            }
        }
        task.resume()
    }
    
    private func handleIncomingOfficialAlert(_ alert: AlertEvent) {
        guard !lastAlertIDs.contains(alert.id) else { return }
        lastAlertIDs.insert(alert.id)
        
        recentAlerts.insert(alert, at: 0)
        if recentAlerts.count > 40 {
            recentAlerts.removeLast()
        }
        activeAlerts = [alert]
        
        HapticService.shared.notificationError()
        onNewOfficialAlertDetected?(alert)
    }
}

// MARK: - 3. Moteur de Simulation et Alertes de Test (AlertTestEngine)

/// Système de test 100% ISOLÉ des alertes réelles :
/// - Ne contacte JAMAIS le serveur officiel Pikoud HaOref
/// - Ne déclenche AUCUNE notification d'urgence réelle
/// - Génère une fausse alerte strictement étiquetée "SIMULATION"
public final class AlertTestEngine {
    public static let shared = AlertTestEngine()
    
    private init() {}
    
    /// Génère un événement d'alerte de test réaliste mais strictement marqué isTest = true
    public func generateTestAlert(specificCity: String? = nil) -> AlertEvent {
        let city: IsraelCity
        if let query = specificCity, let resolved = IsraelCityDatabase.shared.resolveCity(from: query) {
            city = resolved
        } else {
            city = IsraelCityDatabase.shared.cities.randomElement() ?? IsraelCity(id: "tel_aviv", name: "Tel Aviv", hebrewName: "תל אביב", latitude: 32.0853, longitude: 34.7818, region: "Centre")
        }
        
        let testId = "TEST_\(UUID().uuidString.prefix(8))"
        let testAlert = AlertEvent(
            id: testId,
            timestamp: Date(),
            type: "SIMULATION — Tir de missile fictif",
            affectedAreas: [city.name, "\(city.region) (Zone Test)"],
            source: "SARAH_TEST_ENGINE",
            isOfficial: false,
            isTest: true,
            status: "test",
            coordinates: [city.latitude, city.longitude],
            descriptionText: "⚠️ Ceci est un test de simulation du système d'affichage cartographique. Aucune mise à l'abri requise.",
            cityName: city.name
        )
        return testAlert
    }
}
