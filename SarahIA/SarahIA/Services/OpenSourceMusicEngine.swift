import Foundation
import AVFoundation

/// Moteur d'Intelligence Artificielle Musicale Générative 100% Local & Open Source pour Téléphone
/// - Synthèse polyphonique multi-pistes générative en temps réel (AVAudioEngine + Synthèse PCM)
/// - Génère des compositions uniques avec mélodie, harmonies d'accords, ligne de basse et textures rythmiques
/// - Styles variés : Lo-Fi Chill, Synthwave Électro, Piano Classique, Ambiance Zen, Épique Cinématique, Jazz Bossa
/// - Fonctionne 100% Hors-Ligne, zéro quota, zéro dépendance externe, latence instantanée
public final class OpenSourceMusicEngine: NSObject {
    
    public static let shared = OpenSourceMusicEngine()
    
    public enum MusicStyle: String, CaseIterable {
        case lofi = "Lo-Fi Chill"
        case synthwave = "Synthwave Électro"
        case classical = "Piano Classique"
        case ambient = "Ambiance Méditation"
        case cinematic = "Épique Cinématique"
        case jazz = "Jazz Bossa"
        
        public var bpm: Double {
            switch self {
            case .lofi: return 80.0
            case .synthwave: return 125.0
            case .classical: return 90.0
            case .ambient: return 60.0
            case .cinematic: return 110.0
            case .jazz: return 100.0
            }
        }
        
        public var description: String {
            switch self {
            case .lofi: return "des accords chaleureux et une mélodie relaxante"
            case .synthwave: return "une ligne de basse percutante et un arpégiateur rétro"
            case .classical: return "des arpèges de piano mélancoliques et harmonieux"
            case .ambient: return "des nappes sonores immersives et apaisantes"
            case .cinematic: return "une progression harmonique grandiose et rythmée"
            case .jazz: return "des harmonies subtiles et un swing feutré"
            }
        }
    }
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100.0
    
    public private(set) var isPlaying: Bool = false
    public private(set) var currentStyle: MusicStyle?
    
