import Foundation

/// Service d'intelligence artificielle avec moteur d'apprentissage dynamique et mémoire persistante.
final class AIService {
    
    static let shared = AIService()
    
    private let storage = StorageService.shared
    
    private let openAI = OpenAIService.shared
    private let translation = TranslationEngine.shared
    private let modelDownloader = ModelDownloader.shared
    
    private init() {}
    
    /// Génère une réponse IA synchrone 100% native (iOS 12+)
    func generateSyncResponse(for question: String) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeText(trimmed)
        
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
        
        var state = storage.loadState()
        
        if let pendingTrigger = state.pendingLearningTrigger, !pendingTrigger.isEmpty {
            if normalized == "annule" || normalized == "annuler" || normalized == "laisse tomber" || normalized == "stop" {
                state.pendingLearningTrigger = nil
                storage.saveState(state)
                return "D'accord, apprentissage annulé ! Que souhaitez-vous faire ?"
            }
            
            let cleanTrigger = pendingTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
            state.learnedMemories[normalizeText(cleanTrigger)] = trimmed
            state.pendingLearningTrigger = nil
            storage.saveState(state)
            return "C'est appris ! 🧠 Dès que vous me direz « \(cleanTrigger) », je répondrai : « \(trimmed) »."
        }
        
        if let directLearning = parseDirectLearningCommand(trimmed) {
            state.learnedMemories[normalizeText(directLearning.trigger)] = directLearning.response
            storage.saveState(state)
            return "Parfait ! J'ai mémorisé que pour « \(directLearning.trigger) », je dois répondre : « \(directLearning.response) »."
        }
        
        if let triggerToLearn = parseInteractiveLearningInitiation(trimmed) {
            state.pendingLearningTrigger = triggerToLearn
            storage.saveState(state)
            return "Je dois répondre quoi ?"
        }
        
        if normalized.starts(with: "oublie ") || normalized.starts(with: "efface ") {
            let target = trimmed.replacingOccurrences(of: "oublie ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "efface ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let normTarget = normalizeText(target)
            if state.learnedMemories.removeValue(forKey: normTarget) != nil {
                storage.saveState(state)
                return "J'ai bien oublié la réponse pour « \(target) » ! 🗑️"
            } else {
                return "Je n'avais aucun souvenir enregistré pour « \(target) »."
            }
        }
        
        if normalized.contains("que sais tu") || normalized.contains("tes souvenirs") || normalized.contains("liste memoire") {
            if state.learnedMemories.isEmpty {
                return "Je n'ai pas encore appris de réponses personnalisées. Dites par exemple : « Apprends papa » pour commencer !"
            }
            let list = state.learnedMemories.map { "• « \($0.key) » ➔ \($0.value)" }.joined(separator: "\n")
            return "Voici ce que j'ai appris jusqu'à présent : 🧠\n\n\(list)"
        }
        
        if let learned = state.learnedMemories[normalized] {
            return learned
        }
        
        for (learnedKey, response) in state.learnedMemories {
            if normalized.contains(learnedKey) || learnedKey.contains(normalized) {
                return response
            }
        }
        
        return generateKnowledgeResponse(normalized: normalized, trimmed: trimmed)
    }
    
