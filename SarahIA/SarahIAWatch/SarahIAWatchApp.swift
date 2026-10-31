import SwiftUI
import WatchConnectivity
import AVFoundation
import Combine

/// La montre ne traduit pas et ne lit aucun audio : elle transmet seulement
/// des échantillons PCM 16 kHz à l'iPhone jumelé, quand celui-ci est joignable.
final class SarahWatchAudio: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SarahWatchAudio()

    @Published private(set) var recording = false
    @Published private(set) var paired = false
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var status = "Connexion à l'iPhone…"

    private let engine = AVAudioEngine()
    private let conversionQueue = DispatchQueue(label: "sarah.watch.pcm")
    private var pcm: [Int16] = []
    private var samplePhase = 0.0
    private var phoneSpeaking = false
    private let sampleRate = 16_000.0
    private let packetSamples = 3_200 // 200 ms de parole

    private override init() {
        super.init()
        guard WCSession.isSupported() else {
            status = "Connexion Apple Watch indisponible"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func start() {
        guard !recording else { return }
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            status = "Ouvre Sarah IA sur l'iPhone"
            return
        }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard granted else {
                    self.status = "Autorise le micro dans Réglages"
                    return
                }
                Task { @MainActor in await self.startMicrophone() }
            }
        }
    }

    @MainActor
    private func startMicrophone() async {
        guard !recording else { return }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement)
            try await audio.activate()

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                status = "Micro de la montre indisponible"
                return
            }

            conversionQueue.async { [weak self] in
                self?.pcm.removeAll(keepingCapacity: true)
                self?.samplePhase = 0
            }
            phoneSpeaking = false
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.capture(buffer, rate: format.sampleRate)
            }
            engine.prepare()
            try engine.start()
            recording = true
            status = "🎙️ Hébreu • écoute en cours"
            WCSession.default.sendMessage(["type": "start", "source": "he", "target": "fr"],
                                          replyHandler: nil, errorHandler: { [weak self] _ in
                DispatchQueue.main.async { self?.status = "Connexion iPhone interrompue" }
            })
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            status = "Micro indisponible : \(error.localizedDescription)"
        }
    }

    func stop(notifyPhone: Bool = true) {
        guard recording else { return }
        recording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        level = 0
        status = "Micro arrêté"
        conversionQueue.async { [weak self] in self?.pcm.removeAll(keepingCapacity: true) }
        if notifyPhone, WCSession.default.isReachable {
            WCSession.default.sendMessage(["type": "stop"], replyHandler: nil, errorHandler: nil)
        }
    }

    private func capture(_ buffer: AVAudioPCMBuffer, rate: Double) {
        guard recording, !phoneSpeaking,
              let channels = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return }

        // La conversion se fait hors du thread de capture audio.
        let samples: [Float] = (0..<frameCount).map { i in
            var sum: Float = 0
            for channel in 0..<channelCount { sum += channels[channel][i] }
            return sum / Float(channelCount)
        }
        conversionQueue.async { [weak self] in
            self?.consume(samples, inputRate: rate)
        }
    }

    private func consume(_ samples: [Float], inputRate: Double) {
        guard inputRate > 0 else { return }
        let ratio = sampleRate / inputRate
        var maxLevel: Float = 0

        for value in samples {
            let sample = min(1, max(-1, value))
            maxLevel = max(maxLevel, abs(sample))
            samplePhase += ratio
            while samplePhase >= 1 {
                pcm.append(Int16((sample * 32_000).rounded()))
                samplePhase -= 1
            }
        }

        if pcm.count >= packetSamples {
            let chunk = Array(pcm.prefix(packetSamples))
            pcm.removeFirst(packetSamples)
            var bytes = Data(capacity: chunk.count * 2)
            for sample in chunk {
                let raw = UInt16(bitPattern: sample)
                bytes.append(UInt8(truncatingIfNeeded: raw))
                bytes.append(UInt8(truncatingIfNeeded: raw >> 8))
            }
            if WCSession.default.activationState == .activated && WCSession.default.isReachable {
                WCSession.default.sendMessageData(bytes, replyHandler: nil, errorHandler: { [weak self] _ in
                    DispatchQueue.main.async { self?.status = "Transmission interrompue : ouvre Sarah IA" }
                })
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.status = "Ouvre Sarah IA sur l'iPhone"
                    self?.stop(notifyPhone: false)
                }
            }
        }
        let displayLevel = CGFloat(min(1, maxLevel * 5))
        DispatchQueue.main.async { [weak self] in self?.level = displayLevel }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.paired = state == .activated && session.isReachable
            if !self.recording {
                self.status = self.paired ? "Prête • hébreu → français" : "Ouvre Sarah IA sur l'iPhone"
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.paired = session.isReachable
            if !session.isReachable && self.recording { self.stop(notifyPhone: false) }
            if !self.recording {
                self.status = self.paired ? "Prête • hébreu → français" : "Ouvre Sarah IA sur l'iPhone"
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case "speaking": self.phoneSpeaking = (message["active"] as? Bool) ?? false
            case "stop": self.stop(notifyPhone: false)
            default: break
            }
        }
    }
}

@main
struct SarahIAWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SarahWatchHome()
                .onChange(of: scenePhase) { phase in
                    // L'écoute active ne survit pas arbitrairement à la suspension watchOS.
                    if phase != .active { SarahWatchAudio.shared.stop() }
                }
        }
    }
}

struct SarahWatchHome: View {
    @StateObject private var audio = SarahWatchAudio.shared
    @State private var intro = true
    @State private var glowing = false

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.09).ignoresSafeArea()
            RadialGradient(colors: [.cyan.opacity(0.19), .blue.opacity(0.08), .clear],
                           center: .center, startRadius: 6, endRadius: 180)

            if intro {
                VStack(spacing: 9) {
                    ZStack {
                        Circle().stroke(.cyan.opacity(0.5), lineWidth: 1)
                            .frame(width: 72, height: 72)
                            .scaleEffect(glowing ? 1 : 0.7)
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                            .font(.system(size: 24))
                    }
                    Text("Sarah").font(.system(size: 26, weight: .semibold, design: .rounded))
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    Text("Sarah IA Watch")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("🇮🇱  →  🇫🇷").font(.system(size: 22))

                    Button {
                        audio.recording ? audio.stop() : audio.start()
                    } label: {
                        ZStack {
                            Circle().fill(Color.cyan.opacity(0.18))
                                .frame(width: 82, height: 82)
                                .scaleEffect(audio.recording ? 1 + audio.level * 0.18 : 1)
                            Image(systemName: audio.recording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(audio.recording ? .red : .white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(audio.recording ? "Arrêter l'écoute" : "Démarrer l'écoute hébreu")
                    Text(audio.status)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                }
                .padding(.horizontal, 8)
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { glowing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(.easeInOut(duration: 0.3)) { intro = false }
            }
        }
    }
}
