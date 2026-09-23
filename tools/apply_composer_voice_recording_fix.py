from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAT = ROOT / "SarahIA/SarahIA/Views/ChatScreenView.swift"

text = CHAT.read_text(encoding="utf-8")


def replace_once(old: str, new: str, label: str):
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Missing expected block: {label}")
    text = text.replace(old, new, 1)

replace_once(
    "import QuartzCore\n",
    "import QuartzCore\nimport SceneKit\n",
    "SceneKit import",
)

replace_once(
    "    @State private var isShowingNathanVideoEditor: Bool = false\n",
    "    @State private var isShowingNathanVideoEditor: Bool = false\n    @State private var isShowing3DStudio: Bool = false\n",
    "3D studio state",
)

replace_once(
    '''        .onAppear {\n            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {''',
    '''        .onAppear {\n            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-3d") {\n                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {\n                    isShowing3DStudio = true\n                }\n            }\n\n            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {''',
    "3D smoke route",
)

replace_once(
    '''        .fullScreenCover(isPresented: $viewModel.isShowingVAICodingStudio) {\n            VAICodingStudioView(viewModel: viewModel)\n        }''',
    '''        .fullScreenCover(isPresented: $viewModel.isShowingVAICodingStudio) {\n            VAICodingStudioView(viewModel: viewModel)\n        }\n        .fullScreenCover(isPresented: $isShowing3DStudio) {\n            Sarah3DEnvironmentStudioView()\n        }''',
    "3D studio cover",
)

replace_once(
    '''                    .default(Text("🎬 Générer une Vidéo / Short")) {\n                        viewModel.activeAgent = .nathan\n                        viewModel.inputText = "Génère une vidéo de 6 secondes "\n                    },''',
    '''                    .default(Text("🎬 Générer une Vidéo / Short")) {\n                        viewModel.activeAgent = .nathan\n                        viewModel.inputText = "Génère une vidéo de 6 secondes "\n                    },\n                    .default(Text("🧊 Studio 3D · Créer un environnement")) {\n                        keyboard.dismiss()\n                        isShowing3DStudio = true\n                    },''',
    "3D studio action",
)

