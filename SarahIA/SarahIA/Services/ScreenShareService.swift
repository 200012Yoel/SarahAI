import Foundation
import UIKit
import ReplayKit
import AVFoundation
import CoreImage
#if canImport(Combine)
import Combine
#endif

/// États de connexion de la session de partage d'écran
public enum ScreenShareStatus: String, Codable {
    case disconnected = "Déconnecté"
    case connecting = "Connexion..."
    case connected = "Connecté"
    case active = "En direct"
    
    public var badgeTitle: String {
        switch self {
        case .disconnected: return "● En ligne"
        case .connecting: return "● 🟡 Connexion..."
        case .connected: return "● 🟢 Connecté"
        case .active: return "● 🔴 LIVE — Tom observe"
        }
    }
}

/// Service Unique de Partage d'Écran et Live Streaming Haute Performance (100% ReplayKit Officiel) :
/// - Source Unique de Vérité (Single Source of Truth) : Flux CMSampleBuffer ReplayKit natif
/// - Pipeline direct :
///     ReplayKit CMSampleBuffer vidéo
///       ├─► PiP système direct (ScreenSharePiPManager.enqueueSampleBuffer)
///       └─► Décodage UIImage optimisé (CIContext persistant réutilisé)
///             ├─► Notification d'Aperçu Miroir Flottant en direct (Live Preview UI)
///             └─► Analyse Vision Tom régulée (LocalVisionEngine)
/// - Arrêt complet et suppression instantanée de tout tampon mémoire lors de l'arrêt
public final class ScreenShareService: NSObject {
    
    public static let shared = ScreenShareService()
    
    // Notifications & App Group
    public static let appGroupIdentifier = "group.com.sarahia.shared"
    public static let darwinNotificationName = "group.com.sarahia.broadcast.frame"
    public static let liveFrameNotification = NSNotification.Name("SarahLiveScreenFrameUpdated")
    public static let statusDidChangeNotification = NSNotification.Name("SarahScreenShareStatusDidChange")
    
    private let screenRecorder = RPScreenRecorder.shared()
    public private(set) var isScreenSharingActive: Bool = false
    public private(set) var latestCapturedImage: UIImage?
    
