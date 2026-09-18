import Foundation
import UIKit
import CoreML
import AVFoundation
import Combine
import ZIPFoundation

#if canImport(StableDiffusion)
import StableDiffusion
#endif

/// Service d'intelligence artificielle avec moteur d'apprentissage dynamique et mémoire persistante.
final class AIService {
    
    static let shared = AIService()
    
    private let storage = StorageService.shared
    
    private let openAI = OpenAIService.shared
    private let translation = TranslationEngine.shared
    private let modelDownloader = ModelDownloader.shared
    
    private init() {}
    
    /// Génère une réponse IA pour la question ou la commande donnée (iOS 13+)
    @available(iOS 13.0, *)
    func generateResponse(for question: String) async -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeText(trimmed)
        
        // -----------------------------------------------------------------
        // 0. CONTRÔLE MATÉRIEL & PRESSE-PAPIER LOCAL
        // -----------------------------------------------------------------
        if normalized.contains("batterie") || normalized.contains("niveau de batterie") || normalized.contains("pourcentage batterie") {
            return DeviceController.shared.getBatteryStatus()
        }
        
        if normalized.contains("presse papier") || normalized.contains("texte copie") || normalized.contains("ce que j ai copie") {
            if let clip = ClipboardCompanion.shared.getClipboardText(), !clip.isEmpty {
                return "Voici le contenu de votre presse-papier : « \(clip) »."
            } else {
                return "Votre presse-papier est actuellement vide."
            }
        }
        
        // -----------------------------------------------------------------
        // 0.1 TRADUCTION MULTILINGUE TEMPS RÉEL (FR ⇄ HE, FR ⇄ EN, EN ⇄ FR)
        // -----------------------------------------------------------------
        if let translationReq = translation.parseTranslationIntent(input: trimmed) {
            let translated = await translation.translate(
                text: translationReq.textToTranslate,
                sourceLang: translationReq.sourceLanguage,
                targetLang: translationReq.targetLanguage
            )
            return "En \(translationReq.targetLanguage.displayNameFr) : \(translated)"
        }
        
        if #available(iOS 16.0, *) {
            // -----------------------------------------------------------------
            // 0.2 CRÉATION LOCALE — IMAGE / MUSIQUE / VIDÉO
            // -----------------------------------------------------------------
            if isImageGenerationIntent(normalized) {
                let prompt = cleanedMediaPrompt(trimmed, mediaWords: [
                    "génère une image", "genere une image", "génère une photo", "genere une photo",
                    "crée une image", "cree une image", "crée une photo", "cree une photo",
                    "fais une image", "fais une photo", "dessine"
                ])

                guard SarahLocalImageGenEngine.shared.isInstalled else {
                    let profile = SarahGenerativeModelCatalog.imageProfile()
                    return "🎨 Le moteur **\(profile.displayName)** est sélectionné pour cet iPhone. Installe-le d'abord dans Réglages → Création locale."
                }

                return await withCheckedContinuation { continuation in
                    SarahLocalImageGenEngine.shared.generate(prompt: prompt) { result in
                        switch result {
                        case .success(let url):
                            continuation.resume(returning:
                                "🎨 Image générée localement avec **\(SarahGenerativeModelCatalog.imageProfile().displayName)**. Fichier : \(url.lastPathComponent)"
                            )
                        case .failure(let error):
                            continuation.resume(returning: "🎨 La génération locale a échoué : \(error.localizedDescription)")
                        }
                    }
                }
            }

            let musicIntent = SarahLocalMusicGenEngine.shared.detectIntent(trimmed)
            if musicIntent.isIntent {
                if musicIntent.wantsLyrics {
                    let languageText = musicIntent.language == "en" ? "anglais" : "français"
                    return "🎤 Je peux préparer une chanson avec des paroles originales en \(languageText). Le profil de chant **\(SarahGenerativeModelCatalog.vocalSongProfile().displayName)** reste expérimental sur iPhone. Pour l'instant, la vraie génération audio locale disponible est l'instrumental Stable Audio."
                }

                guard SarahLocalMusicGenEngine.shared.isInstalled else {
                    return "🎵 Le modèle **\(SarahGenerativeModelCatalog.musicProfile().displayName)** doit d'abord être téléchargé dans Réglages → Création locale."
                }

                return await withCheckedContinuation { continuation in
                    SarahLocalMusicGenEngine.shared.generate(prompt: musicIntent.prompt) { result in
                        switch result {
                        case .success(let url):
                            continuation.resume(returning:
                                "🎵 Musique générée localement avec **Stable Audio Open Small · Core ML**. Fichier : \(url.lastPathComponent)"
                            )
                        case .failure(let error):
                            continuation.resume(returning: "🎵 La génération musicale locale a échoué : \(error.localizedDescription)")
                        }
                    }
                }
            }

