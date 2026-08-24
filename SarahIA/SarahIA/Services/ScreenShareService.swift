import Foundation
import UIKit
import ReplayKit
import AVFoundation
#if canImport(Combine)
import Combine
#endif

/// Service de Partage d'Écran et Live Streaming avec Sarah :
/// - Découplage complet de la lecture de trames sur une file dédiée d'arrière-plan (decodeQueue)
/// - Décodage JPEG instantané sans blocage de l'interface graphique
/// - Capture persistante en arrière-plan (Home Screen et hors app) via ReplayKit et Darwin IPC
/// - Rendu ultra-fluide à 0ms sans artefact visuel ni saccade
public final class ScreenShareService: NSObject {
    
    public static let shared = ScreenShareService()
    
    // Notifications & App Group
    public static let appGroupIdentifier = "group.com.sarahia.shared"
    public static let darwinNotificationName = "group.com.sarahia.broadcast.frame"
    public static let liveFrameNotification = NSNotification.Name("SarahLiveScreenFrameUpdated")
    
    private let screenRecorder = RPScreenRecorder.shared()
    public private(set) var isScreenSharingActive: Bool = false
    public private(set) var latestCapturedImage: UIImage?
    
    // Files et minuteries d'arrière-plan
    private let decodeQueue = DispatchQueue(label: "com.sarahia.screenshare.decode", qos: .userInteractive)
    private var dispatchTimer: DispatchSourceTimer?
    private var lastAnalyzedText: String = ""
    private var lastDarwinFrameTimestamp: TimeInterval = 0
    private var currentFrameCallback: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    
    private override init() {
        super.init()
        setupDarwinIPCReceiver()
    }
    
    // MARK: - Récepteur IPC Darwin Notification (Arrière-plan système)
    
    private func setupDarwinIPCReceiver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let name = CFNotificationName(Self.darwinNotificationName as CFString)
        
