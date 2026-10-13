import SwiftUI
import UIKit
import MapKit

/// Geocoded by the real OpenStreetMap search; never a guessed destination.
@available(iOS 15.0, *)
public struct SarahMapDestination: Equatable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let address: String

    public init(name: String, latitude: Double, longitude: Double, address: String) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}

/// Apple provides the real published app icons via its App Store lookup API.
/// No imitation logos and no guessed asset URLs.
@available(iOS 15.0, *)
@MainActor
public final class SarahNavigationAppIcons: ObservableObject {
    @Published private(set) public var images: [Int: URL] = [:]
    private var fetched = false

    public func load() async {
        guard !fetched else { return }
        fetched = true
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=915056765,323229106,585027354&country=fr") else { return }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = object["results"] as? [[String: Any]] else { return }
            var found: [Int: URL] = [:]
            for result in results {
                guard let identifier = result["trackId"] as? Int,
                      let urlText = (result["artworkUrl512"] as? String)
                        ?? (result["artworkUrl100"] as? String),
                      let iconURL = URL(string: urlText) else { continue }
                found[identifier] = iconURL
            }
            images = found
        } catch {
            // Keep accessible app names and the icon fallback when offline.
        }
    }
}

@available(iOS 15.0, *)
private enum SarahNavigationTarget: CaseIterable, Identifiable {
    case apple, waze, google

    var id: String { label }
    var label: String {
        switch self {
        case .apple: return "Apple Plans"
        case .waze: return "Waze"
        case .google: return "Google Maps"
        }
    }
    var storeID: Int {
        switch self {
        case .apple: return 915056765
        case .waze: return 323229106
        case .google: return 585027354
        }
    }
    var fallbackSymbol: String {
        switch self {
        case .apple: return "map.fill"
        case .waze: return "car.fill"
        case .google: return "mappin.and.ellipse"
        }
    }
    var accent: Color {
        switch self {
        case .apple: return .white
        case .waze: return .cyan
        case .google: return .blue
        }
    }
    var available: Bool {
        switch self {
        case .apple: return true // Apple's universal Maps link also works on web.
        case .waze: return UIApplication.shared.canOpenURL(URL(string: "waze://")!)
        case .google: return UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
        }
    }
    func open(_ destination: SarahMapDestination) {
        let position = String(format: "%.7f,%.7f", locale: Locale(identifier: "en_US_POSIX"),
                              destination.latitude, destination.longitude)
        let address = destination.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlText: String
        switch self {
        case .apple:
            urlText = "https://maps.apple.com/?daddr=\(position)&dirflg=d"
        case .waze:
            // Direct native Waze URL, with coordinates from the selected POI.
            urlText = "waze://?ll=\(position)&navigate=yes"
        case .google:
            urlText = "comgooglemaps://?daddr=\(position)&directionsmode=driving"
        }
        guard let url = URL(string: urlText) else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            // Fallback still transmits the destination. No empty maps.
            let fallback: String
            switch self {
            case .apple: fallback = "https://maps.apple.com/?daddr=\(position)"
            case .waze: fallback = "https://www.waze.com/ul?ll=\(position)&navigate=yes"
            case .google: fallback = "https://www.google.com/maps/dir/?api=1&destination=\(position)"
            }
            if let web = URL(string: fallback) {
                UIApplication.shared.open(web)
            } else if let search = URL(string: "https://maps.apple.com/?q=\(address)") {
                UIApplication.shared.open(search)
            }
        }
    }
}

@available(iOS 15.0, *)
public struct SarahNavigationOptions: View {
    public let destination: SarahMapDestination?
    @ObservedObject public var icons: SarahNavigationAppIcons

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .foregroundColor(.cyan)
                Text("LANCER L’ITINÉRAIRE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.72))
            }
            HStack(spacing: 10) {
                ForEach(SarahNavigationTarget.allCases) { target in
                    Button {
                        guard let destination, target.available else { return }
                        target.open(destination)
                    } label: {
                        VStack(spacing: 6) {
                            Group {
                                if let remote = icons.images[target.storeID] {
                                    AsyncImage(url: remote) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFit()
                                        } else {
                                            placeholder(for: target)
                                        }
                                    }
                                } else {
                                    placeholder(for: target)
                                }
                            }
                            .frame(width: 43, height: 43)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            Text(target.label)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .foregroundColor(.white)
                            Text(target.available ? "Itinéraire" : "Non installé")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 93)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(target.accent.opacity(0.30), lineWidth: 1))
                    }
                    .disabled(destination == nil || !target.available)
                    .opacity(destination == nil || !target.available ? 0.48 : 1)
                    .accessibilityLabel("\(target.label), \(target.available ? "itinéraire" : "application non installée")")
                    .accessibilityIdentifier("sarah.map.route.\(target.id)")
                }
            }
            if destination == nil {
                Text("Recherche de l’adresse en cours. Choisis un lieu pour ouvrir un itinéraire.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.60))
            }
        }
        .padding(14)
        .background(Color(red: 0.075, green: 0.092, blue: 0.145))
    }

    private func placeholder(for target: SarahNavigationTarget) -> some View {
        Image(systemName: target.fallbackSymbol)
            .resizable()
            .scaledToFit()
            .padding(10)
            .foregroundColor(target.accent)
            .frame(width: 43, height: 43)
            .background(Color.white.opacity(0.10))
    }
}

/// Native satellite/flyover mode uses licensed imagery inside MapKit itself.
@available(iOS 15.0, *)
public struct SarahSatelliteMapView: UIViewRepresentable {
    public var destination: SarahMapDestination?
    public func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.showsBuildings = true
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        return map
    }
    public func updateUIView(_ map: MKMapView, context: Context) {
        guard let destination else { return }
        let coordinate = CLLocationCoordinate2D(latitude: destination.latitude,
                                                 longitude: destination.longitude)
        // Prevent re-centering on every SwiftUI frame update.
        let previous = map.camera.centerCoordinate
        if abs(previous.latitude - coordinate.latitude) < 0.00001,
           abs(previous.longitude - coordinate.longitude) < 0.00001 { return }
        let camera = MKMapCamera(lookingAtCenter: coordinate,
                                 fromDistance: 650, pitch: 65, heading: -15)
        map.setCamera(camera, animated: true)
    }
}