            if isVideoGenerationIntent(normalized) {
                let profile = SarahGenerativeModelCatalog.videoProfile()
                let installed = GenerativeModelManager.shared.isVideoCheckpointInstalled
                if installed {
                    return "🎬 **\(profile.displayName)** est téléchargé. Le checkpoint est local, mais son runtime iOS reste expérimental : Sarah ne lance pas une fausse génération tant que l'inférence vidéo n'est pas validée."
                } else {
                    return "🎬 Le profil vidéo sélectionné est **\(profile.displayName)**. Tu peux télécharger son checkpoint depuis Réglages → Création locale. Le runtime iOS reste expérimental."
                }
            }
        }

        var state = storage.loadState()
        
        // -----------------------------------------------------------------
        // 1. ÉTAPE 2 DE L'APPRENTISSAGE INTERACTIF (En attente de la réponse)
        // -----------------------------------------------------------------
        if let pendingTrigger = state.pendingLearningTrigger, !pendingTrigger.isEmpty {
            // Si l'utilisateur annule
            if normalized == "annule" || normalized == "annuler" || normalized == "laisse tomber" || normalized == "stop" {
                state.pendingLearningTrigger = nil
                storage.saveState(state)
                return "D'accord, apprentissage annulé ! Que souhaitez-vous faire ?"
            }
            
            // Enregistrer l'association dans la mémoire persistante
            let cleanTrigger = pendingTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
            state.learnedMemories[normalizeText(cleanTrigger)] = trimmed
            state.pendingLearningTrigger = nil
            storage.saveState(state)
            
            return "C'est appris ! 🧠 Dès que vous me direz « \(cleanTrigger) », je répondrai : « \(trimmed) »."
        }
        
        // -----------------------------------------------------------------
        // 2. DÉCLENCHEMENT D'APPRENTISSAGE DIRECT (Mono-instruction)
        // Ex: "Apprends : papa = il est pas là" ou "Quand je dis papa, réponds il est pas là"
        // -----------------------------------------------------------------
        if let directLearning = parseDirectLearningCommand(trimmed) {
            state.learnedMemories[normalizeText(directLearning.trigger)] = directLearning.response
            storage.saveState(state)
            return "Parfait ! J'ai mémorisé que pour « \(directLearning.trigger) », je dois répondre : « \(directLearning.response) »."
        }
        
        // -----------------------------------------------------------------
        // 3. DÉCLENCHEMENT D'APPRENTISSAGE INTERACTIF (Multi-tours)
        // Ex: "Apprends papa" ou "Apprends : papa" ou "Enseigne papa"
        // -----------------------------------------------------------------
        if let triggerToLearn = parseInteractiveLearningInitiation(trimmed) {
            state.pendingLearningTrigger = triggerToLearn
            storage.saveState(state)
            return "Je dois répondre quoi ?"
        }
        
        // -----------------------------------------------------------------
        // 4. COMMANDES DE GESTION DE MÉMOIRE (Oublier / Lister)
        // -----------------------------------------------------------------
        if normalized.starts(with: "oublie ") || normalized.starts(with: "efface ") {
            let target = trimmed.replacingOccurrences(of: "oublie ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "efface ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let normTarget = normalizeText(target)
            if state.learnedMemories.removeValue(forKey: normTarget) != nil {
                storage.saveState(state)
                return "C'est fait, j'ai oublié ce que je devais répondre pour « \(target) »."
            } else if normalized.contains("tout") || normalized.contains("memoire") {
                state.learnedMemories.removeAll()
                storage.saveState(state)
                return "Toute ma mémoire personnalisée a été réinitialisée !"
            }
        }
        
        if normalized.contains("qu'est ce que tu as appris") || normalized.contains("que sais tu") || normalized.contains("liste ta memoire") || normalized.contains("tes souvenirs") {
            if state.learnedMemories.isEmpty {
                return "Je n'ai pas encore appris de réponses personnalisées. Vous pouvez m'apprendre quelque chose en disant par exemple : « Apprends papa » !"
            } else {
                var list = "Voici ce que vous m'avez appris jusqu'à présent :\n"
                for (trigger, response) in state.learnedMemories {
                    list += "• Quand vous dites « \(trigger) » ➔ « \(response) »\n"
                }
                return list
            }
        }
        
        // -----------------------------------------------------------------
        // 5. RECHERCHE DANS LA MÉMOIRE PERSISTANTE APPRISE
        // -----------------------------------------------------------------
        if let learnedResponse = state.learnedMemories[normalized] {
            return learnedResponse
        }
        
        // Recherche souple si la phrase contient exactement un déclencheur appris
        for (trigger, response) in state.learnedMemories {
            if normalized == trigger || normalized.contains(" \(trigger) ") || normalized.starts(with: "\(trigger) ") || normalized.hasSuffix(" \(trigger)") {
                return response
            }
        }
        
        // -----------------------------------------------------------------
        // 6. CONVERSATION NATURELLE & GREETINGS
        // -----------------------------------------------------------------
        if normalized == "bonjour" || normalized == "salut" || normalized == "hello" || normalized == "coucou" || normalized.starts(with: "bonjour") || normalized.starts(with: "salut") {
            return "Bonjour ! 👋 Comment puis-je vous aider aujourd'hui ?"
        }
        
        if normalized.contains("meteo") || normalized.contains("temps") || normalized.contains("pluie") || normalized.contains("soleil") {
            return pickRandom(from: weatherResponses)
        }
        
        if normalized.contains("heure") || normalized.contains("quelle heure") {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let time = formatter.string(from: Date())
            return "Il est actuellement \(time). ⏰ Que puis-je faire pour vous ?"
        }
        
        if normalized.contains("aide") || normalized.contains("aider") || normalized.contains("comment tu marche") {
            return "Je suis Sarah, votre assistante IA interactive ! 🌟\n\nVous pouvez :\n1. Discuter avec moi au texte ou à la voix.\n2. M'apprendre des réponses personnalisées (ex: dites « Apprends papa » puis indiquez quoi répondre).\n3. Voir mes expressions et gestes en direct sur mon Avatar 3D !"
        }
        
        if normalized.contains("merci") || normalized.contains("super") || normalized.contains("genial") || normalized.contains("parfait") {
            return pickRandom(from: thanksResponses)
        }
        
        if normalized.contains("nom") || normalized.contains("appelle") || normalized.contains("qui es tu") || normalized.contains("qui est tu") || normalized == "sarah" {
            return pickRandom(from: identityResponses)
        }
        
        if normalized.contains("blague") || normalized.contains("rire") || normalized.contains("drole") || normalized.contains("humour") {
            return pickRandom(from: jokeResponses)
        }
        
        if normalized.contains("au revoir") || normalized.contains("bye") || normalized.contains("a bientot") || normalized.contains("bonne nuit") {
            return pickRandom(from: goodbyeResponses)
        }
        
        // -----------------------------------------------------------------
        // 5. RAISONNEMENT PROFOND OPENAI (Multi-tours & intelligence poussée)
        // -----------------------------------------------------------------
        let pastContext = SemanticMemoryIndex.shared.findRelevantContext(query: trimmed)
        if openAI.isConfigured {
            do {
                let promptWithContext = pastContext != nil ? "\(trimmed) (Contexte récent : \(pastContext!))" : trimmed
                let aiResponse = try await openAI.ask(prompt: promptWithContext)
                SemanticMemoryIndex.shared.indexExchange(userText: trimmed, assistantText: aiResponse, topicType: "conversation")
                return aiResponse
            } catch {
                print("⚠️ [AIService] OpenAI indisponible, bascule sur le modèle hors-ligne.")
            }
        }
        
        // -----------------------------------------------------------------
        // 6. MODÈLE HORS-LIGNE & BASE LOCALE RÉSILIENTE (AVEC CONTEXTE LOCAL RAG)
        // -----------------------------------------------------------------
        let detected = translation.detectLanguage(text: trimmed)
        let response: String
        if detected == "he" {
            response = "שלום ! שמעתי אותך מצוין : « \(trimmed) ». איך אני יכולה לעזור לך ?"
        } else if let ctx = pastContext {
            response = "Concernant notre échange précédent, j'ai bien noté : « \(trimmed) »."
        } else {
            response = pickRandom(from: defaultResponses)
        }
        
        SemanticMemoryIndex.shared.indexExchange(userText: trimmed, assistantText: response, topicType: "offline")
        return response
    }
    
    /// Réponse pour le test de notification d'arrière-plan
    @available(iOS 13.0, *)
    func generateBackgroundTestResponse() async -> String {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        return "🔔 Test d'arrière-plan réussi ! Sarah AI continue de fonctionner et de vous écouter même en arrière-plan. 🚀"
    }
    
    private func isImageGenerationIntent(_ normalized: String) -> Bool {
        [
            "genere une image", "genere une photo", "cree une image", "cree une photo",
            "fais une image", "fais une photo", "dessine"
        ].contains { normalized.contains($0) }
    }

    private func isVideoGenerationIntent(_ normalized: String) -> Bool {
        [
            "genere une video", "cree une video", "fais une video",
            "video ia", "image vers video"
        ].contains { normalized.contains($0) }
    }

    private func cleanedMediaPrompt(_ text: String, mediaWords: [String]) -> String {
        var result = text
        for word in mediaWords {
            result = result.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        result = result.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":,-"))
        )
        return result.isEmpty ? text : result
    }

    // MARK: - Parsing Helpers
    
    private func parseDirectLearningCommand(_ text: String) -> (trigger: String, response: String)? {
        let lower = text.lowercased()
        
        // Ex: "Apprends : papa = il est pas là" ou "Apprends papa = il est pas là"
        if (lower.starts(with: "apprends") || lower.starts(with: "enseigne")) && text.contains("=") {
            let cleaned = text.replacingOccurrences(of: "apprends :", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "apprends", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "enseigne", with: "", options: .caseInsensitive)
            let parts = cleaned.components(separatedBy: "=")
            if parts.count >= 2 {
                let trigger = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let response = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trigger.isEmpty && !response.isEmpty {
                    return (trigger, response)
                }
            }
        }
        
        // Ex: "Quand je dis papa, réponds il est pas là"
        if lower.starts(with: "quand je dis ") && lower.contains("reponds ") {
            let withoutPrefix = text.replacingOccurrences(of: "quand je dis ", with: "", options: .caseInsensitive)
            let parts = withoutPrefix.components(separatedBy: "réponds ")
            if parts.count >= 2 {
                let trigger = parts[0].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let response = parts.dropFirst().joined(separator: "réponds ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trigger.isEmpty && !response.isEmpty {
                    return (trigger, response)
                }
            }
        }
        
        return nil
    }
    
    private func parseInteractiveLearningInitiation(_ text: String) -> String? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if lower.starts(with: "apprends :") || lower.starts(with: "apprends:") {
            let trigger = text.replacingOccurrences(of: "apprends :", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "apprends:", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trigger.isEmpty ? nil : trigger
        }
        
        if lower.starts(with: "apprends ") {
            let trigger = text.replacingOccurrences(of: "apprends ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trigger.isEmpty ? nil : trigger
        }
        
        if lower.starts(with: "enseigne ") {
            let trigger = text.replacingOccurrences(of: "enseigne ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trigger.isEmpty ? nil : trigger
        }
        
        return nil
    }
    
    private func normalizeText(_ text: String) -> String {
        return text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Pools de Réponses
    
    private let thanksResponses = [
        "De rien ! C'est un plaisir de vous aider. 😊",
        "Avec plaisir ! 🌟 Je suis toujours là si vous avez besoin de moi.",
        "Merci à vous ! C'est motivant de pouvoir échanger. 💪"
    ]
    
    private let identityResponses = [
        "Je suis Sarah AI, votre assistante 3D intelligente ! 🤖 Vous pouvez me poser des questions ou m'apprendre de nouvelles réponses.",
        "Mon nom est Sarah ! Je suis une intelligence artificielle interactive embarquée sur votre appareil. 📱"
    ]
    
    private let jokeResponses = [
        "Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? 🤔 Parce que sinon ils tomberaient dans le bateau ! 😂",
        "Qu'est-ce qu'un canif ? 🔪 Un petit fien ! 😄",
        "Deux informaticiens discutent : « C'est quoi ton adresse IP ? » — « 192.168... attends, c'est personnel ! » 💻😄"
    ]
    
    private let weatherResponses = [
        "La météo est changeante ! ☁️ N'oubliez pas de jeter un coup d'œil à votre application météo.",
        "Je n'ai pas accès aux données satellites en temps réel, mais j'espère qu'il fait beau chez vous ! ☀️"
    ]
    
    private let goodbyeResponses = [
        "Au revoir ! 👋 C'était un plaisir. À très vite !",
        "À bientôt ! 🌟 Prenez soin de vous.",
        "Bonne journée ! 😊 N'hésitez pas à revenir quand vous voulez."
    ]
    
    private let defaultResponses = [
        "C'est une remarque intéressante ! 🤔 Si vous voulez que je retienne une réponse précise pour ce mot, dites-moi « Apprends [mot] » !",
        "Je comprends ! 💡 N'hésitez pas à m'apprendre comment vous souhaitez que je réponde à cela.",
        "Je note cela ! 🧠 Je m'améliore constamment grâce à nos échanges.",
        "Ma base de connaissances est encore limitée. 📚 Essayons un autre sujet ! Vous pouvez me demander des blagues, de l'aide, ou simplement discuter."
    ]
    
    // MARK: - Helpers
    
    private func pickRandom(from pool: [String]) -> String {
        pool.randomElement() ?? "Je suis là pour vous aider ! 😊"
    }
}


// MARK: - Embedded Generative Media Runtime
// Ces types restent volontairement dans un fichier source déjà inclus dans
// la cible Xcode stable. Cela évite qu'une ancienne structure de projet
// ignore de nouveaux fichiers lors du build Xcode 26.6.

public enum SarahGenerativeMediaKind: String, Codable {
    case image
    case video
    case music
    case vocalSong
}

public enum SarahGenerativeRuntimeState: String, Codable {
    case ready
    case requiresDownload
    case experimental
    case unsupported
}

public struct SarahGenerativeModelProfile: Codable, Equatable {
    public let kind: SarahGenerativeMediaKind
    public let identifier: String
    public let displayName: String
    public let resolution: String
    public let licenseName: String
    public let licenseURL: String
    public let sourceURL: String
    public let minimumRAMGB: Double
    public let minimumIOSMajor: Int
    public let runtimeState: SarahGenerativeRuntimeState
    public let note: String
}

public struct SarahGenerativeModelCatalog {
    public static var physicalRAMGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
    }

    public static var iosMajor: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    public static func imageProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        if os >= 17 && ram >= 7.5 {
            return .init(
                kind: .image,
                identifier: "apple-sdxl-1.0-ios-4bit",
                displayName: "SDXL 1.0 Core ML 4-bit",
                resolution: "768 × 768",
                licenseName: "OpenRAIL++",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 17,
                runtimeState: .requiresDownload,
                note: "Profil haute qualité pour les iPhone disposant d'environ 8 Go de RAM ou plus."
            )
        }

        if os >= 17 && ram >= 5.5 {
            return .init(
                kind: .image,
                identifier: "apple-sd21-6bit",
                displayName: "Stable Diffusion 2.1 Core ML 6-bit",
                resolution: "512 × 512",
                licenseName: "CreativeML OpenRAIL++-M",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized",
                minimumRAMGB: 5.5,
                minimumIOSMajor: 17,
                runtimeState: .requiresDownload,
                note: "Profil recommandé pour iPhone 14 : compact et optimisé Core ML."
            )
        }

        if os >= 16 && ram >= 4.0 {
            return .init(
                kind: .image,
                identifier: "apple-sd21-base",
                displayName: "Stable Diffusion 2.1 Core ML",
                resolution: "512 × 512",
                licenseName: "CreativeML OpenRAIL++-M",
                licenseURL: "https://huggingface.co/stabilityai/stable-diffusion-2/blob/main/LICENSE-MODEL",
                sourceURL: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base",
                minimumRAMGB: 4.0,
                minimumIOSMajor: 16,
                runtimeState: .requiresDownload,
                note: "Profil compatible avec les iPhone plus anciens disposant d'au moins 4 Go de RAM."
            )
        }

        return .init(
            kind: .image,
            identifier: "image-local-unsupported",
            displayName: "Image locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 16,
            runtimeState: .unsupported,
            note: "Mémoire insuffisante pour Stable Diffusion local."
        )
    }

    public static func videoProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        if os >= 18 && ram >= 7.5 {
            return .init(
                kind: .video,
                identifier: "movd-coreml",
                displayName: "MOVD Core ML",
                resolution: "Texte → vidéo",
                licenseName: "MIT",
                licenseURL: "https://github.com/eai-lab/MOVD/blob/main/LICENSE",
                sourceURL: "https://github.com/eai-lab/MOVD",
                minimumRAMGB: 7.5,
                minimumIOSMajor: 18,
                runtimeState: .experimental,
                note: "Profil vidéo pour les iPhone puissants. Le runtime doit encore être validé dans Sarah avant activation."
            )
        }

        if os >= 17 && ram >= 5.5 {
            return .init(
                kind: .video,
                identifier: "mobilei2v-027b",
                displayName: "MobileI2V 0.27B",
                resolution: "Image → vidéo",
                licenseName: "MIT (poids) / Apache-2.0 (code)",
                licenseURL: "https://huggingface.co/hustvl/MobileI2V",
                sourceURL: "https://github.com/hustvl/MobileI2V",
                minimumRAMGB: 5.5,
                minimumIOSMajor: 17,
                runtimeState: .experimental,
                note: "Profil iPhone 14. Le checkpoint est téléchargeable, mais le runtime iOS public n'est pas encore prêt : Sarah ne prétend pas générer tant que l'inférence locale n'est pas validée."
            )
        }

        return .init(
            kind: .video,
            identifier: "video-local-unsupported",
            displayName: "Vidéo locale indisponible",
            resolution: "—",
            licenseName: "—",
            licenseURL: "",
            sourceURL: "",
            minimumRAMGB: 0,
            minimumIOSMajor: 16,
            runtimeState: .unsupported,
            note: "Pas de moteur vidéo local vérifié pour ce matériel."
        )
    }

    public static func musicProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        guard os >= 16 && ram >= 5.5 else {
            return .init(
                kind: .music,
                identifier: "music-local-unsupported",
                displayName: "Musique locale indisponible",
                resolution: "—",
                licenseName: "—",
                licenseURL: "",
                sourceURL: "",
                minimumRAMGB: 0,
                minimumIOSMajor: 16,
                runtimeState: .unsupported,
                note: "La génération musicale demande environ 6 Go de RAM."
            )
        }

        return .init(
            kind: .music,
            identifier: "stable-audio-open-small-coreml",
            displayName: "Stable Audio Open Small · Core ML",
            resolution: "44,1 kHz stéréo · ~10 s",
            licenseName: "Stability AI Community License",
            licenseURL: "https://stability.ai/license",
            sourceURL: "https://github.com/john-rocky/CoreML-Models/tree/main/sample_apps/StableAudioDemo",
            minimumRAMGB: 5.5,
            minimumIOSMajor: 16,
            runtimeState: .requiresDownload,
            note: "Profil iPhone 14 : environ 580 Mo de modèles Core ML téléchargés à la demande."
        )
    }

    public static func vocalSongProfile() -> SarahGenerativeModelProfile {
        let ram = physicalRAMGB
        let os = iosMajor

        guard os >= 16 && ram >= 5.5 else {
            return .init(
                kind: .vocalSong,
                identifier: "vocal-song-local-unsupported",
                displayName: "Chanson chantée locale indisponible",
                resolution: "—",
                licenseName: "—",
                licenseURL: "",
                sourceURL: "",
                minimumRAMGB: 0,
                minimumIOSMajor: 16,
                runtimeState: .unsupported,
                note: "Pas de runtime de chant local validé pour cet appareil."
            )
        }

        return .init(
            kind: .vocalSong,
            identifier: "ace-step-1.5-turbo",
            displayName: "ACE-Step 1.5 Turbo",
            resolution: "Chanson complète · paroles multilingues",
            licenseName: "MIT",
            licenseURL: "https://github.com/ace-step/ACE-Step-1.5/blob/main/LICENSE",
            sourceURL: "https://github.com/ace-step/ACE-Step-1.5",
            minimumRAMGB: 5.5,
            minimumIOSMajor: 16,
            runtimeState: .experimental,
            note: "Cible pour chansons chantées en français et anglais. Pas encore activée sur iPhone faute de runtime iOS local validé."
        )
    }
}

