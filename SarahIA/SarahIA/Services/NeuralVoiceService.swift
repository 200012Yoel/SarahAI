import Foundation
import AVFoundation
import SherpaOnnx

/// Offline Supertonic 3 TTS. Uses no Apple speech synthesis API.
/// The iOS audio session and AVAudioPlayer only play PCM generated on device.
/// Weights: OpenRAIL-M; runtime: Apache-2.0. See docs/VOICE_LICENSES.md.
@available(iOS 15.0, *)
public final class NeuralVoiceService: NSObject, AVAudioPlayerDelegate {
    public static let shared = NeuralVoiceService()

    public struct Profile {
        public let speakerID: Int
        public let label: String

        public static func forAgent(_ agent: AgentType) -> Profile {
            switch agent {
            case .sarah: return Profile(speakerID: 0, label: "F1")
            case .ethel: return Profile(speakerID: 1, label: "F2")
            case .esther: return Profile(speakerID: 5, label: "M1")
            case .tom: return Profile(speakerID: 6, label: "M2")
            case .yohan: return Profile(speakerID: 7, label: "M3")
            case .nathan: return Profile(speakerID: 8, label: "M4")
            }
        }
    }

    public var onStarted: (() -> Void)?
    public var onFinished: (() -> Void)?
    /// Dedicated callback for the isolated Yoann Translate Live session.
    /// Does not replace the agent manager's ordinary playback callbacks.
    public var onPlaybackFinished: (() -> Void)?
    /// Independent from AgentVoiceManager's onStarted callback.
    /// Fired only after AVAudioPlayer.play() really succeeds.
    public var onPlaybackStarted: (() -> Void)?
    public var onGenerationStarted: (() -> Void)?
    public var onFailure: ((String) -> Void)?
    public var onPlaybackError: ((String) -> Void)?

    private let synthesisQueue = DispatchQueue(label: "sarah.local-neural-tts", qos: .userInitiated)
    private var model: SherpaOnnxOfflineTtsWrapper? // accessed on synthesisQueue only
    private var player: AVAudioPlayer?
    // Prevent Yoann's interpreted speech from invoking Sarah's chat
    // onFinished/onStarted handlers and accidentally restarting her mic.
    private var isInterpreterPlayback = false
    private var generation = UUID() // accessed on main queue only
    public private(set) var isSpeaking = false

    private override init() {
        super.init()
    }

    /// Warm up the bundled offline TTS once *after* the microphone starts.
    /// The same serial synthesis queue is used by actual speech, so model
    /// initialization cannot race with the first generated reply.
    public func prepareForVoiceConversation() {
        synthesisQueue.async { [weak self] in
            guard let self else { return }
            do {
                _ = try self.loadModel()
            } catch {
                print("⚠️ [Sarah voice preload] \(error.localizedDescription)")
            }
        }
    }

    public func stop() {
        // Invalidate the result of any synthesis that is still in flight.
        generation = UUID()
        player?.stop()
        player = nil
        isSpeaking = false
        isInterpreterPlayback = false
        NotificationCenter.default.post(name: NSNotification.Name("SarahNeuralSpeechStateChanged"), object: nil)
        AudioSessionManager.shared.deactivateSession()
    }

    public func speak(
        text: String, for agent: AgentType, language: String = "fr",
        speed: Float = 1.0, qualitySteps: Int = 8,
        dedicatedInterpreter: Bool = false
    ) {
        assert(Thread.isMainThread)
        stop()
        isInterpreterPlayback = dedicatedInterpreter
        let token = generation
        let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            // Every accepted request must finish, including empty snippets.
            // Without this the interpreter keeps isSpeakingTranslation = true.
            finishPlayback()
            return
        }

