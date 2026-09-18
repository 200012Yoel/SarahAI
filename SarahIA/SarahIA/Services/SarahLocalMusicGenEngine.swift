import Foundation
import AVFoundation
import CoreAIOps

@available(iOS 27.0, *)
public final class SarahLocalMusicGenEngine {

    public static let shared = SarahLocalMusicGenEngine()

    public struct MusicIntent {
        public let isIntent: Bool
        public let wantsLyrics: Bool
        public let prompt: String
        public let language: String
    }

    public enum MusicError: LocalizedError {
        case emptyPrompt
        case vocalSongRuntimeUnavailable

        public var errorDescription: String? {
            switch self {
            case .emptyPrompt:
                return "La description musicale est vide."
            case .vocalSongRuntimeUnavailable:
                return "Le moteur local de chanson chantée avec paroles n'est pas encore disponible sur iPhone."
            }
        }
    }

    private init() {}

    public func detectIntent(_ text: String) -> MusicIntent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()

        let triggers = [
            "génère une musique", "genere une musique",
            "génère un morceau", "genere un morceau",
            "compose une musique", "compose un morceau",
            "crée une musique", "cree une musique",
            "fais une musique", "fais un morceau",
            "generate music", "generate a song",
            "instrumental", "chanson avec paroles"
        ]

        let isIntent = triggers.contains { lower.contains($0) }
        let wantsLyrics =
            lower.contains("paroles")
            || lower.contains("lyrics")
            || lower.contains("chanson")
            || lower.contains("song")

        let language: String
        if lower.contains("anglais") || lower.contains("english") {
            language = "en"
        } else {
            language = "fr"
        }

        var prompt = clean
        for trigger in triggers {
            prompt = prompt.replacingOccurrences(
                of: trigger,
                with: "",
                options: .caseInsensitive
            )
        }
        prompt = prompt.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
                .union(CharacterSet(charactersIn: ":,-"))
        )
        if prompt.isEmpty { prompt = clean }

        return MusicIntent(
            isIntent: isIntent,
            wantsLyrics: wantsLyrics,
            prompt: prompt,
            language: language
        )
    }

    public func generateInstrumental(
        prompt: String,
        seconds: Float = 11,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(MusicError.emptyPrompt))
            return
        }

        Task {
            do {
                let audio = try await CoreAI.compose(
                    clean,
                    seconds: max(2, min(seconds, 11))
                )

                let output = try Self.writeStereoWAV(
                    samples: audio.samples,
                    sampleRate: audio.sampleRate,
                    prompt: clean
                )

                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedMusicReady"),
                        object: output,
                        userInfo: [
                            "prompt": clean,
                            "modelName": "Stable Audio Open Small · Core AI",
                            "isLocal": true
                        ]
                    )
                    completion(.success(output))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    public func prepareInstrumentalModel(
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        CoreAI.onDownload { event in
            DispatchQueue.main.async {
                progress(event.fraction, event.currentFile)
            }
        }

        Task {
            do {
                try await CoreAI.prepare(.compose)
                await MainActor.run {
                    CoreAI.onDownload(nil)
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    CoreAI.onDownload(nil)
                    completion(.failure(error))
                }
            }
        }
    }

    public func vocalSongAvailabilityMessage() -> String {
        let profile = SarahGenerativeModelCatalog.vocalSongProfile()
        return "Paroles chantées : \(profile.displayName) est sélectionné comme cible. \(profile.note)"
    }

    private static func outputDirectory() throws -> URL {
        let fm = FileManager.default
        let root = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? fm.temporaryDirectory
        let dir = root.appendingPathComponent("SarahIA/GeneratedMusic", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func writeStereoWAV(
        samples: [Float],
        sampleRate: Int,
        prompt: String
    ) throws -> URL {
        let dir = try outputDirectory()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let safeName = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()

        let name = "sarah-\(safeName.isEmpty ? "music" : safeName)-\(formatter.string(from: Date())).wav"
        let url = dir.appendingPathComponent(name)

        let channels: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let rate = UInt32(sampleRate)
        let bytesPerSample = UInt32(bitsPerSample / 8)
        let byteRate = rate * UInt32(channels) * bytesPerSample
        let blockAlign = channels * UInt16(bytesPerSample)

        var pcm = Data(capacity: samples.count * 2)
        for value in samples {
            let clipped = max(-1.0, min(1.0, value))
            let scaled = Int16(clipped * Float(Int16.max))
            appendLE(scaled, to: &pcm)
        }

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        appendLE(UInt32(36 + pcm.count), to: &wav)
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        appendLE(UInt32(16), to: &wav)
        appendLE(UInt16(1), to: &wav)
        appendLE(channels, to: &wav)
        appendLE(rate, to: &wav)
        appendLE(byteRate, to: &wav)
        appendLE(blockAlign, to: &wav)
        appendLE(bitsPerSample, to: &wav)
        wav.append(contentsOf: Array("data".utf8))
        appendLE(UInt32(pcm.count), to: &wav)
        wav.append(pcm)

        try wav.write(to: url, options: .atomic)
        return url
    }

    private static func appendLE<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { raw in
            data.append(contentsOf: raw)
        }
    }
}
