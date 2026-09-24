from pathlib import Path
import re

ROOT = Path('.')
VM = ROOT / 'SarahIA/SarahIA/ViewModels/ChatViewModel.swift'
CHAT = ROOT / 'SarahIA/SarahIA/Views/ChatScreenView.swift'


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Missing anchor: {label}')
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# ChatViewModel: restore the recent persistent voice-session orchestration.
# -----------------------------------------------------------------------------
vm = VM.read_text(encoding='utf-8')
if 'import UIKit' not in vm:
    vm = replace_once(vm, 'import AVFoundation\n', 'import AVFoundation\nimport UIKit\n', 'UIKit import')

if 'case starting' not in vm:
    vm = replace_once(vm, '    case idle\n    case listening(level: Float)', '    case idle\n    case starting\n    case listening(level: Float)', 'voice starting state')

if 'isVoiceMicrophoneMuted' not in vm:
    vm = replace_once(
        vm,
        '    @Published public var isContinuousConversationActive: Bool = false\n',
        '    @Published public var isContinuousConversationActive: Bool = false\n    @Published public var isVoiceMicrophoneMuted: Bool = false\n',
        'voice muted published state'
    )

if 'public func appendVisionAnalysis(' not in vm:
    anchor = '''    public init() {\n        restorePersistedState()\n        setupModeObserver()\n        bindCoreServices()\n    }\n'''
    addition = anchor + r'''

    public func appendVisionAnalysis(image: UIImage, result: LocalVisionEngine.VisionAnalysisResult) {
        let imageData = image.jpegData(compressionQuality: 0.88)
        let textSuffix = result.detectedText.isEmpty ? "" : "\n\n📝 **Texte détecté** : \(result.detectedText)"
        appendMessage(
            Message(
                content: "👁️ **Vision locale**\n\n\(result.naturalSpokenResponse)\(textSuffix)",
                isFromUser: false,
                imageData: imageData
            )
        )
    }

    public func appendImportedFile(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent.isEmpty ? "Fichier" : url.lastPathComponent
        do {
            let data = try Data(contentsOf: url)
            let previewData = data.prefix(24_000)
            let preview = String(data: previewData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var content = "📎 **Fichier ajouté : \(name)**"
            if let preview, !preview.isEmpty {
                content += "\n\n```\n\(String(preview.prefix(8_000)))\n```"
            }
            appendMessage(Message(content: content, isFromUser: true))
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = "Analyse le fichier \(name)"
            }
        } catch {
            inputText = "Impossible d'ouvrir \(name) : \(error.localizedDescription)"
        }
    }
'''
    vm = replace_once(vm, anchor, addition, 'media helper insertion')

# Add recognizer state forwarding once.
if 'switch AppleSpeechRecognizer.shared.state' not in vm:
    anchor = '''        ObservableSpeechRecognizer.shared.$micEnergyLevel\n            .receive(on: DispatchQueue.main)\n            .sink { [weak self] level in\n                self?.micInputLevel = level\n            }\n            .store(in: &cancellables)\n'''
    addition = anchor + r'''

        NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerStateChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                switch AppleSpeechRecognizer.shared.state {
                case .idle:
                    if self.isContinuousConversationActive,
                       !self.isVoiceMicrophoneMuted,
                       !self.voiceManager.isSpeaking,
                       !AppleSpeechRecognizer.shared.isListening {
                        self.voiceStatus = .idle
                    }
                case .listening:
                    self.isMicRunning = true
                    self.voiceStatus = .listening(level: self.micInputLevel)
                case .processing:
                    self.voiceStatus = .processing
                case .error(let message):
                    self.isMicRunning = false
                    self.voiceStatus = .error(message)
                }
            }
            .store(in: &cancellables)
'''
    vm = replace_once(vm, anchor, addition, 'speech state observer')

