import Foundation
import SceneKit
import UIKit
import ModelIO
import SceneKit.ModelIO

/// Structure décrivant les os et morphers découverts dans un modèle VRM / VRoid Studio
public struct VRMAvatarRig {
    public var rootNode: SCNNode
    public var headNode: SCNNode?
    public var spineNode: SCNNode?
    public var chestNode: SCNNode?
    public var neckNode: SCNNode?
    public var leftShoulderNode: SCNNode?
    public var rightShoulderNode: SCNNode?
    public var leftUpperArmNode: SCNNode?
    public var rightUpperArmNode: SCNNode?
    public var leftForearmNode: SCNNode?
    public var rightForearmNode: SCNNode?
    public var leftHandNode: SCNNode?
    public var rightHandNode: SCNNode?
    public var morphers: [SCNMorpher] = []
    public var blendshapeTargetNames: [String] = []
    
    public init(rootNode: SCNNode) {
        self.rootNode = rootNode
    }
}

/// Chargeur et analyseur sécurisé de modèles 3D VRoid Studio (.vrm / .glb / .usdz / .scn)
public final class VRMLoader {
    
    public static let shared = VRMLoader()
    
    private init() {}
    
    /// Recherche et charge le fichier VRM "Sarah.vrm" ou ses variantes en toute sécurité sans risque de crash.
    public func loadSarahAvatar() -> VRMAvatarRig? {
        let candidateNames = [
            "Sarah.vrm",
            "Sarah.glb",
            "Sarah.gltf",
            "Sarah.usdz",
            "Sarah.scn",
            "SarahHead.usdz",
            "SarahHead.scn",
            "avatar.vrm",
            "avatar.usdz"
        ]
        
        let fileManager = FileManager.default
        let documentUrls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let appSupportUrls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        
        for candidate in candidateNames {
            let baseName = (candidate as NSString).deletingPathExtension
            let ext = (candidate as NSString).pathExtension
            
            // 1. Recherche dans le Bundle principal
            if let bundleUrl = Bundle.main.url(forResource: baseName, withExtension: ext) {
                if let rig = safeLoadAvatar(from: bundleUrl) {
                    print("✅ [VRMLoader] Modèle 3D chargé depuis le Bundle: \(candidate)")
                    return rig
                }
            }
            
            // 2. Recherche dans Documents
            if let docUrl = documentUrls.first?.appendingPathComponent(candidate), fileManager.fileExists(atPath: docUrl.path) {
                if let rig = safeLoadAvatar(from: docUrl) {
                    print("✅ [VRMLoader] Modèle 3D chargé depuis Documents: \(candidate)")
                    return rig
                }
            }
            
            // 3. Recherche dans Application Support / SarahAI
            if let appSupport = appSupportUrls.first {
                let customUrl = appSupport.appendingPathComponent("SarahAI/\(candidate)")
                if fileManager.fileExists(atPath: customUrl.path) {
                    if let rig = safeLoadAvatar(from: customUrl) {
                        print("✅ [VRMLoader] Modèle 3D chargé depuis AppSupport: \(candidate)")
                        return rig
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Charge un avatar depuis une URL locale avec gestion d'erreurs try-catch globale.
    public func safeLoadAvatar(from url: URL) -> VRMAvatarRig? {
        let ext = url.pathExtension.lowercased()
        
        do {
            // Formats SceneKit / USDZ natifs
            if ext == "usdz" || ext == "scn" || ext == "dae" || ext == "obj" {
                let scene = try SCNScene(url: url, options: [
                    .checkConsistency: true,
                    .createNormalsIfAbsent: true
                ])
                return parseAvatarRig(from: scene.rootNode)
            }
            
            // Formats VRM / GLB (glTF 2.0 Binary)
            if ext == "vrm" || ext == "glb" || ext == "gltf" {
                // 1. Tentative avec ModelIO natif Apple (MDLAsset -> SCNScene)
                let asset = MDLAsset(url: url)
                let mdlScene = SCNScene(mdlAsset: asset)
                if !mdlScene.rootNode.childNodes.isEmpty {
                    return parseAvatarRig(from: mdlScene.rootNode)
                }
                
                // 2. Tentative directe SCNScene
                if let scene = try? SCNScene(url: url, options: nil) {
                    return parseAvatarRig(from: scene.rootNode)
                }
            }
        } catch {
            print("⚠️ [VRMLoader] Erreur de chargement du fichier 3D (\(url.lastPathComponent)): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Analyse l'arborescence 3D et extrait les os squelettiques et les morphers BlendShapes.
    public func parseAvatarRig(from root: SCNNode) -> VRMAvatarRig {
        var rig = VRMAvatarRig(rootNode: root)
        
        root.enumerateChildNodes { node, _ in
            let rawName = node.name ?? ""
            let name = rawName.lowercased()
            
            // 1. Extraction des Morphers (Expressions faciales & voyelles)
            if let morpher = node.morpher {
                rig.morphers.append(morpher)
                if rig.headNode == nil {
                    rig.headNode = node
                }
                
                for target in morpher.targets {
                    if let targetName = target.name {
                        rig.blendshapeTargetNames.append(targetName)
                    }
                }
            }
            
            // 2. Mapping Squelettique Humanoïde (VRoid Studio / Mixamo / VRM)
            if name.contains("j_bip_c_head") || (name.contains("head") && !name.contains("hair") && !name.contains("headband")) {
                if rig.headNode == nil { rig.headNode = node }
            } else if name.contains("j_bip_c_neck") || name.contains("neck") {
                rig.neckNode = node
            } else if name.contains("j_bip_c_chest") || name.contains("j_bip_c_upperchest") || name.contains("chest") {
                rig.chestNode = node
            } else if name.contains("j_bip_c_spine") || name.contains("spine") || name.contains("torso") {
                rig.spineNode = node
            }
            // Bras Gauche
            else if name.contains("j_bip_l_shoulder") || name.contains("shoulder_l") || name.contains("leftshoulder") {
                rig.leftShoulderNode = node
            } else if name.contains("j_bip_l_upperarm") || name.contains("arm_l") || name.contains("leftupperarm") {
                rig.leftUpperArmNode = node
            } else if name.contains("j_bip_l_lowerarm") || name.contains("forearm_l") || name.contains("leftforearm") {
                rig.leftForearmNode = node
            } else if name.contains("j_bip_l_hand") || name.contains("hand_l") || name.contains("lefthand") {
                rig.leftHandNode = node
            }
            // Bras Droit
            else if name.contains("j_bip_r_shoulder") || name.contains("shoulder_r") || name.contains("rightshoulder") {
                rig.rightShoulderNode = node
            } else if name.contains("j_bip_r_upperarm") || name.contains("arm_r") || name.contains("rightupperarm") {
                rig.rightUpperArmNode = node
            } else if name.contains("j_bip_r_lowerarm") || name.contains("forearm_r") || name.contains("rightforearm") {
                rig.rightForearmNode = node
            } else if name.contains("j_bip_r_hand") || name.contains("hand_r") || name.contains("righthand") {
                rig.rightHandNode = node
            }
        }
        
        return rig
    }
    
    private func parseGLBOrVRMData(_ data: Data, originalUrl: URL) -> VRMAvatarRig? {
        guard data.count >= 12 else { return nil }
        let magic = data.subdata(in: 0..<4)
        guard let magicStr = String(data: magic, encoding: .ascii), magicStr == "glTF" else { return nil }
        
        do {
            let scene = try SCNScene(url: originalUrl, options: nil)
            return parseAvatarRig(from: scene.rootNode)
        } catch {
            print("⚠️ [VRMLoader] Impossible de parser les données GLB: \(error.localizedDescription)")
            return nil
        }
    }
}
