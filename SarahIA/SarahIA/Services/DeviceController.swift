import Foundation
import UIKit
import AVFoundation

/// Contrôleur Matériel & Système Local pour iOS (100% Hors-Ligne) :
/// - Statut et Pourcentage de la Batterie (UIDevice)
/// - Contrôle de la Lampe Torche / Flash Caméra (AVCaptureDevice)
/// - Heure et Date en temps réel
/// - Informations Système & Liens Réglages
public final class DeviceController {
    
    public static let shared = DeviceController()
    
    private var isTorchOn: Bool = false
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    // MARK: - Batterie
    
    public func getBatteryStatus() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = Int(UIDevice.current.batteryLevel * 100)
        let state = UIDevice.current.batteryState
        
        let isCharging = (state == .charging || state == .full)
        if level < 0 {
            return "Le niveau de batterie est disponible directement sur votre appareil physique. 🔋"
        }
        
        if isCharging {
            return "Votre batterie est à \(level)% et est actuellement en charge ⚡."
        } else if level <= 20 {
            return "Attention, votre batterie est faible : il vous reste \(level)%. Pensez à brancher votre appareil ! 🪫"
        } else {
            return "Votre batterie est actuellement à \(level)%. 🔋"
        }
    }
    
    // MARK: - Lampe Torche / Flash
    
    public func toggleTorch(enable: Bool? = nil) -> String {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            return "La lampe torche n'est pas disponible sur cet appareil ou simulateur. 🔦"
        }
        
        do {
            try device.lockForConfiguration()
            let shouldTurnOn: Bool
            if let explicit = enable {
                shouldTurnOn = explicit
            } else {
                shouldTurnOn = (device.torchMode != .on)
            }
            
            if shouldTurnOn {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
                device.unlockForConfiguration()
                return "J'ai allumé la lampe torche pour vous ! 🔦✨"
            } else {
                device.torchMode = .off
                isTorchOn = false
                device.unlockForConfiguration()
                return "La lampe torche est maintenant éteinte. 💡"
            }
        } catch {
            return "Impossible d'accéder au flash de l'appareil : \(error.localizedDescription)"
        }
    }
    
    // MARK: - Date & Heure
    
    public func getCurrentTimeFormatted() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH'h'mm"
        let time = formatter.string(from: Date())
        return "Il est actuellement \(time). ⏰"
    }
    
    public func getCurrentDateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        let dateStr = formatter.string(from: Date())
        return "Aujourd'hui, nous sommes le \(dateStr). 📅"
    }
    
    // MARK: - Informations Système
    
    public func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "Appareil : \(device.model), fonctionnant sous iOS \(device.systemVersion). 📱"
    }
    
    public func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
