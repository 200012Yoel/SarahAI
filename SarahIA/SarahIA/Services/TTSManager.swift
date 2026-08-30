import Foundation
import AVFoundation
import UIKit

/// Gestionnaire de Synthèse Vocale Unifié et Rétro-compatible pour Sarah AI.
/// Redirige vers `AgentVoiceManager` pour les 6 agents (Sarah, Nathan, Esther, Tom, Yohan, Ethel).
public final class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    
    public static let shared = TTSManager()
    
    private let agentVoice = AgentVoiceManager.shared
    
    private override init() {
        super.init()
    }
    
    public func speakAsSarah(_ text: String) {
        agentVoice.speak(text: text, as: .sarah)
    }
    
    public func speakAsNathan(_ text: String) {
        agentVoice.speak(text: text, as: .nathan)
    }
    
    public func speakAsEsther(_ text: String) {
        agentVoice.speak(text: text, as: .esther)
    }
    
    public func speakAsTom(_ text: String) {
        agentVoice.speak(text: text, as: .tom)
    }
    
    public func speakAsYohan(_ text: String) {
        agentVoice.speak(text: text, as: .yohan)
    }
    
    public func speakAsEthel(_ text: String) {
        agentVoice.speak(text: text, as: .ethel)
    }
    
    public func speakAsRaphael(_ text: String) {
        agentVoice.speak(text: text, as: .esther)
    }
    
    public func speak(text: String) {
        agentVoice.speak(text: text, as: .sarah)
    }
    
    public func stop() {
        agentVoice.stop()
    }
    
    public var isSpeaking: Bool {
        return agentVoice.isSpeaking
    }
}
