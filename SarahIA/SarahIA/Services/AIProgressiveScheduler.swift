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

/// Ordonnanceur Progressif Asynchrone (Non-Bloquant avec Swift Concurrency)
/// Exécute les tâches lourdes sans geler le MainActor et adapte la cadence à la température/RAM
public final class AIProgressiveScheduler {
    
    public static let shared = AIProgressiveScheduler()
    
    private let resourceManager = AIResourceManager.shared
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
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
        let streamingBuffer = AIStreamingBuffer()
        streamingBuffer.start(onFlush: onProgress)
        
        let task = Task.detached(priority: taskPriorityToTaskPriority(priority)) { [weak self] in
            guard let self = self else { return }
            
            var accumulated = ""
            for token in textTokens {
                // Vérification d'annulation
                if Task.isCancelled {
                    break
                }
                
                // Mode ralenti intelligent adaptatif
                let delayMs = self.resourceManager.getAdaptiveBatchDelayMs()
                if delayMs > 0 {
                    try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                }
                
                // Céder la main au système (Cooperative Multitasking)
                await Task.yield()
                
                accumulated += token
                streamingBuffer.append(token: token)
            }
            
            streamingBuffer.flush()
            let finalText = streamingBuffer.stopAndGetFinalText()
            
            self.lock.lock()
            self.activeTasks.removeValue(forKey: taskId)
            self.lock.unlock()
            
            await MainActor.run {
                onCompletion(finalText.isEmpty ? accumulated : finalText)
            }
        }
        
        lock.lock()
        activeTasks[taskId] = task
        lock.unlock()
        
        return taskId
    }
    
    /// Annule une tâche précise
    public func cancelTask(id: UUID) {
        lock.lock()
        if let task = activeTasks.removeValue(forKey: id) {
            task.cancel()
        }
        lock.unlock()
    }
    
    /// Annule toutes les tâches actives (Changement de conversation, Stop)
    public func cancelAllTasks() {
        lock.lock()
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        lock.unlock()
    }
    
    private func taskPriorityToTaskPriority(_ p: AITaskPriority) -> TaskPriority {
        switch p {
        case .p1_userDirect: return .userInitiated
        case .p2_userExplicitAction: return .medium
        case .p3_secondaryAgent: return .utility
        case .p4_maintenanceCache: return .background
        }
    }
}
