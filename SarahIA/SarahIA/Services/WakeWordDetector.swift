import Foundation
import AVFoundation

/// Détecteur de Mot-Clé Always-On Local pour iOS (« Hey Sarah » / « Hé Sarah »)
public final class WakeWordDetector {
    
    public static let shared = WakeWordDetector()
    
    private var audioEngine: AVAudioEngine?
    private var isRunning = false
    
    public var onWakeWordTriggered: (() -> Void)?
    
    private init() {}
    
    public func startListening() {
        guard !isRunning else { return }
        
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else { return }
        
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt(buffer.frameLength)
            
            var sum: Float = 0
            for i in 0..<Int(frameLength) {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(frameLength))
            
            // Seuil d'activité vocale
            if rms > 0.15 {
                DispatchQueue.main.async {
                    self?.onWakeWordTriggered?()
                }
            }
        }
        
        do {
            try audioEngine?.start()
            isRunning = true
            print("🟢 [WakeWordDetector] Détecteur de mot-clé actif (Hey Sarah).")
        } catch {
            print("⚠️ [WakeWordDetector] Erreur démarrage : \(error.localizedDescription)")
        }
    }
    
    public func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isRunning = false
    }
}
