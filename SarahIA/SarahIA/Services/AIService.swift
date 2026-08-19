import Foundation

/// Service d'intelligence artificielle avec moteur d'apprentissage dynamique et mémoire persistante.
final class AIService {
    
    static let shared = AIService()
    
    private let storage = StorageService.shared
    
    private let openAI = OpenAIService.shared
    private let translation = TranslationEngine.shared
    private let modelDownloader = ModelDownloader.shared
    
    private init() {}
    
    /// Génère une réponse IA pour la question ou la commande donnée, avec prise en compte de la mémoire apprise.
    func generateResponse(for question: String) async -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeText(trimmed)
        
        // -----------------------------------------------------------------
        // 0. TRADUCTION MULTILINGUE TEMPS RÉEL (FR ⇄ HE, FR ⇄ EN, EN ⇄ FR)
        // -----------------------------------------------------------------
        if let translationReq = translation.parseTranslationIntent(input: trimmed) {
            let translated = await translation.translate(
                text: translationReq.textToTranslate,
                sourceLang: translationReq.sourceLanguage,
                targetLang: translationReq.targetLanguage
            )
            return "En \(translationReq.targetLanguage.displayNameFr) : \(translated)"
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
        if openAI.isConfigured {
            do {
                let aiResponse = try await openAI.ask(prompt: trimmed)
                return aiResponse
            } catch {
                print("⚠️ [AIService] OpenAI indisponible, bascule sur le modèle hors-ligne.")
            }
        }
        
        // -----------------------------------------------------------------
        // 6. MODÈLE HORS-LIGNE & BASE LOCALE RÉSILIENTE
        // -----------------------------------------------------------------
        let detected = translation.detectLanguage(text: trimmed)
        if detected == "he" {
            return "שלום ! שמעתי אותך מצוין : « \(trimmed) ». איך אני יכולה לעזור לך ?"
        }
        
        return pickRandom(from: defaultResponses)
    }
    
    /// Réponse pour le test de notification d'arrière-plan
    func generateBackgroundTestResponse() async -> String {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        return "🔔 Test d'arrière-plan réussi ! Sarah AI continue de fonctionner et de vous écouter même en arrière-plan. 🚀"
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
