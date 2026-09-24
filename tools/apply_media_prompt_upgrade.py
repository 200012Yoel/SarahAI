from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    (ROOT / rel).write_text(text, encoding="utf-8")


def replace_required(text: str, old: str, new: str, label: str, count: int = 0) -> str:
    if new in text:
        return text
    found = text.count(old)
    if found == 0:
        raise RuntimeError(f"Patch introuvable: {label}")
    if count:
        return text.replace(old, new, count)
    return text.replace(old, new)


def patch_ai_service() -> None:
    rel = "SarahIA/SarahIA/Services/AIService.swift"
    text = read(rel)

    music_old = "let musicCheck = SarahLocalMusicGenEngine.shared.detectIntent(trimmed)"
    music_new = """let baseMusicCheck = SarahLocalMusicGenEngine.shared.detectIntent(trimmed)
            let semanticMusic = SarahMediaPromptUnderstanding.music(trimmed)
            let musicCheck = SarahLocalMusicGenEngine.MusicIntent(
                isIntent: baseMusicCheck.isIntent,
                wantsLyrics: baseMusicCheck.wantsLyrics,
                prompt: semanticMusic.enhancedPrompt,
                language: semanticMusic.language,
                requestedSeconds: baseMusicCheck.requestedSeconds ?? semanticMusic.durationSeconds.map { Float($0) }
            )"""
    text = replace_required(text, music_old, music_new, "AIService music semantics")

    video_old = "let videoCheck = SarahLocalVideoGenEngine.shared.detectVideoIntent(trimmed)"
    video_new = """let videoCheck = SarahLocalVideoGenEngine.shared.detectVideoIntent(trimmed)
        let semanticVideo = SarahMediaPromptUnderstanding.video(trimmed)"""
    text = replace_required(text, video_old, video_new, "AIService video semantics")
    text = text.replace("prompt: videoCheck.prompt,", "prompt: semanticVideo.enhancedPrompt,")
    text = text.replace("duration: videoCheck.duration,", "duration: semanticVideo.durationSeconds,")
    text = text.replace("vertical: videoCheck.isVertical", "vertical: semanticVideo.aspectRatio == .portrait")
    text = text.replace("videoCheck.isVertical ?", "semanticVideo.aspectRatio == .portrait ?")
    text = text.replace("Int(videoCheck.duration)", "Int(semanticVideo.durationSeconds)")

    image_old = "let prompt = imageCheck.cleanedPrompt"
    image_new = """let prompt = imageCheck.cleanedPrompt
            let semanticImage = SarahMediaPromptUnderstanding.image(prompt)"""
    text = replace_required(text, image_old, image_new, "AIService image semantics")
    text = text.replace("generateImage(prompt: prompt)", "generateImage(prompt: semanticImage.enhancedPrompt)")

    write(rel, text)


def patch_multi_agent() -> None:
    rel = "SarahIA/SarahIA/Services/MultiAgentCoordinator.swift"
    text = read(rel)

    if "semanticMusic = SarahMediaPromptUnderstanding.music" not in text:
        pattern = re.compile(r"(?P<indent>[ \t]*)let musicCheck = SarahLocalMusicGenEngine\.shared\.detectIntent\((?P<expr>[^\n]+)\)")
        def music_repl(m):
            ind = m.group("indent")
            expr = m.group("expr")
            return (
                f"{ind}let baseMusicCheck = SarahLocalMusicGenEngine.shared.detectIntent({expr})\n"
                f"{ind}let semanticMusic = SarahMediaPromptUnderstanding.music({expr})\n"
                f"{ind}let musicCheck = SarahLocalMusicGenEngine.MusicIntent(\n"
                f"{ind}    isIntent: baseMusicCheck.isIntent,\n"
                f"{ind}    wantsLyrics: baseMusicCheck.wantsLyrics,\n"
                f"{ind}    prompt: semanticMusic.enhancedPrompt,\n"
                f"{ind}    language: semanticMusic.language,\n"
                f"{ind}    requestedSeconds: baseMusicCheck.requestedSeconds ?? semanticMusic.durationSeconds.map {{ Float($0) }}\n"
                f"{ind})"
            )
        text, n = pattern.subn(music_repl, text)
        if n == 0:
            print("MultiAgent: aucun routeur musique direct à modifier")

    if "semanticVideo = SarahMediaPromptUnderstanding.video" not in text:
        pattern = re.compile(r"(?P<indent>[ \t]*)let localVideoIntent = SarahLocalVideoGenEngine\.shared\.detectVideoIntent\((?P<expr>[^\n]+)\)")
        def video_repl(m):
            ind = m.group("indent")
            expr = m.group("expr")
            return (
                f"{ind}let localVideoIntent = SarahLocalVideoGenEngine.shared.detectVideoIntent({expr})\n"
                f"{ind}let semanticVideo = SarahMediaPromptUnderstanding.video({expr})"
            )
        text, _ = pattern.subn(video_repl, text)

    text = text.replace("prompt: localVideoIntent.prompt,", "prompt: semanticVideo.enhancedPrompt,")
    text = text.replace("duration: localVideoIntent.duration,", "duration: semanticVideo.durationSeconds,")
    text = text.replace("vertical: localVideoIntent.isVertical", "vertical: semanticVideo.aspectRatio == .portrait")
    text = text.replace("localVideoIntent.isVertical ?", "semanticVideo.aspectRatio == .portrait ?")
    text = text.replace("Int(localVideoIntent.duration)", "Int(semanticVideo.durationSeconds)")

    if "semanticImage = SarahMediaPromptUnderstanding.image" not in text:
        text = text.replace(
            "let prompt = imageCheck.isIntent ? imageCheck.cleanedPrompt : trimmed",
            "let prompt = imageCheck.isIntent ? imageCheck.cleanedPrompt : trimmed\n        let semanticImage = SarahMediaPromptUnderstanding.image(prompt)"
        )
    text = text.replace("generateImage(prompt: prompt)", "generateImage(prompt: semanticImage.enhancedPrompt)")

    write(rel, text)