public final class SarahLocalImageGenEngine {

    public static let shared = SarahLocalImageGenEngine()

    public struct Configuration {
        public var steps: Int = 20
        public var guidanceScale: Float = 7.5
        public var seed: UInt32 = UInt32.random(in: 0...UInt32.max)

        public init() {}
    }

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.sarahia.imagegen.local", qos: .userInitiated)

    private init() {}

    public var modelDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent(SarahGenerativeModelCatalog.imageProfile().identifier, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func discoverResourceDirectory() -> URL? {
        if isValidResourceDirectory(modelDirectory) { return modelDirectory }

        guard let e = fm.enumerator(
            at: modelDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in e {
            if isValidResourceDirectory(url) { return url }
        }
        return nil
    }

    public var isInstalled: Bool {
        discoverResourceDirectory() != nil
    }

    private func isValidResourceDirectory(_ dir: URL) -> Bool {
        let textEncoder = fm.fileExists(atPath: dir.appendingPathComponent("TextEncoder.mlmodelc").path)
        let unet =
            fm.fileExists(atPath: dir.appendingPathComponent("Unet.mlmodelc").path)
            || (
                fm.fileExists(atPath: dir.appendingPathComponent("UnetChunk1.mlmodelc").path)
                && fm.fileExists(atPath: dir.appendingPathComponent("UnetChunk2.mlmodelc").path)
            )
        let vae = fm.fileExists(atPath: dir.appendingPathComponent("VAEDecoder.mlmodelc").path)
        let vocab = fm.fileExists(atPath: dir.appendingPathComponent("vocab.json").path)
        let merges =
            fm.fileExists(atPath: dir.appendingPathComponent("merges.txt").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("merges.text").path)
        return textEncoder && unet && vae && vocab && merges
    }

    public func generate(
        prompt: String,
        configuration: Configuration = Configuration(),
        progress: ((Int, Int) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(error(400, "Le prompt image est vide.")))
            return
        }

        guard let resources = discoverResourceDirectory() else {
            completion(.failure(error(404, "Le modèle image local n'est pas installé.")))
            return
        }

        #if canImport(StableDiffusion)
        guard #available(iOS 16.2, *) else {
            completion(.failure(error(426, "Stable Diffusion local nécessite iOS 16.2 ou plus.")))
            return
        }

        queue.async {
            do {
                var config = StableDiffusionPipeline.Configuration(prompt: clean)
                config.seed = configuration.seed
                config.stepCount = max(1, min(configuration.steps, 50))
                config.guidanceScale = configuration.guidanceScale

                let mlConfig = MLModelConfiguration()
                mlConfig.computeUnits = .all

                let pipeline = try StableDiffusionPipeline(
                    resourcesAt: resources,
                    controlNet: [],
                    configuration: mlConfig,
                    disableSafety: false,
                    reduceMemory: true
                )

                try pipeline.loadResources()
                let images = try pipeline.generateImages(configuration: config) { state in
                    DispatchQueue.main.async {
                        progress?(state.step, config.stepCount)
                    }
                    return true
                }
                pipeline.unloadResources()

                guard let cg = images.compactMap({ $0 }).first else {
                    throw self.error(500, "Aucune image produite.")
                }

                let image = UIImage(cgImage: cg)
                let url = try self.save(image: image, prompt: clean)

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedImageReady"),
                        object: url,
                        userInfo: [
                            "prompt": clean,
                            "modelName": SarahGenerativeModelCatalog.imageProfile().displayName,
                            "isLocal": true
                        ]
                    )
                    completion(.success(url))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        #else
        completion(.failure(error(501, "Le runtime StableDiffusion n'est pas lié à cette compilation.")))
        #endif
    }

    private func save(image: UIImage, prompt: String) throws -> URL {
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = root.appendingPathComponent("SarahIA/GeneratedImages", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let safe = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()
        let file = "sarah-\(safe.isEmpty ? "image" : safe)-\(Int(Date().timeIntervalSince1970)).jpg"
        let url = dir.appendingPathComponent(file)
        guard let data = image.jpegData(compressionQuality: 0.94) else {
            throw error(500, "Impossible d'encoder l'image.")
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private func error(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "SarahLocalImageGenEngine", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@available(iOS 16.0, *)
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
        case modelsMissing
        case invalidPackage(String)
        case tokenizerMissing
        case predictionFailed(String)
        case audioWriteFailed

        public var errorDescription: String? {
            switch self {
            case .emptyPrompt: return "La description musicale est vide."
            case .modelsMissing: return "Le modèle musical local n'est pas installé."
            case .invalidPackage(let name): return "Le paquet Core ML \(name) est invalide."
            case .tokenizerMissing: return "Le vocabulaire du tokenizer musical est manquant."
            case .predictionFailed(let stage): return "Échec de l'inférence musicale : \(stage)."
            case .audioWriteFailed: return "Impossible d'enregistrer le fichier audio."
            }
        }
    }

    private struct Asset {
        let id: String
        let url: URL
        let compiledName: String?
        let isArchive: Bool
    }

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.sarahia.music.local", qos: .userInitiated)

    private var vocabulary: [String: Int32] = [:]
    private var t5Encoder: MLModel?
    private var numberEmbedder: MLModel?
    private var diffusionTransformer: MLModel?
    private var vaeDecoder: MLModel?

    private let eosToken: Int32 = 1
    private let padToken: Int32 = 0

    private static let sampleRate: Double = 44_100
    private static let latentChannels = 64
    private static let latentLength = 256
    private static let fullAudioSamples = 524_288
    private static let maxTokens = 64
    private static let maxConditionSeconds: Float = 256

    private init() {}

    public func detectIntent(_ text: String) -> MusicIntent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let triggers = [
            "génère une musique", "genere une musique", "génère un morceau",
            "genere un morceau", "compose une musique", "compose un morceau",
            "crée une musique", "cree une musique", "fais une musique",
            "fais un morceau", "generate music", "generate a song",
            "instrumental", "chanson avec paroles"
        ]

        let isIntent = triggers.contains { lower.contains($0) }
        let wantsLyrics =
            lower.contains("paroles")
            || lower.contains("lyrics")
            || lower.contains("chanson")
            || lower.contains("song")

        let language = (lower.contains("anglais") || lower.contains("english")) ? "en" : "fr"

        var prompt = clean
        for trigger in triggers {
            prompt = prompt.replacingOccurrences(of: trigger, with: "", options: .caseInsensitive)
        }
        prompt = prompt.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":,-"))
        )
        if prompt.isEmpty { prompt = clean }

        return MusicIntent(
            isIntent: isIntent,
            wantsLyrics: wantsLyrics,
            prompt: prompt,
            language: language
        )
    }

