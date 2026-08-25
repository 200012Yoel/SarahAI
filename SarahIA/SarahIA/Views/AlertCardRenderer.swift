import Foundation
import UIKit
import WebKit
import MapKit

// MARK: - 1. Générateur de Carte HTML / SVG Interactive Locale (AlertCardRenderer)

public final class AlertCardRenderer {
    public static let shared = AlertCardRenderer()
    
    private init() {}
    
    /// Génère un document HTML 100% autonome et sécurisé pour l'affichage de la carte d'alerte dans le chat
    public func renderAlertHTML(for alert: AlertEvent, isCompact: Bool = true) -> String {
        let isSimulation = alert.isTest
        let headerColor = isSimulation ? "#ff9500" : "#ff3b30"
        let headerBadge = isSimulation ? "🟠 SIMULATION — TEST" : "🔴 ALERTE OFFICIELLE"
        let subtitle = isSimulation ? "⚠️ TEST — PAS UNE ALERTE RÉELLE" : "Zone sous alerte : \(alert.affectedAreas.joined(separator: ", "))"
        
        let cityName = alert.cityName
        let timeStr = alert.formattedTime
        let sourceStr = isSimulation ? "Simulation Sarah IA (Isolée)" : alert.source
        
        // Calcul des coordonnées relatives sur le tracé de la carte d'Israël (SVG Viewbox: 0 0 200 300)
        // Latitude Israël: ~29.5 (Sud/Eilat) à ~33.3 (Nord/Mont Hermon)
        // Longitude Israël: ~34.2 (Ouest/Gaza-Littoral) à ~35.9 (Est/Golan)
        let lat = alert.latitude
        let lon = alert.longitude
        
        let minLat = 29.5
        let maxLat = 33.3
        let minLon = 34.2
        let maxLon = 35.8
        
        let normY = 1.0 - max(0.0, min(1.0, (lat - minLat) / (maxLat - minLat)))
        let normX = max(0.0, min(1.0, (lon - minLon) / (maxLon - minLon)))
        
        let markerX = 50 + (normX * 90)
        let markerY = 30 + (normY * 230)
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
                body { background: transparent; color: #ffffff; padding: 8px; display: flex; justify-content: center; }
                .card {
                    width: 100%; max-width: 320px; background: #13131a; border: 1.5px solid \(headerColor);
                    border-radius: 14px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.5);
                }
                .header {
                    background: linear-gradient(90deg, \(headerColor) 0%, rgba(20,20,30,0.9) 100%);
                    padding: 8px 12px; display: flex; justify-content: space-between; align-items: center;
                }
                .badge { font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; }
                .time { font-size: 11px; font-weight: 600; opacity: 0.9; }
                .content { padding: 10px 12px; }
                .city-title { font-size: 17px; font-weight: 700; color: #fff; margin-bottom: 2px; }
                .subtitle { font-size: 11px; color: \(headerColor); margin-bottom: 8px; font-weight: 600; }
                .map-box {
                    width: 100%; height: 135px; background: #0a0a0f; border-radius: 8px;
                    position: relative; overflow: hidden; border: 1px solid rgba(255,255,255,0.08);
                    display: flex; justify-content: center; align-items: center;
                }
                svg { width: 100%; height: 100%; }
                .marker-pulse {
                    animation: pulse 1.5s infinite;
                    transform-origin: center;
                }
                @keyframes pulse {
                    0% { r: 5px; opacity: 1; }
                    50% { r: 12px; opacity: 0.4; }
                    100% { r: 5px; opacity: 1; }
                }
                .footer {
                    margin-top: 8px; display: flex; justify-content: space-between; align-items: center;
                }
                .source { font-size: 9px; color: #8e8e93; }
                .btn {
                    background: rgba(255,255,255,0.12); color: #fff; border: none; padding: 4px 8px;
                    border-radius: 6px; font-size: 10px; font-weight: 600; text-decoration: none; display: inline-block;
                }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="header">
                    <span class="badge">\(headerBadge)</span>
                    <span class="time">🕐 \(timeStr)</span>
                </div>
                <div class="content">
                    <div class="city-title">📍 \(cityName)</div>
                    <div class="subtitle">\(subtitle)</div>
                    <div class="map-box">
                        <svg viewBox="0 0 200 300">
                            <!-- Silhouette stylisée d'Israël -->
                            <path d="M95,30 L115,45 L110,70 L118,90 L105,120 L100,160 L85,190 L90,240 L80,285 L88,290 L95,260 L105,220 L115,170 L120,130 L130,95 L125,50 Z"
                                  fill="#1f2430" stroke="#3a4454" stroke-width="2" />
                            <!-- Mer Méditerranée & Mer Morte -->
                            <path d="M70,40 Q85,120 75,200" fill="none" stroke="#007aff" stroke-width="1.5" stroke-dasharray="3,3" opacity="0.4" />
                            
                            <!-- Onde d'impact / Alerte -->
                            <circle cx="\(markerX)" cy="\(markerY)" r="10" fill="\(headerColor)" opacity="0.3" class="marker-pulse" />
                            <circle cx="\(markerX)" cy="\(markerY)" r="5" fill="\(headerColor)" stroke="#fff" stroke-width="1.5" />
                            <text x="\(markerX + 8)" y="\(markerY + 4)" fill="#ffffff" font-size="10" font-weight="bold">\(cityName)</text>
                        </svg>
                    </div>
                    <div class="footer">
                        <span class="source">Source : \(sourceStr)</span>
                        <a href="sarahia://openmap?lat=\(lat)&lon=\(lon)&city=\(cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cityName)" class="btn">📍 Plans →</a>
                    </div>
                </div>
            </div>
        </body>
        </html>
        """
        return html
    }
}

// MARK: - 2. Vue UIKit & Contrôleur Cartographique Plein Écran (AlertMapViewController)

public final class AlertMapViewController: UIViewController, MKMapViewDelegate {
    private let alert: AlertEvent
    private let mapView = MKMapView()
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let appleMapsButton = UIButton(type: .system)
    
    public init(alert: AlertEvent) {
        self.alert = alert
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureMap()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 0.95)
        view.addSubview(topBar)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = alert.isTest ? "🟠 SIMULATION CARTE ALERTE" : "🔴 ALERTE OFFICIELLE : \(alert.cityName)"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = alert.isTest ? .orange : UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
        topBar.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "🕐 \(alert.formattedTime) — Source : \(alert.source)"
        subtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        topBar.addSubview(subtitleLabel)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕ Fermer", for: .normal)
        closeButton.setTitleColor(UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0), for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        view.addSubview(mapView)
        
        appleMapsButton.translatesAutoresizingMaskIntoConstraints = false
        appleMapsButton.setTitle("📍 Ouvrir dans Plans", for: .normal)
        appleMapsButton.setTitleColor(.white, for: .normal)
        appleMapsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        appleMapsButton.backgroundColor = UIColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 0.9)
        appleMapsButton.layer.cornerRadius = 12
        appleMapsButton.addTarget(self, action: #selector(openAppleMapsTapped), for: .touchUpInside)
        view.addSubview(appleMapsButton)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 54),
            
            titleLabel.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            
            closeButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            mapView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            appleMapsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            appleMapsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            appleMapsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            appleMapsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureMap() {
        let coord = alert.coordinate
        let span = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        let region = MKCoordinateRegion(center: coord, span: span)
        mapView.setRegion(region, animated: false)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coord
        annotation.title = alert.cityName
        annotation.subtitle = alert.isTest ? "⚠️ Simulation d'alerte" : "🔴 Zone sous alerte"
        mapView.addAnnotation(annotation)
        mapView.selectAnnotation(annotation, animated: true)
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func openAppleMapsTapped() {
        let coord = alert.coordinate
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = alert.cityName
        
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        
        // Fallback d'URL si MKMapItem n'est pas disponible ou deep link
        if !mapItem.openInMaps(launchOptions: launchOptions) {
            if let webURL = URL(string: "https://maps.apple.com/?q=\(alert.latitude),\(alert.longitude)") {
                UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
            }
        }
    }
}