    private override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let node = playerNode else { return }
        engine.attach(node)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("Erreur démarrage Audio Engine Musical : \(error.localizedDescription)")
        }
    }
    
    // MARK: - Détection d'Intention Musicale
    
    /// Détecte si l'utilisateur demande à Sarah de générer ou jouer une musique
    public func isMusicGenerationIntent(_ text: String) -> (isIntent: Bool, detectedStyle: MusicStyle, userQuery: String) {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let triggers = [
            "génère une musique", "genere une musique", "crée une musique", "cree une musique",
            "génère-moi une musique", "genere moi une musique", "crée-moi une musique", "cree moi une musique",
            "fais une musique", "fais-moi une musique", "compose une musique", "compose-moi une musique",
            "joue une musique", "joue-moi une musique", "lance une musique", "fais de la musique",
            "génère un son", "genere un son", "crée un son", "cree un son", "joue du piano", "fais du piano",
            "génère un morceau", "genere un morceau", "crée un morceau", "cree un morceau"
        ]
        
        var isIntent = triggers.contains { lower.contains($0) }
        if !isIntent {
            if (lower.contains("musique") || lower.contains("morceau") || lower.contains("chanson")) &&
               (lower.contains("génère") || lower.contains("genere") || lower.contains("crée") || lower.contains("cree") || lower.contains("joue") || lower.contains("compose")) {
                isIntent = true
            }
        }
        
        guard isIntent else { return (false, .lofi, text) }
        
        // Détection du style
        var style: MusicStyle = .lofi
        if lower.contains("synthwave") || lower.contains("electro") || lower.contains("électro") || lower.contains("techno") || lower.contains("futuriste") {
            style = .synthwave
        } else if lower.contains("classique") || lower.contains("piano") || lower.contains("mozart") || lower.contains("chopin") {
            style = .classical
        } else if lower.contains("ambient") || lower.contains("ambiance") || lower.contains("zen") || lower.contains("méditation") || lower.contains("relax") || lower.contains("dort") || lower.contains("dormir") {
            style = .ambient
        } else if lower.contains("cinematique") || lower.contains("cinématique") || lower.contains("epique") || lower.contains("épique") || lower.contains("film") || lower.contains("action") {
            style = .cinematic
        } else if lower.contains("jazz") || lower.contains("bossa") || lower.contains("blues") || lower.contains("groove") {
            style = .jazz
        } else {
            style = .lofi
        }
        
        return (true, style, text)
    }
    
    // MARK: - Génération & Lecture Musicale
    
    /// Génère un morceau complet en mémoire et le joue immédiatement
    public func generateAndPlayTrack(
        style: MusicStyle = .lofi,
        durationSeconds: Double = 30.0,
        variationSeed: UInt64 = UInt64.random(in: 1...UInt64.max),
        completion: @escaping (Bool, String) -> Void
    ) {
        stopMusic()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let buffer = self.synthesizeTrackBuffer(
                style: style,
                durationSeconds: durationSeconds,
                variationSeed: variationSeed
            ) else {
                DispatchQueue.main.async {
                    completion(false, "Impossible de synthétiser le flux audio.")
                }
                return
            }

            DispatchQueue.main.async {
                guard let engine = self.audioEngine, let player = self.playerNode else {
                    completion(false, "Moteur audio indisponible.")
                    return
                }

                if !engine.isRunning {
                    try? engine.start()
                }

                self.currentStyle = style
                self.isPlaying = true

                player.scheduleBuffer(
                    buffer,
                    at: nil,
                    options: .interrupts,
                    completionHandler: { [weak self] in
                        DispatchQueue.main.async {
                            self?.isPlaying = false
                            self?.currentStyle = nil
                        }
                    }
                )
                player.play()

                NotificationCenter.default.post(
                    name: NSNotification.Name("SarahMusicPlaybackStarted"),
                    object: nil,
                    userInfo: [
                        "style": style.rawValue,
                        "duration": durationSeconds,
                        "variationSeed": variationSeed
                    ]
                )

                let message = """
                🎵 **Morceau composé par Sarah Music Engine**
                • Style : **\(style.rawValue)**
                • Variation : **\(String(variationSeed, radix: 16).suffix(6))**
                • Éléments : \(style.description)

                *Lecture en cours sur votre haut-parleur...*
                """
                completion(true, message)
            }
        }
    }

    public func stopMusic() {
        playerNode?.stop()
        isPlaying = false
        currentStyle = nil
        NotificationCenter.default.post(name: NSNotification.Name("SarahMusicPlaybackStopped"), object: nil)
    }
    
    // MARK: - Algorithme de Synthèse Polyphonique (AudioCraft / Math Synth)
    
    private func synthesizeTrackBuffer(
        style: MusicStyle,
        durationSeconds: Double,
        variationSeed: UInt64
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return nil
        }

        var rng = SarahMusicRandom(seed: variationSeed)

        let tempoFactor = 0.90 + rng.unit() * 0.22
        let bpm = style.bpm * tempoFactor
        let beatDuration = 60.0 / bpm
        let totalBeats = Int((durationSeconds / beatDuration).rounded(.up))

        let baseScale: [Double]
        switch style {
        case .lofi, .jazz:
            baseScale = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25, 587.33, 659.25]
        case .synthwave:
            baseScale = [220.00, 246.94, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 523.25, 587.33]
        case .classical:
            baseScale = [293.66, 329.63, 349.23, 392.00, 440.00, 466.16, 523.25, 587.33, 659.25, 698.46]
        case .ambient:
            baseScale = [174.61, 220.00, 261.63, 329.63, 392.00, 440.00, 523.25, 659.25]
        case .cinematic:
            baseScale = [130.81, 146.83, 155.56, 174.61, 196.00, 220.00, 246.94, 261.63, 311.13, 392.00]
        }

        let semitoneShift = rng.int(in: -5...6)
        let transposeRatio = pow(2.0, Double(semitoneShift) / 12.0)
        let scaleFreqs = baseScale.map { $0 * transposeRatio }

        let progressions = [
            [0, 3, 4, 1],
            [0, 4, 2, 5],
            [0, 5, 3, 4],
            [0, 2, 4, 1],
            [0, 1, 4, 3]
        ]
        let progression = progressions[rng.int(in: 0...(progressions.count - 1))]
        let melodyDensity = 0.45 + rng.unit() * 0.40
        let octaveChance = 0.20 + rng.unit() * 0.35
        let swingAmount = rng.unit() * 0.12
        let harmonic2 = 0.12 + rng.unit() * 0.30
        let harmonic3 = 0.04 + rng.unit() * 0.18

        let stepDivision: Int
        switch style {
        case .synthwave:
            stepDivision = 4
        case .ambient:
            stepDivision = 2
        default:
            let choices = [2, 3, 4]
            stepDivision = choices[rng.int(in: 0...(choices.count - 1))]
        }

        struct NoteEvent {
            let startTime: Double
            let duration: Double
            let freq: Double
            let amplitude: Float
            let isBass: Bool
            let pan: Float
        }

        var noteEvents: [NoteEvent] = []
        let rootSpan = max(1, min(scaleFreqs.count - 4, 6))

        for beat in 0..<totalBeats {
            let beatTime = Double(beat) * beatDuration

            if beat % 4 == 0 {
                let barIndex = beat / 4
                let degree = progression[barIndex % progression.count] % rootSpan
                let thirdIndex = min(degree + (rng.unit() > 0.50 ? 2 : 3), scaleFreqs.count - 1)
                let fifthIndex = min(degree + 4, scaleFreqs.count - 1)

                noteEvents.append(
                    NoteEvent(
                        startTime: beatTime,
                        duration: beatDuration * (3.1 + rng.unit() * 0.75),
                        freq: scaleFreqs[degree] * 0.5,
                        amplitude: 0.15,
                        isBass: true,
                        pan: 0
                    )
                )
                noteEvents.append(
                    NoteEvent(
                        startTime: beatTime,
                        duration: beatDuration * (2.8 + rng.unit() * 0.8),
                        freq: scaleFreqs[thirdIndex],
                        amplitude: 0.09,
                        isBass: false,
                        pan: Float(-0.20 + rng.unit() * 0.18)
                    )
                )
                noteEvents.append(
                    NoteEvent(
                        startTime: beatTime,
                        duration: beatDuration * (2.8 + rng.unit() * 0.8),
                        freq: scaleFreqs[fifthIndex],
                        amplitude: 0.08,
                        isBass: false,
                        pan: Float(0.02 + rng.unit() * 0.24)
                    )
                )
            }

            let stepDuration = beatDuration / Double(stepDivision)

            for step in 0..<stepDivision {
                guard rng.unit() <= melodyDensity else { continue }

                var stepTime = beatTime + Double(step) * stepDuration
                if step % 2 == 1 {
                    stepTime += stepDuration * swingAmount
                }
                if stepTime >= durationSeconds {
                    continue
                }

                let noteIndex = rng.int(in: 0...(scaleFreqs.count - 1))
                var melodyFreq = scaleFreqs[noteIndex]

                if rng.unit() < octaveChance && style != .ambient {
                    melodyFreq *= 2.0
                } else if rng.unit() < 0.12 {
                    melodyFreq *= 0.5
                }

                let durationMultiplier: Double
                switch style {
                case .ambient:
                    durationMultiplier = 1.8 + rng.unit() * 1.6
                case .classical:
                    durationMultiplier = 0.75 + rng.unit() * 0.75
                default:
                    durationMultiplier = 0.48 + rng.unit() * 0.62
                }

                noteEvents.append(
                    NoteEvent(
                        startTime: stepTime,
                        duration: min(
                            durationSeconds - stepTime,
                            stepDuration * durationMultiplier
                        ),
                        freq: melodyFreq,
                        amplitude: Float(0.10 + rng.unit() * 0.10),
                        isBass: false,
                        pan: Float(-0.55 + rng.unit() * 1.10)
                    )
                )
            }
        }

        let totalSamples = Int(frameCount)
        for index in 0..<totalSamples {
            leftChannel[index] = 0
            rightChannel[index] = 0
        }

        let twoPi = 2.0 * Double.pi

        for event in noteEvents {
            let startSample = max(0, Int(event.startTime * sampleRate))
            let durationSamples = max(1, Int(event.duration * sampleRate))
            let endSample = min(startSample + durationSamples, totalSamples)

            guard startSample < endSample else { continue }

            for sample in startSample..<endSample {
                let t = Double(sample - startSample) / sampleRate
                let progress = Double(sample - startSample) / Double(durationSamples)

                let attack = min(1.0, progress / 0.08)
                let release = min(1.0, (1.0 - progress) / 0.16)
                let envelope = Float(max(0, min(attack, release)))

                let fundamental = sin(twoPi * event.freq * t)
                let second = sin(twoPi * event.freq * 2.0 * t)
                let third = sin(twoPi * event.freq * 3.0 * t)

                let wave: Double
                if event.isBass {
                    wave = fundamental + harmonic2 * 0.55 * second
                } else {
                    switch style {
                    case .synthwave:
                        wave = 0.66 * fundamental + harmonic2 * second + harmonic3 * third
                    case .ambient:
                        wave = 0.86 * fundamental + harmonic2 * 0.38 * second
                    case .classical:
                        wave = 0.78 * fundamental + harmonic2 * 0.48 * second + harmonic3 * 0.25 * third
                    default:
                        wave = 0.80 * fundamental + harmonic2 * second + harmonic3 * 0.35 * third
                    }
                }

                let sampleValue = Float(wave) * event.amplitude * envelope
                let pan = max(-1, min(1, event.pan))
                let leftGain = sqrt((1 - pan) * 0.5)
                let rightGain = sqrt((1 + pan) * 0.5)

                leftChannel[sample] += sampleValue * leftGain
                rightChannel[sample] += sampleValue * rightGain
            }
        }

        for index in 0..<totalSamples {
            leftChannel[index] = tanh(leftChannel[index] * 1.35) * 0.82
            rightChannel[index] = tanh(rightChannel[index] * 1.35) * 0.82
        }

        return buffer
    }

}

private struct SarahMusicRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func unit() -> Double {
        Double(next() % 1_000_000) / 1_000_000.0
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }
}
