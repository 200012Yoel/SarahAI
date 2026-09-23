from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch_chat_screen():
    path = ROOT / "SarahIA/SarahIA/Views/ChatScreenView.swift"
    text = path.read_text(encoding="utf-8")

    if "import PhotosUI" not in text:
        text = text.replace(
            "import SwiftUI\n",
            "import SwiftUI\nimport PhotosUI\nimport AVKit\nimport AVFoundation\nimport CoreTransferable\nimport UniformTypeIdentifiers\nimport QuartzCore\n",
            1,
        )

    state_old = """    @State private var isShowingActionSheet: Bool = false
    @State private var isShowingVoiceCallScreen: Bool = false
    @State private var isShowingAgentPicker: Bool = false
"""
    state_new = """    @State private var isShowingActionSheet: Bool = false
    @State private var isShowingVoiceCallScreen: Bool = false
    @State private var isShowingAgentPicker: Bool = false
    @State private var isShowingVisionPicker: Bool = false
    @State private var selectedVisionItem: PhotosPickerItem? = nil
    @State private var isShowingNathanVideoPicker: Bool = false
    @State private var selectedNathanVideoItem: PhotosPickerItem? = nil
    @State private var nathanEditorVideoURL: URL? = nil
    @State private var isShowingNathanVideoEditor: Bool = false
"""
    if state_new not in text:
        if state_old not in text:
            raise RuntimeError("ChatScreenView state anchor not found")
        text = text.replace(state_old, state_new, 1)

    methods_anchor = """    private var topSafeArea: CGFloat {
"""
    methods = r'''    private func analyzeSelectedVisionItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run {
                        viewModel.inputText = "Impossible de lire cette image."
                    }
                    return
                }

                LocalVisionEngine.shared.recognizeObject(in: image) { result in
                    viewModel.appendVisionAnalysis(image: image, result: result)
                }
            } catch {
                await MainActor.run {
                    viewModel.inputText = "Impossible d'ouvrir la photo : \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadSelectedNathanVideo(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: SarahPickedMovie.self) else {
                    return
                }
                await MainActor.run {
                    viewModel.activeAgent = .nathan
                    nathanEditorVideoURL = movie.url
                    isShowingNathanVideoEditor = true
                }
            } catch {
                await MainActor.run {
                    viewModel.inputText = "Impossible d'ouvrir cette vidéo : \(error.localizedDescription)"
                }
            }
        }
    }

    private var topSafeArea: CGFloat {
'''
    if "analyzeSelectedVisionItem" not in text:
        if methods_anchor not in text:
            raise RuntimeError("ChatScreenView methods anchor not found")
        text = text.replace(methods_anchor, methods, 1)

    modifier_anchor = """        .fullScreenCover(isPresented: $isShowingVoiceCallScreen) {
            VoiceCallScreenView()
        }
"""
    modifiers = """        .fullScreenCover(isPresented: $isShowingVoiceCallScreen) {
            VoiceCallScreenView()
        }
        .photosPicker(
            isPresented: $isShowingVisionPicker,
            selection: $selectedVisionItem,
            matching: .images
        )
        .onChange(of: selectedVisionItem) { item in
            analyzeSelectedVisionItem(item)
        }
        .photosPicker(
            isPresented: $isShowingNathanVideoPicker,
            selection: $selectedNathanVideoItem,
            matching: .videos
        )
        .onChange(of: selectedNathanVideoItem) { item in
            loadSelectedNathanVideo(item)
        }
        .fullScreenCover(isPresented: $isShowingNathanVideoEditor) {
            if let sourceURL = nathanEditorVideoURL {
                NathanVideoEditorView(sourceURL: sourceURL, viewModel: viewModel)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
"""
    if ".photosPicker(\n            isPresented: $isShowingVisionPicker" not in text:
        if modifier_anchor not in text:
            raise RuntimeError("ChatScreenView modifier anchor not found")
        text = text.replace(modifier_anchor, modifiers, 1)

    vision_old = """                    .default(Text("👁️ Vision & Analyse Multimodale (OCR)")) {
                        viewModel.inputText = "Analyse cette photo et décris ce que tu vois"
                    },
"""
    vision_new = """                    .default(Text("👁️ Ajouter une photo · Vision & OCR local")) {
                        selectedVisionItem = nil
                        isShowingVisionPicker = true
                    },
"""
    if vision_new not in text:
        if vision_old not in text:
            raise RuntimeError("Vision action not found")
        text = text.replace(vision_old, vision_new, 1)

    video_old = """                    .default(Text("🎬 Générer une Vidéo / Short")) {
                        viewModel.activeAgent = .nathan
                        viewModel.inputText = "Génère une vidéo de 6 secondes "
                    },
"""
    video_new = """                    .default(Text("🎬 Générer une Vidéo / Short")) {
                        viewModel.activeAgent = .nathan
                        viewModel.inputText = "Génère une vidéo de 6 secondes "
                    },
                    .default(Text("✂️ Nathan · Monter une vidéo")) {
                        viewModel.activeAgent = .nathan
                        selectedNathanVideoItem = nil
                        isShowingNathanVideoPicker = true
                    },
"""
    if "✂️ Nathan · Monter une vidéo" not in text:
        if video_old not in text:
            raise RuntimeError("Video action not found")
        text = text.replace(video_old, video_new, 1)

    if "public struct NathanVideoEditorView" not in text:
        text = text.rstrip() + r'''

// MARK: - Import média local

@available(iOS 16.0, *)
public struct SarahPickedMovie: Transferable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("sarah-import-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return SarahPickedMovie(url: destination)
        }
    }
}

public enum NathanVideoAspect: String, CaseIterable, Identifiable {
    case original = "Original"
    case vertical = "9:16"
    case landscape = "16:9"

    public var id: String { rawValue }
}

// MARK: - Éditeur vidéo Nathan

@available(iOS 16.0, *)
public struct NathanVideoEditorView: View {
    public let sourceURL: URL
    @ObservedObject public var viewModel: ChatViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var duration: Double = 1
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    @State private var targetAspect: NathanVideoAspect = .vertical
    @State private var overlayText: String = ""
    @State private var statusText: String = "Prêt"
    @State private var isExporting = false

    public init(sourceURL: URL, viewModel: ChatViewModel) {
        self.sourceURL = sourceURL
        self.viewModel = viewModel
        _player = State(initialValue: AVPlayer(url: sourceURL))
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VideoPlayer(player: player)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .sarahLiquidGlass(cornerRadius: 22, tint: .purple, intensity: 0.06)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Découpage")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Text("Début")
                                Spacer()
                                Text(formatTime(trimStart))
                            }
                            .foregroundColor(.secondary)
                            Slider(value: $trimStart, in: 0...max(0.1, min(trimEnd - 0.1, duration)), step: 0.05)
                                .tint(.purple)

                            HStack {
                                Text("Fin")
                                Spacer()
                                Text(formatTime(trimEnd))
                            }
                            .foregroundColor(.secondary)
                            Slider(value: $trimEnd, in: min(duration, trimStart + 0.1)...max(duration, trimStart + 0.1), step: 0.05)
                                .tint(.purple)
                        }
                        .padding(14)
                        .sarahLiquidGlass(cornerRadius: 18, tint: .purple, intensity: 0.06)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Format social")
                                .font(.headline)
                                .foregroundColor(.white)
                            Picker("Format", selection: $targetAspect) {
                                ForEach(NathanVideoAspect.allCases) { aspect in
                                    Text(aspect.rawValue).tag(aspect)
                                }
                            }
                            .pickerStyle(.segmented)

                            TextField("Texte à afficher sur la vidéo", text: $overlayText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(14)
                        .sarahLiquidGlass(cornerRadius: 18, tint: .purple, intensity: 0.06)

                        Button(action: applyNathanSocialPreset) {
                            Label("Nathan · Préparer pour Reels / Shorts", systemImage: "wand.and.stars")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)

                        Button(action: exportVideo) {
                            HStack {
                                if isExporting { ProgressView().tint(.white) }
                                Image(systemName: "square.and.arrow.up")
                                Text(isExporting ? "Export en cours…" : "Exporter le montage")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .foregroundColor(.white)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isExporting || trimEnd <= trimStart)

                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Nathan · Montage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await loadDuration() }
        .onDisappear { player.pause() }
    }

    private func loadDuration() async {
        do {
            let asset = AVURLAsset(url: sourceURL)
            let loaded = try await asset.load(.duration)
            let seconds = max(0.1, loaded.seconds)
            await MainActor.run {
                duration = seconds
                trimStart = 0
                trimEnd = seconds
            }
        } catch {
            await MainActor.run {
                statusText = "Impossible de lire la durée : \(error.localizedDescription)"
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let safe = max(0, seconds)
        let minutes = Int(safe) / 60
        let secs = Int(safe) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func applyNathanSocialPreset() {
        HapticService.shared.buttonTap()
        targetAspect = .vertical
        if duration > 1 {
            trimStart = min(0.15, duration * 0.02)
            trimEnd = max(trimStart + 0.2, duration - min(0.15, duration * 0.02))
        }
        statusText = "Preset Nathan : vertical 9:16, export social et coupe des marges de début/fin."
        viewModel.activeAgent = .nathan
    }

    private func exportVideo() {
        guard !isExporting else { return }
        isExporting = true
        statusText = "Nathan prépare le montage…"

        NathanVideoEditorEngine.export(
            sourceURL: sourceURL,
            trimStart: trimStart,
            trimEnd: trimEnd,
            aspect: targetAspect,
            overlayText: overlayText
        ) { result in
            DispatchQueue.main.async {
                isExporting = false
                switch result {
                case .success(let url):
                    statusText = "Montage exporté."
                    viewModel.appendEditedVideo(
                        url: url,
                        title: overlayText.isEmpty ? "Montage Nathan" : overlayText,
                        vertical: targetAspect == .vertical
                    )
                case .failure(let error):
                    statusText = "Échec de l'export : \(error.localizedDescription)"
                }
            }
        }
    }
}

@available(iOS 16.0, *)
public enum NathanVideoEditorEngine {
    public static func export(
        sourceURL: URL,
        trimStart: Double,
        trimEnd: Double,
        aspect: NathanVideoAspect,
        overlayText: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: sourceURL)
        guard let sourceVideo = asset.tracks(withMediaType: .video).first else {
            completion(.failure(NSError(
                domain: "NathanVideoEditor",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Aucune piste vidéo trouvée."]
            )))
            return
        }

        let assetDuration = max(0.1, asset.duration.seconds)
        let safeStart = min(max(0, trimStart), max(0, assetDuration - 0.1))
        let safeEnd = min(max(safeStart + 0.1, trimEnd), assetDuration)
        let range = CMTimeRange(
            start: CMTime(seconds: safeStart, preferredTimescale: 600),
            duration: CMTime(seconds: safeEnd - safeStart, preferredTimescale: 600)
        )

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(.failure(NSError(
                domain: "NathanVideoEditor",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de créer la piste vidéo."]
            )))
            return
        }

        do {
            try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
            if let sourceAudio = asset.tracks(withMediaType: .audio).first,
               let audioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try? audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
            }
        } catch {
            completion(.failure(error))
            return
        }

        let sourceRect = CGRect(origin: .zero, size: sourceVideo.naturalSize)
            .applying(sourceVideo.preferredTransform)
        let orientedSize = CGSize(
            width: max(1, abs(sourceRect.width)),
            height: max(1, abs(sourceRect.height))
        )

        let renderSize: CGSize
        switch aspect {
        case .vertical:
            renderSize = CGSize(width: 720, height: 1280)
        case .landscape:
            renderSize = CGSize(width: 1280, height: 720)
        case .original:
            renderSize = CGSize(
                width: max(2, floor(orientedSize.width / 2) * 2),
                height: max(2, floor(orientedSize.height / 2) * 2)
            )
        }

        let scale = min(
            renderSize.width / orientedSize.width,
            renderSize.height / orientedSize.height
        )
        let fitted = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let tx = (renderSize.width - fitted.width) / 2
        let ty = (renderSize.height - fitted.height) / 2

        var transform = sourceVideo.preferredTransform
        transform = transform.concatenating(
            CGAffineTransform(translationX: -sourceRect.minX, y: -sourceRect.minY)
        )
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: tx, y: ty))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(transform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: range.duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let cleanOverlay = overlayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanOverlay.isEmpty {
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: renderSize)

            let videoLayer = CALayer()
            videoLayer.frame = parentLayer.bounds
            parentLayer.addSublayer(videoLayer)

            let textLayer = CATextLayer()
            textLayer.string = cleanOverlay
            textLayer.alignmentMode = .center
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.30).cgColor
            textLayer.cornerRadius = 12
            textLayer.fontSize = max(28, renderSize.width * 0.045)
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.isWrapped = true
            textLayer.frame = CGRect(
                x: renderSize.width * 0.08,
                y: renderSize.height * 0.08,
                width: renderSize.width * 0.84,
                height: renderSize.height * 0.12
            )
            parentLayer.addSublayer(textLayer)

            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                postProcessingAsVideoLayer: videoLayer,
                in: parentLayer
            )
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(NSError(
                domain: "NathanVideoEditor",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de créer l'exporteur vidéo."]
            )))
            return
        }

        let canMP4 = exporter.supportedFileTypes.contains(.mp4)
        let outputType: AVFileType = canMP4 ? .mp4 : .mov
        let ext = canMP4 ? "mp4" : "mov"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NathanEdit-\(UUID().uuidString).\(ext)")
        try? FileManager.default.removeItem(at: outputURL)

        exporter.outputURL = outputURL
        exporter.outputFileType = outputType
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outputURL))
            case .cancelled:
                completion(.failure(NSError(
                    domain: "NathanVideoEditor",
                    code: 499,
                    userInfo: [NSLocalizedDescriptionKey: "Export annulé."]
                )))
            default:
                completion(.failure(exporter.error ?? NSError(
                    domain: "NathanVideoEditor",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "L'export vidéo a échoué."]
                )))
            }
        }
    }
}
''' + "\n"

    path.write_text(text, encoding="utf-8")


