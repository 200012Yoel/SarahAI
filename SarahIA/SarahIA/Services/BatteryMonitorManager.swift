import Foundation
import UIKit
import AVFoundation

/// Gestionnaire de Surveillance de Batterie avec Annonce Vocale Sarah (20%)
/// - Active la surveillance continue UIDevice.isBatteryMonitoringEnabled = true
/// - Détecte le seuil critique de 20%
/// - Déclenche l'avertissement vocal de Sarah : "Attention, la batterie de ton téléphone est à 20%, pense à le brancher !"
/// - Déclenchement unique par cycle de décharge pour éviter les répétitions intempestives
/// - 100% universel de iOS 12.0 à iOS 18.0
public final class BatteryMonitorManager: NSObject {
    
    public static let shared = BatteryMonitorManager()
    
    public private(set) var currentBatteryLevel: Float = -1.0
    public private(set) var isCharging: Bool = false
    
    // Empêche les déclenchements multiples sur le même cycle de décharge
    private var hasTriggered20PercentAlert: Bool = false
    
    private override init() {
        super.init()
        setupBatteryMonitoring()
    }
    
    public func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryState()
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        updateBatteryState()
    }
    
    private func updateBatteryState() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        
        self.currentBatteryLevel = level
        self.isCharging = (state == .charging || state == .full)
        
        checkBatteryThreshold(level: level, state: state)
    }
    
    @objc private func batteryLevelDidChange() {
        updateBatteryState()
    }
    
    @objc private func batteryStateDidChange() {
        let state = UIDevice.current.batteryState
        self.isCharging = (state == .charging || state == .full)
        
        // Réinitialisation de l'alerte dès que le téléphone est rechargé au-delà de 25%
        if isCharging && UIDevice.current.batteryLevel > 0.25 {
            hasTriggered20PercentAlert = false
        }
    }
    
    private func checkBatteryThreshold(level: Float, state: UIDevice.BatteryState) {
        guard level > 0 else { return } // Niveau inconnu (-1.0)
        
        let percentage = Int(round(level * 100))
        let isDischarging = (state == .unplugged || state == .unknown)
        
        // Seuil d'alerte : 20% en cours de décharge
        if percentage <= 20 && isDischarging {
            if !hasTriggered20PercentAlert {
                hasTriggered20PercentAlert = true
                trigger20PercentSpokenAlert(percentage: percentage)
            }
        } else if percentage > 25 {
            // Réarmement du déclencheur si le niveau remonte au-dessus de 25%
            hasTriggered20PercentAlert = false
        }
    }
    
    private func trigger20PercentSpokenAlert(percentage: Int) {
        DispatchQueue.main.async {
            HapticService.shared.buttonTap()
            
            let message = "Attention, la batterie de ton téléphone est à \(percentage)%, pense à le brancher !"
            
            TTSManager.shared.speakAsSarah(message)
            
            NotificationCenter.default.post(
                name: NSNotification.Name("SarahBatteryWarning20Percent"),
                object: nil,
                userInfo: ["batteryLevel": percentage]
            )
        }
    }
}