new_voice_block = r'''    private func setupVoicePipeline() {
        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            DispatchQueue.main.async { self?.liveTranscriptionText = partial }
        }

        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    self.voiceStatus = .idle
                    return
                }
                self.liveTranscriptionText = ""
                self.sendMessage(cleaned)
            }
        }

        voiceManager.onSpeechStarted = { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeaking = true
                self?.voiceStatus = .speaking
                self?.haptics.speechStarted()
            }
        }

        voiceManager.onSpeechFinished = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSpeaking = false
                self.voiceStatus = .idle
                self.haptics.speechFinished()

                if self.isContinuousConversationActive && !self.isVoiceMicrophoneMuted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        guard self.isContinuousConversationActive,
                              !self.isVoiceMicrophoneMuted,
                              !self.voiceManager.isSpeaking else { return }
                        AppleSpeechRecognizer.shared.startListening()
                        self.isMicRunning = AppleSpeechRecognizer.shared.isListening
                        self.voiceStatus = self.isMicRunning ? .listening(level: 0.0) : .idle
                    }
                }
            }
        }
    }

    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if isContinuousConversationActive {
            if isVoiceMicrophoneMuted { resumeVoiceMicrophone() } else { pauseVoiceMicrophone() }
            return
        }
        startVoiceConversation()
    }

    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        if voiceManager.isSpeaking {
            voiceStatus = .speaking
            return
        }

        guard !AppleSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        voiceStatus = .starting
        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        if isMicRunning { voiceStatus = .listening(level: 0.0) }
    }

    public func pauseVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        isVoiceMicrophoneMuted = true
        AppleSpeechRecognizer.shared.stopListening()
        isMicRunning = false
        micInputLevel = 0
        liveTranscriptionText = ""
        voiceStatus = voiceManager.isSpeaking ? .speaking : .idle
    }

    public func resumeVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        guard !voiceManager.isSpeaking else {
            voiceStatus = .speaking
            return
        }

        voiceStatus = .starting
        AppleSpeechRecognizer.shared.startListening()
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        if isMicRunning { voiceStatus = .listening(level: 0.0) }
    }

    public func endVoiceConversation() {
        stopVoiceConversation(stopSpeech: true)
        isShowingVoiceOrbModal = false
    }

    public func stopVoiceConversation(stopSpeech: Bool = true) {
        isContinuousConversationActive = false
        isVoiceMicrophoneMuted = false
        if stopSpeech { voiceManager.stop() }
        AppleSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.deactivateSession()
        isMicRunning = false
        micInputLevel = 0.0
        liveTranscriptionText = ""
        voiceStatus = .idle
    }

'''
pattern = re.compile(r'    private func setupVoicePipeline\(\) \{.*?(?=    public func speakMessage)', re.S)
vm, count = pattern.subn(new_voice_block, vm, count=1)
if count != 1:
    raise SystemExit(f'Could not replace voice orchestration, matches={count}')

if 'public func cancelCurrentGeneration()' not in vm:
    marker = '    // MARK: - Envoi de Message & Orchestration Multi-Agents\n'
    addition = r'''    public func cancelCurrentGeneration() {
        haptics.buttonTap()
        isTyping = false
        voiceStatus = .idle
        AIProgressiveScheduler.shared.cancelAllTasks()
    }

'''
    vm = replace_once(vm, marker, addition + marker, 'cancel generation insertion')

VM.write_text(vm, encoding='utf-8')

# -----------------------------------------------------------------------------
# ChatScreen: restore safe-area composer, attachments, persistent voice mini-bar.
# Absolutely no SceneKit / 3D code is introduced.
# -----------------------------------------------------------------------------
chat = CHAT.read_text(encoding='utf-8')
if 'import PhotosUI' not in chat:
    chat = replace_once(
        chat,
        'import SwiftUI\n',
        'import SwiftUI\nimport PhotosUI\nimport UniformTypeIdentifiers\nimport UIKit\n',
        'ChatScreen imports'
    )

state_anchor = '''    @State private var isShowingActionSheet: Bool = false\n    @State private var isShowingVoiceCallScreen: Bool = false\n'''
if 'isShowingPhotoPicker' not in chat:
    chat = replace_once(
        chat,
        state_anchor,
        state_anchor + '''    @State private var isShowingPhotoPicker: Bool = false\n    @State private var selectedPhotoItem: PhotosPickerItem? = nil\n    @State private var isShowingCamera: Bool = false\n    @State private var isShowingFileImporter: Bool = false\n''',
        'attachment state'
    )