    private func generateKnowledgeResponse(normalized: String, trimmed: String) -> String {
        var state = storage.loadState()
        
        // Mémorisation du prénom de l'utilisateur
        if normalized.starts(with: "je m appelle ") || normalized.starts(with: "mon nom est ") || normalized.starts(with: "mon prenom est ") {
            let name = trimmed.components(separatedBy: " ").suffix(from: 3).joined(separator: " ")
            if !name.isEmpty {
                state.learnedMemories["_user_name"] = name
                storage.saveState(state)
                return "Enchantée \(name) ! C'est un plaisir de discuter avec vous. Comment puis-je vous aider aujourd'hui ? 😊"
            }
        }
        
        if normalized.contains("comment je m appelle") || normalized.contains("mon prenom") || normalized.contains("mon nom") {
            if let userName = state.learnedMemories["_user_name"] {
                return "Vous vous appelez \(userName) ! Je n'oublie jamais mes amis. ✨"
            }
            return "Vous ne m'avez pas encore dit votre prénom ! Dites simplement : « Je m'appelle [Votre prénom] » pour que je le retienne."
        }
        
        // Salutations & Présentation
        if normalized == "bonjour" || normalized == "salut" || normalized == "hello" || normalized == "coucou" || normalized.starts(with: "bonjour") || normalized.starts(with: "salut") {
            if let userName = state.learnedMemories["_user_name"] {
                return "Bonjour \(userName) ! 👋 Que puis-je faire pour vous aujourd'hui ?"
            }
            return "Bonjour ! 👋 Je suis Sarah. Comment puis-je vous aider aujourd'hui ?"
        }
        
        if normalized.contains("ca va") || normalized.contains("comment vas tu") || normalized.contains("comment tu vas") {
            return "Je vais à merveille, merci ! Prête à vous assister et répondre à toutes vos questions. Et vous, comment se passe votre journée ?"
        }
        
        // Date & Calendrier
        if normalized.contains("quel jour") || normalized.contains("date") || normalized.contains("aujourd hui") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateStyle = .full
            let dateStr = formatter.string(from: Date())
            return "Aujourd'hui, nous sommes le \(dateStr). 📅"
        }
        
        // Heure
        if normalized.contains("heure") || normalized.contains("quelle heure") {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let time = formatter.string(from: Date())
            return "Il est actuellement \(time). ⏰"
        }
        
        // Météo
        if normalized.contains("meteo") || normalized.contains("temps") || normalized.contains("pluie") || normalized.contains("soleil") {
            return pickRandom(from: weatherResponses)
        }
        
        // Traductions rapides
        if normalized.contains("traduis") || normalized.contains("comment on dit") || normalized.contains("en anglais") {
            if normalized.contains("bonjour") { return "« Bonjour » se traduit par « Hello » ou « Good morning » en anglais. 🇬🇧" }
            if normalized.contains("merci") { return "« Merci » se traduit par « Thank you » en anglais. 🇬🇧" }
            if normalized.contains("au revoir") { return "« Au revoir » se traduit par « Goodbye » en anglais. 🇬🇧" }
            if normalized.contains("je t aime") { return "« Je t'aime » se traduit par « I love you » en anglais. ❤️" }
            if normalized.contains("shalom") || normalized.contains("en hebreu") { return "En hébreu, « Bonjour » et « Paix » se disent « Shalom » (שלום). 🇮🇱" }
        }
        
        // Connaissances générales & Culture
        if normalized.contains("qui a cree apple") || normalized.contains("createur apple") || normalized.contains("steve jobs") {
            return "Apple a été cofondée en 1976 par Steve Jobs, Steve Wozniak et Ronald Wayne en Californie. 🍎"
        }
        
        if normalized.contains("capitale") {
            if normalized.contains("france") { return "La capitale de la France est Paris. 🇫🇷" }
            if normalized.contains("israel") { return "La capitale d'Israël est Jérusalem. 🇮🇱" }
            if normalized.contains("italie") { return "La capitale de l'Italie est Rome. 🇮🇹" }
            if normalized.contains("espagne") { return "La capitale de l'Espagne est Madrid. 🇪🇸" }
            if normalized.contains("etats unis") || normalized.contains("usa") { return "La capitale des États-Unis est Washington D.C. 🇺🇸" }
            if normalized.contains("angleterre") || normalized.contains("royaume uni") { return "La capitale du Royaume-Uni est Londres. 🇬🇧" }
        }
        
        // Histoires & Détente
        if normalized.contains("histoire") || normalized.contains("raconte une histoire") {
            return "Il était une fois, dans un iPhone 5S plein d'énergie, une assistante nommée Sarah qui résolvait tous les calculs et apprenait chaque mot de son utilisateur avec le sourire ! 📖✨"
        }
        
        // Conseils & Astuces
        if normalized.contains("conseil") || normalized.contains("astuce") || normalized.contains("dormir") {
            return "Voici mon conseil pour une super journée : buvez un grand verre d'eau le matin, prenez 5 minutes pour respirer et évitez les écrans 30 minutes avant de dormir ! 💡🌙"
        }
        