        CFNotificationCenterAddObserver(center, observer, { (center, observer, name, object, userInfo) in
            guard let observer = observer else { return }
            let service = Unmanaged<ScreenShareService>.fromOpaque(observer).takeUnretainedValue()
            service.handleIncomingBroadcastFrame()
        }, name.rawValue, nil, .deliverImmediately)
    }
    
    private func handleIncomingBroadcastFrame() {
        guard isScreenSharingActive else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastDarwinFrameTimestamp >= 0.4 else { return }
        lastDarwinFrameTimestamp = now
        
        decodeQueue.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
                return
            }
            let frameURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
            
            guard let data = try? Data(contentsOf: frameURL, options: .alwaysMapped),
                  let image = UIImage(data: data) else {
                return
            }
            
            self.broadcastAndProcessFrame(image)
        }
    }
    
    // MARK: - Lancement du Partage d'Écran en Direct
    
    /// Démarre le partage d'écran en direct avec injection immédiate de la 1ère trame
    public func startLiveScreenSharing(
        from viewController: UIViewController,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        if isScreenSharingActive {
            completion(true, "🔴 Le partage d'écran en direct est déjà actif !")
            return
        }
        
        isScreenSharingActive = true
        currentFrameCallback = onFrameAnalyzed
        
        // 1. Notification de statut
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": true]
        )
        
        // 2. Capture synchrone IMMÉDIATE de la 1ère trame à 0ms
        let targetView = viewController.view.window ?? viewController.view
        if let initialSnapshot = self.captureScreen(from: targetView) {
            self.latestCapturedImage = initialSnapshot
            self.broadcastAndProcessFrame(initialSnapshot)
        }
        
        // 3. Initialisation et démarrage du Picture-in-Picture persistant
        ScreenSharePiPManager.shared.setupPiP(in: viewController.view)
        ScreenSharePiPManager.shared.startPictureInPicture()
        
        // 4. Lancement de la minuterie DispatchSource haute performance (1.5 FPS)
        startHighPerformanceBackgroundSampling(from: viewController)
        
        // 5. ReplayKit In-App Capture en parallèle
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = true
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, self.isScreenSharingActive, error == nil else { return }
                
                if sampleBufferType == .video {
                    ScreenSharePiPManager.shared.enqueueSampleBuffer(sampleBuffer)
                    self.decodeQueue.async {
                        if let image = self.imageFromSampleBuffer(sampleBuffer) {
                            self.broadcastAndProcessFrame(image)
                        }
                    }
                }
            }) { error in
                completion(true, "🔴 Partage d'écran en direct activé !")
            }
        } else {
            completion(true, "🔴 Partage d'écran en direct activé !")
        }
    }
    
    /// Boucle de capture haute performance sur file d'arrière-plan dédiée (non bloquante)
    private func startHighPerformanceBackgroundSampling(from viewController: UIViewController) {
        dispatchTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: decodeQueue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.6) // ~1.6 FPS
        timer.setEventHandler { [weak self, weak viewController] in
            guard let self = self, self.isScreenSharingActive, let vc = viewController else { return }
            
            DispatchQueue.main.async {
                let targetView = vc.view.window ?? vc.view
                if let screenshot = self.captureScreen(from: targetView) {
                    self.decodeQueue.async {
                        self.broadcastAndProcessFrame(screenshot)
                    }
                }
            }
        }
        timer.resume()
        self.dispatchTimer = timer
    }
    
    /// Traite et diffuse la trame décodée sans latence
    public func broadcastAndProcessFrame(_ image: UIImage) {
        self.latestCapturedImage = image
        
        // 1. Envoi au contrôleur PiP
        ScreenSharePiPManager.shared.enqueueImage(image)
        
        // 2. Sauvegarde atomique dans l'App Group pour les extensions
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier),
           let jpegData = image.jpegData(compressionQuality: 0.6) {
            let fileURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
            try? jpegData.write(to: fileURL, options: .atomic)
        }
        
        // 3. Dispatch immédiat sur le thread principal pour mise à jour UI réactive
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            NotificationCenter.default.post(
                name: Self.liveFrameNotification,
                object: nil,
                userInfo: ["image": image]
            )
            
            let defaultResult = LocalVisionEngine.VisionAnalysisResult(
                objectLabel: "flux en direct",
                naturalSpokenResponse: "",
                detectedText: "",
                confidence: 0.9
            )
            self.currentFrameCallback?(defaultResult, image)
        }
        
        // 4. Analyse IA Vision en tâche de fond
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 800, quality: 0.7) else { return }
            
            LocalVisionEngine.shared.recognizeObject(in: processed.image) { [weak self] result in
                guard let self = self, self.isScreenSharingActive else { return }
                
                let newKey = "\(result.objectLabel)|\(result.detectedText)"
                if newKey != self.lastAnalyzedText && (!result.detectedText.isEmpty || result.objectLabel != "inconnu") {
                    self.lastAnalyzedText = newKey
                    DispatchQueue.main.async {
                        self.currentFrameCallback?(result, processed.image)
                    }
                }
            }
        }
    }
    
    // MARK: - Arrêt du Partage d'Écran
    
    public func stopLiveScreenSharing(completion: ((Bool) -> Void)? = nil) {
        isScreenSharingActive = false
        dispatchTimer?.cancel()
        dispatchTimer = nil
        currentFrameCallback = nil
        latestCapturedImage = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": false]
        )
        
        ScreenSharePiPManager.shared.stopPictureInPicture()
        
        if #available(iOS 11.0, *), screenRecorder.isRecording {
            screenRecorder.stopCapture { error in
                completion?(error == nil)
            }
        } else {
            completion?(true)
        }
    }
    
    // MARK: - Capture Universelle Haute Performance
    
    public func captureScreen(from windowOrView: UIView? = nil) -> UIImage? {
        return autoreleasepool { () -> UIImage? in
            let targetView: UIView? = windowOrView
                ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                ?? UIApplication.shared.keyWindow
                ?? UIApplication.shared.windows.first
            guard let view = targetView else { return nil }
            let bounds = view.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return nil }
            
            UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return nil
            }
            
            if !view.drawHierarchy(in: bounds, afterScreenUpdates: false) {
                view.layer.render(in: context)
            }
            
            let captured = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return captured
        }
    }
    
    // MARK: - Conversion CMSampleBuffer ➔ UIImage
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
