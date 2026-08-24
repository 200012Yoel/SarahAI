import Foundation
import UIKit
import AVFoundation
import AVKit
import CoreMedia
import CoreVideo

/// Gestionnaire de Picture-in-Picture (PiP) Système Universel pour le Partage d'Écran
/// - Compatible de iOS 12 à iOS 18
/// - Maintient le clone vidéo flottant système sur l'écran d'accueil et dans les autres applications
public final class ScreenSharePiPManager: NSObject {
    
    public static let shared = ScreenSharePiPManager()
    
    // Layers et Vues
    public let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AnyObject?
    private var pipDelegateHelper: AnyObject?
    private var playerLayer: AVPlayerLayer?
    private var dummyPlayer: AVPlayer?
    
    public var isPiPActive: Bool = false
    
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
        
        if #available(iOS 14.0, *) {
            setupNativePiP(in: containerView)
        }
    }
    
    @available(iOS 14.0, *)
    private func setupNativePiP(in containerView: UIView) {
        guard pipController == nil else { return }
        
        guard let blankURL = createBlankVideoAsset() else { return }
        let playerItem = AVPlayerItem(url: blankURL)
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        let pLayer = AVPlayerLayer(player: player)
        pLayer.frame = containerView.bounds
        pLayer.videoGravity = .resizeAspect
        containerView.layer.insertSublayer(pLayer, at: 0)
        
        self.dummyPlayer = player
        self.playerLayer = pLayer
        
        if let controller = AVPictureInPictureController(playerLayer: pLayer) {
            let helper = PiPDelegateHelper(manager: self)
            self.pipDelegateHelper = helper
            controller.delegate = helper
            if #available(iOS 14.2, *) {
                controller.canStartPictureInPictureAutomaticallyFromInline = true
            }
            self.pipController = controller
        }
        
        player.play()
    }
    
    // MARK: - Contrôle du Picture-in-Picture
    
    public func startPictureInPicture() {
        guard isPiPSupported else { return }
        
        if #available(iOS 14.0, *),
           let controller = pipController as? AVPictureInPictureController,
           !controller.isPictureInPictureActive {
            DispatchQueue.main.async {
                controller.startPictureInPicture()
            }
        }
    }
    
    public func stopPictureInPicture() {
        if #available(iOS 14.0, *),
           let controller = pipController as? AVPictureInPictureController,
           controller.isPictureInPictureActive {
            DispatchQueue.main.async {
                controller.stopPictureInPicture()
            }
        }
    }
    
    // MARK: - Injection de Trames Vidéo
    
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
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            OSType(kCVPixelFormatType_32ARGB),
            attrs as CFDictionary,
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
    
    private func createBlankVideoAsset() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("blank_pip.mp4")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            return tempURL
        }
        return Bundle.main.url(forResource: "blank", withExtension: "mp4") ?? tempURL
    }
}

// MARK: - Helper Délégué Isolé iOS 14+ (Résout les conflits de protocoles de compilation)

@available(iOS 14.0, *)
private final class PiPDelegateHelper: NSObject, AVPictureInPictureControllerDelegate {
    
    weak var manager: ScreenSharePiPManager?
    
    init(manager: ScreenSharePiPManager) {
        self.manager = manager
        super.init()
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        manager?.isPiPActive = true
        NotificationCenter.default.post(name: NSNotification.Name("SarahPiPStatusChanged"), object: nil, userInfo: ["isActive": true])
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        manager?.isPiPActive = true
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        manager?.isPiPActive = false
        NotificationCenter.default.post(name: NSNotification.Name("SarahPiPStatusChanged"), object: nil, userInfo: ["isActive": false])
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        manager?.isPiPActive = false
        print("⚠️ [ScreenSharePiPManager] Échec démarrage PiP: \(error.localizedDescription)")
    }
}
