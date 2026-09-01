import Foundation
import AVFoundation
import UIKit

// ============================================================================
// REALTIME AUDIO WAVEFORM EXTRACTOR — VISUALISEUR VOCAL 60 FPS
// ============================================================================
// Analyse le flux audio en temps réel sans bloquer l'inférence ou le thread UI.
// Utilise un Tap non-bloquant sur AVAudioEngine (bus 0) avec adaptation dynamique
// au format matériel (écouteurs Bluetooth, micros 16kHz / 48kHz) et rafraîchissement
// 60 FPS via CADisplayLink.
// ============================================================================

public final class RealtimeAudioWaveformExtractor: NSObject {
    
    public static let shared = RealtimeAudioWaveformExtractor()
    
    public var onAmplitudeChanged: ((Float) -> Void)?
    
    private var displayLink: CADisplayLink?
    private var currentRMS: Float = 0.0
    private let processingQueue = DispatchQueue(label: "com.sarahia.waveform.queue", qos: .userInteractive)
    
    private override init() {
        super.init()
    }
    
    /// Démarre l'écoute et l'extraction du signal audio
    public func startMonitoring(audioEngine: AVAudioEngine) {
        stopMonitoring(audioEngine: audioEngine)
        
        let inputNode = audioEngine.inputNode
        // Format dynamique selon le matériel actif (micro iPhone, AirPods, etc.)
        let format = inputNode.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 else {
            print("⚠️ [WaveformExtractor] Format audio invalide ou indisponible.")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, _) in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            
            var sum: Float = 0.0
            for i in 0..<frames {
                sum += channelData[i] * channelData[i]
            }
            
            let rms = sqrt(sum / Float(frames))
            // Amplification et lissage sécurisé (valeur entre 0.0 et 1.0)
            let normalized = min(max(rms * 4.5, 0.0), 1.0)
            
            self?.processingQueue.async {
                self?.currentRMS = normalized
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.renderFrame))
            self.displayLink?.add(to: .main, forMode: .common)
        }
    }
    
    @objc private func renderFrame() {
        onAmplitudeChanged?(currentRMS)
    }
    
    /// Arrête proprement le tap et le CADisplayLink
    public func stopMonitoring(audioEngine: AVAudioEngine) {
        displayLink?.invalidate()
        displayLink = nil
        currentRMS = 0.0
        
        audioEngine.inputNode.removeTap(onBus: 0)
        DispatchQueue.main.async { [weak self] in
            self?.onAmplitudeChanged?(0.0)
        }
    }
}
