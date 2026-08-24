import Foundation
import AVFoundation
import UIKit
#if canImport(Combine)
import Combine
#endif

/// Gestionnaire Matériel Universel de la Torche / Flashlight (iOS 12 -> 18)
/// - Détection précise de l'état physique via AVCaptureDevice.torchMode et isTorchActive
/// - Bascule sécurisée avec AVCaptureDevice lockForConfiguration
/// - Persistance matérielle en arrière-plan (reste allumée même en quittant l'application via UIBackgroundTaskIdentifier)
/// - Maintien actif du pipeline matériel via AVCaptureSession dédiée
/// - Synchronisation réactive immédiate sur le thread principal
public final class FlashlightManager: NSObject {
    
    public static let shared = FlashlightManager()
    
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var captureSession: AVCaptureSession?
    private var deviceInput: AVCaptureDeviceInput?
    
    private var captureDevice: AVCaptureDevice? {
        return AVCaptureDevice.default(for: .video)
    }
    
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
        guard let device = captureDevice else { return false }
        return device.hasTorch && device.isTorchAvailable
    }
    
    private override init() {
        super.init()
        updateTorchState()
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        if isTorchOn {
            startBackgroundTask()
            reinforceTorchState(true)
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        if isTorchOn {
            startBackgroundTask()
            reinforceTorchState(true)
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        if isTorchOn {
            reinforceTorchState(true)
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        updateTorchState()
    }
    
    public func updateTorchState() {
        guard let device = captureDevice else {
            isTorchOn = false
            return
        }
        isTorchOn = (device.torchMode == .on || device.isTorchActive)
    }
    
    /// Bascule l'état de la torche entre Allumé et Éteint avec persistance arrière-plan garantie
    @discardableResult
    public func toggleTorch() -> Bool {
        guard let device = captureDevice, device.hasTorch, device.isTorchAvailable else {
            return false
        }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on || device.isTorchActive {
                device.torchMode = .off
                isTorchOn = false
                device.unlockForConfiguration()
                teardownCaptureSession()
                endBackgroundTask()
            } else {
                setupCaptureSessionIfNeeded(for: device)
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
                device.unlockForConfiguration()
                startBackgroundTask()
            }
            HapticService.shared.buttonTap()
            return isTorchOn
        } catch {
            print("⚠️ [FlashlightManager] Erreur configuration torche: \(error.localizedDescription)")
            device.unlockForConfiguration()
            return isTorchOn
        }
    }
    
    public func setTorch(on: Bool) {
        guard let device = captureDevice, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            if on {
                setupCaptureSessionIfNeeded(for: device)
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
                device.unlockForConfiguration()
                startBackgroundTask()
            } else {
                device.torchMode = .off
                isTorchOn = false
                device.unlockForConfiguration()
                teardownCaptureSession()
                endBackgroundTask()
            }
        } catch {
            print("⚠️ [FlashlightManager] Erreur torche: \(error.localizedDescription)")
            device.unlockForConfiguration()
        }
    }
    
    private func reinforceTorchState(_ on: Bool) {
        guard let device = captureDevice, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            if on {
                setupCaptureSessionIfNeeded(for: device)
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            device.unlockForConfiguration()
        }
    }
    
    private func setupCaptureSessionIfNeeded(for device: AVCaptureDevice) {
        guard captureSession == nil else {
            if let session = captureSession, !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            }
            return
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
            self.deviceInput = input
        }
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        self.captureSession = session
    }
    
    private func teardownCaptureSession() {
        if let session = captureSession {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
            self.captureSession = nil
            self.deviceInput = nil
        }
    }
    
    private func startBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else { return }
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "SarahPersistentTorch") { [weak self] in
            // Si le temps système est écoulé, on termine proprement la tâche
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
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
        let newState = FlashlightManager.shared.toggleTorch()
        DispatchQueue.main.async {
            self.isTorchOn = newState
        }
    }
}
#endif