def patch_music_engine() -> None:
    rel = "SarahIA/SarahIA/Services/SarahLocalMusicGenEngine.swift"
    text = read(rel)
    if "let semantic = SarahMediaPromptUnderstanding.music(clean)" in text:
        return

    marker = """        if prompt.count < 3 {
            prompt = "instrumental doux et mélodique"
        }

        return MusicIntent("""
    replacement = """        if prompt.count < 3 {
            prompt = "instrumental doux et mélodique"
        }

        let semantic = SarahMediaPromptUnderstanding.music(clean)
        let finalPrompt = semantic.enhancedPrompt.isEmpty ? prompt : semantic.enhancedPrompt
        let finalDuration = requestedSeconds ?? semantic.durationSeconds.map { Float($0) }

        return MusicIntent("""
    text = replace_required(text, marker, replacement, "music engine semantic bridge", count=1)
    text = text.replace("            prompt: prompt,\n            language: language,\n            requestedSeconds: requestedSeconds", "            prompt: finalPrompt,\n            language: semantic.language.isEmpty ? language : semantic.language,\n            requestedSeconds: finalDuration", 1)
    write(rel, text)


def patch_video_engine() -> None:
    rel = "SarahIA/SarahIA/Services/SarahLocalImageGenEngine.swift"
    text = read(rel)
    if "let semanticVideo = SarahMediaPromptUnderstanding.video(clean)" not in text:
        needle = """    public func detectVideoIntent(_ text: String) -> VideoIntent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)"""
        replacement = needle + "\n        let semanticVideo = SarahMediaPromptUnderstanding.video(clean)"
        text = replace_required(text, needle, replacement, "video engine semantic bridge", count=1)

    old = """        return VideoIntent(
            isIntent: true,
            prompt: prompt,
            duration: requestedDuration(from: clean) ?? 6,
            isVertical: vertical
        )"""
    new = """        return VideoIntent(
            isIntent: true,
            prompt: semanticVideo.enhancedPrompt,
            duration: semanticVideo.durationSeconds,
            isVertical: semanticVideo.aspectRatio == .portrait
        )"""
    text = replace_required(text, old, new, "video engine semantic return", count=1)
    write(rel, text)


def patch_image_service() -> None:
    rel = "SarahIA/SarahIA/Services/OpenSourceImageGenerationService.swift"
    text = read(rel)

    old_triggers = '            "generate an image of ", "generate a picture of ", "draw me "'
    new_triggers = '            "generate an image of ", "generate a picture of ", "draw me ",\n            "crée une affiche ", "cree une affiche ", "crée un poster ", "cree un poster ",\n            "crée un logo ", "cree un logo ", "crée un fond d’écran ", "cree un fond d ecran ",\n            "visualise ", "rends-moi une image ", "rends moi une image "'
    if new_triggers not in text:
        text = replace_required(text, old_triggers, new_triggers, "image intent vocabulary", count=1)

    if "let semantic = SarahMediaPromptUnderstanding.image(clean)" not in text:
        anchor = """        let lower = clean.lowercased()
        var base = clean"""
        repl = """        let lower = clean.lowercased()
        let semantic = SarahMediaPromptUnderstanding.image(clean)
        var base = semantic.enhancedPrompt"""
        text = replace_required(text, anchor, repl, "image semantic enhancer", count=1)

    write(rel, text)


