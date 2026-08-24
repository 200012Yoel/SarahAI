import Foundation
import UIKit
import AVFoundation
import AVKit
import CoreMedia
import CoreVideo

/// Gestionnaire de Picture-in-Picture (PiP) Système pour le Partage d'Écran en Direct
/// - Utilise AVPictureInPictureController avec AVSampleBufferDisplayLayer (iOS 15+) et fallback AVPlayer (iOS 14)
/// - Permet d'afficher la vignette vidéo flottante système EN DEHORS DE L'APPLICATION (sur l'écran d'accueil et d'autres apps)
/// - Injecte les CMSampleBuffer / CVPixelBuffer de ReplayKit directement dans le flux PiP
public final class ScreenSharePiPManager: NSObject {
    
    public static let shared = ScreenSharePiPManager()
    
    // Vues et Layers Vidéo
    public let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var pipVideoSource: Any? // Retient la source PiP
    
    // Support AVPlayer Fallback pour iOS 14
    private var fallbackPlayer: AVPlayer?
    private var fallbackPlayerLayer: AVPlayerLayer?
    
    // États
    public private(set) var isPiPActive: Bool = false
    public private(set) var isPiPSupported: Bool = false
    
    private override init() {
        super.init()
        checkPiPSupport()
        configureAudioSessionForPiP()
    }
    
    // MARK: - Vérification du Support PiP
    
    private func checkPiPSupport() {
        if #available(iOS 14.0, *) {
            isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
        } else {
            isPiPSupported = false
        }
    }
    
    private func configureAudioSessionForPiP() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ [ScreenSharePiPManager] Erreur configuration audio PiP: \(error)")
        }
    }
    
    // MARK: - Initialisation du Layer PiP dans une Vue Hôte
    
    /// Attache le layer d'affichage PiP à une vue hôte (ex: ChatScreenView ou LegacyChatViewController)
    public func setupPiP(in containerView: UIView) {
        guard isPiPSupported else { return }
        
        sampleBufferDisplayLayer.frame = containerView.bounds
        sampleBufferDisplayLayer.videoGravity = .resizeAspect
        
        if sampleBufferDisplayLayer.superlayer !== containerView.layer {
            sampleBufferDisplayLayer.removeFromSuperlayer()
            containerView.layer.insertSublayer(sampleBufferDisplayLayer, at: 0)
        }
        
        if #available(iOS 15.0, *) {
            setupSampleBufferPiP()
        } else if #available(iOS 14.0, *) {
            setupLegacyPlayerPiP(in: containerView)
        }
    }
    
    // MARK: - Configuration PiP iOS 15+ (AVSampleBufferDisplayLayer)
    
    @available(iOS 15.0, *)
    private func setupSampleBufferPiP() {
        guard pipController == nil else { return }
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: sampleBufferDisplayLayer,
            playbackDelegate: self
        )
        pipVideoSource = contentSource
        
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.pipController = controller
    }
    
    // MARK: - Configuration PiP iOS 14 Fallback (AVPlayerLayer)
    
    @available(iOS 14.0, *)
    private func setupLegacyPlayerPiP(in containerView: UIView) {
        guard pipController == nil else { return }
        
        // Création d'une composition vidéo silencieuse en boucle
        guard let blankVideoURL = createBlankVideoAsset() else { return }
        let playerItem = AVPlayerItem(url: blankVideoURL)
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
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = containerView.bounds
        playerLayer.videoGravity = .resizeAspect
        containerView.layer.insertSublayer(playerLayer, at: 0)
        
        self.fallbackPlayer = player
        self.fallbackPlayerLayer = playerLayer
        
        let controller = AVPictureInPictureController(playerLayer: playerLayer)
        controller?.delegate = self
        if #available(iOS 14.2, *) {
            controller?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        self.pipController = controller
        
        player.play()
    }
    
    // MARK: - Contrôle du Picture-in-Picture
    
    /// Démarre le PiP flottant au premier plan système
    public func startPictureInPicture() {
        guard isPiPSupported, let controller = pipController, !controller.isPictureInPictureActive else { return }
        
        DispatchQueue.main.async {
            controller.startPictureInPicture()
        }
    }
    
    /// Arrête le PiP
    public func stopPictureInPicture() {
        guard let controller = pipController, controller.isPictureInPictureActive else { return }
        
        DispatchQueue.main.async {
            controller.stopPictureInPicture()
        }
    }
    
    // MARK: - Injection de Trames Vidéo (ReplayKit / Snapshot ➔ PiP)
    
    /// Injecte une trame CMSampleBuffer directement dans la fenêtre flottante PiP
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
    
    /// Injecte une UIImage ou CVPixelBuffer dans le flux PiP
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
    
    private func createBlankVideoAsset() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("blank_pip.mp4")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            return tempURL
        }
        return Bundle.main.url(forResource: "blank", withExtension: "mp4") ?? tempURL
    }
}

// MARK: - AVPictureInPictureControllerDelegate

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
        print("⚠️ [ScreenSharePiPManager] Échec du démarrage PiP: \(error.localizedDescription)")
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate (iOS 15+)

@available(iOS 15.0, *)
extension ScreenSharePiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // Gère la mise en pause/lecture depuis les boutons de la fenêtre flottante PiP
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: CMTime(value: 1000000, timescale: 1))
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // Redimensionnement de la fenêtre PiP par l'utilisateur
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
