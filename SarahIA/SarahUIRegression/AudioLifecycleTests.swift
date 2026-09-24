import XCTest
import AVFoundation
@testable import SarahIA

@MainActor
final class AudioLifecycleTests: XCTestCase {
    func testDictationFinalStaysInDraft() {
        let model = ChatViewModel()
        let count = model.messages.count
        model.isDictating = true
        model.receiveFinalTranscription("Bonjour ça va")
        XCTAssertEqual(model.inputText, "Bonjour ça va")
        XCTAssertEqual(model.messages.count, count)
        XCTAssertFalse(model.isDictating)
        XCTAssertFalse(model.isContinuousConversationActive)
    }

    func testLateFinalAfterStopCannotSend() {
        let model = ChatViewModel()
        model.inputText = "Brouillon conservé"
        let count = model.messages.count
        model.stopVoiceConversation()
        model.receiveFinalTranscription("Ancienne reconnaissance")
        XCTAssertEqual(model.inputText, "Brouillon conservé")
        XCTAssertEqual(model.messages.count, count)
        XCTAssertFalse(model.isMicRunning)
        XCTAssertFalse(model.isSpeaking)
    }

    func testVocalMuteDoesNotStartDictation() {
        let model = ChatViewModel()
        model.isContinuousConversationActive = true
        model.toggleVoiceMicrophone()
        XCTAssertTrue(model.isContinuousConversationActive)
        XCTAssertTrue(model.isVoiceMicrophoneMuted)
        XCTAssertFalse(model.isDictating)
        model.stopVoiceConversation()
    }

    func testStaleSpeechCancellationCannotFinishNewSession() {
        let manager = AgentVoiceManager.shared
        manager.stop()
        var finished = false
        manager.onSpeechFinished = { finished = true }
        XCTAssertTrue(AudioSessionManager.shared.configurePlaybackSession())
        manager.speechSynthesizer(AVSpeechSynthesizer(), didCancel: AVSpeechUtterance(string: "Ancienne voix"))
        XCTAssertFalse(finished)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        manager.onSpeechFinished = nil
        manager.stop()
    }
}