        // Supertonic 3 does not include a Hebrew voice. Previously ONE
        // Hebrew word inside a predominantly French reply silenced the
        // entire answer. Preserve audible French/Latin text, while refusing
        // to mispronounce a Hebrew-only request as French speech.
        let containsHebrew = sanitized.unicodeScalars.contains {
            (0x0590...0x05FF).contains($0.value)
        }
        if language == "he" {
            reportSpeechFailure("La synthèse vocale hébraïque n'est pas installée.")
            finishPlayback()
            return
        }
        let preparedText = containsHebrew
            ? sanitized.unicodeScalars.map { scalar -> String in
                (0x0590...0x05FF).contains(scalar.value) ? " " : String(scalar)
              }.joined().split(whereSeparator: \.isWhitespace).joined(separator: " ")
            : sanitized
        guard preparedText.rangeOfCharacter(from: .letters) != nil else {
            reportSpeechFailure("Cette réponse ne contient pas de texte prononçable par la voix installée.")
            finishPlayback()
            return
        }

        // Supertonic 3 can voice these 31 languages directly. Never force
        // unsupported scripts into a French voice (false language claims).
        guard TranslateLiveLanguages.spokenOutputCodes.contains(language) else {
            let message = "Pas de voix Supertonic 3 disponible pour la langue \(language)."
            reportSpeechFailure(message)
            finishPlayback()
            return
        }
        let selectedLanguage = language
        let sid = Profile.forAgent(agent).speakerID
        if dedicatedInterpreter { onGenerationStarted?() }
        synthesisQueue.async { [weak self] in
            guard let self else { return }
            do {
                let engine = try self.loadModel()
                var options = SherpaOnnxGenerationConfigSwift()
                options.sid = sid
                // 5 diffusion steps for low-latency Translate Live, 8 for
                // regular agent quality. Supertonic supports this tradeoff.
                options.numSteps = max(5, min(qualitySteps, 10))
                // Keep the voice-speed setting functional with the new engine.
                let storedRate = StorageService.shared.loadState().voiceSettings.speechRate
                let configuredSpeed = (speed == 1.0) ? storedRate * 2.0 : speed
                options.speed = max(0.75, min(configuredSpeed, 1.4))
                options.extra = ["lang": selectedLanguage]
                let result = engine.generateWithConfig(
                    text: preparedText,
                    config: options,
                    callback: nil,
                    arg: nil
                )
                guard result.audio != nil, result.n > 0, result.sampleRate > 0 else {
                    throw NSError(domain: "SarahNeuralTTS", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Le moteur vocal n'a produit aucun son."])
                }
                // Generating zero-amplitude PCM is not successful speech.
                // Surface a real error rather than falsely claiming to speak.
                guard result.samples.contains(where: { abs($0) > 0.0001 }) else {
                    throw NSError(domain: "SarahNeuralTTS", code: 5,
                                  userInfo: [NSLocalizedDescriptionKey: "Le modèle vocal a généré du silence."])
                }
                let wav = Self.waveData(samples: result.samples, sampleRate: Int(result.sampleRate))
                DispatchQueue.main.async {
                    guard self.generation == token else { return }
                    do {
                        AudioSessionManager.shared.configurePlaybackSession()
                        let playback = try AVAudioPlayer(data: wav)
                        playback.delegate = self
                        playback.volume = 1.0
                        playback.prepareToPlay()
                        guard playback.play() else {
                            throw NSError(domain: "SarahNeuralTTS", code: 3,
                                          userInfo: [NSLocalizedDescriptionKey: "Lecture audio impossible."])
                        }
                        self.player = playback
                        self.isSpeaking = true
                        NotificationCenter.default.post(name: NSNotification.Name("SarahNeuralSpeechStateChanged"), object: nil)
                        if self.isInterpreterPlayback {
                            self.onPlaybackStarted?()
                        } else {
                            self.onStarted?()
                        }
                    } catch {
                        self.reportSpeechFailure(error.localizedDescription)
                        self.finishPlayback()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.generation == token else { return }
                    self.reportSpeechFailure(error.localizedDescription)
                    self.finishPlayback()
                }
            }
        }
    }

    private func loadModel() throws -> SherpaOnnxOfflineTtsWrapper {
        if let model { return model }

        guard let root = Bundle.main.resourceURL?
            .appendingPathComponent("NeuralVoices/Supertonic3", isDirectory: true) else {
            throw NSError(domain: "SarahNeuralTTS", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Ressources du modèle vocal indisponibles."])
        }
        let names = [
            "duration_predictor.int8.onnx", "text_encoder.int8.onnx",
            "vector_estimator.int8.onnx", "vocoder.int8.onnx",
            "tts.json", "unicode_indexer.bin", "voice.bin"
        ]
        let fm = FileManager.default
        guard names.allSatisfy({ fm.fileExists(atPath: root.appendingPathComponent($0).path) }) else {
            throw NSError(domain: "SarahNeuralTTS", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Le modèle vocal Supertonic 3 n'est pas inclus dans l'IPA."])
        }
        func resource(_ filename: String) -> String { root.appendingPathComponent(filename).path }

        let config = sherpaOnnxOfflineTtsSupertonicModelConfig(
            durationPredictor: resource(names[0]), textEncoder: resource(names[1]),
            vectorEstimator: resource(names[2]), vocoder: resource(names[3]),
            ttsJson: resource(names[4]), unicodeIndexer: resource(names[5]),
            voiceStyle: resource(names[6])
        )
        let engineConfig = sherpaOnnxOfflineTtsModelConfig(numThreads: 2, supertonic: config)
        var ttsConfig = sherpaOnnxOfflineTtsConfig(model: engineConfig)
        let instance = SherpaOnnxOfflineTtsWrapper(config: &ttsConfig)
        guard instance.tts != nil else {
            throw NSError(domain: "SarahNeuralTTS", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Initialisation du moteur vocal impossible."])
        }
        self.model = instance
        return instance
    }

    private func reportSpeechFailure(_ message: String) {
        if isInterpreterPlayback {
            onPlaybackError?(message)
        } else {
            onFailure?(message)
        }
    }

    private func finishPlayback() {
        let wasInterpreterPlayback = isInterpreterPlayback
        isInterpreterPlayback = false
        isSpeaking = false
        player = nil
        NotificationCenter.default.post(name: NSNotification.Name("SarahNeuralSpeechStateChanged"), object: nil)
        AudioSessionManager.shared.deactivateSession()
        if wasInterpreterPlayback {
            onPlaybackFinished?()
        } else {
            onFinished?()
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        if !flag {
            reportSpeechFailure("La sortie audio a été interrompue par iOS.")
        }
        finishPlayback()
    }

    /// Wrap mono normalized float samples in standard 16-bit PCM WAV data.
    private static func waveData(samples: [Float], sampleRate: Int) -> Data {
        var bytes = Data()
        func put(_ value: UInt32) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { bytes.append(contentsOf: $0) }
        }
        func put16(_ value: UInt16) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { bytes.append(contentsOf: $0) }
        }
        let dataBytes = UInt32(samples.count * MemoryLayout<Int16>.size)
        bytes.append(contentsOf: Array("RIFF".utf8))
        put(36 + dataBytes)
        bytes.append(contentsOf: Array("WAVEfmt ".utf8))
        put(16) // PCM fmt chunk
        put16(1) // 16-bit PCM
        put16(1) // mono
        put(UInt32(sampleRate))
        put(UInt32(sampleRate * 2))
        put16(2)
        put16(16)
        bytes.append(contentsOf: Array("data".utf8))
        put(dataBytes)
        for sample in samples {
            let bounded = min(1, max(-1, sample))
            var pcm = Int16(bounded * 32767).littleEndian
            withUnsafeBytes(of: &pcm) { bytes.append(contentsOf: $0) }
        }
        return bytes
    }
}
