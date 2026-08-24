import Foundation
import ReplayKit
import AVFoundation

/// Handler universel de diffusion d'écran système en arrière-plan (Extension ReplayKit Broadcast)
/// - Capture les trames CMSampleBuffer au niveau système (même sur l'écran d'accueil iOS et en dehors de Sarah)
/// - Encode en JPEG optimisé et écrit de manière atomique dans le conteneur partagé App Group
/// - Notifie immédiatement l'application principale via Darwin Notification
@objc(SampleHandler)
public class SampleHandler: RPBroadcastSampleHandler {
    
    private let appGroupIdentifier = "group.com.sarahia.shared"
    private let darwinNotificationName = "group.com.sarahia.broadcast.frame"
    private var lastFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 0.5 // 2 FPS fluide et économe en batterie
    private let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    
    public override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        lastFrameTime = 0
    }
    
    public override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let jpegData = ciContext.jpegRepresentation(
                of: ciImage,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6]
              ) else {
            return
        }
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
        do {
            try jpegData.write(to: fileURL, options: .atomic)
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(center, CFNotificationName(darwinNotificationName as CFString), nil, nil, true)
        } catch {
            // Ignorer erreurs temporaires d'écriture I/O
        }
    }
    
    public override func broadcastFinished() {
        // Arrêt de la diffusion système
    }
}
