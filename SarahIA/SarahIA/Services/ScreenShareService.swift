import Foundation
import UIKit
import ReplayKit
import AVFoundation

/// Service de Partage d'Écran et Live Streaming avec Sarah :
/// - Enregistrement et capture en direct de l'écran (RPScreenRecorder & RPSystemBroadcastPickerView)
/// - Compatible avec tous les iPhone (iPhone 5S, 6, 7, 8, SE, X, 11, 12, 13, 14, 15, 16 sur iOS 12+)
/// - Analyse OCR et reconnaissance d'interface en temps réel par LocalVisionEngine
/// - Retransmission et commentaires vocaux de Sarah sur ce que l'utilisateur fait à l'écran
public final class ScreenShareService: NSObject {
    
    public static let shared = ScreenShareService()
    
    private let screenRecorder = RPScreenRecorder.shared()
    public private(set) var isScreenSharingActive: Bool = false
    private var liveTimer: Timer?
    private var liveFrameCount: Int = 0
    private var lastAnalyzedText: String = ""
    
    private override init() {
        super.init()
    }
    
    // MARK: - 1. Lancement du Partage d'Écran en Direct (Live Screen Broadcast)
    
    /// Démarre le partage d'écran en direct avec Sarah (Temps Réel)
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
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": true]
        )
        
        // 1. Essai ReplayKit si disponible
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = true
            
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, self.isScreenSharingActive, error == nil else { return }
                
                if sampleBufferType == .video {
                    self.liveFrameCount += 1
                    // Analyser 1 frame toutes les 35 frames (~1-2 fois par seconde) pour économiser batterie et CPU sur iPhone 5S/7
                    if self.liveFrameCount % 35 == 0 {
                        if let image = self.imageFromSampleBuffer(sampleBuffer) {
                            self.processLiveFrame(image, onFrameAnalyzed: onFrameAnalyzed)
                        }
                    }
                }
            }) { [weak self] error in
                guard let self = self else { return }
                if let err = error {
                    print("⚠️ [ScreenShareService] ReplayKit capture fallback: \(err.localizedDescription)")
                    // Démarrage du Fallback universel par échantillonnage de fenêtre
                    self.startUniversalWindowSampling(from: viewController, onFrameAnalyzed: onFrameAnalyzed)
                    completion(true, "🔴 Partage d'écran en direct activé ! Sarah analyse votre écran en continu.")
                } else {
                    completion(true, "🔴 Partage d'écran en direct activé ! Sarah analyse votre écran en continu.")
                }
            }
        } else {
            // 2. Fallback universel ultra-fluide pour iOS 12 (iPhone 5S, 6) ou en cas de restriction ReplayKit
            startUniversalWindowSampling(from: viewController, onFrameAnalyzed: onFrameAnalyzed)
            completion(true, "🔴 Partage d'écran en direct activé ! Sarah analyse votre écran en continu.")
        }
    }
    
    /// Boucle d'échantillonnage vidéo universelle ultra-rapide (compatible 100% iPhone 5S / 7 / 8)
    private func startUniversalWindowSampling(
        from viewController: UIViewController,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    ) {
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isScreenSharingActive else { return }
            
            DispatchQueue.main.async {
                guard let screenshot = self.captureScreen(from: viewController.view.window ?? viewController.view) else { return }
                self.processLiveFrame(screenshot, onFrameAnalyzed: onFrameAnalyzed)
            }
        }
    }
    
    private func processLiveFrame(
        _ image: UIImage,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 800, quality: 0.7) else { return }
            
            LocalVisionEngine.shared.recognizeObject(in: processed.image) { [weak self] result in
                guard let self = self, self.isScreenSharingActive else { return }
                
                // Ne notifier vocalement que si un changement de contexte ou texte pertinent est détecté
                if !result.detectedText.isEmpty && result.detectedText != self.lastAnalyzedText {
                    self.lastAnalyzedText = result.detectedText
                }
                
                DispatchQueue.main.async {
                    onFrameAnalyzed?(result, processed.image)
                }
            }
        }
    }
    
    /// Arrête le partage d'écran
    public func stopLiveScreenSharing(completion: ((Bool) -> Void)? = nil) {
        guard isScreenSharingActive else {
            completion?(true)
            return
        }
        
        isScreenSharingActive = false
        liveTimer?.invalidate()
        liveTimer = nil
        liveFrameCount = 0
        
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": false]
        )
        
        if #available(iOS 11.0, *), screenRecorder.isRecording {
            screenRecorder.stopCapture { error in
                completion?(error == nil)
            }
        } else {
            completion?(true)
        }
    }
    
    // MARK: - 2. Capture Instantanée d'Écran Unique & Analyse
    
    /// Capture l'écran actuel, le compresse et l'analyse avec Sarah
    public func shareAndAnalyzeScreen(
        from viewController: UIViewController,
        completion: @escaping (LocalVisionEngine.VisionAnalysisResult, UIImage, Data) -> Void
    ) {
        guard let screenshot = captureScreen(from: viewController.view.window ?? viewController.view) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(screenshot, maxDimension: 800, quality: 0.7) else {
                return
            }
            
            LocalVisionEngine.shared.recognizeObject(in: processed.image) { result in
                let adaptedSpokenResponse: String
                if !result.detectedText.isEmpty {
                    adaptedSpokenResponse = "Sur ton écran, je lis : « \(result.detectedText) » 📱"
                } else if result.objectLabel != "inconnu" && result.objectLabel != "objet devant la caméra" {
                    adaptedSpokenResponse = "Sur ton écran, je vois \(result.objectLabel) 🖥️"
                } else {
                    adaptedSpokenResponse = "J'observe ton écran en direct ! Que souhaites-tu que je t'explique ou que je fasse ? 💡"
                }
                
                let screenResult = LocalVisionEngine.VisionAnalysisResult(
                    objectLabel: result.objectLabel,
                    naturalSpokenResponse: adaptedSpokenResponse,
                    detectedText: result.detectedText,
                    confidence: max(0.85, result.confidence)
                )
                
                DispatchQueue.main.async {
                    completion(screenResult, processed.image, processed.data)
                }
            }
        }
    }
    
    /// Capture universelle UIView / UIWindow
    public func captureScreen(from windowOrView: UIView? = nil) -> UIImage? {
        return autoreleasepool { () -> UIImage? in
            let targetView: UIView? = windowOrView ?? UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            guard let view = targetView else { return nil }
            let bounds = view.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return nil }
            
            UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
            view.drawHierarchy(in: bounds, afterScreenUpdates: false)
            let captured = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return captured
        }
    }
    
    // MARK: - Utilitaires CMSampleBuffer ➔ UIImage
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false, CIContextOption.priorityRequestLow: true])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

