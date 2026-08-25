import Foundation
import UIKit
import AVFoundation
import AVKit
import CoreMedia
import CoreVideo

/// Gestionnaire de Picture-in-Picture (PiP) Système Universel pour le Partage d'Écran
/// - Reçoit directement le CMSampleBuffer natif issu de ReplayKit (Zéro conversion redondante)
/// - Sur iOS 15+ : AVPictureInPictureController.ContentSource avec AVSampleBufferDisplayLayer
/// - Sur iOS 14 : Support PiP vérifié via AVPictureInPictureController.isPictureInPictureSupported()
/// - Sur iOS 12 & 13 : PiP système désactivé proprement sans crash, fallback prévisualisation interne
/// - Gestion de la Timebase CMTimebase et récupération automatique si le layer entre en statut .failed
public final class ScreenSharePiPManager: NSObject {
    
    public static let shared = ScreenSharePiPManager()
    
    // Layer d'affichage vidéo natif pour PiP
    public let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var timebase: CMTimebase?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // Objets PiP système conservés avec types natifs / protections de version
    private var pipController: AnyObject?
    private var pipDelegateHelper: AnyObject?
    private var sampleBufferPlaybackDelegate: AnyObject?
    private weak var hostContainerView: UIView?
    
    public internal(set) var isPiPActive: Bool = false
    
