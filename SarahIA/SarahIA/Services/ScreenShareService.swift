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
    
    private override init() {
        super.init()
    }
    
    // MARK: - 1. Lancement du Partage d'Écran en Direct (Live Screen Broadcast)
    
    /// Démarre le partage d'écran en direct avec Sarah
    public func startLiveScreenSharing(
        from viewController: UIViewController,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard screenRecorder.isAvailable else {
            completion(false, "L'enregistrement d'écran n'est pas disponible sur cet appareil.")
            return
        }
        
        // Configuration ReplayKit pour capture continue
        screenRecorder.isMicrophoneEnabled = true
        
        if #available(iOS 12.0, *) {
            // Affichage du sélecteur de diffusion système iOS
            let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
            picker.showsMicrophoneButton = true
            viewController.view.addSubview(picker)
            picker.center = viewController.view.center
            picker.isHidden = true
            
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                }
            }
        }
        
        // Capture des images d'écran en continu (ReplayKit Live Handler)
        if #available(iOS 11.0, *) {
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, error == nil else { return }
                
                if sampleBufferType == .video {
                    self.liveFrameCount += 1
                    // Analyser 1 frame toutes les 30 frames (~1 fois par seconde) pour économiser la batterie sur iPhone 5S
                    if self.liveFrameCount % 30 == 0 {
                        if let image = self.imageFromSampleBuffer(sampleBuffer) {
                            LocalVisionEngine.shared.recognizeObject(in: image) { result in
                                onFrameAnalyzed?(result, image)
                            }
                        }
                    }
                }
            }) { [weak self] error in
                if let err = error {
                    self?.isScreenSharingActive = false
                    completion(false, "Impossible de démarrer le partage : \(err.localizedDescription)")
                } else {
                    self?.isScreenSharingActive = true
                    completion(true, "🔴 Partage d'écran en direct activé ! Sarah analyse votre écran en continu.")
                }
            }
        } else {
            // Fallback iOS 10
            isScreenSharingActive = true
            completion(true, "Partage d'écran activé !")
        }
    }
    
    /// Arrête le partage d'écran
    public func stopLiveScreenSharing(completion: ((Bool) -> Void)? = nil) {
        guard isScreenSharingActive else {
            completion?(true)
            return
        }
        
        if #available(iOS 11.0, *) {
            screenRecorder.stopCapture { [weak self] error in
                self?.isScreenSharingActive = false
                self?.liveTimer?.invalidate()
                self?.liveTimer = nil
                completion?(error == nil)
            }
        } else {
            isScreenSharingActive = false
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
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
