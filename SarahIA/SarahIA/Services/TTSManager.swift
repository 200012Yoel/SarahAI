import Foundation
import AVFoundation
import UIKit

/// Gestionnaire de Synthèse Vocale Unifié et Rétro-compatible pour Sarah AI.
/// Redirige vers `MultiAgentVoiceManager` pour les 4 agents (Sarah, Tom, Raphaël, Yohan).
public final class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    
    public static let shared = TTSManager()
    
    private let multiVoice = MultiAgentVoiceManager.shared
    
    private override init() {
        super.init()
    }
    
    public func speakAsSarah(_ text: String) {
        multiVoice.speak(text: text, for: .sarah)
    }
    
    public func speakAsTom(_ text: String) {
        multiVoice.speak(text: text, for: .tom)
    }
    
    public func speakAsRaphael(_ text: String) {
        multiVoice.speak(text: text, for: .raphael)
    }
    
    public func speakAsYohan(_ text: String) {
        multiVoice.speak(text: text, for: .yohan)
    }
    
    public func speak(text: String) {
        multiVoice.speak(text: text, for: .sarah)
    }
    
    public func stop() {
        multiVoice.stop()
    }
    
    public var isSpeaking: Bool {
        return multiVoice.isSpeaking
    }
}