    public private(set) var status: ScreenShareStatus = .disconnected {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.statusDidChangeNotification,
                    object: nil,
                    userInfo: [
                        "status": self.status.rawValue,
                        "isActive": self.isScreenSharingActive
                    ]
                )
            }
        }
    }
    
    // CIContext persistant unique pour éviter les réallocations coûteuses à chaque frame
    private let ciContext = CIContext(options: [
        CIContextOption.useSoftwareRenderer: false,
        CIContextOption.priorityRequestLow: false
    ])
    
    // Files de traitement et de décodage ReplayKit
    private let decodeQueue = DispatchQueue(label: "com.sarahia.screenshare.decode", qos: .userInteractive)
    private let visionThrottleQueue = DispatchQueue(label: "com.sarahia.screenshare.vision", qos: .userInitiated)
    
    private var lastDarwinFrameTimestamp: TimeInterval = 0
    private var lastVisionAnalysisTimestamp: TimeInterval = 0
    private var isVisionProcessing: Bool = false
    private var lastAnalyzedText: String = ""
    private var currentFrameCallback: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    
    private override init() {
        super.init()
        setupDarwinIPCReceiver()
    }
    
    // MARK: - 1. Récepteur IPC Darwin Notification (RPBroadcastSampleHandler App Group)
    
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
        guard isScreenSharingActive || status == .connecting else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastDarwinFrameTimestamp >= 0.05 else { return } // Max ~20 FPS
        lastDarwinFrameTimestamp = now
        
        decodeQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
                return
            }
            let frameURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
            
            guard let data = try? Data(contentsOf: frameURL, options: .alwaysMapped),
                  let image = UIImage(data: data) else {
                return
            }
            
            if !self.isScreenSharingActive {
                self.isScreenSharingActive = true
                self.status = .active
                ScreenSharePiPManager.shared.startPictureInPicture()
            }
            
            print("[ReplayKit] VIDEO FRAME RECEIVED (Broadcast Extension)")
            print("[ReplayKit] frame size = \(Int(image.size.width))x\(Int(image.size.height))")
            print("[ReplayKit] frame timestamp = \(String(format: "%.3f", CACurrentMediaTime()))")
            print("[ScreenShareService] FRAME RECEIVED")
            
            self.broadcastAndProcessDecodedImage(image)
        }
    }
    
    // MARK: - 2. Démarrage de la Capture ReplayKit en Direct
    
    /// Démarre le partage d'écran avec ReplayKit
    public func startLiveScreenSharing(
        from viewController: UIViewController? = nil,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        if isScreenSharingActive {
            completion(true, "🔴 Le partage d'écran ReplayKit est déjà actif.")
            return
        }
        
        print("[ReplayKit] startCapture requested")
        status = .connecting
        currentFrameCallback = onFrameAnalyzed
        lastVisionAnalysisTimestamp = 0
        lastAnalyzedText = ""
        
        // Configuration du Picture-in-Picture persistant si disponible
        let targetVC = viewController
            ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.keyWindow?.rootViewController
            ?? UIApplication.shared.windows.first?.rootViewController
        
        if let hostView = targetVC?.view.window ?? targetVC?.view ?? UIApplication.shared.keyWindow {
            ScreenSharePiPManager.shared.setupPiP(in: hostView)
        }
        
        // Démarrage de la capture ReplayKit in-app (iOS 11+)
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = false
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, error == nil else {
                    if let err = error {
                        print("[ReplayKit] ERROR = \(err.localizedDescription)")
                    }
                    return
                }
                
                if sampleBufferType == .video {
                    self.processIncomingReplayKitSampleBuffer(sampleBuffer)
                }
            }) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    print("[ReplayKit] ERROR = \(error.localizedDescription)")
                    self.isScreenSharingActive = false
                    self.status = .disconnected
                    completion(false, "Échec du démarrage de ReplayKit : \(error.localizedDescription)")
                } else {
                    print("[ReplayKit] capture started")
                    self.isScreenSharingActive = true
                    self.status = .active
                    ScreenSharePiPManager.shared.startPictureInPicture()
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahScreenShareStatusChanged"),
                        object: nil,
                        userInfo: ["isActive": true]
                    )
                    completion(true, "🔴 Partage d'écran en direct activé.")
                }
            }
        } else {
            // Support iOS 12 pur ou mode broadcast distant
            print("[ReplayKit] capture started (iOS 12 fallback)")
            self.isScreenSharingActive = true
            self.status = .active
            completion(true, "🔴 Partage d'écran en direct activé.")
        }
    }
    
    // MARK: - 3. Traitement Direct du CMSampleBuffer ReplayKit (Single Source of Truth)
    
    private func processIncomingReplayKitSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isScreenSharingActive else { return }
        
        guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else { return }
        
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ptsSeconds = CMTimeGetSeconds(pts)
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        print("[ReplayKit] VIDEO FRAME RECEIVED")
        print("[ReplayKit] frame size = \(width)x\(height)")
        print("[ReplayKit] frame timestamp = \(String(format: "%.3f", ptsSeconds > 0 ? ptsSeconds : CACurrentMediaTime()))")
        
        // 1. Injection directe du CMSampleBuffer natif dans le PiP (Sans conversions intermédiaires)
        ScreenSharePiPManager.shared.enqueueSampleBuffer(sampleBuffer)
        
        // 2. Décodage asynchrone de la frame pour l'Aperçu Miroir Flottant et Vision Tom
        decodeQueue.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            if let image = self.imageFromPixelBuffer(imageBuffer) {
                self.broadcastAndProcessDecodedImage(image)
            }
        }
    }
    
    // MARK: - 4. Distribution de l'Image Décodée (Preview + Vision Tom)
    
    private func broadcastAndProcessDecodedImage(_ image: UIImage) {
        self.latestCapturedImage = image
        
        // 1. Publication vers la prévisualisation miroir flottante locale (Live Preview)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            print("[ScreenShareService] PREVIEW UPDATED")
            NotificationCenter.default.post(
                name: Self.liveFrameNotification,
                object: nil,
                userInfo: ["image": image]
            )
        }
        
        // 2. Analyse IA Vision Tom régulée (Throttling à 800ms pour préserver le CPU/RAM de l'iPhone 5s)
        let now = CACurrentMediaTime()
        if now - lastVisionAnalysisTimestamp >= 0.8 && !isVisionProcessing {
            lastVisionAnalysisTimestamp = now
            isVisionProcessing = true
            print("[ScreenShareService] VISION ANALYSIS STARTED")
            
            visionThrottleQueue.async { [weak self] in
                guard let self = self, self.isScreenSharingActive else {
                    self?.isVisionProcessing = false
                    return
                }
                
                guard let processed = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 640, quality: 0.65) else {
                    self.isVisionProcessing = false
                    return
                }
                
                LocalVisionEngine.shared.recognizeObject(in: processed.image) { [weak self] result in
                    guard let self = self, self.isScreenSharingActive else {
                        self?.isVisionProcessing = false
                        return
                    }
                    
                    self.isVisionProcessing = false
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
    }
    
    // MARK: - 5. Arrêt Complet & Nettoyage Définitif (Stop Behavior)
    
    public func stopLiveScreenSharing(completion: ((Bool) -> Void)? = nil) {
        print("[ReplayKit] capture stopped")
        isScreenSharingActive = false
        status = .disconnected
        currentFrameCallback = nil
        latestCapturedImage = nil
        lastAnalyzedText = ""
        isVisionProcessing = false
        
        // 1. Notification de fermeture immédiate pour l'UI
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": false]
        )
        NotificationCenter.default.post(
            name: Self.liveFrameNotification,
            object: nil,
            userInfo: [:]
        )
        
        // 2. Arrêt PiP
        ScreenSharePiPManager.shared.stopPictureInPicture()
        
        // 3. Suppression des fichiers temporaires partagés
        DispatchQueue.global(qos: .utility).async {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
                let frameURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
                try? FileManager.default.removeItem(at: frameURL)
            }
        }
        
        // 4. Arrêt de ReplayKit
        if #available(iOS 11.0, *), screenRecorder.isRecording {
            screenRecorder.stopCapture { error in
                if let err = error {
                    print("[ReplayKit] ERROR = \(err.localizedDescription)")
                }
                completion?(error == nil)
            }
        } else {
            completion?(true)
        }
    }
    
    // MARK: - 6. Conversion Optimisée CVPixelBuffer ➔ UIImage avec CIContext Réutilisé
    
    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - 7. Capture d'Écran Locale de Secours (View Snapshot Fallback)
    
    public func captureScreen(from view: UIView? = nil) -> UIImage? {
        if let latest = latestCapturedImage {
            return latest
        }
        
        let targetView = view ?? UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        guard let validView = targetView else { return nil }
        
        return autoreleasepool { () -> UIImage? in
            let bounds = validView.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return nil }
            
            UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
            validView.drawHierarchy(in: bounds, afterScreenUpdates: false)
            let captured = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return captured
        }
    }
}

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ScreenShareStateTracker: ObservableObject {
    public static let shared = ScreenShareStateTracker()
    
    @Published public var status: ScreenShareStatus = .disconnected
    @Published public var isActive: Bool = false
    @Published public var latestImage: UIImage? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: ScreenShareService.statusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }
                if let rawStatus = notif.userInfo?["status"] as? String,
                   let st = ScreenShareStatus(rawValue: rawStatus) {
                    self.status = st
                }
                if let active = notif.userInfo?["isActive"] as? Bool {
                    self.isActive = active
                    if !active {
                        self.latestImage = nil
                    }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: ScreenShareService.liveFrameNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }
                if let img = notif.userInfo?["image"] as? UIImage {
                    self.latestImage = img
                } else if !self.isActive {
                    self.latestImage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    public func updateStatus(_ newStatus: ScreenShareStatus, active: Bool) {
        DispatchQueue.main.async {
            self.status = newStatus
            self.isActive = active
            if !active {
                self.latestImage = nil
            }
        }
    }
}

@available(iOS 13.0, *)
public typealias ScreenShareStateObserver = ScreenShareStateTracker
#endif


