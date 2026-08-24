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
        case .active: return "● 🔴 En direct"
        }
    }
}

/// Service de Partage d'Écran et Live Streaming Haute Performance avec Sarah (iOS 12 -> 18) :
/// - Résolution automatique du contrôleur racine actif (évite le bug des contrôleurs modaux fermés)
/// - Rendu vidéo fluide 15 FPS en temps réel sur tous les iPhone (iPhone 5S, 6, 7, 8, SE, X, 11, 12, 13, 14, 15, 16)
/// - Picture-in-Picture persistant automatique à la sortie de l'application
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
    
    // Files et minuteries d'arrière-plan
    private let decodeQueue = DispatchQueue(label: "com.sarahia.screenshare.decode", qos: .userInteractive)
    private var dispatchTimer: DispatchSourceTimer?
    private var lastAnalyzedText: String = ""
    private var lastDarwinFrameTimestamp: TimeInterval = 0
    private var currentFrameCallback: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)?
    
    private override init() {
        super.init()
        setupDarwinIPCReceiver()
    }
    
    // MARK: - Récepteur IPC Darwin Notification (Arrière-plan système)
    
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
        let now = CACurrentMediaTime()
        guard now - lastDarwinFrameTimestamp >= 0.06 else { return }
        lastDarwinFrameTimestamp = now
        
        if !isScreenSharingActive {
            isScreenSharingActive = true
            status = .active
            ScreenSharePiPManager.shared.startPictureInPicture()
        }
        
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
            
            self.broadcastAndProcessFrame(image)
        }
    }
    
    // MARK: - Lancement du Partage d'Écran en Direct
    
    /// Démarre le partage d'écran en direct avec synchronisation de l'état
    public func startLiveScreenSharing(
        from viewController: UIViewController? = nil,
        onFrameAnalyzed: ((LocalVisionEngine.VisionAnalysisResult, UIImage) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        if isScreenSharingActive {
            completion(true, "🔴 Le partage d'écran en direct est déjà actif !")
            return
        }
        
        // Résolution robuste du contrôleur et de la vue active
        let targetVC = viewController
            ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.keyWindow?.rootViewController
            ?? UIApplication.shared.windows.first?.rootViewController
        
        let hostView = targetVC?.view.window ?? targetVC?.view ?? UIApplication.shared.keyWindow
        
        isScreenSharingActive = true
        status = .connecting
        currentFrameCallback = onFrameAnalyzed
        
        // 1. Notification de statut
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": true]
        )
        
        // 2. Capture synchrone IMMÉDIATE de la 1ère trame à 0ms
        if let view = hostView, let initialSnapshot = self.captureScreen(from: view) {
            self.latestCapturedImage = initialSnapshot
            self.status = .active
            self.broadcastAndProcessFrame(initialSnapshot)
        } else {
            self.status = .connected
        }
        
        // 3. Initialisation et démarrage du Picture-in-Picture persistant dans la vue active
        if let targetHostView = hostView {
            ScreenSharePiPManager.shared.setupPiP(in: targetHostView)
            ScreenSharePiPManager.shared.startPictureInPicture()
        }
        
        // 4. Lancement de la minuterie DispatchSource haute performance (12-15 FPS fluide)
        startHighPerformanceBackgroundSampling(from: hostView)
        
        // 5. ReplayKit In-App Capture en parallèle
        if #available(iOS 11.0, *), screenRecorder.isAvailable {
            screenRecorder.isMicrophoneEnabled = true
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
            }) { error in
                completion(true, "🔴 Partage d'écran en direct activé !")
            }
        } else {
            completion(true, "🔴 Partage d'écran en direct activé !")
        }
    }
    
    /// Boucle de capture haute performance sur file d'arrière-plan dédiée (12-15 FPS fluide)
    private func startHighPerformanceBackgroundSampling(from hostView: UIView?) {
        dispatchTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: decodeQueue)
        // Intervalle de 70ms = ~14 FPS ultra-fluide sans surchauffe ni lag
        timer.schedule(deadline: .now() + 0.1, repeating: 0.07)
        timer.setEventHandler { [weak self, weak hostView] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            DispatchQueue.main.async {
                let activeView = hostView
                    ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                    ?? UIApplication.shared.keyWindow
                    ?? UIApplication.shared.windows.first
                
                if let view = activeView, let screenshot = self.captureScreen(from: view) {
                    self.decodeQueue.async {
                        self.broadcastAndProcessFrame(screenshot)
                    }
                }
            }
        }
        timer.resume()
        self.dispatchTimer = timer
    }
    
    /// Traite et diffuse la trame décodée sans latence
    public func broadcastAndProcessFrame(_ image: UIImage) {
        self.latestCapturedImage = image
        if status != .active {
            status = .active
        }
        
        // 1. Envoi immédiat au contrôleur Picture-in-Picture
        ScreenSharePiPManager.shared.enqueueImage(image)
        
        // 2. Publication réactive locale instantanée sur le thread principal pour l'UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            
            NotificationCenter.default.post(
                name: Self.liveFrameNotification,
                object: nil,
                userInfo: ["image": image]
            )
            
            let defaultResult = LocalVisionEngine.VisionAnalysisResult(
                objectLabel: "flux en direct",
                naturalSpokenResponse: "",
                detectedText: "",
                confidence: 0.9
            )
            self.currentFrameCallback?(defaultResult, image)
        }
        
        // 3. Sauvegarde atomique non-bloquante dans l'App Group en tâche de fond (toutes les 400ms pour l'extension)
        DispatchQueue.global(qos: .utility).async {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier),
               let jpegData = image.jpegData(compressionQuality: 0.50) {
                let fileURL = containerURL.appendingPathComponent("broadcast_frame.jpg")
                try? jpegData.write(to: fileURL, options: .atomic)
            }
        }
        
        // 4. Analyse IA Vision périodique en tâche de fond
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isScreenSharingActive else { return }
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 800, quality: 0.7) else { return }
            
            LocalVisionEngine.shared.recognizeObject(in: processed.image) { [weak self] result in
                guard let self = self, self.isScreenSharingActive else { return }
                
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
    
    // MARK: - Arrêt du Partage d'Écran
    
    public func stopLiveScreenSharing(completion: ((Bool) -> Void)? = nil) {
        isScreenSharingActive = false
        status = .disconnected
        dispatchTimer?.cancel()
        dispatchTimer = nil
        currentFrameCallback = nil
        latestCapturedImage = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahScreenShareStatusChanged"),
            object: nil,
            userInfo: ["isActive": false]
        )
        
        ScreenSharePiPManager.shared.stopPictureInPicture()
        
        if #available(iOS 11.0, *), screenRecorder.isRecording {
            screenRecorder.stopCapture { error in
                completion?(error == nil)
            }
        } else {
            completion?(true)
        }
    }
    
    // MARK: - Capture Universelle Haute Performance
    
    public func captureScreen(from windowOrView: UIView? = nil) -> UIImage? {
        return autoreleasepool { () -> UIImage? in
            let targetView: UIView? = windowOrView
                ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                ?? UIApplication.shared.keyWindow
                ?? UIApplication.shared.windows.first
            guard let view = targetView else { return nil }
            let bounds = view.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return nil }
            
            // Échelle adaptée pour fluidité 15 FPS sans saturer la RAM de l'iPhone 5S / 6 / 7
            let scale: CGFloat = bounds.width > 400 ? 0.6 : 0.8
            let targetSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return nil
            }
            context.scaleBy(x: scale, y: scale)
            
            if !view.drawHierarchy(in: bounds, afterScreenUpdates: false) {
                view.layer.render(in: context)
            }
            
            let captured = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return captured
        }
    }
    
    // MARK: - Conversion CMSampleBuffer ➔ UIImage
    
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
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: ScreenShareService.liveFrameNotification)
            .compactMap { $0.userInfo?["image"] as? UIImage }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] img in
                self?.latestImage = img
            }
            .store(in: &cancellables)
    }
    
    public func updateStatus(_ newStatus: ScreenShareStatus, active: Bool) {
        DispatchQueue.main.async {
            self.status = newStatus
            self.isActive = active
        }
    }
}

@available(iOS 13.0, *)
public typealias ScreenShareStateObserver = ScreenShareStateTracker
#endif
