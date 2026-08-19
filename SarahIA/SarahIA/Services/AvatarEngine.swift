import Foundation
import SceneKit
import UIKit
import Combine

/// Moteur 3D SceneKit avancé gérant l'avatar, les blendshapes faciaux, le rigging squelettique,
/// la gestuelle conversationnelle procédurale et les dynamiques corporelles (respiration, idle, barge-in).
public final class AvatarEngine: ObservableObject {
    
    public static let shared = AvatarEngine()
    
    // MARK: - SceneKit Core Nodes
    public let scene: SCNScene
    public let cameraNode: SCNNode
    public let avatarRootNode: SCNNode
    
    // MARK: - Facial & Head Nodes
    private var headNode: SCNNode?
    private var jawNode: SCNNode?
    private var mouthNode: SCNNode?
    private var leftEyeNode: SCNNode?
    private var rightEyeNode: SCNNode?
    private var leftEyelidNode: SCNNode?
    private var rightEyelidNode: SCNNode?
    private var morpher: SCNMorpher?
    
    // MARK: - Skeletal & Upper-Body Nodes
    private var spineNode: SCNNode?
    private var chestNode: SCNNode?
    private var neckNode: SCNNode?
    private var leftShoulderNode: SCNNode?
    private var rightShoulderNode: SCNNode?
    private var leftUpperArmNode: SCNNode?
    private var rightUpperArmNode: SCNNode?
    private var leftForearmNode: SCNNode?
    private var rightForearmNode: SCNNode?
    private var leftHandNode: SCNNode?
    private var rightHandNode: SCNNode?
    private var allMorphers: [SCNMorpher] = []
    
    // MARK: - Animation State & Motion Blending
    private var animationTimer: Timer?
    private var blinkTimer: Timer?
    private var timeTracker: Float = 0.0
    
    // Gesture & Speech Dynamics
    private var currentGestureWeight: Float = 0.0
    private var targetGestureWeight: Float = 0.0
    private var speechEnergySmoothed: Float = 0.0
    private var speechCadencePhase: Float = 0.0
    
    // Transform Targets (for smooth 60fps interpolation)
    private var lookAtDeltaX: Float = 0.0
    private var lookAtDeltaY: Float = 0.0
    private var currentLookAtX: Float = 0.0
    private var currentLookAtY: Float = 0.0
    
    // Initial neutral transforms for skeletal bones
    private var neutralUpperArmLRot = SCNVector3(0.1, 0, 0.25)
    private var neutralUpperArmRRot = SCNVector3(0.1, 0, -0.25)
    private var neutralForearmLRot = SCNVector3(0.4, 0, 0.2)
    private var neutralForearmRRot = SCNVector3(0.4, 0, -0.2)
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.scene = SCNScene()
        self.cameraNode = SCNNode()
        self.avatarRootNode = SCNNode()
        
