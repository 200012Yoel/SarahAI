import Foundation

/// Priorité des tâches gérées par l'ordonnanceur
public enum AITaskPriority: Int, Comparable {
    case p1_userDirect = 1        // Conversation directe Sarah / Utilisateur
    case p2_userExplicitAction = 2 // Génération de code VAI / Traduction de document
    case p3_secondaryAgent = 3    // Tâche d'agent en arrière-plan
    case p4_maintenanceCache = 4  // Indexation sémantique / caches
    
    public static func < (lhs: AITaskPriority, rhs: AITaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Token d'annulation pour tâches universelles (iOS 12.0+ & iOS 13.0+)
public final class AIScheduledTaskToken {
    public let id: UUID
    private var isCancelledFlag: Bool = false
    private let lock = NSLock()
    
    public init(id: UUID) {
        self.id = id
    }
    
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledFlag
    }
    
    public func cancel() {
        lock.lock()
        isCancelledFlag = true
        lock.unlock()
    }
}

/// Ordonnanceur Progressif Asynchrone Universel (Compatible iOS 12.0+ et iOS 13+)
/// Exécute les tâches lourdes sans geler le MainActor et adapte la cadence à la température/RAM
public final class AIProgressiveScheduler {
    
    public static let shared = AIProgressiveScheduler()
    
    private let resourceManager = AIResourceManager.shared
    private var activeTokens: [UUID: AIScheduledTaskToken] = [:]
    private let queue = DispatchQueue(label: "com.sarahai.progressive.scheduler", qos: .userInitiated)
    private let lock = NSLock()
    
    private init() {}
    
    /// Exécute une tâche de génération longue de façon progressive et cadencée
    @discardableResult
    public func scheduleGeneration(
        priority: AITaskPriority,
        textTokens: [String],
        onProgress: @escaping (String) -> Void,
        onCompletion: @escaping (String) -> Void
    ) -> UUID {
        let taskId = UUID()
        let token = AIScheduledTaskToken(id: taskId)
        
        lock.lock()
        activeTokens[taskId] = token
        lock.unlock()
        
        let streamingBuffer = AIStreamingBuffer()
        streamingBuffer.start(onFlush: onProgress)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var accumulated = ""
            for tokenItem in textTokens {
                // Vérification d'annulation
                if token.isCancelled {
                    break
                }
                
                // Mode ralenti intelligent adaptatif
                let delayMs = self.resourceManager.getAdaptiveBatchDelayMs()
                if delayMs > 0 {
                    usleep(useconds_t(delayMs * 1000))
                }
                
                accumulated += tokenItem
                streamingBuffer.append(token: tokenItem)
            }
            
            streamingBuffer.flush()
            let finalText = streamingBuffer.stopAndGetFinalText()
            let resultText = finalText.isEmpty ? accumulated : finalText
            
            self.lock.lock()
            self.activeTokens.removeValue(forKey: taskId)
            self.lock.unlock()
            
            DispatchQueue.main.async {
                onCompletion(resultText)
            }
        }
        
        return taskId
    }
    
    /// Annule une tâche précise
    public func cancelTask(id: UUID) {
        lock.lock()
        if let token = activeTokens.removeValue(forKey: id) {
            token.cancel()
        }
        lock.unlock()
    }
    
    /// Annule toutes les tâches actives (Changement de conversation, Stop)
    public func cancelAllTasks() {
        lock.lock()
        for (_, token) in activeTokens {
            token.cancel()
        }
        activeTokens.removeAll()
        lock.unlock()
    }
}
