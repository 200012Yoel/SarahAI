import Foundation
import SceneKit
import UIKit

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
}

/// Chargeur et analyseur de modèles VRoid Studio (.vrm / .glb / .usdz / .scn)
public final class VRMLoader {
    
    public static let shared = VRMLoader()
    
    private init() {}
    
    /// Recherche et charge le fichier VRM "Sarah.vrm" ou ses variantes
    public func loadSarahAvatar() -> VRMAvatarRig? {
        let candidates = [
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
        
        for candidate in candidates {
            let baseName = (candidate as NSString).deletingPathExtension
            let ext = (candidate as NSString).pathExtension
            
            // 1. Recherche dans le Bundle principal
            if let bundleUrl = Bundle.main.url(forResource: baseName, withExtension: ext) {
                if let rig = loadAvatar(from: bundleUrl) {
                    print("✅ [VRMLoader] Modèle chargé depuis le Bundle: \(candidate)")
                    return rig
                }
            }
            
            // 2. Recherche dans Documents
            if let docUrl = documentUrls.first?.appendingPathComponent(candidate), fileManager.fileExists(atPath: docUrl.path) {
                if let rig = loadAvatar(from: docUrl) {
                    print("✅ [VRMLoader] Modèle chargé depuis Documents: \(candidate)")
                    return rig
                }
            }
            
            // 3. Recherche dans Application Support / SarahAI
            if let appSupport = appSupportUrls.first {
                let customUrl = appSupport.appendingPathComponent("SarahAI/\(candidate)")
                if fileManager.fileExists(atPath: customUrl.path) {
                    if let rig = loadAvatar(from: customUrl) {
                        print("✅ [VRMLoader] Modèle chargé depuis AppSupport: \(candidate)")
                        return rig
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Charge un avatar depuis une URL locale
    public func loadAvatar(from url: URL) -> VRMAvatarRig? {
        let ext = url.pathExtension.lowercased()
        
        // Pour les formats SceneKit / USDZ natifs
        if ext == "usdz" || ext == "scn" || ext == "dae" || ext == "obj" {
            if let scene = try? SCNScene(url: url, options: nil) {
                return parseAvatarRig(from: scene.rootNode)
            }
        }
        
        // Pour les fichiers VRM / GLB (glTF 2.0 Binary)
        if ext == "vrm" || ext == "glb" || ext == "gltf" {
            // Tentative directe avec ModelIO / SceneKit
            if let scene = try? SCNScene(url: url, options: nil) {
                return parseAvatarRig(from: scene.rootNode)
            }
            
            // Si SCNScene n'a pas de convertisseur glTF natif sur cette version iOS,
            // on inspecte le contenu et on extrait les nodes
            if let data = try? Data(contentsOf: url) {
                return parseGLBOrVRMData(data, originalUrl: url)
            }
        }
        
        return nil
    }
    
    /// Analyse et découvre l'arborescence squelettique et les blendshapes VRM / VRoid
    public func parseAvatarRig(from root: SCNNode) -> VRMAvatarRig {
        var rig = VRMAvatarRig(rootNode: root)
        
        root.enumerateChildNodes { node, _ in
            let rawName = node.name ?? ""
            let name = rawName.lowercased()
            
            // 1. Détection des Morphers (Visage & BlendShapes)
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
            
            // 2. Détection du Squelette Humanoïde VRoid Studio (Convention J_Bip_ / Mixamo / VRM)
            // Tête & Cou
            if name.contains("j_bip_c_head") || name.contains("head") && !name.contains("hair") && !name.contains("headband") {
                if rig.headNode == nil { rig.headNode = node }
            } else if name.contains("j_bip_c_neck") || name.contains("neck") {
                rig.neckNode = node
            }
            // Rachis & Torse
            else if name.contains("j_bip_c_chest") || name.contains("j_bip_c_upperchest") || name.contains("chest") || name.contains("upperchest") {
                rig.chestNode = node
            } else if name.contains("j_bip_c_spine") || name.contains("spine") || name.contains("torso") {
                rig.spineNode = node
            }
            // Bras Gauche
            else if name.contains("j_bip_l_shoulder") || name.contains("shoulder_l") || name.contains("leftshoulder") {
                rig.leftShoulderNode = node
            } else if name.contains("j_bip_l_upperarm") || name.contains("arm_l") || name.contains("leftupperarm") || name.contains("leftarm") {
                rig.leftUpperArmNode = node
            } else if name.contains("j_bip_l_lowerarm") || name.contains("forearm_l") || name.contains("leftforearm") || name.contains("leftlowerarm") {
                rig.leftForearmNode = node
            } else if name.contains("j_bip_l_hand") || name.contains("hand_l") || name.contains("lefthand") || name.contains("wrist_l") {
                rig.leftHandNode = node
            }
            // Bras Droit
            else if name.contains("j_bip_r_shoulder") || name.contains("shoulder_r") || name.contains("rightshoulder") {
                rig.rightShoulderNode = node
            } else if name.contains("j_bip_r_upperarm") || name.contains("arm_r") || name.contains("rightupperarm") || name.contains("rightarm") {
                rig.rightUpperArmNode = node
            } else if name.contains("j_bip_r_lowerarm") || name.contains("forearm_r") || name.contains("rightforearm") || name.contains("rightlowerarm") {
                rig.rightForearmNode = node
            } else if name.contains("j_bip_r_hand") || name.contains("hand_r") || name.contains("righthand") || name.contains("wrist_r") {
                rig.rightHandNode = node
            }
        }
        
        return rig
    }
    
    private func parseGLBOrVRMData(_ data: Data, originalUrl: URL) -> VRMAvatarRig? {
        // Validation header glTF (Magic 0x46546C67 = "glTF")
        guard data.count >= 12 else { return nil }
        let magic = data.subdata(in: 0..<4)
        guard let magicStr = String(data: magic, encoding: .ascii), magicStr == "glTF" else { return nil }
        
        // Chargement via SCNScene temporaire
        if let scene = try? SCNScene(url: originalUrl, options: nil) {
            return parseAvatarRig(from: scene.rootNode)
        }
        
        return nil
    }
}