        setupSceneEnvironment()
        setupAvatarModel()
        setupLipSyncAndSpeechBindings()
        startUnified60FPSAnimationPipeline()
    }
    
    deinit {
        animationTimer?.invalidate()
        blinkTimer?.invalidate()
    }
    
    // MARK: - 1. Configuration de la Scène 3D
    
    private func setupSceneEnvironment() {
        scene.background.contents = UIColor.black
        
        // Caméra principale avec perspective portrait optimisée pour haut du corps & visage
        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.1
        camera.zFar = 100.0
        camera.wantsHDR = true
        camera.bloomIntensity = 0.75
        camera.bloomThreshold = 0.82
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0.08, z: 2.95)
        scene.rootNode.addChildNode(cameraNode)
        
        // Éclairage Studio Cinématique 3-Points
        // 1. Key Light (Lumière principale douce)
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 950
        keyLight.color = UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0)
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(x: 1.6, y: 2.2, z: 2.5)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        // 2. Fill Light (Ambiance subtile cyan / bleutée)
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 480
        fillLight.color = UIColor(red: 0.45, green: 0.68, blue: 1.0, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(x: -2.2, y: 0.6, z: 1.6)
        fillLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLightNode)
        
        // 3. Rim Light (Lumière de contour arrière violette / cyberpunk)
        let rimLight = SCNLight()
        rimLight.type = .spot
        rimLight.intensity = 1300
        rimLight.color = UIColor(red: 0.88, green: 0.42, blue: 1.0, alpha: 1.0)
        rimLight.spotInnerAngle = 35
        rimLight.spotOuterAngle = 85
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(x: 0, y: 2.6, z: -2.2)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)
        
        // Ambiance générale
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        ambientLight.color = UIColor(white: 0.35, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        scene.rootNode.addChildNode(avatarRootNode)
    }
    
    // MARK: - 2. Chargement du Modèle VRoid (Sarah.vrm) ou Procédural
    
    private func setupAvatarModel() {
        // Tentative de chargement prioritaire de "Sarah.vrm" via VRMLoader
        if let vrmRig = VRMLoader.shared.loadSarahAvatar() {
            print("✨ [AvatarEngine] Modèle VRoid Studio Sarah.vrm chargé avec succès !")
            avatarRootNode.addChildNode(vrmRig.rootNode)
            
            self.headNode = vrmRig.headNode
            self.spineNode = vrmRig.spineNode
            self.chestNode = vrmRig.chestNode
            self.neckNode = vrmRig.neckNode
            self.leftShoulderNode = vrmRig.leftShoulderNode
            self.rightShoulderNode = vrmRig.rightShoulderNode
            self.leftUpperArmNode = vrmRig.leftUpperArmNode
            self.rightUpperArmNode = vrmRig.rightUpperArmNode
            self.leftForearmNode = vrmRig.leftForearmNode
            self.rightForearmNode = vrmRig.rightForearmNode
            self.leftHandNode = vrmRig.leftHandNode
            self.rightHandNode = vrmRig.rightHandNode
            self.allMorphers = vrmRig.morphers
            self.morpher = vrmRig.morphers.first
            return
        }
        
        print("🎨 [AvatarEngine] Aucun fichier Sarah.vrm détecté pour l'instant : utilisation de l'avatar procédural stylisé avec squelette.")
        createFullProceduralAvatarWithRig()
    }
    
    /// Construit un avatar stylisé complet avec rig squelettique articulaire (Buste, Épaules, Bras, Mains)
    private func createFullProceduralAvatarWithRig() {
        let characterRoot = SCNNode()
        characterRoot.name = "SarahRiggedCharacter"
        
        // Matériaux PBR Réalistes / Stylisés
        let skinMaterial = SCNMaterial()
        skinMaterial.lightingModel = .physicallyBased
        skinMaterial.diffuse.contents = UIColor(red: 0.94, green: 0.82, blue: 0.76, alpha: 1.0)
        skinMaterial.roughness.contents = 0.42
        skinMaterial.metalness.contents = 0.04
        
        let jacketMaterial = SCNMaterial()
        jacketMaterial.lightingModel = .physicallyBased
        jacketMaterial.diffuse.contents = UIColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0) // Bleu nuit élégant
        jacketMaterial.roughness.contents = 0.35
        jacketMaterial.metalness.contents = 0.15
        
        let topInnerMaterial = SCNMaterial()
        topInnerMaterial.lightingModel = .physicallyBased
        topInnerMaterial.diffuse.contents = UIColor(red: 0.88, green: 0.90, blue: 0.95, alpha: 1.0)
        topInnerMaterial.roughness.contents = 0.5
        
        // -------------------------------------------------------------
        // 1. Rachis & Buste / Chest (Point d'ancrage de la respiration)
        // -------------------------------------------------------------
        let spine = SCNNode()
        spine.name = "Spine"
        spine.position = SCNVector3(0, -0.65, 0)
        characterRoot.addChildNode(spine)
        self.spineNode = spine
        
        let chest = SCNNode()
        chest.name = "Chest"
        chest.position = SCNVector3(0, 0.25, 0)
        spine.addChildNode(chest)
        self.chestNode = chest
        
        // Torse / Veste
        let torsoGeom = SCNCylinder(radius: 0.34, height: 0.55)
        let torsoMeshNode = SCNNode(geometry: torsoGeom)
        torsoMeshNode.geometry?.materials = [jacketMaterial]
        torsoMeshNode.position = SCNVector3(0, 0, 0)
        torsoMeshNode.scale = SCNVector3(1.15, 1.0, 0.75)
        chest.addChildNode(torsoMeshNode)
        
        // -------------------------------------------------------------
        // 2. Cou & Tête (Enfant du Chest)
        // -------------------------------------------------------------
        let neck = SCNNode()
        neck.name = "Neck"
        neck.position = SCNVector3(0, 0.32, -0.02)
        chest.addChildNode(neck)
        self.neckNode = neck
        
        let neckMesh = SCNNode(geometry: SCNCylinder(radius: 0.15, height: 0.22))
        neckMesh.geometry?.materials = [skinMaterial]
        neckMesh.position = SCNVector3(0, 0, 0)
        neck.addChildNode(neckMesh)
        
        // Tête & Visage
        let head = SCNNode()
        head.name = "Head"
        head.position = SCNVector3(0, 0.22, 0.03)
        neck.addChildNode(head)
        self.headNode = head
        
        let headGeometry = SCNSphere(radius: 0.48)
        headGeometry.segmentCount = 48
        headGeometry.materials = [skinMaterial]
        let headMesh = SCNNode(geometry: headGeometry)
        headMesh.scale = SCNVector3(0.90, 1.06, 0.94)
        head.addChildNode(headMesh)
        
        // Yeux Stylisés
        setupEyesAndEyelids(on: head, skinMat: skinMaterial)
        
        // Cheveux Stylisés
        let hairMaterial = SCNMaterial()
        hairMaterial.lightingModel = .physicallyBased
        hairMaterial.diffuse.contents = UIColor(red: 0.14, green: 0.11, blue: 0.18, alpha: 1.0)
        hairMaterial.roughness.contents = 0.35
        let hair = SCNNode(geometry: SCNSphere(radius: 0.52))
        hair.geometry?.materials = [hairMaterial]
        hair.position = SCNVector3(0, 0.08, -0.05)
        hair.scale = SCNVector3(0.98, 1.05, 1.02)
        head.addChildNode(hair)
        
        // Bouche et Mâchoire pour Visèmes
        setupMouthAndJaw(on: head)
        
        // -------------------------------------------------------------
        // 3. Bras Gauche (Left Shoulder -> UpperArm -> ForeArm -> Hand)
        // -------------------------------------------------------------
        let leftShoulder = SCNNode()
        leftShoulder.name = "LeftShoulder"
        leftShoulder.position = SCNVector3(-0.38, 0.22, 0)
        chest.addChildNode(leftShoulder)
        self.leftShoulderNode = leftShoulder
        
        let leftUpperArm = SCNNode()
        leftUpperArm.name = "LeftUpperArm"
        leftUpperArm.position = SCNVector3(-0.12, -0.02, 0)
        leftUpperArm.eulerAngles = neutralUpperArmLRot
        leftShoulder.addChildNode(leftUpperArm)
        self.leftUpperArmNode = leftUpperArm
        
        let armLMesh = SCNNode(geometry: SCNCylinder(radius: 0.09, height: 0.38))
        armLMesh.geometry?.materials = [jacketMaterial]
        armLMesh.position = SCNVector3(0, -0.18, 0)
        leftUpperArm.addChildNode(armLMesh)
        
        let leftForearm = SCNNode()
        leftForearm.name = "LeftForeArm"
        leftForearm.position = SCNVector3(0, -0.38, 0)
        leftForearm.eulerAngles = neutralForearmLRot
        leftUpperArm.addChildNode(leftForearm)
        self.leftForearmNode = leftForearm
        
        let forearmLMesh = SCNNode(geometry: SCNCylinder(radius: 0.075, height: 0.34))
        forearmLMesh.geometry?.materials = [jacketMaterial]
        forearmLMesh.position = SCNVector3(0, -0.16, 0)
        leftForearm.addChildNode(forearmLMesh)
        
        let leftHand = SCNNode()
        leftHand.name = "LeftHand"
        leftHand.position = SCNVector3(0, -0.33, 0)
        leftForearm.addChildNode(leftHand)
        self.leftHandNode = leftHand
        
        let handLMesh = SCNNode(geometry: SCNSphere(radius: 0.065))
        handLMesh.geometry?.materials = [skinMaterial]
        handLMesh.scale = SCNVector3(0.6, 1.2, 0.8)
        leftHand.addChildNode(handLMesh)
        
        // -------------------------------------------------------------
        // 4. Bras Droit (Right Shoulder -> UpperArm -> ForeArm -> Hand)
        // -------------------------------------------------------------
        let rightShoulder = SCNNode()
        rightShoulder.name = "RightShoulder"
        rightShoulder.position = SCNVector3(0.38, 0.22, 0)
        chest.addChildNode(rightShoulder)
        self.rightShoulderNode = rightShoulder
        
        let rightUpperArm = SCNNode()
        rightUpperArm.name = "RightUpperArm"
        rightUpperArm.position = SCNVector3(0.12, -0.02, 0)
        rightUpperArm.eulerAngles = neutralUpperArmRRot
        rightShoulder.addChildNode(rightUpperArm)
        self.rightUpperArmNode = rightUpperArm
        
        let armRMesh = SCNNode(geometry: SCNCylinder(radius: 0.09, height: 0.38))
        armRMesh.geometry?.materials = [jacketMaterial]
        armRMesh.position = SCNVector3(0, -0.18, 0)
        rightUpperArm.addChildNode(armRMesh)
        
        let rightForearm = SCNNode()
        rightForearm.name = "RightForeArm"
        rightForearm.position = SCNVector3(0, -0.38, 0)
        rightForearm.eulerAngles = neutralForearmRRot
        rightUpperArm.addChildNode(rightForearm)
        self.rightForearmNode = rightForearm
        
        let forearmRMesh = SCNNode(geometry: SCNCylinder(radius: 0.075, height: 0.34))
        forearmRMesh.geometry?.materials = [jacketMaterial]
        forearmRMesh.position = SCNVector3(0, -0.16, 0)
        rightForearm.addChildNode(forearmRMesh)
        
        let rightHand = SCNNode()
        rightHand.name = "RightHand"
        rightHand.position = SCNVector3(0, -0.33, 0)
        rightForearm.addChildNode(rightHand)
        self.rightHandNode = rightHand
        
        let handRMesh = SCNNode(geometry: SCNSphere(radius: 0.065))
        handRMesh.geometry?.materials = [skinMaterial]
        handRMesh.scale = SCNVector3(0.6, 1.2, 0.8)
        rightHand.addChildNode(handRMesh)
        
        avatarRootNode.addChildNode(characterRoot)
    }
    
    private func setupEyesAndEyelids(on parent: SCNNode, skinMat: SCNMaterial) {
        let eyeMaterial = SCNMaterial()
        eyeMaterial.lightingModel = .physicallyBased
        eyeMaterial.diffuse.contents = UIColor.white
        eyeMaterial.roughness.contents = 0.1
        
        let irisMaterial = SCNMaterial()
        irisMaterial.lightingModel = .physicallyBased
        irisMaterial.diffuse.contents = UIColor(red: 0.12, green: 0.58, blue: 0.88, alpha: 1.0)
        irisMaterial.emission.contents = UIColor(red: 0.0, green: 0.25, blue: 0.45, alpha: 0.45)
        
        // Œil Gauche
        let leftEye = SCNNode(geometry: SCNSphere(radius: 0.075))
        leftEye.geometry?.materials = [eyeMaterial]
        leftEye.position = SCNVector3(-0.17, 0.05, 0.40)
        let leftIris = SCNNode(geometry: SCNCylinder(radius: 0.042, height: 0.015))
        leftIris.geometry?.materials = [irisMaterial]
        leftIris.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        leftIris.position = SCNVector3(0, 0, 0.07)
        leftEye.addChildNode(leftIris)
        parent.addChildNode(leftEye)
        self.leftEyeNode = leftEye
        
        // Œil Droit
        let rightEye = SCNNode(geometry: SCNSphere(radius: 0.075))
        rightEye.geometry?.materials = [eyeMaterial]
        rightEye.position = SCNVector3(0.17, 0.05, 0.40)
        let rightIris = SCNNode(geometry: SCNCylinder(radius: 0.042, height: 0.015))
        rightIris.geometry?.materials = [irisMaterial]
        rightIris.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        rightIris.position = SCNVector3(0, 0, 0.07)
        rightEye.addChildNode(rightIris)
        parent.addChildNode(rightEye)
        self.rightEyeNode = rightEye
        
        // Paupières
        let leftLid = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 0.025))
        leftLid.geometry?.materials = [skinMat]
        leftLid.position = SCNVector3(-0.17, 0.10, 0.41)
        leftLid.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        leftLid.scale = SCNVector3(1, 1, 0.01)
        parent.addChildNode(leftLid)
        self.leftEyelidNode = leftLid
        
        let rightLid = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 0.025))
        rightLid.geometry?.materials = [skinMat]
        rightLid.position = SCNVector3(0.17, 0.10, 0.41)
        rightLid.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        rightLid.scale = SCNVector3(1, 1, 0.01)
        parent.addChildNode(rightLid)
        self.rightEyelidNode = rightLid
    }
    
    private func setupMouthAndJaw(on parent: SCNNode) {
        let lipMaterial = SCNMaterial()
        lipMaterial.lightingModel = .physicallyBased
        lipMaterial.diffuse.contents = UIColor(red: 0.88, green: 0.42, blue: 0.48, alpha: 1.0)
        lipMaterial.roughness.contents = 0.3
        
        let mouthGeom = SCNCapsule(capRadius: 0.028, height: 0.16)
        let mouth = SCNNode(geometry: mouthGeom)
        mouth.geometry?.materials = [lipMaterial]
        mouth.position = SCNVector3(0, -0.22, 0.42)
        mouth.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        parent.addChildNode(mouth)
        self.mouthNode = mouth
        
        let jaw = SCNNode()
        jaw.position = SCNVector3(0, -0.26, 0.34)
        parent.addChildNode(jaw)
        self.jawNode = jaw
    }
    
    // MARK: - 3. Synchronisation Vocale & Gestuelle
    
    private func setupLipSyncAndSpeechBindings() {
        TTSService.shared.onVisemeUpdated = { [weak self] frame in
            self?.applyVisemeFrame(frame)
        }
        
        TTSService.shared.onSpeechStarted = { [weak self] in
            self?.targetGestureWeight = 1.0
        }
        
        TTSService.shared.onSpeechFinished = { [weak self] in
            self?.targetGestureWeight = 0.0
        }
        
        // Barge-In Interruption : retour immédiat et fluide à la pose neutre
        TTSService.shared.onSpeechInterrupted = { [weak self] in
            self?.targetGestureWeight = 0.0
            self?.speechEnergySmoothed = 0.0
            self?.applyVisemeFrame(.zero)
        }
    }
    
    /// Applique les poids de blendshapes faciaux (Support ARKit & VRoid Studio VRM)
    public func applyVisemeFrame(_ frame: VisemeFrame) {
        speechEnergySmoothed = frame.amplitude
        
        // 1. Application sur tous les Morphers découverts (VRoid VRM & USDZ)
        for m in allMorphers {
            // Mapping ARKit standard
            m.setWeight(CGFloat(frame.jawOpen), forTargetNamed: "jawOpen")
            m.setWeight(CGFloat(frame.mouthPucker), forTargetNamed: "mouthPucker")
            m.setWeight(CGFloat(frame.mouthFunnel), forTargetNamed: "mouthFunnel")
            m.setWeight(CGFloat(frame.mouthSmile), forTargetNamed: "mouthSmile")
            
            // Mapping VRoid Studio VRM Standard (Voyelles & Expressions)
            // A (Grande ouverture)
            m.setWeight(CGFloat(frame.jawOpen), forTargetNamed: "Fcl_MTH_A")
            m.setWeight(CGFloat(frame.jawOpen), forTargetNamed: "A")
            m.setWeight(CGFloat(frame.jawOpen), forTargetNamed: "vrm.a")
            
            // I (Sourire / Étirement)
            m.setWeight(CGFloat(frame.mouthSmile), forTargetNamed: "Fcl_MTH_I")
            m.setWeight(CGFloat(frame.mouthSmile), forTargetNamed: "I")
            m.setWeight(CGFloat(frame.mouthSmile), forTargetNamed: "vrm.i")
            m.setWeight(CGFloat(frame.mouthSmile * 0.5), forTargetNamed: "Joy")
            m.setWeight(CGFloat(frame.mouthSmile * 0.5), forTargetNamed: "Fcl_ALL_Joy")
            
            // U (Bouche en avant / Pucker)
            m.setWeight(CGFloat(frame.mouthPucker), forTargetNamed: "Fcl_MTH_U")
            m.setWeight(CGFloat(frame.mouthPucker), forTargetNamed: "U")
            m.setWeight(CGFloat(frame.mouthPucker), forTargetNamed: "vrm.u")
            
            // E (Ouverture intermédiaire)
            let weightE = (frame.jawOpen * 0.5) + (frame.mouthSmile * 0.5)
            m.setWeight(CGFloat(weightE), forTargetNamed: "Fcl_MTH_E")
            m.setWeight(CGFloat(weightE), forTargetNamed: "E")
            m.setWeight(CGFloat(weightE), forTargetNamed: "vrm.e")
            
            // O (Rond / Funnel)
            m.setWeight(CGFloat(frame.mouthFunnel), forTargetNamed: "Fcl_MTH_O")
            m.setWeight(CGFloat(frame.mouthFunnel), forTargetNamed: "O")
            m.setWeight(CGFloat(frame.mouthFunnel), forTargetNamed: "vrm.o")
        }
        
        // 2. Modèle procédural de secours
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.03
        
        if let mouth = mouthNode {
            let scaleX = 1.0 + (frame.mouthSmile * 0.35) - (frame.mouthPucker * 0.45)
            let scaleY = 1.0 + (frame.jawOpen * 2.1) + (frame.mouthFunnel * 0.75)
            let scaleZ = 1.0 + (frame.mouthPucker * 0.5)
            
            mouth.scale = SCNVector3(scaleX, scaleY, scaleZ)
            mouth.position = SCNVector3(0, -0.22 - (frame.jawOpen * 0.04), 0.42 + (frame.mouthPucker * 0.02))
        }
        
        if let jaw = jawNode {
            jaw.position = SCNVector3(0, -0.26 - (frame.jawOpen * 0.06), 0.34)
        }
        
        SCNTransaction.commit()
    }
    
    // MARK: - 4. Pipeline Unifié 60 FPS (Respiration, Gestes Vocaux, Idle, LERP)
    
    private func startUnified60FPSAnimationPipeline() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateAnimationTick(deltaTime: 1.0 / 60.0)
        }
        
        scheduleNextBlink()
    }
    
    private func updateAnimationTick(deltaTime: Float) {
        timeTracker += deltaTime
        speechCadencePhase += deltaTime * (2.5 + speechEnergySmoothed * 4.0)
        
        // -------------------------------------------------------------
        // A. Interpolation du poids de geste (Motion Blending / Barge-In)
        // -------------------------------------------------------------
        let blendFactor: Float = (targetGestureWeight > currentGestureWeight) ? 0.08 : 0.14
        currentGestureWeight += (targetGestureWeight - currentGestureWeight) * blendFactor
        
        // LERP doux pour l'orientation tactile
        currentLookAtX += (lookAtDeltaX - currentLookAtX) * 0.12
        currentLookAtY += (lookAtDeltaY - currentLookAtY) * 0.12
        
        // -------------------------------------------------------------
        // B. Dynamiques Corporelles Idle & Respiration (0.22 Hz)
        // -------------------------------------------------------------
        let breathFrequency: Float = 1.4 // ~0.22 Hz (cycle respiratoire naturel de 4.5s)
        let breathSin = sin(timeTracker * breathFrequency)
        
        // Soulèvement subtil de la poitrine & des épaules
        let chestExpansion = 1.0 + (breathSin * 0.015)
        chestNode?.scale = SCNVector3(Float(chestExpansion), Float(chestExpansion * 1.02), Float(chestExpansion * 1.03))
        
        // Micro-ondulation du rachis & balancement de poids
        let weightShift = sin(timeTracker * 0.4) * 0.018
        let spineTiltX = sin(timeTracker * breathFrequency) * 0.012
        let spineTiltZ = cos(timeTracker * 0.35) * 0.015
        spineNode?.eulerAngles = SCNVector3(spineTiltX, weightShift * 0.5, spineTiltZ)
        
        // Micro-mouvements de tête organiques
        let headBreathingPitch = sin(timeTracker * breathFrequency + 0.3) * 0.015
        let headIdleYaw = sin(timeTracker * 0.6) * 0.035 + currentLookAtY
        let headIdlePitch = cos(timeTracker * 0.5) * 0.025 + currentLookAtX
        headNode?.eulerAngles = SCNVector3(headIdlePitch + headBreathingPitch, headIdleYaw, -weightShift * 0.4)
        
        // -------------------------------------------------------------
        // C. Gestuelle Vocale Procédurale (Bras & Mains pendant la parole)
        // -------------------------------------------------------------
        let intensity = currentGestureWeight * (0.6 + speechEnergySmoothed * 0.8)
        
        // Bras Droit (Gestuelle Principale d'Élocution & Expression)
        let rArmGestureX = sin(speechCadencePhase * 1.1) * 0.22 * intensity
        let rArmGestureY = cos(speechCadencePhase * 0.8) * 0.15 * intensity
        let rArmGestureZ = sin(speechCadencePhase * 0.9 + 0.4) * 0.18 * intensity
        
        let rForearmGestureX = (sin(speechCadencePhase * 1.3) * 0.35 + 0.35) * intensity
        let rForearmGestureZ = cos(speechCadencePhase * 1.0) * 0.20 * intensity
        
        let rHandGestureX = sin(speechCadencePhase * 1.8) * 0.25 * intensity
        let rHandGestureZ = cos(speechCadencePhase * 1.4) * 0.18 * intensity
        
        // Bras Gauche (Gestuelle Complémentaire Subtile & Balancement)
        let lArmGestureX = cos(speechCadencePhase * 0.7 + 1.2) * 0.14 * intensity
        let lArmGestureZ = sin(speechCadencePhase * 0.6) * 0.12 * intensity
        let lForearmGestureX = (sin(speechCadencePhase * 0.9 + 0.8) * 0.20 + 0.20) * intensity
        
        // Application aux os avec interpolation fluide depuis la pose neutre
        rightUpperArmNode?.eulerAngles = SCNVector3(
            neutralUpperArmRRot.x - rArmGestureX,
            neutralUpperArmRRot.y + rArmGestureY,
            neutralUpperArmRRot.z - rArmGestureZ
        )
        
        rightForearmNode?.eulerAngles = SCNVector3(
            neutralForearmRRot.x + rForearmGestureX,
            neutralForearmRRot.y,
            neutralForearmRRot.z - rForearmGestureZ
        )
        
        rightHandNode?.eulerAngles = SCNVector3(
            rHandGestureX,
            0,
            rHandGestureZ
        )
        
        leftUpperArmNode?.eulerAngles = SCNVector3(
            neutralUpperArmLRot.x - lArmGestureX,
            neutralUpperArmLRot.y,
            neutralUpperArmLRot.z + lArmGestureZ
        )
        
        leftForearmNode?.eulerAngles = SCNVector3(
            neutralForearmLRot.x + lForearmGestureX,
            neutralForearmLRot.y,
            neutralForearmLRot.z
        )
        
        // Balancement global de l'avatar dans la scène
        avatarRootNode.position = SCNVector3(weightShift * 0.8, breathSin * 0.01, 0)
    }
    
    // MARK: - 5. Clignements d'Yeux Organiques & Micro-Saccades
    
    private func scheduleNextBlink() {
        let interval = Double.random(in: 2.5...5.0)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.triggerNaturalBlink()
            self?.scheduleNextBlink()
        }
    }
    
    private func triggerNaturalBlink() {
        // Animation des paupières VRM
        for m in allMorphers {
            m.setWeight(1.0, forTargetNamed: "Fcl_EYE_Close")
            m.setWeight(1.0, forTargetNamed: "Blink")
            m.setWeight(1.0, forTargetNamed: "eyeBlinkLeft")
            m.setWeight(1.0, forTargetNamed: "eyeBlinkRight")
        }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.07
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.07
            self.leftEyelidNode?.scale = SCNVector3(1, 1, 0.01)
            self.rightEyelidNode?.scale = SCNVector3(1, 1, 0.01)
            for m in self.allMorphers {
                m.setWeight(0.0, forTargetNamed: "Fcl_EYE_Close")
                m.setWeight(0.0, forTargetNamed: "Blink")
                m.setWeight(0.0, forTargetNamed: "eyeBlinkLeft")
                m.setWeight(0.0, forTargetNamed: "eyeBlinkRight")
            }
            SCNTransaction.commit()
        }
        
        leftEyelidNode?.scale = SCNVector3(1, 1, 1.0)
        rightEyelidNode?.scale = SCNVector3(1, 1, 1.0)
        SCNTransaction.commit()
    }
    
    public func setLookAtOffset(deltaX: Float, deltaY: Float) {
        lookAtDeltaX = min(0.35, max(-0.35, deltaY * 0.004))
        lookAtDeltaY = min(0.45, max(-0.45, deltaX * 0.004))
    }
    
    public func setLookAtTarget(x: Float, y: Float) {
        lookAtDeltaY = min(0.45, max(-0.45, x * 0.45))
        lookAtDeltaX = min(0.35, max(-0.35, y * 0.35))
    }
}

