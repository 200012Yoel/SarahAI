import SwiftUI
import Foundation
import Combine
import CryptoKit

/// Un seul catalogue de poids, distribué sous le nom public Sarah Engine.
/// Les binaires de l'app, les voix Apple et Google ML Kit ne sont pas des modèles
/// librement copiables dans les assets de cette release.
final class SarahEngineInstaller: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = SarahEngineInstaller()
    static let releaseBase = "https://github.com/200012Yoel/SarahAI/releases/download/sarah-engine-v1/"

    @Published private(set) var progress: Double = 0
    @Published private(set) var status = "Sarah Engine est prêt à être téléchargé."
    @Published private(set) var isInstalling = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isReady = false

    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var checksums: [String: String] = [:]
    private var currentWhisperProgress: Double = 0
    private let fm = FileManager.default

    private var modelsFolder: URL {
        (fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory)
            .appendingPathComponent("SarahAI/models", isDirectory: true)
    }

    private var whisperURL: URL { modelsFolder.appendingPathComponent("ggml-base.bin") }

    private var whisperAvailable: Bool {
        fm.fileExists(atPath: whisperURL.path)
            || Bundle.main.url(forResource: "ggml-base", withExtension: "bin", subdirectory: "WhisperModels") != nil
    }

    /// Contrôle synchrone au premier lancement pour éviter une feuille inutile
    /// lors d'une mise à jour d'une ancienne IPA qui contenait déjà les poids.
    var hasRequiredModels: Bool {
        BackgroundModelDownloader.isModelDownloaded && whisperAvailable
    }

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.sarahia.sarahengine.whisper.v1")
        config.isDiscretionary = false
        config.allowsCellularAccess = false
        config.waitsForConnectivity = true
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        refreshInstalledState()
    }

    func refreshInstalledState() {
        let ready = BackgroundModelDownloader.isModelDownloaded && whisperAvailable
        DispatchQueue.main.async {
            self.isReady = ready
            if ready && !self.isInstalling {
                self.progress = 1
                self.status = "Sarah Engine installé et disponible hors ligne."
            }
        }
    }

    func start() {
        guard !isInstalling else { return }
        if BackgroundModelDownloader.isModelDownloaded && whisperAvailable {
            refreshInstalledState()
            return
        }
        guard ModelSelectionEngine.shared.isLocalGGUFAllowed() else {
            errorMessage = "Cet appareil n'a pas assez de mémoire pour faire tourner Sarah Engine localement."
            return
        }

        isInstalling = true
        isReady = false
        progress = 0
        errorMessage = nil
        status = "Vérification du catalogue Sarah Engine sur GitHub…"
        guard let url = URL(string: Self.releaseBase + "SHA256SUMS.txt") else {
            fail("Adresse du catalogue Sarah Engine invalide.")
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard error == nil,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    self.fail("Les modèles Sarah Engine ne sont pas encore accessibles sur GitHub. Réessaie après leur publication.")
                    return
                }
                self.checksums = self.parseChecksums(text)
                guard self.checksums[ModelSelectionEngine.shared.recommendedLocalModelFileName] != nil,
                      self.checksums["ggml-base.bin"] != nil else {
                    self.fail("Le catalogue GitHub n'indique pas toutes les empreintes de vérification.")
                    return
                }
                self.startQwen()
            }
        }.resume()
    }

    private func startQwen() {
        let downloader = BackgroundModelDownloader.shared
        let name = ModelSelectionEngine.shared.recommendedLocalModelFileName

        if BackgroundModelDownloader.isModelDownloaded,
           let existing = BackgroundModelDownloader.localModelURL {
            validate(existing, name: name) { ok in
                if ok { self.startWhisper() }
                else {
                    // Une copie incomplète n'est pas une installation valide.
                    // Supprimer seulement le fichier de ce modèle vérifié en échec.
                    if existing.path.hasPrefix(self.modelsFolder.path) {
                        try? self.fm.removeItem(at: existing)
                    }
                    self.requestQwenDownload()
                }
            }
            return
        }
        requestQwenDownload()
    }

    private func requestQwenDownload() {
        status = "Téléchargement Sarah Engine • intelligence locale"
        let downloader = BackgroundModelDownloader.shared
        downloader.onProgress = { [weak self] value, _, _ in
            DispatchQueue.main.async { self?.progress = min(0.78, value * 0.78) }
        }
        downloader.onCompletion = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let url):
                    let name = ModelSelectionEngine.shared.recommendedLocalModelFileName
                    self.validate(url, name: name) { valid in
                        if valid {
                            self.progress = 0.78
                            self.startWhisper()
                        } else {
                            if url.path.hasPrefix(self.modelsFolder.path) {
                                try? self.fm.removeItem(at: url)
                            }
                            self.fail("Vérification SHA-256 du modèle Sarah Engine échouée. Réessaie.")
                        }
                    }
                case .failure(let error):
                    self.fail(error.localizedDescription)
                }
            }
        }
        downloader.startQwenModelDownload()
    }

    private func startWhisper() {
        if whisperAvailable {
            if fm.fileExists(atPath: whisperURL.path) {
                validate(whisperURL, name: "ggml-base.bin") { ok in
                    if ok { self.finish() }
                    else {
                        try? self.fm.removeItem(at: self.whisperURL)
                        self.requestWhisperDownload()
                    }
                }
            } else {
                // Pour les anciennes IPA contenant les vrais poids Whisper.
                finish()
            }
            return
        }
        requestWhisperDownload()
    }

    private func requestWhisperDownload() {
        status = "Téléchargement Sarah Engine • reconnaissance vocale"
        progress = max(progress, 0.78)
        guard let url = URL(string: Self.releaseBase + "ggml-base.bin") else {
            fail("Adresse du modèle vocal invalide.")
            return
        }
        task = session.downloadTask(with: url)
        task?.resume()
    }

    private func parseChecksums(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 2 {
                let digest = String(parts[0]).lowercased()
                let filename = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                if digest.count == 64 { result[filename] = digest }
            }
        }
        return result
    }

    private func validate(_ url: URL, name: String, completion: @escaping (Bool) -> Void) {
        guard let expected = checksums[name] else {
            completion(false)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            guard let stream = InputStream(url: url) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            stream.open()
            defer { stream.close() }
            var hasher = SHA256()
            var buffer = [UInt8](repeating: 0, count: 1024 * 1024)
            var good = true
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 { good = false; break }
                if count == 0 { break }
                hasher.update(data: Data(buffer[0..<count]))
            }
            let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            DispatchQueue.main.async { completion(good && actual == expected) }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        DispatchQueue.main.async {
            self.currentWhisperProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.progress = min(0.99, 0.78 + self.currentWhisperProgress * 0.21)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // iOS efface l'emplacement temporaire juste après le callback.
        // Le copier AVANT de quitter ce delegate, puis contrôler SHA-256.
        let staging = fm.temporaryDirectory.appendingPathComponent("sarah-whisper-\(UUID().uuidString).bin")
        do {
            try fm.copyItem(at: location, to: staging)
        } catch {
            DispatchQueue.main.async { self.fail("Impossible de préparer le modèle vocal : \(error.localizedDescription)") }
            return
        }
        DispatchQueue.main.async {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  response.statusCode == 200 else {
                try? self.fm.removeItem(at: staging)
                self.fail("Le serveur GitHub n'a pas retourné le modèle vocal attendu.")
                return
            }
            self.validate(staging, name: "ggml-base.bin") { valid in
                guard valid else {
                    try? self.fm.removeItem(at: staging)
                    self.fail("Vérification du modèle Whisper échouée.")
                    return
                }
                do {
                    try self.fm.createDirectory(at: self.modelsFolder, withIntermediateDirectories: true)
                    if self.fm.fileExists(atPath: self.whisperURL.path) {
                        try self.fm.removeItem(at: self.whisperURL)
                    }
                    try self.fm.moveItem(at: staging, to: self.whisperURL)
                    WhisperService.shared.prepareModel()
                    self.finish()
                } catch {
                    self.fail("Impossible d'enregistrer Whisper : \(error.localizedDescription)")
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.async { self.fail(error.localizedDescription) }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            AppDelegate.backgroundSessionCompletionHandler?()
            AppDelegate.backgroundSessionCompletionHandler = nil
        }
    }

    private func finish() {
        isInstalling = false
        progress = 1
        isReady = true
        status = "Sarah Engine installé. Traduction et assistant disponibles."
        errorMessage = nil
        UserDefaults.standard.set(true, forKey: "sarah.engine.setup.completed.v1")
        NotificationCenter.default.post(name: Notification.Name("SarahEngineInstalled"), object: nil)
    }

    private func fail(_ message: String) {
        isInstalling = false
        errorMessage = message
        status = "Téléchargement interrompu"
        refreshInstalledState()
    }
}

@available(iOS 16.0, *)
struct SarahEngineSetupView: View {
    @ObservedObject private var installer = SarahEngineInstaller.shared
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 21) {
                    Spacer(minLength: 22)
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.13))
                            .frame(width: 132, height: 132)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 57, weight: .light))
                            .foregroundStyle(.cyan)
                    }
                    Text("Bienvenue dans Sarah IA")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Sarah Engine")
                        .font(.system(size: 39, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Installe l’intelligence et la reconnaissance vocale de Sarah. Le téléchargement provient de ton dépôt GitHub et les modèles restent sur l’iPhone.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        ProgressView(value: installer.progress)
                            .tint(.cyan)
                            .scaleEffect(y: 1.6)
                        Text(installer.status)
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                        Text("\(Int(installer.progress * 100)) %")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.vertical, 14)

                    if let error = installer.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        if installer.isReady { onClose() }
                        else { installer.start() }
                    } label: {
                        HStack {
                            Image(systemName: installer.isReady ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            Text(installer.isReady ? "Commencer avec Sarah" : "Télécharger Sarah Engine")
                        }
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(installer.isInstalling)

                    Text("Wi-Fi recommandé. Le téléchargement peut continuer en arrière-plan. Les packs Google ML Kit sont distribués séparément par Google.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("À propos des moteurs")
                            .font(.headline)
                        Text("• Texte : Qwen3 1,7B ou Qwen3 0,6B (GGUF, llama.cpp)")
                        Text("• Reconnaissance vocale : OpenAI Whisper base (whisper.cpp)")
                        Text("• Traduction : Google ML Kit, avec moteurs Apple lorsque disponibles")
                        Text("• Voix de réponse : AVSpeechSynthesizer, voix d’iOS")
                        Text("• Application Watch : microphone et liaison WatchConnectivity")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
                    Button("Plus tard") { onClose() }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                        .disabled(installer.isInstalling)
                    Spacer(minLength: 15)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 490)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(
            LinearGradient(colors: [
                Color(red: 0.025, green: 0.04, blue: 0.13),
                Color(red: 0.04, green: 0.06, blue: 0.23),
                .black
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }
}
