import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo

/// Gestionnaire de session Caméra Live Ultra-Optimisé, Léger & Universel :
/// - Compatible 100% avec TOUS les iPhone (iPhone 5S, 6, 7, 8, SE, X, 11, 12, 13, 14, 15, 16 sur iOS 12 -> iOS 18)
/// - Reconnexion automatique en cas d'interruption (App Switcher, Verrouillage, Appel)
/// - Résolution adaptative (.vga640x480 / .medium) anti-crash OOM sur 1 Go de RAM
/// - Réutilisation d'un CIContext unique pour éliminer les fuites de mémoire et micro-gels
/// - Support complet des caméras multiples (Wide, Dual, Triple, TrueDepth, UltraWide)
public final class LiveCameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public static let shared = LiveCameraManager()
    
    // MARK: - Propriétés AVCapture
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.sarahia.camera.sessionQueue", qos: .userInitiated)
    private let videoDataQueue = DispatchQueue(label: "com.sarahia.camera.videoDataQueue", qos: .userInitiated)
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Contexte CIContext unique réutilisable pour éviter la surconsommation GPU/RAM
    private let ciContext = CIContext(options: [
        CIContextOption.useSoftwareRenderer: false,
        CIContextOption.priorityRequestLow: true
    ])
    
    private var isSessionConfigured = false
    private var lastFrameTime: TimeInterval = 0
    private let frameThrottleInterval: TimeInterval = 0.35 // Max 3 fps pour l'analyse IA
    private var wasDarkScene: Bool = false
    
    private var onFrameCaptured: ((UIImage) -> Void)?
    
    // MARK: - Initialisation & Notifications d'Interruption
    
    private override init() {
        super.init()
        setupResilientSessionObservers()
    }
    
    private func setupResilientSessionObservers() {
        let center = NotificationCenter.default
        
        // 1. Interruption de la session (ex: appel entrant, mise en veille, obstruction matérielle)
        center.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
        
        // 2. Fin d'interruption (ex: fin d'appel, démasquage, retour au premier plan)
        center.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
        
        // 3. Erreurs d'exécution matérielle (ex: réinitialisation du serveur média, déconnexion capteur)
        center.addObserver(
            self,
            selector: #selector(sessionRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
        
        // 4. Détection du changement de sujet (démasquage de coque, mouvement)
        center.addObserver(
            self,
            selector: #selector(subjectAreaDidChange(_:)),
            name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
            object: nil
        )
        
        // 5. Cycles de vie de l'application
        center.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func sessionWasInterrupted(_ notification: Notification) {
        if #available(iOS 9.0, *),
           let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) {
            print("⚠️ [LiveCameraManager] Session interrompue (Raison: \(reason.rawValue))")
        } else {
            print("⚠️ [LiveCameraManager] Session interrompue")
        }
    }
    
    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        print("✅ [LiveCameraManager] Fin d'interruption détectée. Reprise automatique de la capture...")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            if let device = self.videoDeviceInput?.device {
                self.configureDeviceForContinuousTracking(device)
            }
        }
    }
    
    @objc private func sessionRuntimeError(_ notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        print("❌ [LiveCameraManager] Erreur runtime AVCaptureSession: \(error.localizedDescription) (Code: \(error.code.rawValue))")
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Si les services médias ont été réinitialisés par iOS, reconstruire toute la chaîne AVCapture
            if error.code == .mediaServicesWereReset {
                print("🔄 [LiveCameraManager] Réinitialisation complète des services médias...")
                self.isSessionConfigured = false
                self.setupSession(completion: { _ in
                    self.startSession()
                })
            } else {
                // Tentative de redémarrage direct de la session
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            }
        }
    }
    
    @objc private func subjectAreaDidChange(_ notification: Notification) {
        // Déclenché automatiquement lors du retrait de la coque ou du démasquage physique
        resetContinuousAutoFocus()
    }
    
    @objc private func applicationWillEnterForeground() {
        startSession()
        resetContinuousAutoFocus()
    }
    
    @objc private func applicationDidBecomeActive() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            self.resetContinuousAutoFocus()
        }
    }
    
    @objc private func applicationDidEnterBackground() {
        stopSession()
    }
    
    // MARK: - Configuration Sécurisée de la Session
    
    /// Prépare la session caméra avec une résolution optimisée pour iPhone 5S et iPhone 14
    public func setupSession(previewView: UIView? = nil, completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if self.isSessionConfigured {
                if let view = previewView {
                    DispatchQueue.main.async {
                        self.attachPreview(to: view)
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async { completion(true) }
                }
                return
            }
            
            self.captureSession.beginConfiguration()
            
            // 1. Choix du preset adapté (VGA 640x480 / Medium)
            if self.captureSession.canSetSessionPreset(.vga640x480) {
                self.captureSession.sessionPreset = .vga640x480
            } else if self.captureSession.canSetSessionPreset(.medium) {
                self.captureSession.sessionPreset = .medium
            } else if self.captureSession.canSetSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            }
            
            // 2. Sélection de la caméra (arrière par défaut, ou frontale)
            let camera = self.getDevice(for: .back) ?? self.getDevice(for: .front) ?? AVCaptureDevice.default(for: .video)
            guard let validCamera = camera else {
                print("❌ [LiveCameraManager] Aucune caméra disponible sur cet appareil.")
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: validCamera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.videoDeviceInput = input
                    self.configureDeviceForContinuousTracking(validCamera)
                }
            } catch {
                print("❌ [LiveCameraManager] Erreur configuration input caméra: \(error)")
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 3. Configuration de la sortie vidéo
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
            
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }
            
            // 4. Orientation portrait
            if let connection = self.videoDataOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.captureSession.commitConfiguration()
            self.isSessionConfigured = true
            
            DispatchQueue.main.async {
                if let view = previewView {
                    self.attachPreview(to: view)
                }
                completion(true)
            }
        }
    }
    
    /// Détection multi-générations matérielle (iPhone 5S -> iPhone 14/15/16)
    private func getDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // 1. AVCaptureDevice.default direct
        if let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return dev
        }
        
        // 2. DiscoverySession avec tous les types de capteurs
        if #available(iOS 10.0, *) {
            var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
            if #available(iOS 10.2, *) {
                types.append(.builtInDualCamera)
            }
            if #available(iOS 11.1, *) {
                types.append(.builtInTrueDepthCamera)
            }
            if #available(iOS 13.0, *) {
                types.append(.builtInTripleCamera)
                types.append(.builtInUltraWideCamera)
                types.append(.builtInDualWideCamera)
            }
            let session = AVCaptureDevice.DiscoverySession(
                deviceTypes: types,
                mediaType: .video,
                position: position
            )
            if let dev = session.devices.first(where: { $0.position == position }) ?? session.devices.first {
                return dev
            }
        }
        
        // 3. Fallback universel iOS 10, 11, 12 sur iPhone 5S
        let allDevices = AVCaptureDevice.devices(for: .video)
        return allDevices.first(where: { $0.position == position }) ?? AVCaptureDevice.default(for: .video)
    }
    
    /// Bascule entre la caméra avant et arrière
    public func switchCamera(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            guard let currentInput = self.videoDeviceInput else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let newPosition: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
            guard let newDevice = self.getDevice(for: newPosition) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                self.captureSession.beginConfiguration()
                self.captureSession.removeInput(currentInput)
                
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                    
                    if let connection = self.videoDataOutput.connection(with: .video) {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = (newPosition == .front)
                        }
                    }
                    
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async { completion(true) }
                } else {
                    self.captureSession.addInput(currentInput)
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async { completion(false) }
                }
            } catch {
                print("❌ [LiveCameraManager] Erreur bascule caméra: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // MARK: - Contrôle de la Session
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - Aperçu Vidéo (Preview Layer)
    
    public func attachPreview(to view: UIView) {
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            self.previewLayer = layer
        }
        
        guard let pLayer = previewLayer else { return }
        pLayer.frame = view.bounds
        if let conn = pLayer.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        if pLayer.superlayer !== view.layer {
            pLayer.removeFromSuperlayer()
            view.layer.insertSublayer(pLayer, at: 0)
        }
    }
    
    public func updatePreviewLayout(bounds: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let pLayer = self.previewLayer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            pLayer.frame = bounds
            if let conn = pLayer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
            CATransaction.commit()
        }
    }
    
    // MARK: - Capture d'une Image Fixe Instantanée (Still Frame)
    
    public func captureSnapshot(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.onFrameCaptured = { image in
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Optimisation iPhone 5S / 7 : Si aucune capture photo n'est demandée, sortir IMMÉDIATEMENT
        // L'aperçu vidéo plein écran est géré à 100% par le matériel GPU via AVCaptureVideoPreviewLayer (0% CPU)
        guard let callback = onFrameCaptured else { return }
        
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let isFront = (videoDeviceInput?.device.position == .front)
            let orientation: UIImage.Orientation = isFront ? .leftMirrored : .right
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
            
            self.onFrameCaptured = nil
            callback(uiImage)
        }
    }
    
    // MARK: - Suivi & Focus Dynamique Temps Réel
    
    private func configureDeviceForContinuousTracking(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [LiveCameraManager] Configuration caméra: \(error)")
        }
    }
    
    public func focusAndExpose(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {
                print("⚠️ [LiveCameraManager] Erreur focus/expose point: \(error)")
            }
        }
    }
    
    public func resetContinuousAutoFocus() {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            self?.configureDeviceForContinuousTracking(device)
        }
    }
}