if 'private func analyzeSelectedPhoto' not in chat:
    marker = '    private var topSafeArea: CGFloat {\n'
    helpers = r'''    private func analyzeSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run { viewModel.inputText = "Impossible de lire cette image." }
                    return
                }
                LocalVisionEngine.shared.recognizeObject(in: image) { result in
                    DispatchQueue.main.async {
                        viewModel.appendVisionAnalysis(image: image, result: result)
                    }
                }
            } catch {
                await MainActor.run { viewModel.inputText = "Impossible d'ouvrir la photo : \(error.localizedDescription)" }
            }
        }
    }

    private func handleCameraImage(_ image: UIImage) {
        LocalVisionEngine.shared.recognizeObject(in: image) { result in
            DispatchQueue.main.async {
                viewModel.appendVisionAnalysis(image: image, result: result)
            }
        }
    }

'''
    chat = replace_once(chat, marker, helpers + marker, 'attachment helpers')

old_bar = '''                // 3. Zone de saisie (au-dessus du Home Indicator ou collée au clavier)\n                MessageBar(\n                    text: $viewModel.inputText,\n                    activeAgent: $viewModel.activeAgent,\n                    isRecording: viewModel.isMicRunning,\n                    onSend: { text in\n                        viewModel.sendMessage(text)\n                    },\n                    onToggleMic: {\n                        viewModel.toggleMicrophone()\n                    },\n                    onOpenVoiceOrb: {\n                        viewModel.isShowingVoiceOrbModal = true\n                    },\n                    onOpenVAICoding: {\n                        viewModel.isShowingVAICodingStudio = true\n                    }\n                )\n'''
if old_bar in chat:
    chat = chat.replace(old_bar, '', 1)

old_tail = '''            .padding(.bottom, currentBottomPadding)\n        }\n        .ignoresSafeArea(.keyboard, edges: .bottom)\n'''
new_tail = r'''        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.isContinuousConversationActive && !viewModel.isShowingVoiceOrbModal {
                    HStack {
                        Spacer(minLength: 18)
                        CollapsedVoiceSessionBar(viewModel: viewModel)
                            .frame(maxWidth: 286)
                        Spacer(minLength: 18)
                    }
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                MessageBar(
                    text: $viewModel.inputText,
                    activeAgent: $viewModel.activeAgent,
                    isRecording: viewModel.isMicRunning,
                    isProcessing: viewModel.isGeneratingResponse,
                    onOpenPhotoLibrary: {
                        keyboard.dismiss()
                        selectedPhotoItem = nil
                        isShowingPhotoPicker = true
                    },
                    onOpenCamera: {
                        keyboard.dismiss()
                        isShowingCamera = true
                    },
                    onOpenFile: {
                        keyboard.dismiss()
                        isShowingFileImporter = true
                    },
                    onSend: { text in viewModel.sendMessage(text) },
                    onCancel: { viewModel.cancelCurrentGeneration() },
                    onToggleMic: { viewModel.toggleMicrophone() },
                    onOpenVoiceOrb: {
                        keyboard.dismiss()
                        viewModel.startVoiceConversation()
                        viewModel.isShowingVoiceOrbModal = true
                    },
                    onOpenVAICoding: { viewModel.isShowingVAICodingStudio = true }
                )
            }
            .padding(.bottom, keyboard.isVisible ? 8 : 38)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.02), Color.black.opacity(0.68)]),
                    startPoint: .top,
                    endPoint: .bottom
                ).allowsHitTesting(false)
            )
        }
'''
if old_tail not in chat:
    raise SystemExit('Missing old bottom layout anchor')
chat = chat.replace(old_tail, new_tail, 1)

