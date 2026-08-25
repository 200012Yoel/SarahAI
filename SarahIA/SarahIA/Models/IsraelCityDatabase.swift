import Foundation
import CoreLocation

// MARK: - Modèle Géographique et Base de Données des Villes d'Israël

public struct IsraelCity: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let hebrewName: String
    public let latitude: Double
    public let longitude: Double
    public let region: String
    public let aliases: [String]
    
    public init(
        id: String,
        name: String,
        hebrewName: String,
        latitude: Double,
        longitude: Double,
        region: String,
        aliases: [String] = []
    ) {
        self.id = id
        self.name = name
        self.hebrewName = hebrewName
        self.latitude = latitude
        self.longitude = longitude
        self.region = region
        self.aliases = aliases
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Base de données géographique ultra-légère pour iPhone 5S et iOS 12+
public final class IsraelCityDatabase {
    public static let shared = IsraelCityDatabase()
    
    public let cities: [IsraelCity] = [
        IsraelCity(id: "tel_aviv", name: "Tel Aviv", hebrewName: "תל אביב", latitude: 32.0853, longitude: 34.7818, region: "Centre / Dan", aliases: ["tel-aviv", "tlv", "tel aviv-jaffa", "jaffa", "yafo"]),
        IsraelCity(id: "jerusalem", name: "Jérusalem", hebrewName: "ירושלים", latitude: 31.7683, longitude: 35.2137, region: "Jérusalem & Judée", aliases: ["jerusalem", "al-quds", "yerushalayim"]),
        IsraelCity(id: "haifa", name: "Haïfa", hebrewName: "חיפה", latitude: 32.7940, longitude: 34.9896, region: "Nord / Carmel", aliases: ["haifa", "carmel", "krayot", "kiryat atta", "kiryat motzkin", "kiryat bialik"]),
        IsraelCity(id: "rishon_lezion", name: "Rishon LeZion", hebrewName: "ראשון לציון", latitude: 31.9730, longitude: 34.7925, region: "Centre", aliases: ["rishon", "rishon letsiyon"]),
        IsraelCity(id: "petah_tikva", name: "Petah Tikva", hebrewName: "פתח תקווה", latitude: 32.0840, longitude: 34.8878, region: "Centre", aliases: ["petah tikvah", "petach tikva"]),
        IsraelCity(id: "ashdod", name: "Ashdod", hebrewName: "אשדוד", latitude: 31.8044, longitude: 34.6553, region: "Sud / Littoral", aliases: ["asdod", "ashdod yam"]),
        IsraelCity(id: "ashkelon", name: "Ashkelon", hebrewName: "אשקלון", latitude: 31.6688, longitude: 34.5743, region: "Sud / Enveloppe de Gaza", aliases: ["ashqelon", "ascalon"]),
        IsraelCity(id: "beersheba", name: "Beersheba", hebrewName: "באר שבע", latitude: 31.2529, longitude: 34.7915, region: "Néguev / Sud", aliases: ["beer sheva", "beer-sheva", "be'er sheva"]),
        IsraelCity(id: "netanya", name: "Netanya", hebrewName: "נתניה", latitude: 32.3215, longitude: 34.8532, region: "Sharon", aliases: ["nathanya", "netania"]),
        IsraelCity(id: "herzliya", name: "Herzliya", hebrewName: "הרצליה", latitude: 32.1663, longitude: 34.8433, region: "Sharon / Côte", aliases: ["herzlia", "herzliya pituach"]),
        IsraelCity(id: "ramat_gan", name: "Ramat Gan", hebrewName: "רמת גן", latitude: 32.0684, longitude: 34.8248, region: "Centre / Dan", aliases: ["ramat-gan"]),
        IsraelCity(id: "holon", name: "Holon", hebrewName: "חולון", latitude: 32.0158, longitude: 34.7874, region: "Centre", aliases: ["cholon"]),
        IsraelCity(id: "bat_yam", name: "Bat Yam", hebrewName: "בת ים", latitude: 32.0234, longitude: 34.7508, region: "Centre / Côte", aliases: ["bat-yam"]),
        IsraelCity(id: "bnei_brak", name: "Bnei Brak", hebrewName: "בני ברק", latitude: 32.0833, longitude: 34.8333, region: "Centre", aliases: ["bene beraq", "bney brak"]),
        IsraelCity(id: "kfar_saba", name: "Kfar Saba", hebrewName: "כפר סבא", latitude: 32.1750, longitude: 34.9069, region: "Sharon", aliases: ["kfar saba", "kefar sava"]),
        IsraelCity(id: "raanana", name: "Ra'anana", hebrewName: "רעננה", latitude: 32.1848, longitude: 34.8713, region: "Sharon", aliases: ["raanana", "ra'ananna"]),
        IsraelCity(id: "modiin", name: "Modi'in", hebrewName: "מודיעין", latitude: 31.8903, longitude: 35.0104, region: "Centre / Shéphélah", aliases: ["modiin", "modi'in-maccabim-re'ut"]),
        IsraelCity(id: "eilat", name: "Eilat", hebrewName: "אילת", latitude: 29.5577, longitude: 34.9519, region: "Sud / Mer Rouge", aliases: ["elath", "aylat"]),
        IsraelCity(id: "nazareth", name: "Nazareth", hebrewName: "נצרת", latitude: 32.7019, longitude: 35.3033, region: "Galilée", aliases: ["nazareth illit", "nof hagalil", "natzeret"]),
        IsraelCity(id: "acre", name: "Acre (Saint-Jean-d'Acre)", hebrewName: "עכו", latitude: 32.9278, longitude: 35.0817, region: "Nord / Galilée Occidentale", aliases: ["akko", "acco", "akko"]),
        IsraelCity(id: "nahariya", name: "Nahariya", hebrewName: "נהריה", latitude: 33.0059, longitude: 35.0941, region: "Nord / Littoral", aliases: ["nahariya", "nahariyya"]),
        IsraelCity(id: "tiberias", name: "Tibériade", hebrewName: "טבריה", latitude: 32.7922, longitude: 35.5312, region: "Kinneret / Galilée", aliases: ["tiberiade", "tveria"]),
        IsraelCity(id: "kiryat_shmona", name: "Kiryat Shmona", hebrewName: "קריית שמונה", latitude: 33.2073, longitude: 35.5721, region: "Haute Galilée / Nord", aliases: ["kiryat shmonah", "qiryat shemona", "galilée"]),
        IsraelCity(id: "sderot", name: "Sdérot", hebrewName: "שדרות", latitude: 31.5247, longitude: 34.5961, region: "Enveloppe de Gaza", aliases: ["sderot", "shaar hanegev"]),
        IsraelCity(id: "rehovot", name: "Rehovot", hebrewName: "רחובות", latitude: 31.8928, longitude: 34.8113, region: "Centre", aliases: ["rechovot", "rehovoth"])
    ]
    
    private init() {}
    
    /// Résout une ville ou localité à partir d'un nom texte (français, hébreu, phonétique)
    public func resolveCity(from query: String) -> IsraelCity? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        
        // Recherche exacte ou alias
        for city in cities {
            if city.name.lowercased() == clean || city.hebrewName == clean || city.id == clean {
                return city
            }
            if city.aliases.contains(where: { clean.contains($0) || $0.contains(clean) }) {
                return city
            }
            if clean.contains(city.name.lowercased()) {
                return city
            }
        }
        
        return cities.first(where: { $0.id == "tel_aviv" })
    }
}
