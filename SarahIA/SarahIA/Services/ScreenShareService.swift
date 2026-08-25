import Foundation
import UIKit
import ReplayKit
import AVFoundation
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
/// - Aucune capture d'écran simulée ni sondage de framebuffer privé
/// - Double diffusion synchrone :
///     1. Aperçu Miroir Flottant en direct (Live Preview UI)
///     2. Analyse Vision Tom & Sarah (Intelligemment régulée pour économiser le processeur/batterie)
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
    
    // MARK: - Récepteur IPC Darwin Notification (Diffusion Système RPBroadcastSampleHandler)
    
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
        guard now - lastDarwinFrameTimestamp >= 0.05 else { return } // Max ~20 FPS pour l'aperçu
        lastDarwinFrameTimestamp = now
        
        if !isScreenSharingActive {
            isScreenSharingActive = true
            status = .active
            ScreenSharePiPManager.shared.startPictureInPicture()
        }
        
        decodeQueue.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
                return
            }
            let frameURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
            
            guard let data = try? Data(contentsOf: frameURL, options: .alwaysMapped),
                  let image = UIImage(data: data) else {
                return
            }
            
            self.broadcastAndProcessFrame(image)
        }
    }
    
    // MARK: - Lancement du Partage d'Écran ReplayKit en Direct
    
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
        
        isScreenSharingActive = true
        status = .connecting
        currentFrameCallback = onFrameAnalyzed
        lastVisionAnalysisTimestamp = 0
        lastAnalyzedText = ""
        
        // 1. Notification de statut immédiate
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": true]
        )
        
        // 2. Configuration du Picture-in-Picture persistant
        let targetVC = viewController
            ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.keyWindow?.rootViewController
            ?? UIApplication.shared.windows.first?.rootViewController
        
        if let hostView = targetVC?.view.window ?? targetVC?.view ?? UIApplication.shared.keyWindow {
            ScreenSharePiPManager.shared.setupPiP(in: hostView)
            ScreenSharePiPManager.shared.startPictureInPicture()
        }
        
        // 3. Démarrage de la capture ReplayKit in-app
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = false
            screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, sampleBufferType, error) in
                guard let self = self, self.isScreenSharingActive, error == nil else { return }
                
                if sampleBufferType == .video {
                    ScreenSharePiPManager.shared.enqueueSampleBuffer(sampleBuffer)
                    self.decodeQueue.async {
                        if let image = self.imageFromSampleBuffer(sampleBuffer) {
                            self.broadcastAndProcessFrame(image)
                        }
                    }
                }
            }) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ [ScreenShareService] ReplayKit startCapture: \(error.localizedDescription)")
                    self.status = .active // Reste en attente des trames Broadcast Extension
                } else {
                    self.status = .active
                }
                completion(true, "🔴 Partage d'écran en direct activé.")
            }
        } else {
            // Sur les versions sans startCapture ou en mode broadcast pur
            self.status = .active
            completion(true, "🔴 Partage d'écran en direct activé.")
        }
    }
    
    // MARK: - Pipeline de Diffusion & Analyse Visuelle Unique (Single Source of Truth)
    
    /// Traite et diffuse la trame réelle issue de ReplayKit
    public func broadcastAndProcessFrame(_ image: UIImage) {
        guard isScreenSharingActive else { return }
        
        self.latestCapturedImage = image
        if status != .active {
            status = .active
        }
        
        // 1. Mise à jour Picture-in-Picture
        ScreenSharePiPManager.shared.enqueueImage(image)
        
        // 2. Publication en direct vers la fenêtre d'aperçu miroir flottante (Live Preview)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            NotificationCenter.default.post(
                name: Self.liveFrameNotification,
                object: nil,
                userInfo: ["image": image]
            )
        }
        
        // 3. Régulation Intelligente de l'Analyse IA Vision Tom & Sarah (Throttling pour préserver l'iPhone 5s)
        let now = CACurrentMediaTime()
        // Analyse déclenchée au maximum toutes les 800ms pour éviter de saturer le CPU/OCR
        if now - lastVisionAnalysisTimestamp >= 0.8 && !isVisionProcessing {
            lastVisionAnalysisTimestamp = now
            isVisionProcessing = true
            
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
    
    // MARK: - Arrêt Complet & Nettoyage Définitif (Stop Behavior)
    
    public func stopLiveScreenSharing(completion: ((Bool) -> Void)? = nil) {
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
                completion?(error == nil)
            }
        } else {
            completion?(true)
        }
    }
    
    // MARK: - Capture d'Écran Locale de Secours (View Snapshot Fallback)
    
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
    
    // MARK: - Conversion Optimisée CMSampleBuffer ➔ UIImage
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
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

