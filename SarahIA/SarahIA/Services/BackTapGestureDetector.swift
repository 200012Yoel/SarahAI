import Foundation
import CoreMotion

/// Détecteur de Geste Back-Tap pour iOS (Double-tap au dos) via CoreMotion
public final class BackTapGestureDetector {
    
    public static let shared = BackTapGestureDetector()
    
    private let motionManager = CMMotionManager()
    private var lastZ: Double = 0.0
    private var lastTapTime: TimeInterval = 0.0
    private var tapCount = 0
    
    public var onBackTapTriggered: (() -> Void)?
    
    private init() {}
    
    public func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.02 // 50 Hz
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            
            let z = data.acceleration.z
            let deltaZ = abs(z - self.lastZ)
            self.lastZ = z
            
            let now = Date().timeIntervalSince1970
            if deltaZ > 1.8 { // Impulsion nette sur l'axe Z
                let interval = now - self.lastTapTime
                if interval >= 0.12 && interval <= 0.55 {
                    self.tapCount += 1
                    if self.tapCount >= 2 {
                        self.tapCount = 0
                        self.lastTapTime = 0
                        self.onBackTapTriggered?()
                    }
                } else if interval > 0.55 {
                    self.tapCount = 1
                    self.lastTapTime = now
                }
            }
        }
        print("🟢 [BackTapGestureDetector] Détection de double-tap physique activée.")
    }
    
    public func stop() {
        motionManager.stopAccelerometerUpdates()
    }
}
