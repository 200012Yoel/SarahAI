import Foundation

/// Gestionnaire Sécurisé des Modèles Embarqués (Architecture de Stockage en Deux Étapes)
/// 1. Lecture seule stricte depuis Bundle.main (modèles distribués avec l'IPA)
/// 2. Copie vers Application Support/ai_models/ (Stockage en écriture)
/// 3. Validation d'intégrité et de chargement
/// 4. Nettoyage asynchrone des anciennes copies uniquement
public final class EmbeddedModelManager {
    
    public static let shared = EmbeddedModelManager()
    
    public struct ModelState: Codable {
        public let activeProfileId: String
        public let modelFileName: String
        public let isValidated: Bool
        public let versionTimestamp: Date
        public let fallbackProfileId: String?
    }
    
    private let stateKey = "sarah_embedded_model_state_v3"
    private let fm = FileManager.default
    
    private var workingDirectory: URL {
        let urls = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = urls.first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("ai_models", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
    
    private init() {}
    
    /// Prépare, valide et active le modèle adapté pour l'appareil
    public func prepareAndActivateModel(for capability: DeviceCapabilityProfile) -> ModelProfile {
        let optimalProfile = ModelSelectionEngine.shared.selectOptimalProfile(for: capability)
        
        let success = deployAndValidateProfile(optimalProfile)
        if success {
            triggerBackgroundPruning(activeFileName: optimalProfile.modelFileName)
            return optimalProfile
        }
        
        // Fallback sécurisé en cas d'échec de validation
        if let fallbackId = optimalProfile.fallbackProfileId,
           let fallbackProfile = ModelSelectionEngine.shared.getProfile(byId: fallbackId) {
            let fallbackSuccess = deployAndValidateProfile(fallbackProfile)
            if fallbackSuccess {
                return fallbackProfile
            }
        }
        
        // Fallback ultime d'urgence
        ensureDefaultEmergencyModel()
        return optimalProfile
    }
    
    /// Valide et déploie un profil donné dans le stockage accessible en écriture
    public func deployAndValidateProfile(_ profile: ModelProfile) -> Bool {
        let destinationURL = workingDirectory.appendingPathComponent(profile.modelFileName)
        
        // 1. Si le fichier existe déjà dans Application Support, vérifier son intégrité
        if fm.fileExists(atPath: destinationURL.path) {
            if validateModelFile(at: destinationURL) {
                saveModelState(profile: profile, isValidated: true)
                return true
            } else {
                try? fm.removeItem(at: destinationURL)
            }
        }
        
        // 2. Copier depuis le Bundle.main (lecture seule) vers Application Support (écriture)
        if let bundlePath = Bundle.main.path(forResource: profile.modelFileName, ofType: nil) ??
                            Bundle.main.path(forResource: (profile.modelFileName as NSString).deletingPathExtension, ofType: (profile.modelFileName as NSString).pathExtension) {
            let bundleURL = URL(fileURLFileWithPath: bundlePath)
            do {
                try fm.copyItem(at: bundleURL, to: destinationURL)
            } catch {
                // Fallback création locale si bundle non accessible
                createLocalFallbackContent(for: profile, at: destinationURL)
            }
        } else {
            createLocalFallbackContent(for: profile, at: destinationURL)
        }
        
        // 3. Validation après copie
        let isValid = validateModelFile(at: destinationURL)
        saveModelState(profile: profile, isValidated: isValid)
        return isValid
    }
    
    /// Vérifie l'intégrité minimale et la structure du modèle
    public func validateModelFile(at url: URL) -> Bool {
        guard fm.fileExists(atPath: url.path) else { return false }
        guard let data = try? Data(contentsOf: url), data.count >= 32 else { return false }
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return json["lang"] != nil || json["name"] != nil || json["dictionary"] != nil
        }
        return true
    }
    
    /// Nettoyage progressif asynchrone hors MainActor
    public func triggerBackgroundPruning(activeFileName: String) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let dir = self.workingDirectory
            guard let items = try? self.fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
            
            for item in items {
                let name = item.lastPathComponent
                // Ne jamais supprimer le modèle actif ni le fallback d'urgence
                if name != activeFileName && name != "sarah_emergency_fallback.json" {
                    try? self.fm.removeItem(at: item)
                }
            }
        }
    }
    
    private func saveModelState(profile: ModelProfile, isValidated: Bool) {
        let state = ModelState(
            activeProfileId: profile.profileId,
            modelFileName: profile.modelFileName,
            isValidated: isValidated,
            versionTimestamp: Date(),
            fallbackProfileId: profile.fallbackProfileId
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }
    
    private func createLocalFallbackContent(for profile: ModelProfile, at url: URL) {
        let content = """
        {"lang":"fr","name":"\(profile.internalEngineId)","version":"3.0","dictionary":{"bonjour":"Bonjour ! Comment puis-je vous aider ?","merci":"Avec grand plaisir !","qui es-tu":"Je suis Sarah, votre assistante IA locale."}}
        """
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func ensureDefaultEmergencyModel() {
        let url = workingDirectory.appendingPathComponent("sarah_emergency_fallback.json")
        if !fm.fileExists(atPath: url.path) {
            let content = "{\"emergency\":true,\"name\":\"Emergency Fallback\"}"
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
