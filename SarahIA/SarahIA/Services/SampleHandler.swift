import Foundation
import ReplayKit
import AVFoundation
import CoreImage
import CoreVideo

/// Handler universel de diffusion d'écran système en arrière-plan (Extension ReplayKit Broadcast)
/// - Capture les trames CMSampleBuffer au niveau système (même sur l'écran d'accueil iOS et en dehors de SarahIA)
/// - Valide et inspecte directement chaque RPSampleBufferType.video
/// - Encode en JPEG optimisé à 12-15 FPS et écrit de manière atomique dans le conteneur partagé App Group
/// - Notifie immédiatement l'application principale via Darwin Notification IPC
@objc(SampleHandler)
public class SampleHandler: RPBroadcastSampleHandler {
    
    private let appGroupIdentifier = "group.com.sarahia.shared"
    private let darwinNotificationName = "group.com.sarahia.broadcast.frame"
    private var lastFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 0.066 // ~15 FPS fluide
    private let ciContext = CIContext(options: [
        CIContextOption.useSoftwareRenderer: false,
        CIContextOption.priorityRequestLow: false
    ])
    
    public override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        lastFrameTime = 0
        print("[BroadcastExtension] broadcastStarted")
    }
    
    public override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        print("[BroadcastExtension] processSampleBuffer")
        
        guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else {
            print("[BroadcastExtension] ERROR = invalid or unready sample buffer")
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("[BroadcastExtension] ERROR = failed to get image buffer from sample buffer")
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ptsSeconds = CMTimeGetSeconds(pts)
        let timestampStr = String(format: "%.3f", ptsSeconds > 0 ? ptsSeconds : CACurrentMediaTime())
        
        print("[BroadcastExtension] VIDEO SAMPLE RECEIVED")
        print("[BroadcastExtension] VIDEO FRAME SIZE = \(width)x\(height)")
        print("[BroadcastExtension] timestamp = \(timestampStr)")
        
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let jpegData = ciContext.jpegRepresentation(
                of: ciImage,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.55]
              ) else {
            print("[BroadcastExtension] ERROR = failed to encode frame to JPEG")
            return
        }
        print("[BroadcastExtension] FRAME JPEG CREATED")
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("[BroadcastExtension] ERROR = App Group container not accessible: \(appGroupIdentifier)")
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
        do {
            try jpegData.write(to: fileURL, options: .atomic)
            print("[BroadcastExtension] FRAME WRITTEN")
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(center, CFNotificationName(darwinNotificationName as CFString), nil, nil, true)
            print("[BroadcastExtension] DARWIN NOTIFICATION SENT")
        } catch {
            print("[BroadcastExtension] ERROR = failed to write frame to App Group: \(error.localizedDescription)")
        }
    }
    
    public override func broadcastFinished() {
        print("[BroadcastExtension] broadcastFinished")
    }
}
