import Foundation
import AVFoundation
import UIKit
#if canImport(Combine)
import Combine
#endif

/// Gestionnaire Matériel Universel de la Torche / Flashlight (iOS 12 -> 18)
/// - Détection précise de l'état physique via AVCaptureDevice.torchMode et isTorchActive
/// - Bascule sécurisée avec AVCaptureDevice lockForConfiguration
/// - Synchronisation réactive immédiate sur le thread principal
public final class FlashlightManager: NSObject {
    
    public static let shared = FlashlightManager()
    
    public private(set) var isTorchOn: Bool = false {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FlashlightStateDidChange"),
                    object: nil,
                    userInfo: ["isTorchOn": self.isTorchOn]
                )
            }
        }
    }
    
    public var hasTorch: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.hasTorch && device.isTorchAvailable
    }
    
    private override init() {
        super.init()
        updateTorchState()
    }
    
    public func updateTorchState() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            isTorchOn = false
            return
        }
        isTorchOn = (device.torchMode == .on || device.isTorchActive)
    }
    
    /// Bascule l'état de la torche entre Allumé et Éteint avec mise à jour immédiate
    @discardableResult
    public func toggleTorch() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch, device.isTorchAvailable else {
            return false
        }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on || device.isTorchActive {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
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
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
            } else {
                device.torchMode = .off
                isTorchOn = false
            }
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [FlashlightManager] Erreur torche: \(error.localizedDescription)")
            device.unlockForConfiguration()
        }
    }
}

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ObservableFlashlight: ObservableObject {
    public static let shared = ObservableFlashlight()
    @Published public var isTorchOn: Bool = FlashlightManager.shared.isTorchOn
    
    private var observer: Any?
    
    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FlashlightStateDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            if let on = notif.userInfo?["isTorchOn"] as? Bool {
                DispatchQueue.main.async {
                    self?.isTorchOn = on
                }
            }
        }
    }
    
    public func toggleTorch() {
        _ = FlashlightManager.shared.toggleTorch()
    }
}
#endif