    /// Vérifie si le PiP système est réellement disponible sur le matériel et l'OS actif
    public var isPiPSupported: Bool {
        if #available(iOS 14.0, *) {
            let supported = AVPictureInPictureController.isPictureInPictureSupported()
            return supported
        }
        return false
    }
    
    private override init() {
        super.init()
        setupTimebase()
        configureAudioSessionForPiP()
        setupLifecycleObservers()
    }
    
    // MARK: - 1. Initialisation de la Base de Temps (Timebase)
    
    private func setupTimebase() {
        var tb: CMTimebase?
        let hostClock = CMClockGetHostTimeClock()
        let status = CMTimebaseCreateWithMasterClock(
            allocator: kCFAllocatorDefault,
            masterClock: hostClock,
            timebaseOut: &tb
        )
        if status == noErr, let createdTimebase = tb {
            let hostTime = CMClockGetTime(hostClock)
            CMTimebaseSetTime(createdTimebase, time: hostTime)
            CMTimebaseSetRate(createdTimebase, rate: 1.0)
            self.timebase = createdTimebase
            self.sampleBufferDisplayLayer.controlTimebase = createdTimebase
        }
    }
    
    // MARK: - 2. Configuration Audio & Gestion Cycle de Vie
    
    private func configureAudioSessionForPiP() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ [PiP] Configuration audio PiP: \(error.localizedDescription)")
        }
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        if ScreenShareService.shared.isScreenSharingActive {
            startTransientBackgroundTask()
            ensurePiPConfigured()
            startPictureInPicture()
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        if ScreenShareService.shared.isScreenSharingActive {
            startTransientBackgroundTask()
            ensurePiPConfigured()
            startPictureInPicture()
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        if !ScreenShareService.shared.isScreenSharingActive {
            endTransientBackgroundTask()
        }
    }
    
    public func startTransientBackgroundTask() {
        if backgroundTaskId == .invalid {
            backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "SarahScreenSharePiPTransition") { [weak self] in
                self?.endTransientBackgroundTask()
            }
        }
    }
    
    public func endTransientBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
    
    // MARK: - 3. Montage et Configuration du Contrôleur PiP
    
    public func setupPiP(in containerView: UIView) {
        guard isPiPSupported else {
            print("[PiP] supported = false (iOS 12/13 ou matériel non supporté)")
            return
        }
        self.hostContainerView = containerView
        
        let targetFrame = containerView.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 320, height: 240) : containerView.bounds
        sampleBufferDisplayLayer.frame = targetFrame
        sampleBufferDisplayLayer.videoGravity = .resizeAspect
        
        if sampleBufferDisplayLayer.superlayer !== containerView.layer {
            sampleBufferDisplayLayer.removeFromSuperlayer()
            containerView.layer.insertSublayer(sampleBufferDisplayLayer, at: 0)
        }
        
        if #available(iOS 15.0, *) {
            setupSampleBufferPiPiOS15()
        }
        print("[PiP] supported = true")
        print("[PiP] configured = true")
    }
    
    @available(iOS 15.0, *)
    private func setupSampleBufferPiPiOS15() {
        guard pipController == nil else { return }
        
        let playbackDelegate = SampleBufferPiPPlaybackDelegate(manager: self)
        self.sampleBufferPlaybackDelegate = playbackDelegate
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: sampleBufferDisplayLayer,
            playbackDelegate: playbackDelegate
        )
        
        let controller = AVPictureInPictureController(contentSource: contentSource)
        let helper = PiPDelegateHelper(manager: self)
        self.pipDelegateHelper = helper
        controller.delegate = helper
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.pipController = controller
    }
    
    public func ensurePiPConfigured() {
        guard isPiPSupported else { return }
        if pipController == nil {
            let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                ?? UIApplication.shared.keyWindow
                ?? UIApplication.shared.windows.first
            if let hostView = window?.rootViewController?.view ?? window?.subviews.first ?? window {
                setupPiP(in: hostView)
            }
        }
    }
    
    public func startPictureInPicture() {
        guard isPiPSupported else { return }
        ensurePiPConfigured()
        startTransientBackgroundTask()
        
        if #available(iOS 14.0, *),
           let controller = pipController as? AVPictureInPictureController {
            DispatchQueue.main.async {
                if !controller.isPictureInPictureActive {
                    controller.startPictureInPicture()
                    print("[PiP] started = true")
                }
            }
        }
    }
    
    public func stopPictureInPicture() {
        if #available(iOS 14.0, *),
           let controller = pipController as? AVPictureInPictureController,
           controller.isPictureInPictureActive {
            DispatchQueue.main.async {
                controller.stopPictureInPicture()
                print("[PiP] stopped = true")
            }
        }
        endTransientBackgroundTask()
        isPiPActive = false
    }
    
    // MARK: - 4. Injection Directe de CMSampleBuffer Natif (Single Source of Truth)
    
    /// Injecte directement le CMSampleBuffer brut venant de ReplayKit dans le layer PiP
    public func enqueueSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isPiPSupported else { return }
        
        // Validation que le sampleBuffer est prêt pour l'affichage
        guard CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Récupération automatique si le layer a échoué
            if self.sampleBufferDisplayLayer.status == .failed {
                print("⚠️ [PiP] AVSampleBufferDisplayLayer failed -> flush & re-init timebase")
                self.sampleBufferDisplayLayer.flush()
                self.setupTimebase()
            }
            
            if self.sampleBufferDisplayLayer.isReadyForMoreMediaData {
                self.sampleBufferDisplayLayer.enqueue(sampleBuffer)
            }
        }
    }
}

// MARK: - Délégué de Lecture SampleBuffer PiP (iOS 15+)

@available(iOS 15.0, *)
private final class SampleBufferPiPPlaybackDelegate: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
    
    weak var manager: ScreenSharePiPManager?
    
    init(manager: ScreenSharePiPManager) {
        self.manager = manager
        super.init()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // Lecture continue
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: CMTime(seconds: 3600 * 24, preferredTimescale: 600))
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // Ajustement automatique
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

// MARK: - Délégué PiP Standard (iOS 14+)

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
        print("[PiP] started = true")
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        manager?.isPiPActive = true
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        manager?.isPiPActive = false
        NotificationCenter.default.post(name: NSNotification.Name("SarahPiPStatusChanged"), object: nil, userInfo: ["isActive": false])
        print("[PiP] stopped = true")
    }
}
