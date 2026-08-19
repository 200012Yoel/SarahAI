import Foundation
import UIKit
import AVFoundation

/// Contrôleur Matériel & Système Local pour iOS (100% Hors-Ligne) :
/// - Statut de la Batterie (UIDevice)
/// - Raccourcis et Liens Systèmes Paramètres
public final class DeviceController {
    
    public static let shared = DeviceController()
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    public func getBatteryStatus() -> String {
        let level = Int(UIDevice.current.batteryLevel * 100)
        let state = UIDevice.current.batteryState
        
        let isCharging = (state == .charging || state == .full)
        if level < 0 {
            return "Statut de batterie disponible sur l'appareil réel."
        }
        
        if isCharging {
            return "Votre batterie est à \(level)% et est actuellement en charge ⚡."
        } else {
            return "Votre batterie est actuellement à \(level)%."
        }
    }
    
    public func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
