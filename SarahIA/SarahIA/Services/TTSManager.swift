import Foundation

/// Multi-agent compatibility API, all speech through local neural TTS.
public final class TTSManager: NSObject {
    public static let shared = TTSManager()
    private let agentVoice = AgentVoiceManager.shared
    private override init() { super.init() }

    public func speakAsSarah(_ text: String) { agentVoice.speak(text: text, for: .sarah) }
    public func speakAsNathan(_ text: String) { agentVoice.speak(text: text, for: .nathan) }
    public func speakAsEsther(_ text: String) { agentVoice.speak(text: text, for: .esther) }
    public func speakAsRaphael(_ text: String) { agentVoice.speak(text: text, for: .esther) }
    public func speakAsTom(_ text: String) { agentVoice.speak(text: text, for: .tom) }
    public func speakAsYohan(_ text: String) { agentVoice.speak(text: text, for: .yohan) }
    public func speakAsEthel(_ text: String) { agentVoice.speak(text: text, for: .ethel) }
    public func speak(text: String) { agentVoice.speak(text: text, for: .sarah) }
    public func stop() { agentVoice.stop() }
    public var isSpeaking: Bool { agentVoice.isSpeaking }
}
