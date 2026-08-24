import Foundation
import UIKit
import ReplayKit
import AVFoundation
#if canImport(Combine)
import Combine
#endif

/// Service de Partage d'Écran et Live Streaming avec Sarah :
/// - Capture en direct haute fréquence sans écran noir
/// - Diffusion immédiate de la 1ère trame à 0ms
/// - Notification locale réactive (SarahLiveScreenFrameUpdated) pour UIKit et SwiftUI
/// - Compatible 100% universel de iOS 12 (iPhone 5s) à iOS 18 (iPhone 16 Pro)
public final class ScreenShareService: NSObject {
    
    public static let shared = ScreenShareService()
    
    // Notifications & App Group
    public static let appGroupIdentifier = "group.com.sarahia.shared"
    public static let darwinNotificationName = "group.com.sarahia.broadcast.frame"
    public static let liveFrameNotification = NSNotification.Name("SarahLiveScreenFrameUpdated")
    
    private let screenRecorder = RPScreenRecorder.shared()
    public private(set) var isScreenSharingActive: Bool = false
    public private(set) var latestCapturedImage: UIImage?
    
    private var liveTimer: Timer?
    private var lastAnalyzedText: String = ""
    private var lastDarwinFrameTimestamp: TimeInterval = 0
    private var currentFrameCallback: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    
    private override init() {
        super.init()
        setupDarwinIPCReceiver()
    }
    
    // MARK: - Récepteur IPC Darwin Notification
    
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
        guard now - lastDarwinFrameTimestamp >= 0.5 else { return }
        lastDarwinFrameTimestamp = now
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
    
    /// Démarre le partage d'écran en direct avec injection immédiate de la première trame
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
        
        // 2. Capture synchrone IMMÉDIATE de la 1ère trame (Élimine le délai et l'écran noir)
        let targetView = viewController.view.window ?? viewController.view
        if let initialSnapshot = self.captureScreen(from: targetView) {
            self.latestCapturedImage = initialSnapshot
            self.broadcastAndProcessFrame(initialSnapshot)
        }
        
        // 3. Initialisation du Picture-in-Picture
        ScreenSharePiPManager.shared.setupPiP(in: viewController.view)
        ScreenSharePiPManager.shared.startPictureInPicture()
        
        // 4. Lancement de la boucle continue d'échantillonnage (1 image / 1.0 seconde)
        startUniversalWindowSampling(from: viewController)
        
        // 5. Tentative ReplayKit en parallèle si supporté
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = true
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, self.isScreenSharingActive, error == nil else { return }
                
                if sampleBufferType == .video {
                    ScreenSharePiPManager.shared.enqueueSampleBuffer(sampleBuffer)
                    if let image = self.imageFromSampleBuffer(sampleBuffer) {
                        self.broadcastAndProcessFrame(image)
                    }
                }
            }) { error in
                completion(true, "🔴 Partage d'écran en direct activé !")
            }
        } else {
            completion(true, "🔴 Partage d'écran en direct activé !")
        }
    }
    
    /// Échantillonnage continu et infaillible de la fenêtre (Toutes les 1.0s)
    private func startUniversalWindowSampling(from viewController: UIViewController) {
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isScreenSharingActive else { return }
            
            DispatchQueue.main.async {
                let targetView = viewController.view.window ?? viewController.view
                if let screenshot = self.captureScreen(from: targetView) {
                    self.broadcastAndProcessFrame(screenshot)
                }
            }
        }
    }
    
    /// Diffuse la nouvelle trame instantanément sur le thread principal et déclenche l'analyse IA
    public func broadcastAndProcessFrame(_ image: UIImage) {
        self.latestCapturedImage = image
        
        // 1. Envoi immédiat à Picture-in-Picture
        ScreenSharePiPManager.shared.enqueueImage(image)
        
        // 2. Publication réactive locale sur le thread principal pour l'UI
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
        
        // 3. Analyse IA en arrière-plan
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
        liveTimer?.invalidate()
        liveTimer = nil
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
    
    // MARK: - Capture Universelle Sans Écran Noir
    
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
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