marker = "// MARK: - Sarah 3D Environment Studio"
if marker not in text:
    text += r'''

// MARK: - Sarah 3D Environment Studio

@available(iOS 15.0, *)
private struct Sarah3DEnvironmentStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = "Ville futuriste en verre, lumière douce et grandes avenues"
    @State private var preset: Sarah3DPreset = .city
    @State private var extraBoxes = 0
    @State private var extraSpheres = 0
    @State private var sceneSeed = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        HapticService.shared.buttonTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Studio 3D")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Environnements locaux · SceneKit")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Button {
                        HapticService.shared.buttonTap()
                        sceneSeed += 1
                    } label: {
                        Label("Générer", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 13)
                            .frame(height: 42)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                SarahSceneKitPreview(
                    preset: preset,
                    extraBoxes: extraBoxes,
                    extraSpheres: extraSpheres,
                    seed: sceneSeed
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                )
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "cube.transparent")
                            .foregroundColor(.white.opacity(0.62))

                        TextField("Décris l’environnement 3D…", text: $prompt)
                            .textInputAutocapitalization(.sentences)
                            .foregroundColor(.white)

                        Button {
                            HapticService.shared.buttonTap()
                            sceneSeed += 1
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 27, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Sarah3DPreset.allCases) { option in
                                Button {
                                    HapticService.shared.buttonTap()
                                    preset = option
                                    sceneSeed += 1
                                } label: {
                                    Label(option.title, systemImage: option.icon)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .frame(height: 38)
                                        .background(
                                            preset == option
                                                ? Color.blue.opacity(0.34)
                                                : Color.white.opacity(0.08),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                preset == option ? Color.blue.opacity(0.75) : Color.white.opacity(0.12),
                                                lineWidth: 0.8
                                            )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Sarah3DToolButton(title: "Cube", icon: "cube") {
                            extraBoxes += 1
                            sceneSeed += 1
                        }
                        Sarah3DToolButton(title: "Sphère", icon: "circle.fill") {
                            extraSpheres += 1
                            sceneSeed += 1
                        }
                        Sarah3DToolButton(title: "Réinitialiser", icon: "arrow.counterclockwise") {
                            extraBoxes = 0
                            extraSpheres = 0
                            sceneSeed += 1
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
}

@available(iOS 15.0, *)
private struct Sarah3DToolButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private enum Sarah3DPreset: String, CaseIterable, Identifiable {
    case city
    case nature
    case space
    case showroom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .city: return "Ville"
        case .nature: return "Nature"
        case .space: return "Espace"
        case .showroom: return "Showroom"
        }
    }

    var icon: String {
        switch self {
        case .city: return "building.2"
        case .nature: return "leaf"
        case .space: return "sparkles"
        case .showroom: return "square.grid.2x2"
        }
    }
}

@available(iOS 15.0, *)
private struct SarahSceneKitPreview: UIViewRepresentable {
    let preset: Sarah3DPreset
    let extraBoxes: Int
    let extraSpheres: Int
    let seed: Int

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 60
        view.scene = buildScene()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = buildScene()
    }

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = preset == .space
            ? UIColor(red: 0.01, green: 0.015, blue: 0.04, alpha: 1)
            : UIColor.black

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 58
        camera.position = SCNVector3(0, 5.2, 11.5)
        camera.eulerAngles.x = -.35
        scene.rootNode.addChildNode(camera)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 520
        ambient.light?.color = UIColor(white: 0.72, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 1200
        key.light?.color = UIColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1)
        key.position = SCNVector3(4, 7, 6)
        scene.rootNode.addChildNode(key)

        addFloor(to: scene)

        switch preset {
        case .city:
            addCity(to: scene)
        case .nature:
            addNature(to: scene)
        case .space:
            addSpace(to: scene)
        case .showroom:
            addShowroom(to: scene)
        }

        for index in 0..<extraBoxes {
            let x = Float((index % 5) - 2) * 1.55
            let z = Float(-(index / 5)) * 1.6 - 0.8
            let node = SCNNode(geometry: SCNBox(width: 1.05, height: 1.05, length: 1.05, chamferRadius: 0.16))
            node.position = SCNVector3(x, 0.55, z)
            node.geometry?.firstMaterial = glassMaterial(UIColor.systemBlue)
            scene.rootNode.addChildNode(node)
        }

        for index in 0..<extraSpheres {
            let node = SCNNode(geometry: SCNSphere(radius: 0.52))
            node.position = SCNVector3(Float(index - extraSpheres / 2) * 1.35, 0.6, 2.1)
            node.geometry?.firstMaterial = glassMaterial(UIColor.systemTeal)
            scene.rootNode.addChildNode(node)
        }

        return scene
    }

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.16
        floor.reflectionFalloffEnd = 8
        floor.firstMaterial?.diffuse.contents = UIColor(white: 0.045, alpha: 1)
        floor.firstMaterial?.roughness.contents = 0.28
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
    }

    private func addCity(to scene: SCNScene) {
        for index in 0..<18 {
            let row = index / 6
            let col = index % 6
            let height = CGFloat(1.4 + ((index * 7 + seed) % 8)) * 0.46
            let geometry = SCNBox(width: 0.95, height: height, length: 0.95, chamferRadius: 0.12)
            geometry.firstMaterial = glassMaterial(index.isMultiple(of: 3) ? .systemBlue : .darkGray)
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(Float(col - 3) * 1.35 + 0.65, Float(height / 2), Float(row - 1) * -1.7)
            scene.rootNode.addChildNode(node)
        }
    }

    private func addNature(to scene: SCNScene) {
        for index in 0..<13 {
            let angle = Float(index) * 0.72
            let radius = Float(2.2 + Double(index % 3) * 0.7)
            let trunk = SCNCylinder(radius: 0.12, height: 1.4)
            trunk.firstMaterial?.diffuse.contents = UIColor.brown
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(cos(angle) * radius, 0.7, sin(angle) * radius)
            scene.rootNode.addChildNode(trunkNode)

            let crown = SCNSphere(radius: 0.55)
            crown.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.92)
            let crownNode = SCNNode(geometry: crown)
            crownNode.position = SCNVector3(trunkNode.position.x, 1.65, trunkNode.position.z)
            scene.rootNode.addChildNode(crownNode)
        }
    }

    private func addSpace(to scene: SCNScene) {
        let planet = SCNSphere(radius: 1.65)
        planet.segmentCount = 96
        planet.firstMaterial = glassMaterial(.systemIndigo)
        let planetNode = SCNNode(geometry: planet)
        planetNode.position = SCNVector3(0, 2.05, -1.2)
        scene.rootNode.addChildNode(planetNode)

        for index in 0..<32 {
            let star = SCNSphere(radius: 0.025 + CGFloat(index % 3) * 0.008)
            star.firstMaterial?.emission.contents = UIColor.white
            let node = SCNNode(geometry: star)
            let x = Float((index * 37) % 19 - 9) * 0.65
            let y = Float((index * 17) % 11 + 2) * 0.48
            let z = Float(-((index * 11) % 13)) * 0.62 - 2
            node.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(node)
        }
    }

    private func addShowroom(to scene: SCNScene) {
        let pedestal = SCNCylinder(radius: 1.45, height: 0.42)
        pedestal.firstMaterial = glassMaterial(.white)
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(0, 0.21, 0)
        scene.rootNode.addChildNode(pedestalNode)

        let hero = SCNBox(width: 2.25, height: 1.35, length: 0.18, chamferRadius: 0.22)
        hero.firstMaterial = glassMaterial(.systemBlue)
        let heroNode = SCNNode(geometry: hero)
        heroNode.position = SCNVector3(0, 1.35, 0)
        heroNode.eulerAngles.y = 0.22
        scene.rootNode.addChildNode(heroNode)
    }

    private func glassMaterial(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.78)
        material.metalness.contents = 0.36
        material.roughness.contents = 0.22
        material.lightingModel = .physicallyBased
        return material
    }
}
'''

CHAT.write_text(text, encoding="utf-8")
print("Added Sarah 3D environment studio and smoke route.")