def patch_view_model():
    path = ROOT / "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
    text = path.read_text(encoding="utf-8")

    if "import UIKit" not in text:
        text = text.replace("import AVFoundation\n", "import AVFoundation\nimport UIKit\n", 1)

    anchor = """    // MARK: - Liaison des Services
"""
    methods = r'''    public func appendVisionAnalysis(
        image: UIImage,
        result: LocalVisionEngine.VisionAnalysisResult
    ) {
        let imageData = image.jpegData(compressionQuality: 0.88)
        let textSuffix = result.detectedText.isEmpty
            ? ""
            : "\n\n📝 **Texte détecté** : \(result.detectedText)"

        appendMessage(
            Message(
                content: "👁️ **Vision locale**\n\n\(result.naturalSpokenResponse)\(textSuffix)",
                isFromUser: false,
                imageData: imageData
            )
        )
    }

    public func appendEditedVideo(url: URL, title: String, vertical: Bool) {
        appendMessage(
            Message(
                content: "✂️ **Montage Nathan exporté**\n\n\(title)",
                isFromUser: false,
                generatedVideoURL: url.absoluteString,
                videoGenerationPrompt: "Montage vidéo local Nathan",
                videoIsVertical: vertical,
                isGeneratingVideo: false
            )
        )
    }

    // MARK: - Liaison des Services
'''
    if "public func appendVisionAnalysis(" not in text:
        if anchor not in text:
            raise RuntimeError("ChatViewModel service anchor not found")
        text = text.replace(anchor, methods, 1)

    path.write_text(text.rstrip() + "\n", encoding="utf-8")


patch_chat_screen()
patch_view_model()
print("Nathan media picker/editor patch applied")
