import Foundation
import UIKit

/// Niveau d'état et de pression système
public enum SystemPressureLevel: Int, Comparable {
    case normal = 0
    case slowdown = 1
    case deepSlowdown = 2
    case critical = 3
    case emergency = 4
    
    public static func < (lhs: SystemPressureLevel, rhs: SystemPressureLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Gestionnaire Central des Ressources & Pression Système (RAM, Thermique, Cycle de Vie)
public final class AIResourceManager {
    
    public static let shared = AIResourceManager()
    
    public private(set) var currentPressure: SystemPressureLevel = .normal
    public private(set) var activeProfile: ModelProfile?
    
    private let capabilityDetector = DeviceCapabilityDetector.shared
    private let modelManager = EmbeddedModelManager.shared
    
    private var memoryWarningObserver: NSObjectProtocol?
    private var thermalStateObserver: NSObjectProtocol?
    
    private init() {
        setupObservers()
        bootstrapEngine()
    }
    
    deinit {
        if let obs = memoryWarningObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = thermalStateObserver { NotificationCenter.default.removeObserver(obs) }
    }
    
    public func bootstrapEngine() {
        let capability = capabilityDetector.detectProfile()
        self.activeProfile = modelManager.prepareAndActivateModel(for: capability)
    }
    
    private func setupObservers() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateThermalState()
        }
    }
    
    // MARK: - Évaluation Dynamique de la Pression
    
    public func evaluateCurrentSystemPressure() -> SystemPressureLevel {
        let thermal = ProcessInfo.processInfo.thermalState
        let availableMem = getAvailableMemory()
        
        if thermal == .critical {
            currentPressure = .critical
            return .critical
        } else if thermal == .serious || availableMem < (120 * 1024 * 1024) {
            currentPressure = .deepSlowdown
            return .deepSlowdown
        } else if thermal == .fair || availableMem < (250 * 1024 * 1024) {
            currentPressure = .slowdown
            return .slowdown
        } else {
            currentPressure = .normal
            return .normal
        }
    }
    
    private func handleMemoryWarning() {
        currentPressure = .critical
        // Purge des caches transitoires
        URLCache.shared.removeAllCachedResponses()
        
        // Revenir en mode normal progressif après 5 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.currentPressure = .slowdown
        }
    }
    
    private func evaluateThermalState() {
        _ = evaluateCurrentSystemPressure()
    }
    
    private func getAvailableMemory() -> UInt64 {
        if #available(iOS 13.0, *) {
            let avail = os_proc_available_memory()
            if avail > 0 { return UInt64(avail) }
        }
        return ProcessInfo.processInfo.physicalMemory / 3
    }
    
    /// Fournit le délai d'espacement dynamique entre les micro-lots selon la pression
    public func getAdaptiveBatchDelayMs() -> UInt64 {
        let baseDelay = activeProfile?.defaultBatchIntervalMs ?? 10
        switch evaluateCurrentSystemPressure() {
        case .normal:
            return baseDelay
        case .slowdown:
            return baseDelay + 15
        case .deepSlowdown:
            return baseDelay + 40
        case .critical, .emergency:
            return baseDelay + 90
        }
    }
    
    /// Contexte maximum autorisé dans les conditions actuelles
    public func getEffectiveMaxContextLength() -> Int {
        let baseLength = activeProfile?.maxContextLength ?? 1024
        switch evaluateCurrentSystemPressure() {
        case .normal:
            return baseLength
        case .slowdown:
            return Int(Double(baseLength) * 0.75)
        case .deepSlowdown:
            return Int(Double(baseLength) * 0.50)
        case .critical, .emergency:
            return Int(Double(baseLength) * 0.25)
        }
    }
}