        // Calculs mathématiques automatiques (ex: 2 + 2, calcule 15 * 3)
        if let mathResult = evaluateSimpleMath(in: trimmed) {
            return "Le résultat est : \(mathResult) 🧮"
        }
        
        // Aide & Capacités
        if normalized.contains("aide") || normalized.contains("aider") || normalized.contains("que sais tu faire") || normalized.contains("comment tu marche") {
            return "Je suis Sarah, votre assistante IA ultra-rapide ! 🌟\n\nVoici ce que je peux faire :\n1. 💬 Discuter et répondre à vos questions par écrit ou à la voix.\n2. 🧠 Apprendre de nouveaux souvenirs (ex: « Apprends papa » ➔ puis donnez la réponse).\n3. 🧮 Calculer des opérations mathématiques (ex: « 15 * 8 »).\n4. ⏰ Vous donner l'heure, la date, la météo et l'état de votre batterie.\n5. 🌐 Traduire des mots et partager des anecdotes culturelles !"
        }
        
        // Remerciements & Compliments
        if normalized.contains("merci") || normalized.contains("super") || normalized.contains("genial") || normalized.contains("parfait") || normalized.contains("bravo") {
            return pickRandom(from: thanksResponses)
        }
        
        if normalized.contains("t es belle") || normalized.contains("tu es gentille") || normalized.contains("je t aime") {
            return "C'est très gentil ! Merci beaucoup, je fais de mon mieux pour être la meilleure assistante possible pour vous. 😊"
        }
        
        // Identité
        if normalized.contains("nom") || normalized.contains("appelle") || normalized.contains("qui es tu") || normalized.contains("qui est tu") || normalized == "sarah" {
            return pickRandom(from: identityResponses)
        }
        
        // Humour & Blagues
        if normalized.contains("blague") || normalized.contains("rire") || normalized.contains("drole") || normalized.contains("humour") {
            return pickRandom(from: jokeResponses)
        }
        
        // Au revoir
        if normalized.contains("au revoir") || normalized.contains("bye") || normalized.contains("a bientot") || normalized.contains("bonne nuit") {
            return pickRandom(from: goodbyeResponses)
        }
        
        // Réponse générale intelligente
        return "Je vous écoute ! N'hésitez pas à me poser une question, me demander un calcul ou m'apprendre une nouvelle information avec « Apprends [mot] »."
    }
    
    private func evaluateSimpleMath(in text: String) -> String? {
        let mathText = text.lowercased()
            .replacingOccurrences(of: "calcule", with: "")
            .replacingOccurrences(of: "combien font", with: "")
            .replacingOccurrences(of: "combien fait", with: "")
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "fois", with: "*")
            .replacingOccurrences(of: "plus", with: "+")
            .replacingOccurrences(of: "moins", with: "-")
            .replacingOccurrences(of: "divise par", with: "/")
            .replacingOccurrences(of: "divisé par", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let validChars = CharacterSet(charactersIn: "0123456789+-*/.() ")
        guard mathText.unicodeScalars.allSatisfy({ validChars.contains($0) }),
              mathText.contains(where: { "+-*/".contains($0) }) else {
            return nil
        }
        
        let expr = NSExpression(format: mathText)
        if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            if floor(result.doubleValue) == result.doubleValue {
                return "\(result.intValue)"
            }
            return String(format: "%.2f", result.doubleValue)
        }
        return nil
    }
    
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
            return "Je suis Sarah, votre assistante IA native ! 🌟\n\nVous pouvez :\n1. Discuter avec moi au texte ou à la voix avec une réactivité instantanée.\n2. M'apprendre des réponses personnalisées (ex: dites « Apprends papa » puis indiquez quoi répondre).\n3. Profiter d'une interface de discussion fluide et intuitive !"
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
        "Je suis Sarah, votre assistante IA intelligente ! 🤖 Vous pouvez me poser des questions ou m'apprendre de nouvelles réponses.",
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
