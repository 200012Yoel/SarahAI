import Foundation
import UIKit
import AVFoundation
import AVKit
import CoreMedia
import CoreVideo

/// Gestionnaire de Picture-in-Picture (PiP) Système Universel pour le Partage d'Écran
/// - Compatible 100% avec les cibles de déploiement iOS 12 -> 18
/// - Utilise AVPictureInPictureController sur iOS 14+ avec support AVSampleBufferDisplayLayer sur iOS 15+
/// - Maintient le clone vidéo flottant système sur l'écran d'accueil et dans les autres applications
public final class ScreenSharePiPManager: NSObject {
    
    public static let shared = ScreenSharePiPManager()
    
    // Vues et Layers Vidéo
    public let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var pipControllerObject: AnyObject? // AVPictureInPictureController sécurisé pour iOS 12+
    private var pipPlaybackHelper: AnyObject?
    
    // États
    public private(set) var isPiPActive: Bool = false
    
    public var isPiPSupported: Bool {
        if #available(iOS 14.0, *) {
            return AVPictureInPictureController.isPictureInPictureSupported()
        }
        return false
    }
    
    private override init() {
        super.init()
        configureAudioSessionForPiP()
    }
    
    private func configureAudioSessionForPiP() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ [ScreenSharePiPManager] Configuration audio PiP: \(error)")
        }
    }
    
    // MARK: - Initialisation du Layer PiP dans une Vue Hôte
    
    public func setupPiP(in containerView: UIView) {
        guard isPiPSupported else { return }
        
        sampleBufferDisplayLayer.frame = containerView.bounds
        sampleBufferDisplayLayer.videoGravity = .resizeAspect
        
        if sampleBufferDisplayLayer.superlayer !== containerView.layer {
            sampleBufferDisplayLayer.removeFromSuperlayer()
            containerView.layer.insertSublayer(sampleBufferDisplayLayer, at: 0)
        }
        
        if #available(iOS 15.0, *) {
            setupSampleBufferPiPiOS15()
        }
    }
    
    @available(iOS 15.0, *)
    private func setupSampleBufferPiPiOS15() {
        guard pipControllerObject == nil else { return }
        
        let helper = SampleBufferPiPHelper(manager: self)
        self.pipPlaybackHelper = helper
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: sampleBufferDisplayLayer,
            playbackDelegate: helper
        )
        
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.pipControllerObject = controller
    }
    
    // MARK: - Contrôle du Picture-in-Picture
    
    public func startPictureInPicture() {
        guard isPiPSupported else { return }
        
        if #available(iOS 14.0, *),
           let controller = pipControllerObject as? AVPictureInPictureController,
           !controller.isPictureInPictureActive {
            DispatchQueue.main.async {
                controller.startPictureInPicture()
            }
        }
    }
    
    public func stopPictureInPicture() {
        if #available(iOS 14.0, *),
           let controller = pipControllerObject as? AVPictureInPictureController,
           controller.isPictureInPictureActive {
            DispatchQueue.main.async {
                controller.stopPictureInPicture()
            }
        }
    }
    
    // MARK: - Injection de Trames Vidéo (ReplayKit / Snapshot ➔ PiP)
    
    public func enqueueSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isPiPSupported else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.sampleBufferDisplayLayer.status == .failed {
                self.sampleBufferDisplayLayer.flush()
            }
            
            if self.sampleBufferDisplayLayer.isReadyForMoreMediaData {
                self.sampleBufferDisplayLayer.enqueue(sampleBuffer)
            }
        }
    }
    
    public func enqueueImage(_ image: UIImage) {
        guard isPiPSupported else { return }
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self,
                  let pixelBuffer = self.pixelBuffer(from: image),
                  let sampleBuffer = self.sampleBuffer(from: pixelBuffer) else { return }
            
            self.enqueueSampleBuffer(sampleBuffer)
        }
    }
    
    // MARK: - Convertisseurs Image ➔ CMSampleBuffer
    
    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }
    
    private func sampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600),
            decodeTimeStamp: .invalid
        )
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let format = formatDescription else { return nil }
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        return sampleBuffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate (iOS 14+)

@available(iOS 14.0, *)
extension ScreenSharePiPManager: AVPictureInPictureControllerDelegate {
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
        NotificationCenter.default.post(name: NSNotification.Name("SarahPiPStatusChanged"), object: nil, userInfo: ["isActive": true])
    }
    
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
        NotificationCenter.default.post(name: NSNotification.Name("SarahPiPStatusChanged"), object: nil, userInfo: ["isActive": false])
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isPiPActive = false
        print("⚠️ [ScreenSharePiPManager] Échec démarrage PiP: \(error.localizedDescription)")
    }
}

// MARK: - Helper iOS 15+ pour AVPictureInPictureSampleBufferPlaybackDelegate

@available(iOS 15.0, *)
private final class SampleBufferPiPHelper: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
    
    weak var manager: ScreenSharePiPManager?
    
    init(manager: ScreenSharePiPManager) {
        self.manager = manager
        super.init()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: CMTime(value: 1000000, timescale: 1))
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
