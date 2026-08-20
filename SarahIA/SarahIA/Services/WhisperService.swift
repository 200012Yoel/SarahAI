import Foundation
import Speech
import AVFoundation

/// Service de Reconnaissance Vocale Local et Gratuit (remplaçant Whisper)
@available(iOS 13.0, *)
public final class WhisperService: ObservableObject {
    
    public static let shared = WhisperService()
    
    @Published public private(set) var isRecording: Bool = false
    
    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    
    private let recognizer = AppleSpeechRecognizer.shared
    
    private init() {
        recognizer.onPartialTranscription = { [weak self] partial in
            self?.onPartialTranscription?(partial)
        }
        recognizer.onFinalTranscription = { [weak self] final in
            self?.onFinalTranscription?(final)
        }
    }
    
    public func startRecording() {
        isRecording = true
        recognizer.startListening()
    }
    
    public func stopRecordingAndTranscribe(completion: ((String?) -> Void)? = nil) {
        isRecording = false
        let current = recognizer.currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
        recognizer.stopListening()
        completion?(current.isEmpty ? nil : current)
    }
    
    public func stopRecordingWithoutTranscription() {
        isRecording = false
        recognizer.stopListening()
    }
    
    public func startTranscription() {
        startRecording()
    }
    
    public func stopTranscription() {
        stopRecordingAndTranscribe()
    }
    
    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    public func reset() {
        stopRecordingWithoutTranscription()
    }
}
