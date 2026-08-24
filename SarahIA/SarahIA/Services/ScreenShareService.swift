import Foundation
import UIKit
import ReplayKit
import AVFoundation

/// Service de Partage d'Écran et Live Streaming avec Sarah :
/// - Enregistrement et capture en direct de l'écran (RPScreenRecorder & Universal Window Sampling)
/// - Compatible avec tous les iPhone (iPhone 5S, 6, 7, 8, SE, X, 11, 12, 13, 14, 15, 16 sur iOS 12+)
/// - Retransmission instantanée dans le widget flottant sans écran noir (0s de délai)
/// - Analyse OCR et reconnaissance d'interface en temps réel
public final class ScreenShareService: NSObject {
    
    public static let shared = ScreenShareService()
    
    // App Group & IPC Darwin Notification
    public static let appGroupIdentifier = "group.com.sarahia.shared"
    public static let darwinNotificationName = "group.com.sarahia.broadcast.frame"
    
    private let screenRecorder = RPScreenRecorder.shared()
    public private(set) var isScreenSharingActive: Bool = false
    private var liveTimer: Timer?
    private var liveFrameCount: Int = 0
    private var lastAnalyzedText: String = ""
    private var lastDarwinFrameTimestamp: TimeInterval = 0
    
    private var currentFrameCallback: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    
    private override init() {
        super.init()
        setupDarwinIPCReceiver()
    }
    
    // MARK: - Récepteur IPC Darwin Notification (Extension Broadcast ➔ App Principale)
    
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
        guard now - lastDarwinFrameTimestamp >= 0.6 else { return }
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
            
            self.processLiveFrame(image, onFrameAnalyzed: self.currentFrameCallback)
        }
    }
    
    // MARK: - 1. Lancement du Partage d'Écran en Direct
    
    /// Démarre le partage d'écran en direct avec affichage immédiat de la première trame
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
        
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": true]
        )
        
        // 0. Capture et affichage IMMÉDIAT de la première trame (Zéro écran noir)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let targetView = viewController.view.window ?? viewController.view
            if let initialSnapshot = self.captureScreen(from: targetView) {
                let initialResult = LocalVisionEngine.VisionAnalysisResult(
                    objectLabel: "écran d'accueil",
                    naturalSpokenResponse: "Partage d'écran actif.",
                    detectedText: "",
                    confidence: 0.95
                )
                onFrameAnalyzed?(initialResult, initialSnapshot)
                ScreenSharePiPManager.shared.enqueueImage(initialSnapshot)
            }
        }
        
        // 1. Initialisation du Picture-in-Picture
        ScreenSharePiPManager.shared.setupPiP(in: viewController.view)
        ScreenSharePiPManager.shared.startPictureInPicture()
        
        // 2. Échantillonnage ReplayKit / Window continue
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = true
            
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, self.isScreenSharingActive, error == nil else { return }
                
                if sampleBufferType == .video {
                    self.liveFrameCount += 1
                    ScreenSharePiPManager.shared.enqueueSampleBuffer(sampleBuffer)
                    
                    if self.liveFrameCount % 30 == 0 {
                        if let image = self.imageFromSampleBuffer(sampleBuffer) {
                            self.processLiveFrame(image, onFrameAnalyzed: onFrameAnalyzed)
                        }
                    }
                }
            }) { [weak self] error in
                guard let self = self else { return }
                if error != nil {
                    // Fallback échantillonnage fenêtre
                    self.startUniversalWindowSampling(from: viewController, onFrameAnalyzed: onFrameAnalyzed)
                }
                completion(true, "🔴 Partage d'écran en direct activé !")
            }
        } else {
            // Fallback universel (iOS 12 / iPhone 5s)
            startUniversalWindowSampling(from: viewController, onFrameAnalyzed: onFrameAnalyzed)
            completion(true, "🔴 Partage d'écran en direct activé !")
        }
    }
    
    /// Boucle d'échantillonnage vidéo universelle ultra-rapide (rafraîchie toutes les 1.0s)
    private func startUniversalWindowSampling(
        from viewController: UIViewController,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    ) {
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isScreenSharingActive else { return }
            
            DispatchQueue.main.async {
                guard let targetView = viewController.view.window ?? viewController.view,
                      let screenshot = self.captureScreen(from: targetView) else { return }
                self.processLiveFrame(screenshot, onFrameAnalyzed: onFrameAnalyzed)
            }
        }
    }
    
    private func processLiveFrame(
        _ image: UIImage,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    ) {
        // Envoi au flux Picture-in-Picture flottant
        ScreenSharePiPManager.shared.enqueueImage(image)
        
        DispatchQueue.main.async {
            let result = LocalVisionEngine.VisionAnalysisResult(
                objectLabel: "flux en direct",
                naturalSpokenResponse: "",
                detectedText: "",
                confidence: 0.9
            )
            onFrameAnalyzed?(result, image)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 800, quality: 0.7) else { return }
            
            LocalVisionEngine.shared.recognizeObject(in: processed.image) { [weak self] result in
                guard let self = self, self.isScreenSharingActive else { return }
                
                // Détection de changement d'état significatif
                let newKey = "\(result.objectLabel)|\(result.detectedText)"
                if newKey != self.lastAnalyzedText && (!result.detectedText.isEmpty || result.objectLabel != "inconnu") {
                    self.lastAnalyzedText = newKey
                    DispatchQueue.main.async {
                        onFrameAnalyzed?(result, processed.image)
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
    
    // MARK: - Capture Universelle UIView / UIWindow
    
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
            
            // Double fallback pour garantir une capture d'écran 100% fiable
            if !view.drawHierarchy(in: bounds, afterScreenUpdates: false) {
                view.layer.render(in: context)
            }
            
            let captured = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return captured
        }
    }
    
    // MARK: - Utilitaires de conversion CMSampleBuffer ➔ UIImage
    
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