def patch_about() -> None:
    rel = "SarahIA/SarahIA/Views/SettingsView.swift"
    text = read(rel)
    if 'Section("Modèles génératifs")' in text:
        return

    anchor = """            Section("Informations légales") {"""
    section = """            Section("Modèles génératifs") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo · \(SarahGenerativeModelCatalog.imageProfile().displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Licence : \(SarahGenerativeModelCatalog.imageProfile().licenseName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vidéo · \(SarahGenerativeModelCatalog.videoProfile().displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Licence : \(SarahGenerativeModelCatalog.videoProfile().licenseName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(SarahGenerativeModelCatalog.videoProfile().note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Musique · \(SarahGenerativeModelCatalog.musicProfile().displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Licence : \(SarahGenerativeModelCatalog.musicProfile().licenseName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Les conditions commerciales exactes sont indiquées dans Licences et notices. Sarah ne présente jamais une licence conditionnelle comme libre de droits.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

""" + anchor
    text = replace_required(text, anchor, section, "About model section", count=1)
    write(rel, text)


def patch_3d_studio() -> None:
    rel = "SarahIA/SarahIA/Views/VAICodingStudioView.swift"
    text = read(rel)
    if "VAI3DPreviewRepresentable" in text:
        return

    text = text.replace("import WebKit\n", "import WebKit\nimport SceneKit\n", 1)

    state_anchor = """    @State private var isShowingFigmaSheet: Bool = false
    
    enum StudioTab {"""
    state_repl = """    @State private var isShowingFigmaSheet: Bool = false
    @State private var sceneWidth: Double = 8
    @State private var sceneLength: Double = 10
    @State private var sceneFloors: Double = 2
    @State private var sceneFloorHeight: Double = 2.7
    
    enum StudioTab {"""
    text = replace_required(text, state_anchor, state_repl, "3D studio state", count=1)
    text = text.replace("        case shortcuts\n        case cloudDeploy", "        case shortcuts\n        case scene3D\n        case cloudDeploy", 1)
    text = text.replace('                    Text("⚡ Raccourcis").tag(StudioTab.shortcuts)\n                    Text("🚀 Cloud & Déploiement").tag(StudioTab.cloudDeploy)', '                    Text("⚡ Raccourcis").tag(StudioTab.shortcuts)\n                    Text("🧊 3D").tag(StudioTab.scene3D)\n                    Text("🚀 Cloud & Déploiement").tag(StudioTab.cloudDeploy)', 1)

    content_old = """                } else if selectedTab == .shortcuts {
                    // Compilateur & Exportateur Apple Shortcuts (.shortcut)
                    shortcutsTabContent
                } else {
                    // Déploiement en Ligne, GitHub, Gmail & Play Console
                    cloudDeployTabContent
                }"""
    content_new = """                } else if selectedTab == .shortcuts {
                    // Compilateur & Exportateur Apple Shortcuts (.shortcut)
                    shortcutsTabContent
                } else if selectedTab == .scene3D {
                    scene3DTabContent
                } else {
                    // Déploiement en Ligne, GitHub, Gmail & Play Console
                    cloudDeployTabContent
                }"""
    text = replace_required(text, content_old, content_new, "3D tab routing", count=1)

    marker = """    // MARK: - Onglet Raccourcis Apple
    
    private var shortcutsTabContent: some View {"""
    scene_block = r'''    // MARK: - Studio 3D paramétrique

    private var scene3DTabContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VAI3DPreviewRepresentable(
                    width: sceneWidth,
                    length: sceneLength,
                    floors: max(1, Int(sceneFloors.rounded())),
                    floorHeight: sceneFloorHeight
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .sarahLiquidGlass(cornerRadius: 18, tint: Color(red: 0.15, green: 0.72, blue: 1.0), intensity: 0.08)

                VStack(spacing: 12) {
                    parameterSlider(title: "Largeur", value: $sceneWidth, range: 3...25, suffix: "m")
                    parameterSlider(title: "Longueur", value: $sceneLength, range: 3...35, suffix: "m")
                    parameterSlider(title: "Étages", value: $sceneFloors, range: 1...5, step: 1, suffix: "")
                    parameterSlider(title: "Hauteur sous plafond", value: $sceneFloorHeight, range: 2.2...4.5, step: 0.1, suffix: "m")
                }
                .padding(14)
                .sarahLiquidGlass(cornerRadius: 18, tint: Color(red: 0.15, green: 0.72, blue: 1.0), intensity: 0.06)

                Button(action: send3DBriefToRaphael) {
                    HStack {
                        Image(systemName: "cube.transparent")
                        Text("Envoyer le brief 3D à Raphaël")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color(red: 0.15, green: 0.72, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
        }
    }

    private func parameterSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.5,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(value.wrappedValue, specifier: step < 1 ? \"%.1f\" : \"%.0f\")\(suffix)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray)
            }
            Slider(value: value, in: range, step: step)
                .tint(Color(red: 0.15, green: 0.72, blue: 1.0))
        }
    }

    private func send3DBriefToRaphael() {
        HapticService.shared.buttonTap()
        let floors = max(1, Int(sceneFloors.rounded()))
        let prompt = """
        Raphaël, crée une scène 3D paramétrique éditable avec ce brief :
        - largeur : \(String(format: "%.1f", sceneWidth)) m
        - longueur : \(String(format: "%.1f", sceneLength)) m
        - étages : \(floors)
        - hauteur sous plafond : \(String(format: "%.1f", sceneFloorHeight)) m
        Commence par confirmer les paramètres manquants utiles (pièces, ouvertures, matériaux, éclairage et style), puis génère une structure exploitable par le Studio 3D.
        """
        viewModel.activeAgent = .esther
        viewModel.sendMessage(prompt)
    }

    // MARK: - Onglet Raccourcis Apple
    
    private var shortcutsTabContent: some View {'''
    text = replace_required(text, marker, scene_block, "3D studio content", count=1)

    tail = r'''

/// Aperçu SceneKit local du brief 3D. Il reste volontairement paramétrique :
/// l'interface HTML future pourra piloter les mêmes dimensions sans changer la logique Raphaël.
@available(iOS 14.0, *)
public struct VAI3DPreviewRepresentable: UIViewRepresentable {
    public var width: Double
    public var length: Double
    public var floors: Int
    public var floorHeight: Double

    public init(width: Double, length: Double, floors: Int, floorHeight: Double) {
        self.width = width
        self.length = length
        self.floors = floors
        self.floorHeight = floorHeight
    }

    public func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        return view
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        let scene = SCNScene()
        let root = scene.rootNode

        let safeWidth = max(3.0, width)
        let safeLength = max(3.0, length)
        let safeFloors = max(1, floors)
        let safeHeight = max(2.2, floorHeight)
        let wallThickness = 0.12

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        material.roughness.contents = 0.62

        let accent = SCNMaterial()
        accent.diffuse.contents = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.95)
        accent.roughness.contents = 0.38

        for floor in 0..<safeFloors {
            let baseY = Double(floor) * safeHeight

            let slab = SCNBox(width: safeWidth, height: 0.14, length: safeLength, chamferRadius: 0.04)
            slab.materials = [floor == 0 ? material : accent]
            let slabNode = SCNNode(geometry: slab)
            slabNode.position = SCNVector3(0, Float(baseY), 0)
            root.addChildNode(slabNode)

            let wallH = safeHeight - 0.15
            let frontBack = SCNBox(width: safeWidth, height: wallH, length: wallThickness, chamferRadius: 0.03)
            frontBack.materials = [material]
            for z in [-safeLength / 2, safeLength / 2] {
                let node = SCNNode(geometry: frontBack.copy() as? SCNGeometry)
                node.position = SCNVector3(0, Float(baseY + safeHeight / 2), Float(z))
                root.addChildNode(node)
            }

            let side = SCNBox(width: wallThickness, height: wallH, length: safeLength, chamferRadius: 0.03)
            side.materials = [material]
            for x in [-safeWidth / 2, safeWidth / 2] {
                let node = SCNNode(geometry: side.copy() as? SCNGeometry)
                node.position = SCNVector3(Float(x), Float(baseY + safeHeight / 2), 0)
                root.addChildNode(node)
            }
        }

        let roof = SCNBox(width: safeWidth + 0.18, height: 0.18, length: safeLength + 0.18, chamferRadius: 0.05)
        roof.materials = [accent]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, Float(Double(safeFloors) * safeHeight), 0)
        root.addChildNode(roofNode)

        let camera = SCNCamera()
        camera.fieldOfView = 48
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        let extent = max(safeWidth, safeLength)
        cameraNode.position = SCNVector3(Float(extent * 1.15), Float(Double(safeFloors) * safeHeight * 0.85 + 2), Float(extent * 1.35))
        cameraNode.look(at: SCNVector3(0, Float(Double(safeFloors) * safeHeight * 0.45), 0))
        root.addChildNode(cameraNode)

        let key = SCNLight()
        key.type = .omni
        key.intensity = 900
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(6, 10, 8)
        root.addChildNode(keyNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 480
        ambient.color = UIColor(white: 0.72, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        uiView.scene = scene
        uiView.pointOfView = cameraNode
    }
}
'''
    text = text.rstrip() + tail + "\n"
    write(rel, text)


def main() -> None:
    patch_ai_service()
    patch_multi_agent()
    patch_music_engine()
    patch_video_engine()
    patch_image_service()
    patch_about()
    patch_3d_studio()
    print("Sarah media / 3D upgrade applied successfully")


if __name__ == "__main__":
    main()
