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
    @Published private(set) var phoneForeground = false
    @Published private(set) var awaitingPhone = false
    @Published private(set) var callInProgress = false
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
              !source.isEmpty, !target.isEmpty,
              source.count <= 12, target.count <= 12,
              source != target else { return }
        sourceLanguage = source
        targetLanguage = target
        if recording {
            status = "🎙️ \(languageAccessibleText) • connecté"
        } else if !connecting && paired {
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
    private let packetSamples = 2_560 // 160 ms : sous-titres plus réactifs sur l'iPhone

    private override init() {
        super.init()
        guard WCSession.isSupported() else {
            status = "Connexion Apple Watch indisponible"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sonde l'application jumelle. Depuis la montre, sendMessage peut réveiller
    /// Sarah IA en arrière-plan sans pour autant afficher son écran.
    func refreshPhoneStatus() {
        guard WCSession.default.activationState == .activated else {
            paired = false
            phoneForeground = false
            status = "Connexion à l’iPhone…"
            return
        }
        WCSession.default.sendMessage(["type": "probe"], replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.paired = true
                self.phoneForeground = (reply["foreground"] as? Bool) ?? false
                self.updateLanguages(
                    source: reply["source"] as? String,
                    target: reply["target"] as? String
                )
                if self.awaitingPhone && (reply["ready"] as? Bool) == true {
                    // Le passage au premier plan NE signifie pas que l'utilisateur
                    // a décroché. Attendre l'accord explicite de Sarah IA.
                    self.awaitingPhone = false
                    self.status = "Sarah ouverte • démarrage du microphone…"
                    self.start()
                } else if !self.recording && !self.connecting && !self.awaitingPhone {
                    self.status = self.phoneForeground
                        ? "Prête • \(self.languageAccessibleText)"
                        : "iPhone en veille • appel possible"
                }
            }
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.phoneForeground = false
                if self?.awaitingPhone != true {
                    self?.status = "iPhone indisponible • appel différé"
                }
            }
        })
    }

    /// L'app n'a aucun droit pour déverrouiller l'iPhone ni ouvrir un écran
    /// de force. On envoie une demande et iOS affiche une notification locale.
    func callPhone() {
        guard !recording && !connecting && !callInProgress && !awaitingPhone else { return }
        guard WCSession.default.activationState == .activated else {
            status = "Montre non jumelée"
            return
        }
        let requestId = UUID().uuidString
        callInProgress = true
        status = "Demande de notification Translate Live…"
        let message: [String: Any] = [
            "type": "callTranslateLive",
            "requestId": requestId
        ]
        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.callInProgress = false
                let accepted = (reply["accepted"] as? Bool) ?? false
                self.awaitingPhone = accepted
                if accepted {
                    self.status = "Demande envoyée • ouvre Sarah sur l’iPhone"
                } else if (reply["reason"] as? String) == "notificationsDisabled" {
                    self.status = "Active les notifications Sarah sur l’iPhone"
                } else {
                    self.status = "Notification indisponible • réessaie"
                }
            }
        }, errorHandler: { [weak self] _ in
            // Livraison opportuniste lorsque le téléphone n'est pas joignable.
            // Ne jamais indiquer « Appel reçu » avant une confirmation réelle.
            WCSession.default.transferUserInfo(message)
            DispatchQueue.main.async {
                self?.callInProgress = false
                self?.awaitingPhone = true
                self?.status = "Demande en attente • livraison différée"
            }
        })
    }

    func cancelCall() {
        awaitingPhone = false
        callInProgress = false
        if WCSession.default.activationState == .activated {
            WCSession.default.sendMessage(
                ["type": "cancelTranslateCall"],
                replyHandler: nil,
                errorHandler: nil
            )
        }
        status = "Demande annulée sur la montre"
    }

    func primaryAction() {
        if recording || connecting { stop(); return }
        if awaitingPhone { cancelCall(); return }
        if callInProgress { return }
        if phoneForeground { start() } else { callPhone() }
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
            self.paired = state == .activated
            if state == .activated { self.refreshPhoneStatus() }
            self.updateLanguages(
                source: session.receivedApplicationContext["source"] as? String,
                target: session.receivedApplicationContext["target"] as? String
            )
            if !self.recording && !self.awaitingPhone && !self.callInProgress {
                self.status = self.paired ? "Connexion à Sarah…" : "iPhone indisponible"
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.paired = session.activationState == .activated
            if !session.isReachable {
                self.phoneForeground = false
                if self.recording { self.stop(notifyPhone: false) }
            } else {
                self.refreshPhoneStatus()
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
            case "phoneDeclined":
                self.awaitingPhone = false
                self.callInProgress = false
                self.status = "Demande annulée sur l'iPhone"
            case "phoneReady":
                self.phoneForeground = true
                if self.awaitingPhone || self.callInProgress {
                    self.awaitingPhone = false
                    self.callInProgress = false
                    self.status = "Sarah ouverte • connexion au microphone…"
                    self.start()
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
                    if phase != .active {
                        SarahWatchAudio.shared.stop()
                    } else {
                        SarahWatchAudio.shared.refreshPhoneStatus()
                    }
                }
        }
    }
}

