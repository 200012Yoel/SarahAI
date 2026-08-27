import Foundation

/// Tampon d'agrégation temporel pour le streaming fluide sans surcharger le pipeline de rendu SwiftUI
public final class AIStreamingBuffer {
    
    private var accumulatedText: String = ""
    private var onFlush: ((String) -> Void)?
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval
    private let lock = NSLock()
    
    public init(flushInterval: TimeInterval = 0.035) { // ~30 FPS à 60 FPS optimal
        self.flushInterval = flushInterval
    }
    
    public func start(onFlush: @escaping (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.accumulatedText = ""
        self.onFlush = onFlush
    }
    
    public func append(token: String) {
        lock.lock()
        defer { lock.unlock() }
        accumulatedText += token
        
        if flushTimer == nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                if self.flushTimer == nil {
                    self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.flushInterval, repeats: false) { [weak self] _ in
                        self?.flush()
                    }
                }
                self.lock.unlock()
            }
        }
    }
    
    public func flush() {
        lock.lock()
        let current = accumulatedText
        flushTimer?.invalidate()
        flushTimer = nil
        let callback = onFlush
        lock.unlock()
        
        DispatchQueue.main.async {
            callback?(current)
        }
    }
    
    public func stopAndGetFinalText() -> String {
        lock.lock()
        flushTimer?.invalidate()
        flushTimer = nil
        let final = accumulatedText
        lock.unlock()
        return final
    }
}