    public var modelDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent("stable-audio-open-small-coreml", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var assets: [Asset] {
        [
            Asset(
                id: "T5Encoder",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioT5Encoder.mlpackage.zip")!,
                compiledName: "T5Encoder.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "NumberEmbedder",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioNumberEmbedder.mlpackage.zip")!,
                compiledName: "NumberEmbedder.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "DiT",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioDiT.mlpackage.zip")!,
                compiledName: "DiT.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "VAEDecoder",
                url: URL(string: "https://github.com/john-rocky/CoreML-Models/releases/download/stable-audio-v1/StableAudioVAEDecoder.mlpackage.zip")!,
                compiledName: "VAEDecoder.mlmodelc",
                isArchive: true
            ),
            Asset(
                id: "t5_vocab",
                url: URL(string: "https://raw.githubusercontent.com/john-rocky/CoreML-Models/main/sample_apps/StableAudioDemo/StableAudioDemo/t5_vocab.json")!,
                compiledName: nil,
                isArchive: false
            )
        ]
    }

    public var isInstalled: Bool {
        let required = [
            "T5Encoder.mlmodelc",
            "NumberEmbedder.mlmodelc",
            "DiT.mlmodelc",
            "VAEDecoder.mlmodelc",
            "t5_vocab.json"
        ]
        return required.allSatisfy {
            fm.fileExists(atPath: modelDirectory.appendingPathComponent($0).path)
        }
    }

    public func prepareModel(
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if isInstalled {
            do {
                try loadRuntime()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        installAsset(index: 0, progress: progress, completion: completion)
    }

    private func installAsset(
        index: Int,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard index < assets.count else {
            do {
                try loadRuntime()
                DispatchQueue.main.async {
                    progress(1, "Modèle musical prêt")
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
            return
        }

        let asset = assets[index]
        DispatchQueue.main.async {
            progress(Double(index) / Double(self.assets.count), "Téléchargement : \(asset.id)…")
        }

        URLSession.shared.downloadTask(with: asset.url) { [weak self] tempURL, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let tempURL = tempURL else {
                DispatchQueue.main.async { completion(.failure(MusicError.invalidPackage(asset.id))) }
                return
            }

            do {
                if asset.isArchive {
                    try self.installCompiledModel(downloadedArchive: tempURL, asset: asset)
                } else {
                    try self.installPlainFile(downloadedFile: tempURL, name: "t5_vocab.json")
                }

                DispatchQueue.main.async {
                    progress(Double(index + 1) / Double(self.assets.count), "Installé : \(asset.id)")
                }
                self.installAsset(index: index + 1, progress: progress, completion: completion)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func installPlainFile(downloadedFile: URL, name: String) throws {
        let destination = modelDirectory.appendingPathComponent(name)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: downloadedFile, to: destination)
    }

    private func installCompiledModel(downloadedArchive: URL, asset: Asset) throws {
        guard let compiledName = asset.compiledName else {
            throw MusicError.invalidPackage(asset.id)
        }

        let work = fm.temporaryDirectory.appendingPathComponent("sarah-music-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        try fm.unzipItem(at: downloadedArchive, to: work)

        guard let package = findFirstModelPackage(in: work) else {
            throw MusicError.invalidPackage(asset.id)
        }

        let compiled = try MLModel.compileModel(at: package)
        let destination = modelDirectory.appendingPathComponent(compiledName)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: compiled, to: destination)
    }

    private func findFirstModelPackage(in root: URL) -> URL? {
        if root.pathExtension == "mlpackage" { return root }
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return nil
        }
        for case let url as URL in e where url.pathExtension == "mlpackage" {
            return url
        }
        return nil
    }

    private func loadRuntime() throws {
        guard isInstalled else { throw MusicError.modelsMissing }
        try loadVocabulary()

        let normal = MLModelConfiguration()
        normal.computeUnits = .all

        let dit = MLModelConfiguration()
        dit.computeUnits = .cpuAndGPU

        t5Encoder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("T5Encoder.mlmodelc"),
            configuration: normal
        )
        numberEmbedder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("NumberEmbedder.mlmodelc"),
            configuration: normal
        )
        diffusionTransformer = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("DiT.mlmodelc"),
            configuration: dit
        )
        vaeDecoder = try MLModel(
            contentsOf: modelDirectory.appendingPathComponent("VAEDecoder.mlmodelc"),
            configuration: normal
        )
    }

    private func loadVocabulary() throws {
        let url = modelDirectory.appendingPathComponent("t5_vocab.json")
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let mapping = raw as? [String: String] else {
            throw MusicError.tokenizerMissing
        }

        var parsed: [String: Int32] = [:]
        for (idText, piece) in mapping {
            if let id = Int32(idText) { parsed[piece] = id }
        }
        guard !parsed.isEmpty else { throw MusicError.tokenizerMissing }
        vocabulary = parsed
    }

    private func tokenize(_ prompt: String) -> [Int32] {
        let marker = "\u{2581}"
        let normalized = marker + prompt.lowercased().replacingOccurrences(of: " ", with: marker)
        var ids: [Int32] = []
        var cursor = normalized.startIndex

        while cursor < normalized.endIndex {
            let remaining = normalized.distance(from: cursor, to: normalized.endIndex)
            var found = false
            for length in stride(from: min(24, remaining), through: 1, by: -1) {
                guard let end = normalized.index(cursor, offsetBy: length, limitedBy: normalized.endIndex) else {
                    continue
                }
                let piece = String(normalized[cursor..<end])
                if let id = vocabulary[piece] {
                    ids.append(id)
                    cursor = end
                    found = true
                    break
                }
            }
            if !found { cursor = normalized.index(after: cursor) }
        }

        ids.append(eosToken)
        if ids.count >= Self.maxTokens {
            ids = Array(ids.prefix(Self.maxTokens - 1))
            ids.append(eosToken)
        }
        while ids.count < Self.maxTokens { ids.append(padToken) }
        return ids
    }

    public func generate(
        prompt: String,
        seconds: Float = 10,
        steps: Int = 8,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(MusicError.emptyPrompt))
            return
        }

        queue.async {
            do {
                if self.t5Encoder == nil { try self.loadRuntime() }
                let url = try self.render(
                    prompt: clean,
                    seconds: min(max(seconds, 1), 11.5),
                    steps: min(max(steps, 4), 16),
                    seed: UInt64.random(in: 1...UInt64.max)
                )
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SarahGeneratedMusicReady"),
                        object: url,
                        userInfo: [
                            "prompt": clean,
                            "modelName": "Stable Audio Open Small · Core ML",
                            "isLocal": true
                        ]
                    )
                    completion(.success(url))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func render(prompt: String, seconds: Float, steps: Int, seed: UInt64) throws -> URL {
        guard let t5Encoder = t5Encoder,
              let numberEmbedder = numberEmbedder,
              let diffusionTransformer = diffusionTransformer,
              let vaeDecoder = vaeDecoder else {
            throw MusicError.modelsMissing
        }

        let tokens = tokenize(prompt)
        let inputIDs = try MLMultiArray(shape: [1, NSNumber(value: Self.maxTokens)], dataType: .int32)
        for i in 0..<Self.maxTokens { inputIDs[i] = NSNumber(value: tokens[i]) }

        let textProvider = try MLDictionaryFeatureProvider(dictionary: ["input_ids": inputIDs])
        let textResult = try t5Encoder.prediction(from: textProvider)
        guard let textEmbeddings = textResult.featureValue(for: "text_embeddings")?.multiArrayValue else {
            throw MusicError.predictionFailed("encodage du texte")
        }

        let activeCount = tokens.firstIndex(of: padToken) ?? Self.maxTokens
        sanitize(textEmbeddings, activeTokens: activeCount)

        let normalizedDuration = min(max(seconds, 0), Self.maxConditionSeconds) / Self.maxConditionSeconds
        let durationInput = try MLMultiArray(shape: [1], dataType: .float16)
        durationInput[0] = NSNumber(value: normalizedDuration)

        let durationProvider = try MLDictionaryFeatureProvider(dictionary: ["normalized_seconds": durationInput])
        let durationResult = try numberEmbedder.prediction(from: durationProvider)
        guard let durationEmbedding = durationResult.featureValue(for: "seconds_embedding")?.multiArrayValue else {
            throw MusicError.predictionFailed("conditionnement durée")
        }

        let crossAttention = try MLMultiArray(shape: [1, 65, 768], dataType: .float16)
        for token in 0..<64 {
            for channel in 0..<768 {
                crossAttention[[0, token, channel] as [NSNumber]] =
                    textEmbeddings[[0, token, channel] as [NSNumber]]
            }
        }

        let globalEmbedding = try MLMultiArray(shape: [1, 768], dataType: .float16)
        for channel in 0..<768 {
            let value = durationEmbedding[[0, channel] as [NSNumber]]
            crossAttention[[0, 64, channel] as [NSNumber]] = value
            globalEmbedding[[0, channel] as [NSNumber]] = value
        }

        var latent = try makeNoise(seed: seed)
        let schedule = makeSchedule(steps: steps)

        for step in 0..<steps {
            let timestep = try MLMultiArray(shape: [1], dataType: .float16)
            timestep[0] = NSNumber(value: schedule[step])

            let provider = try MLDictionaryFeatureProvider(dictionary: [
                "latent": latent,
                "timestep": timestep,
                "cross_attn_cond": crossAttention,
                "global_embed": globalEmbedding
            ])
            let prediction = try diffusionTransformer.prediction(from: provider)
            guard let velocity = prediction.featureValue(for: "velocity")?.multiArrayValue else {
                throw MusicError.predictionFailed("diffusion")
            }
            latent = try eulerAdvance(
                latent: latent,
                velocity: velocity,
                delta: schedule[step + 1] - schedule[step]
            )
        }

        let decoded = try vaeDecoder.prediction(
            from: MLDictionaryFeatureProvider(dictionary: ["latent": latent])
        )
        guard let audio = decoded.featureValue(for: "audio")?.multiArrayValue else {
            throw MusicError.predictionFailed("décodage audio")
        }
        return try saveAudio(audio, seconds: seconds, prompt: prompt)
    }

    private func sanitize(_ embeddings: MLMultiArray, activeTokens: Int) {
        for token in 0..<Self.maxTokens {
            for channel in 0..<768 {
                let index = [0, token, channel] as [NSNumber]
                let value = embeddings[index].floatValue
                if !value.isFinite || token >= activeTokens { embeddings[index] = 0 }
            }
        }
    }

    private func makeNoise(seed: UInt64) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, NSNumber(value: Self.latentChannels), NSNumber(value: Self.latentLength)],
            dataType: .float16
        )
        let pointer = array.dataPointer.assumingMemoryBound(to: Float16.self)
        let count = Self.latentChannels * Self.latentLength
        var rng = SarahSeededRandom(seed: seed)

        var i = 0
        while i < count {
            let u1 = Float.random(in: Float.leastNormalMagnitude...1, using: &rng)
            let u2 = Float.random(in: 0...1, using: &rng)
            let radius = sqrtf(-2 * logf(u1))
            let angle = 2 * Float.pi * u2
            pointer[i] = Float16(radius * cosf(angle))
            if i + 1 < count { pointer[i + 1] = Float16(radius * sinf(angle)) }
            i += 2
        }
        return array
    }

    private func makeSchedule(steps: Int) -> [Float] {
        var result: [Float] = []
        for i in 0...steps {
            let logSNR = -6 + Float(i) / Float(steps) * 8
            result.append(1 / (1 + expf(logSNR)))
        }
        if !result.isEmpty {
            result[0] = 1
            result[result.count - 1] = 0
        }
        return result
    }

    private func eulerAdvance(latent: MLMultiArray, velocity: MLMultiArray, delta: Float) throws -> MLMultiArray {
        let output = try MLMultiArray(shape: latent.shape, dataType: .float16)
        let count = Self.latentChannels * Self.latentLength
        let input = latent.dataPointer.assumingMemoryBound(to: Float16.self)
        let out = output.dataPointer.assumingMemoryBound(to: Float16.self)

        if velocity.dataType == .float32 {
            let v = velocity.dataPointer.assumingMemoryBound(to: Float.self)
            for i in 0..<count { out[i] = Float16(Float(input[i]) + delta * v[i]) }
        } else {
            let v = velocity.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<count { out[i] = Float16(Float(input[i]) + delta * Float(v[i])) }
        }
        return output
    }

    private func saveAudio(_ audio: MLMultiArray, seconds: Float, prompt: String) throws -> URL {
        let sampleCount = min(Int(seconds * Float(Self.sampleRate)), Self.fullAudioSamples)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 2,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)),
        let left = buffer.floatChannelData?[0],
        let right = buffer.floatChannelData?[1] else {
            throw MusicError.audioWriteFailed
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        for sample in 0..<sampleCount {
            left[sample] = audio[[0, 0, sample] as [NSNumber]].floatValue
            right[sample] = audio[[0, 1, sample] as [NSNumber]].floatValue
        }

        let root = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = root.appendingPathComponent("SarahIA/GeneratedMusic", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let safe = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
            .lowercased()
        let url = dir.appendingPathComponent(
            "sarah-\(safe.isEmpty ? "music" : safe)-\(Int(Date().timeIntervalSince1970)).wav"
        )

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}

@available(iOS 16.0, *)
private struct SarahSeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

@available(iOS 16.0, *)
public final class GenerativeModelManager: ObservableObject {

    public static let shared = GenerativeModelManager()

    public enum Kind: String {
        case image
        case video
    }

    @Published public private(set) var isDownloading = false
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var statusText: String = ""
    @Published public private(set) var activeKind: Kind?

    private let fm = FileManager.default
    private var task: URLSessionDownloadTask?

    private init() {}

    public func downloadImageModel() {
        let profile = SarahGenerativeModelCatalog.imageProfile()
        let urlString: String?

        switch profile.identifier {
        case "apple-sd21-6bit":
            urlString = "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized/resolve/main/coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled.zip?download=true"
        case "apple-sdxl-1.0-ios-4bit":
            urlString = "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios/resolve/main/coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip?download=true"
        default:
            urlString = nil
        }

        guard let urlString = urlString, let url = URL(string: urlString) else {
            statusText = "Ce profil image doit être installé manuellement dans cette version."
            return
        }

        start(kind: .image, url: url)
    }

    public func downloadVideoCheckpoint() {
        let profile = SarahGenerativeModelCatalog.videoProfile()

        guard profile.identifier == "mobilei2v-027b",
              let url = URL(string: "https://huggingface.co/hustvl/MobileI2V/resolve/main/hybrid_371.pth?download=true") else {
            statusText = "Aucun checkpoint vidéo automatique pour ce profil."
            return
        }

        start(kind: .video, url: url)
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isDownloading = false
        progress = 0
        activeKind = nil
        statusText = "Téléchargement annulé."
    }

    public var isImageInstalled: Bool {
        SarahLocalImageGenEngine.shared.isInstalled
    }

    public var isVideoCheckpointInstalled: Bool {
        let profile = SarahGenerativeModelCatalog.videoProfile()
        guard profile.identifier == "mobilei2v-027b" else { return false }
        return fm.fileExists(
            atPath: videoDirectory.appendingPathComponent("hybrid_371.pth").path
        )
    }

    private var videoDirectory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("SarahAI", isDirectory: true)
            .appendingPathComponent("GenerativeModels", isDirectory: true)
            .appendingPathComponent(SarahGenerativeModelCatalog.videoProfile().identifier, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func start(kind: Kind, url: URL) {
        guard !isDownloading else { return }

        isDownloading = true
        progress = 0
        activeKind = kind
        statusText = kind == .image ? "Téléchargement du modèle image…" : "Téléchargement du checkpoint vidéo…"

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let session = URLSession(configuration: .default, delegate: ProgressDelegate(owner: self), delegateQueue: nil)
        task = session.downloadTask(with: request)
        task?.resume()
    }

    fileprivate func didWrite(total: Int64, expected: Int64) {
        guard expected > 0 else { return }
        DispatchQueue.main.async {
            self.progress = Double(total) / Double(expected)
        }
    }

    fileprivate func didFinish(location: URL) {
        guard let kind = activeKind else { return }

        do {
            switch kind {
            case .image:
                try installImageArchive(location)
                statusText = "Modèle image installé localement."
            case .video:
                let dest = videoDirectory.appendingPathComponent("hybrid_371.pth")
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: location, to: dest)
                statusText = "Checkpoint MobileI2V téléchargé. Runtime vidéo encore expérimental."
            }
            progress = 1
        } catch {
            statusText = error.localizedDescription
        }

        isDownloading = false
        activeKind = nil
        task = nil
    }

    fileprivate func didFail(_ error: Error) {
        DispatchQueue.main.async {
            self.statusText = error.localizedDescription
            self.isDownloading = false
            self.activeKind = nil
            self.task = nil
        }
    }

    private func installImageArchive(_ archive: URL) throws {
        let destination = SarahLocalImageGenEngine.shared.modelDirectory
        if fm.fileExists(atPath: destination.path) {
            let items = try fm.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
            for item in items { try fm.removeItem(at: item) }
        }
        try fm.unzipItem(at: archive, to: destination)

        guard SarahLocalImageGenEngine.shared.discoverResourceDirectory() != nil else {
            throw NSError(
                domain: "GenerativeModelManager",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Le paquet image ne contient pas les ressources Core ML attendues."]
            )
        }
    }
}

@available(iOS 16.0, *)
private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
    weak var owner: GenerativeModelManager?

    init(owner: GenerativeModelManager) {
        self.owner = owner
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        owner?.didWrite(total: totalBytesWritten, expected: totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        owner?.didFinish(location: location)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            owner?.didFail(error)
        }
    }
}