struct SarahWatchHome: View {
    @StateObject private var audio = SarahWatchAudio.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var activity: Bool {
        audio.recording || audio.connecting || audio.callInProgress || audio.awaitingPhone
    }

    private var callMode: Bool { !audio.phoneForeground && !audio.recording }
    private var actionLabel: String {
        if audio.recording || audio.connecting { return "Arrêter la traduction" }
        if audio.awaitingPhone { return "Annuler la demande" }
        if audio.callInProgress { return "Appel en cours…" }
        return callMode ? "Notifier l’iPhone" : "Traduction en temps réel"
    }
    private var actionIcon: String {
        if audio.recording || audio.connecting { return "stop.fill" }
        if audio.awaitingPhone { return "xmark" }
        return callMode ? "iphone.radiowaves.left.and.right" : "mic.fill"
    }

    var body: some View {
        GeometryReader { proxy in
            let short = proxy.size.height < 195 || dynamicTypeSize.isAccessibilitySize
            let narrow = proxy.size.width < 170
            let controlSize = min(proxy.size.width * 0.18, short ? 30.0 : 39.0)
            let space = short ? 5.0 : 10.0

            ZStack {
                Color(red: 0.025, green: 0.035, blue: 0.09).ignoresSafeArea()
                RadialGradient(
                    colors: [.cyan.opacity(0.20), Color.blue.opacity(0.06), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: proxy.size.width * 0.75
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: space) {
                        HStack(spacing: 5) {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(.cyan)
                            Text("SARAH IA")
                                .font(.system(size: short ? 11 : 13, weight: .bold, design: .rounded))
                                .tracking(narrow ? 0.2 : 0.9)
                            Spacer(minLength: 3)
                            Circle()
                                .fill(audio.phoneForeground ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                                .accessibilityLabel(audio.phoneForeground ? "iPhone ouvert" : "iPhone en veille")
                        }
                        .foregroundStyle(.white)

                        Text(audio.languageDisplay)
                            .font(.system(size: short ? 13 : 17, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .accessibilityLabel("Traduction \\(audio.languageAccessibleText)")

                        Button {
                            audio.primaryAction()
                        } label: {
                            HStack(spacing: narrow ? 6 : 9) {
                                Image(systemName: actionIcon)
                                    .font(.system(size: min(controlSize, 22), weight: .bold))
                                    .frame(width: controlSize, height: controlSize)
                                    .background(
                                        Circle().fill(
                                            activity ? Color.pink.opacity(0.25) : Color.cyan.opacity(0.24)
                                        )
                                    )
                                Text(actionLabel)
                                    .font(.system(size: short ? 11 : 13, weight: .bold))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, narrow ? 8 : 11)
                            .padding(.vertical, short ? 7 : 11)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: activity
                                                ? [Color.pink.opacity(0.70), Color.indigo.opacity(0.78)]
                                                : [Color.cyan.opacity(0.77), Color.purple.opacity(0.83)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(audio.callInProgress)
                        .accessibilityLabel(actionLabel)
                        .accessibilityHint(callMode
                            ? "Envoie une demande à l'iPhone ; une notification permet d'ouvrir Sarah."
                            : "Démarre le micro de l'Apple Watch pour traduire sur l'iPhone.")

                        Text(audio.status)
                            .font(.system(size: short ? 9 : 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)

                        HStack {
                            if audio.recording {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.cyan)
                                Text("Micro actif")
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "iphone")
                                    .foregroundStyle(.cyan)
                                Text(audio.phoneForeground ? "iPhone connecté" : "Via l’iPhone")
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                            Spacer(minLength: 2)
                            Button {
                                audio.refreshPhoneStatus()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.cyan)
                                    .frame(width: 30, height: 27)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Vérifier la connexion iPhone")
                        }
                        .font(.system(size: 10))
                    }
                    .padding(.horizontal, max(5, proxy.size.width * 0.045))
                    .padding(.vertical, short ? 3 : 7)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { audio.refreshPhoneStatus() }
    }
}