# Voice sheet attachment callbacks + large presentation only.
old_settings = '''                onOpenSettings: {\n                    isShowingSettings = true\n                }\n'''
new_settings = '''                onOpenSettings: {\n                    isShowingSettings = true\n                },\n                onOpenPhotoLibrary: {\n                    selectedPhotoItem = nil\n                    isShowingPhotoPicker = true\n                },\n                onOpenCamera: {\n                    isShowingCamera = true\n                },\n                onOpenFile: {\n                    isShowingFileImporter = true\n                }\n'''
chat = chat.replace(old_settings, new_settings)
chat = chat.replace('.presentationDetents([.height(255), .large])', '.presentationDetents([.large])')

# Add the three native attachment surfaces after the voice sheet.
anchor = '''        .sheet(isPresented: $viewModel.isShowingVoiceOrbModal) {\n            voiceSheetContent\n        }\n'''
if '.photosPicker(' not in chat:
    addition = anchor + r'''        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { item in
            analyzeSelectedPhoto(item)
        }
        .sheet(isPresented: $isShowingCamera) {
            SarahCameraPicker { image in
                isShowingCamera = false
                if let image = image { handleCameraImage(image) }
            }
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.appendImportedFile(url: url)
            } else if case .failure(let error) = result {
                viewModel.inputText = "Impossible d'ouvrir le fichier : \(error.localizedDescription)"
            }
        }
'''
    chat = replace_once(chat, anchor, addition, 'attachment surfaces')

# Insert the persistent collapsed voice bar before WebsiteBrief.
if 'private struct CollapsedVoiceSessionBar' not in chat:
    marker = '/// Brief conservé entre une première maquette et ses améliorations.\n'
    collapsed = r'''@available(iOS 15.0, *)
private struct CollapsedVoiceSessionBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var pulse = false
    private var accent: Color { viewModel.activeAgent.themeColor }

    private var status: String {
        switch viewModel.voiceStatus {
        case .starting: return "Activation du micro…"
        case .processing: return "Réflexion…"
        case .speaking: return "\(viewModel.activeAgent.displayName) parle"
        case .error: return "Micro indisponible"
        default: return viewModel.isVoiceMicrophoneMuted ? "Micro coupé" : "À l’écoute"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.isShowingVoiceOrbModal = true
            } label: {
                ZStack {
                    Circle().fill(accent.opacity(0.22)).frame(width: 34, height: 34)
                    Circle().stroke(accent.opacity(0.62), lineWidth: 1).frame(width: 34, height: 34)
                        .scaleEffect(pulse ? 1.08 : 0.94).opacity(pulse ? 0.28 : 0.82)
                    Image(systemName: "waveform").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }
            }.buttonStyle(PlainButtonStyle())

            Text(status).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.white).lineLimit(1)
            Spacer(minLength: 2)

            Button {
                HapticService.shared.buttonTap()
                viewModel.toggleMicrophone()
            } label: {
                Image(systemName: viewModel.isVoiceMicrophoneMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial))
            }.buttonStyle(PlainButtonStyle())

            Button {
                HapticService.shared.buttonTap()
                viewModel.endVoiceConversation()
            } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accent.opacity(0.22)))
            }.buttonStyle(PlainButtonStyle())
        }
        .padding(.leading, 10).padding(.trailing, 8).frame(height: 50)
        .sarahLiquidGlass(cornerRadius: 25, tint: accent, intensity: 0.15)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

'''
    chat = replace_once(chat, marker, collapsed + marker, 'collapsed voice bar')

# Camera bridge, no third-party code and no 3D dependency.
if 'private struct SarahCameraPicker' not in chat:
    chat += r'''

@available(iOS 15.0, *)
private struct SarahCameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.mediaTypes = ["public.image"]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }
    }
}
'''

# Hard non-3D guard for the two restored production files.
for token in ['SceneKit', 'RealityKit', 'Model3D', 'Sarah3DEnvironmentStudioView', 'cube.transparent']:
    if token in chat:
        raise SystemExit(f'Forbidden 3D token reintroduced in ChatScreen: {token}')

CHAT.write_text(chat, encoding='utf-8')
print('Restored latest non-3D composer, attachments and persistent voice UI.')
