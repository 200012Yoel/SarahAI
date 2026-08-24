import Foundation
import CoreLocation

/// Service Météo Connecté par Géolocalisation GPS (100% Gratuit & Compatible iOS 12 à 18) :
/// - Récupère la position GPS précise de l'utilisateur via CoreLocation
/// - Interroge l'API Open-Meteo haute précision (sans clé API)
/// - Détermine la ville via Geocoding inversé
/// - Traduit les codes météo WMO en descriptions naturelles en français
public final class WeatherService: NSObject, CLLocationManagerDelegate {
    
    public static let shared = WeatherService()
    
    // MARK: - Structures de Données
    public struct WeatherInfo {
        public let cityName: String
        public let temperature: Double
        public let apparentTemperature: Double
        public let conditionDescription: String
        public let conditionIcon: String
        public let humidity: Int
        public let windSpeed: Double
        public let tempMax: Double
        public let tempMin: Double
        public let isDay: Bool
        
        public var naturalSpokenSummary: String {
            return "À \(cityName), il fait actuellement \(Int(round(temperature)))°C avec un temps \(conditionDescription.lowercased()). Le vent souffle à \(Int(round(windSpeed))) km/h, avec des températures entre \(Int(round(tempMin)))°C et \(Int(round(tempMax)))°C aujourd'hui."
        }
    }
    
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var isLocationRequested = false
    private var locationCompletion: ((CLLocation?) -> Void)?
    
    public private(set) var currentWeather: WeatherInfo?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    // MARK: - 1. Demande de Position GPS
    
    public func requestCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        if let loc = lastLocation, loc.timestamp.timeIntervalSinceNow > -600 {
            completion(loc)
            return
        }
        
        locationCompletion = completion
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .restricted, .denied:
            completion(nil)
        @unknown default:
            completion(nil)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        locationCompletion?(location)
        locationCompletion = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCompletion?(nil)
        locationCompletion = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    // MARK: - 2. Récupération de la Météo
    
    /// Récupère la météo actuelle pour la position actuelle ou une ville spécifique
    public func fetchWeather(for cityQuery: String? = nil, completion: @escaping (WeatherInfo?) -> Void) {
        if let city = cityQuery, !city.isEmpty {
            // Recherche par nom de ville
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(city) { [weak self] placemarks, error in
                guard let self = self, let placemark = placemarks?.first, let location = placemark.location else {
                    completion(nil)
                    return
                }
                let detectedCity = placemark.locality ?? placemark.name ?? city
                self.fetchOpenMeteoData(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, cityName: detectedCity, completion: completion)
            }
        } else {
            // Recherche par position GPS locale
            requestCurrentLocation { [weak self] location in
                guard let self = self, let loc = location else {
                    // Fallback sur Paris si géolocalisation indisponible
                    self?.fetchOpenMeteoData(latitude: 48.8566, longitude: 2.3522, cityName: "Paris", completion: completion)
                    return
                }
                
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
                    let cityName = placemarks?.first?.locality ?? placemarks?.first?.name ?? "votre position"
                    self?.fetchOpenMeteoData(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, cityName: cityName, completion: completion)
                }
            }
        }
    }
    
    private func fetchOpenMeteoData(latitude: Double, longitude: Double, cityName: String, completion: @escaping (WeatherInfo?) -> Void) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let daily = json["daily"] as? [String: Any] {
                    
                    let temp = current["temperature_2m"] as? Double ?? 20.0
                    let appTemp = current["apparent_temperature"] as? Double ?? temp
                    let humidity = current["relative_humidity_2m"] as? Int ?? 50
                    let wind = current["wind_speed_10m"] as? Double ?? 10.0
                    let weatherCode = current["weather_code"] as? Int ?? 0
                    let isDay = (current["is_day"] as? Int ?? 1) == 1
                    
                    let tempMaxList = daily["temperature_2m_max"] as? [Double] ?? [temp]
                    let tempMinList = daily["temperature_2m_min"] as? [Double] ?? [temp]
                    let tempMax = tempMaxList.first ?? temp
                    let tempMin = tempMinList.first ?? temp
                    
                    let (desc, icon) = self.describeWMOWeatherCode(weatherCode, isDay: isDay)
                    
                    let info = WeatherInfo(
                        cityName: cityName,
                        temperature: temp,
                        apparentTemperature: appTemp,
                        conditionDescription: desc,
                        conditionIcon: icon,
                        humidity: humidity,
                        windSpeed: wind,
                        tempMax: tempMax,
                        tempMin: tempMin,
                        isDay: isDay
                    )
                    
                    self.currentWeather = info
                    DispatchQueue.main.async {
                        completion(info)
                    }
                    return
                }
            } catch {}
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
        task.resume()
    }
    
    // MARK: - 3. Traduction des Codes Météo WMO
    
    private func describeWMOWeatherCode(_ code: Int, isDay: Bool) -> (String, String) {
        switch code {
        case 0:
            return (isDay ? "Ensoleillé" : "Nuit claire", isDay ? "☀️" : "🌙")
        case 1:
            return ("Principalement dégagé", isDay ? "🌤️" : "🌤️")
        case 2:
            return ("Partiellement nuageux", "⛅")
        case 3:
            return ("Couvert", "☁️")
        case 45, 48:
            return ("Brouillard", "🌫️")
        case 51, 53, 55:
            return ("Bruine légère", "🌦️")
        case 61, 63, 65:
            return ("Pluie", "🌧️")
        case 66, 67:
            return ("Pluie verglaçante", "🌧️❄️")
        case 71, 73, 75, 77:
            return ("Chutes de neige", "🌨️")
        case 80, 81, 82:
            return ("Averses de pluie", "🌧️")
        case 85, 86:
            return ("Averses de neige", "🌨️")
        case 95:
            return ("Orageux", "⛈️")
        case 96, 99:
            return ("Orage avec grêle", "⛈️❄️")
        default:
            return ("Temps variable", "🌥️")
        }
    }
}
