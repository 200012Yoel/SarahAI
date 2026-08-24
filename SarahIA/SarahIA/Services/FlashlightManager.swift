import Foundation
import AVFoundation
import UIKit

/// Gestionnaire Matériel de la Torche / Flashlight (iOS 12 -> 18)
/// - Détection précise de l'état (allumé / éteint)
/// - Bascule sécurisée avec AVCaptureDevice lockForConfiguration
public final class FlashlightManager: ObservableObject {
    
    public static let shared = FlashlightManager()
    
    @Published public private(set) var isTorchOn: Bool = false
    
    public var hasTorch: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.hasTorch && device.isTorchAvailable
    }
    
    private init() {
        updateTorchState()
    }
    
    public func updateTorchState() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            isTorchOn = false
            return
        }
        isTorchOn = (device.torchMode == .on)
    }
    
    /// Bascule l'état de la torche entre Allumé et Éteint
    @discardableResult
    public func toggleTorch() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch, device.isTorchAvailable else {
            return false
        }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                isTorchOn = true
            }
            device.unlockForConfiguration()
            HapticService.shared.buttonTap()
            return isTorchOn
        } catch {
            print("⚠️ [FlashlightManager] Erreur configuration torche: \(error.localizedDescription)")
            device.unlockForConfiguration()
            return isTorchOn
        }
    }
    
    public func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            isTorchOn = on
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [FlashlightManager] Erreur torche: \(error.localizedDescription)")
            device.unlockForConfiguration()
        }
    }
}
