import SwiftUI
import WatchConnectivity
import AVFoundation
import Combine

/// La montre ne traduit pas et ne lit aucun audio : elle transmet seulement
/// des échantillons PCM 16 kHz à l'iPhone jumelé, quand celui-ci est joignable.
final class SarahWatchAudio: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SarahWatchAudio()

    @Published private(set) var recording = false
    @Published private(set) var connecting = false
    @Published private(set) var paired = false
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var status = "Connexion à l'iPhone…"
    @Published private(set) var sourceLanguage = "he"
    @Published private(set) var targetLanguage = "fr"

    // Les langues sont choisies dans l'app iPhone, pas figées dans la Watch.
    var languageDisplay: String {
        "\(Self.flag(for: sourceLanguage))  →  \(Self.flag(for: targetLanguage))"
    }
    var languageAccessibleText: String {
        "\(Self.name(for: sourceLanguage)) vers \(Self.name(for: targetLanguage))"
    }
    private static func flag(for code: String) -> String {
        switch code {
        case "he": return "🇮🇱"
        case "fr": return "🇫🇷"
        case "en": return "🇬🇧"
        default: return "🌐"
        }
    }
    private static func name(for code: String) -> String {
        switch code {
        case "he": return "hébreu"
        case "fr": return "français"
        case "en": return "anglais"
        default: return code.uppercased()
        }
    }
    private func updateLanguages(source: String?, target: String?) {
        guard let source, let target,
              ["he", "fr", "en"].contains(source),
              ["he", "fr", "en"].contains(target),
              source != target else { return }
        sourceLanguage = source
        targetLanguage = target
        if !recording && !connecting && paired {
            status = "Prête • \(languageAccessibleText)"
        }
    }

    private let engine = AVAudioEngine()
    private let conversionQueue = DispatchQueue(label: "sarah.watch.pcm")
    private var pcm: [Int16] = []
    private var samplePhase = 0.0
    // Utilisés exclusivement par conversionQueue, jamais par la vue SwiftUI.
    private var conversionEnabled = false
    private var conversionMuted = false
    private var packetInFlight = false
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
        guard !recording && !connecting else { return }
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            status = "Ouvre Sarah IA sur l'iPhone"
            return
        }
        connecting = true
        status = "Autorisation du microphone…"
        Task { @MainActor in
            let granted = await AVAudioApplication.requestRecordPermission()
            guard connecting else { return }
            guard granted else {
                connecting = false
                status = "Autorise le micro dans Réglages"
                return
            }
            requestPhoneSession()
        }
    }

    private func requestPhoneSession() {
        guard connecting else { return }
        status = "Connexion au traducteur iPhone…"
        // Attendre l'accord explicite avant d'envoyer le moindre paquet PCM.
        WCSession.default.sendMessage(
            ["type": "start"],
            replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self, self.connecting else { return }
                    self.updateLanguages(
                        source: response["source"] as? String,
                        target: response["target"] as? String
                    )
                    guard response["started"] as? Bool == true else {
                        self.connecting = false
                        self.status = "Traduction iPhone indisponible"
                        return
                    }
                    Task { @MainActor in await self.startMicrophone() }
                }
            },
            errorHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.connecting = false
                    self?.status = "Ouvre Sarah IA sur l'iPhone"
                }
            }
        )
    }

    @MainActor
    private func startMicrophone() async {
        guard connecting && !recording else { return }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement)
            try await audio.activate()

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                connecting = false
                status = "Micro de la montre indisponible"
                try? audio.setActive(false)
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(["type": "stop"], replyHandler: nil, errorHandler: nil)
                }
                return
            }

            conversionQueue.async { [weak self] in
                self?.pcm.removeAll(keepingCapacity: true)
                self?.samplePhase = 0
                self?.packetInFlight = false
                self?.conversionEnabled = true
                self?.conversionMuted = false
            }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.capture(buffer, rate: format.sampleRate)
            }
            engine.prepare()
            try engine.start()
            recording = true
            connecting = false
            status = "🎙️ \(languageAccessibleText) • connecté"
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            connecting = false
            try? AVAudioSession.sharedInstance().setActive(false)
            status = "Micro indisponible : \(error.localizedDescription)"
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["type": "stop"], replyHandler: nil, errorHandler: nil)
            }
        }
    }

    func stop(notifyPhone: Bool = true) {
        guard recording || connecting else { return }
        connecting = false
        recording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        level = 0
        status = "Micro arrêté"
        try? AVAudioSession.sharedInstance().setActive(false)
        conversionQueue.async { [weak self] in
            self?.conversionEnabled = false
            self?.pcm.removeAll(keepingCapacity: true)
            self?.packetInFlight = false
        }
        if notifyPhone, WCSession.default.isReachable {
            WCSession.default.sendMessage(["type": "stop"], replyHandler: nil, errorHandler: nil)
        }
    }

    private func capture(_ buffer: AVAudioPCMBuffer, rate: Double) {
        guard let channels = buffer.floatChannelData else { return }
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
        guard conversionEnabled, !conversionMuted, inputRate > 0 else { return }
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

        // Garder moins d'une seconde de retard si la liaison ralentit.
        // On supprime la parole la plus ancienne au lieu de lire un flux en retard.
        if pcm.count > packetSamples * 4 {
            pcm.removeFirst(pcm.count - packetSamples * 4)
        }
        sendNextPacketIfPossible()
        let displayLevel = CGFloat(min(1, maxLevel * 5))
        DispatchQueue.main.async { [weak self] in self?.level = displayLevel }
    }

    private func sendNextPacketIfPossible() {
        guard conversionEnabled, !conversionMuted,
              !packetInFlight, pcm.count >= packetSamples else { return }
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            DispatchQueue.main.async { [weak self] in
                self?.status = "Ouvre Sarah IA sur l'iPhone"
                self?.stop(notifyPhone: false)
            }
            return
        }

        let chunk = Array(pcm.prefix(packetSamples))
        pcm.removeFirst(packetSamples)
        var bytes = Data(capacity: chunk.count * 2)
        for sample in chunk {
            let raw = UInt16(bitPattern: sample)
            bytes.append(UInt8(truncatingIfNeeded: raw))
            bytes.append(UInt8(truncatingIfNeeded: raw >> 8))
        }
        packetInFlight = true
        WCSession.default.sendMessageData(bytes, replyHandler: { [weak self] _ in
            self?.conversionQueue.async {
                self?.packetInFlight = false
                self?.sendNextPacketIfPossible()
            }
        }, errorHandler: { [weak self] _ in
            self?.conversionQueue.async { self?.packetInFlight = false }
            DispatchQueue.main.async {
                self?.status = "Transmission interrompue : ouvre Sarah IA"
            }
        })
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.paired = state == .activated && session.isReachable
            self.updateLanguages(
                source: session.receivedApplicationContext["source"] as? String,
                target: session.receivedApplicationContext["target"] as? String
            )
            if !self.recording {
                self.status = self.paired ? "Prête • \(self.languageAccessibleText)" : "Ouvre Sarah IA sur l'iPhone"
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.paired = session.isReachable
            if !session.isReachable && self.recording { self.stop(notifyPhone: false) }
            if !self.recording {
                self.status = self.paired ? "Prête • \(self.languageAccessibleText)" : "Ouvre Sarah IA sur l'iPhone"
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.updateLanguages(
                source: applicationContext["source"] as? String,
                target: applicationContext["target"] as? String
            )
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case "speaking":
                let speaking = (message["active"] as? Bool) ?? false
                self.conversionQueue.async { [weak self] in
                    self?.conversionMuted = speaking
                    if speaking { self?.pcm.removeAll(keepingCapacity: true) }
                }
            case "languages":
                self.updateLanguages(
                    source: message["source"] as? String,
                    target: message["target"] as? String
                )
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
                .onChange(of: scenePhase) { _, phase in
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

    private var listening: Bool { audio.recording || audio.connecting }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 205
            ZStack {
                Color(red: 0.025, green: 0.035, blue: 0.09).ignoresSafeArea()
                RadialGradient(
                    colors: [
                        Color(red: 0.03, green: 0.28, blue: 0.40).opacity(0.50),
                        Color(red: 0.04, green: 0.06, blue: 0.17).opacity(0.7),
                        .clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: geometry.size.width * 0.80
                )

                if intro {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: compact ? 24 : 32, weight: .medium))
                            .foregroundStyle(.cyan)
                            .scaleEffect(glowing ? 1.0 : 0.87)
                        Text("Sarah")
                            .font(.system(size: compact ? 21 : 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .transition(.opacity)
                    .accessibilityElement(children: .combine)
                } else {
                    VStack(spacing: compact ? 5 : 9) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(audio.paired ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text("SARAH IA")
                                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.86))
                        }

                        HStack(spacing: 5) {
                            Text(audio.languageDisplay)
                        }
                        .font(.system(size: compact ? 15 : 18))
                        .accessibilityLabel("Traduction \(audio.languageAccessibleText)")

                        Button {
                            listening ? audio.stop() : audio.start()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.cyan.opacity(0.20), lineWidth: 2)
                                    .frame(width: compact ? 65 : 88, height: compact ? 65 : 88)
                                Circle()
                                    .fill(
                                        listening
                                            ? Color.red.opacity(0.20)
                                            : Color.cyan.opacity(0.18)
                                    )
                                    .frame(width: compact ? 58 : 78, height: compact ? 58 : 78)
                                    .scaleEffect(audio.recording ? 1 + audio.level * 0.13 : 1)
                                Image(systemName: listening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: compact ? 25 : 30, weight: .medium))
                                    .foregroundStyle(listening ? .red : .white)
                            }
                            .frame(width: compact ? 68 : 90, height: compact ? 68 : 90)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(listening ? "Arrêter l'écoute" : "Démarrer la traduction")
                        .accessibilityHint("Le microphone de la montre transmet la langue sélectionnée à l'iPhone")

                        Text(audio.status)
                            .font(.system(size: compact ? 10 : 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { glowing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(.easeInOut(duration: 0.3)) { intro = false }
            }
        }
    }
}
