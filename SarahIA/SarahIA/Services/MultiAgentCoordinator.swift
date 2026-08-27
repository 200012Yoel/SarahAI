import Foundation
import UIKit
import AVFoundation

/// Coordinateur Central Multi-Agents (Sarah, Tom, Raphaël, Yohan).
/// Analyse les requêtes utilisateur pour identifier l'agent expert approprié,
/// effectue le routage instantané, bascule l'orbe et synthétise la voix Siri correspondante.
/// Supporte la passation universelle entre n'importe quelle paire d'agents (ex: Tom -> Yohan, Sarah -> Tom, etc.)
public final class MultiAgentCoordinator {
    
    public static let shared = MultiAgentCoordinator()
    
    public struct AgentResponse {
        public let agent: AgentType
        public let text: String
        public let spokenText: String
        public let openStudio: Bool
        public let generatedCode: String?
        public let handoffSarahTransition: String?
        public let handoffAgentGreeting: String?
        public let handoffSourceAgent: AgentType?
        
        public init(
            agent: AgentType,
            text: String,
            spokenText: String,
            openStudio: Bool = false,
            generatedCode: String? = nil,
            handoffSarahTransition: String? = nil,
            handoffAgentGreeting: String? = nil,
            handoffSourceAgent: AgentType? = nil
        ) {
            self.agent = agent
            self.text = text
            self.spokenText = spokenText
            self.openStudio = openStudio
            self.generatedCode = generatedCode
            self.handoffSarahTransition = handoffSarahTransition
            self.handoffAgentGreeting = handoffAgentGreeting
            self.handoffSourceAgent = handoffSourceAgent
        }
    }
    
    private struct SwitchCommandMatch {
        let targetAgent: AgentType
        let residualPrompt: String
    }
    
    private init() {}
    
    /// Analyse la phrase utilisateur et route vers l'agent adéquat
    public func routeAndProcess(
        query: String,
        currentAgent: AgentType? = nil,
        explicitAgent: AgentType? = nil,
        completion: @escaping (AgentResponse) -> Void
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalize(trimmed)
        let sourceAgent = currentAgent ?? .sarah
        
        // 1. Détection prioritaire d'un ordre explicite de passage / bascule d'agent
        if let switchMatch = detectSwitchCommand(normalized: normalized, original: trimmed) {
            handleAgentHandoff(from: sourceAgent, to: switchMatch.targetAgent, residualPrompt: switchMatch.residualPrompt, completion: completion)
            return
        }
        
        // 2. Si un agent a été forcé explicitement (sélection manuelle dans l'UI)
        let activeAgent = explicitAgent ?? currentAgent ?? detectTargetAgent(normalized: normalized)
        
        // 3. Exécution selon l'agent
        switch activeAgent {
        case .yohan:
            processWithYohan(text: trimmed, completion: completion)
            
        case .raphael:
            processWithRaphael(text: trimmed, completion: completion)
            
        case .tom:
            processWithTom(text: trimmed, completion: completion)
            
        case .sarah:
            processWithSarah(text: trimmed, completion: completion)
        }
    }
    
    // MARK: - Normalisation & Détection d'Intention de Bascule (Switching)
    
    private func normalize(_ text: String) -> String {
        return text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func detectSwitchCommand(normalized: String, original: String) -> SwitchCommandMatch? {
        let norm = " " + normalized + " "
        
        let switchKeywords = [
            "donne moi ", "donne-moi ", "donnemoi ",
            "donne ", "donnez moi ", "donnez-moi ",
            "passe moi ", "passe-moi ", "passemoi ",
            "passe ", "passez moi ", "passez-moi ",
            "peux tu me passer ", "peux-tu me passer ", "peux tu me donner ", "peux-tu me donner ",
            "est ce que tu peux me passer ", "est-ce que tu peux me passer ",
            "est ce que tu peux me donner ", "est-ce que tu peux me donner ",
            "est ce que tu peux passer ", "est-ce que tu peux passer ",
            "est ce que je peux parler a ", "est-ce que je peux parler a ",
            "est ce que je peux parler avec ", "est-ce que je peux parler avec ",
            "pourrais tu me passer ", "pourrais-tu me passer ",
            "je veux parler a ", "je veux parler avec ", "je voudrais parler a ", "je voudrais parler avec ",
            "fais moi parler a ", "fais-moi parler a ", "fais moi parler avec ", "fais-moi parler avec ",
            "parle a ", "parle avec ", "parler a ", "parler avec ",
            "bascule sur ", "bascule vers ", "bascule a ", "bascule ",
            "switch to ", "switch sur ", "switch ",
            "mets moi ", "mets-moi ", "metsmoi ", "mets ",
            "appelle ", "reviens sur ", "reprends la main ", "reprend la main "
        ]
        
        let yohanTokens = ["yoann", "yohan", "yoan", "johan", "yohan traducteur", "yoann traducteur"]
        let tomTokens = ["tom", "thomas"]
        let raphaelTokens = ["raphael", "raphaël", "raph", "rafael"]
        let sarahTokens = ["sarah", "sara", "la patronne", "pilote"]
        
        func extractResidual(trigger: String, agentToken: String) -> String {
            var working = normalized
            if let range = working.range(of: trigger + agentToken) {
                working.removeSubrange(range)
            } else if let range = working.range(of: trigger) {
                working.removeSubrange(range)
                if let aRange = working.range(of: agentToken) {
                    working.removeSubrange(aRange)
                }
            }
            return working.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 1. Cible Yohan (priorité aux tokens les plus longs ex: yoann, yohan)
        for kw in switchKeywords {
            for name in yohanTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .yohan, residualPrompt: residual)
                }
            }
        }
        
        // 2. Cible Tom
        for kw in switchKeywords {
            for name in tomTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .tom, residualPrompt: residual)
                }
            }
        }
        
        // 3. Cible Raphaël
        for kw in switchKeywords {
            for name in raphaelTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .raphael, residualPrompt: residual)
                }
            }
        }
        
        // 4. Cible Sarah
        for kw in switchKeywords {
            for name in sarahTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .sarah, residualPrompt: residual)
                }
            }
        }
        
        // Commandes directes d'appel isolées ou début de phrase
        for name in yohanTokens {
            if normalized == name || normalized.starts(with: name + " ") {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .yohan, residualPrompt: res)
            }
        }
        for name in tomTokens {
            if normalized == name || normalized.starts(with: name + " ") {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .tom, residualPrompt: res)
            }
        }
        for name in raphaelTokens {
            if normalized == name || normalized.starts(with: name + " ") || normalized == "\(name) code" {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .raphael, residualPrompt: res)
            }
        }
        for name in sarahTokens {
            if normalized == name || normalized.starts(with: name + " ") {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .sarah, residualPrompt: res)
            }
        }
        
        return nil
    }
    
    // MARK: - Détection Thématique d'Agent Spécialisé
    
    private func detectTargetAgent(normalized: String) -> AgentType {
        // Yohan (Traduction Français <-> Hébreu)
        if normalized.contains("yohan") || normalized.contains("yoann") || normalized.contains("yoan") || normalized.contains("johan") ||
           normalized.contains("en hebreu") || normalized.contains("en francais") ||
           normalized.contains("traduis") || normalized.contains("traduit") ||
           normalized.contains("comment on dit") || normalized.contains("comment dit on") ||
           YohanLexiconEngine.shared.isHebrew(normalized) {
            return .yohan
        }
        
        // Raphaël (Code, VAI Coding, Shortcuts, HTML/JS, Swift, Python, Figma)
        if normalized.contains("raphael") ||
           normalized.contains("code") || normalized.contains("programme") ||
           normalized.contains("shortcut") || normalized.contains("raccourci") ||
           normalized.contains("html") || normalized.contains("swift") ||
           normalized.contains("python") || normalized.contains("figma") ||
           normalized.contains("stitch") || normalized.contains("calculatrice") ||
           normalized.contains("composant web") || normalized.contains("studio") {
            return .raphael
        }
        
        // Tom (Histoire, Géopolitique depuis 1948, Conflits, Débats, Wikipédia, Ve République)
        if normalized.contains("tom") ||
           normalized.contains("histoire") || normalized.contains("geopolitique") ||
           normalized.contains("1948") || normalized.contains("ben gourion") || normalized.contains("guerre des six jours") ||
           normalized.contains("kippour") || normalized.contains("abraham") || normalized.contains("de gaulle") ||
           normalized.contains("ve republique") || normalized.contains("guerre froide") || normalized.contains("otan") ||
           normalized.contains("actualites") || normalized.contains("actualite") || normalized.contains("politique") {
            return .tom
        }
        
        // Par défaut : Sarah (Patronne & Pilote)
        return .sarah
    }
    
    // MARK: - Handoff & Accueil Personnalisé de l'Agent Cible
    
    private func handleAgentHandoff(
        from sourceAgent: AgentType,
        to targetAgent: AgentType,
        residualPrompt: String,
        completion: @escaping (AgentResponse) -> Void
    ) {
        let cleanResidual = residualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si l'utilisateur a joint une requête précise lors du passage d'agent
        if !cleanResidual.isEmpty && cleanResidual != "bonjour" && cleanResidual != "salut" {
            switch targetAgent {
            case .tom:
                processWithTom(text: cleanResidual, completion: completion)
            case .raphael:
                processWithRaphael(text: cleanResidual, completion: completion)
            case .yohan:
                processWithYohan(text: cleanResidual, completion: completion)
            case .sarah:
                processWithSarah(text: cleanResidual, completion: completion)
            }
            return
        }
        
        // Phrase de transition personnalisée selon qui passe la main
        let transitionLine: String
        let sourceName: String
        switch sourceAgent {
        case .sarah:
            transitionLine = "Attends, ne quitte pas, je te le passe !"
            sourceName = "👑 **Sarah**"
        case .tom:
            transitionLine = "Pas de problème Yoël, je te le passe !"
            sourceName = "🌍 **Tom**"
        case .raphael:
            transitionLine = "Ça marche, je te le passe tout de suite !"
            sourceName = "⚡ **Raphaël**"
        case .yohan:
            transitionLine = "Beseder Yoël, je te le passe !"
            sourceName = "🇮🇱 **Yohan**"
        }
        
        switch targetAgent {
        case .tom:
            let tomGreeting = "Bonjour Yoël ! C'est Tom. Je prends la suite. De quoi souhaites-tu discuter ? Conflits du Moyen-Orient, histoire politique mondiale depuis 1948 ou grands débats internationaux ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n🌍 **Tom [Histoire & Géopolitique]** :\n\(tomGreeting)"
            
            completion(AgentResponse(
                agent: .tom,
                text: fullText,
                spokenText: "\(transitionLine) \(tomGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: tomGreeting,
                handoffSourceAgent: sourceAgent
            ))
            
        case .raphael:
            let raphGreeting = "Salut Yoël ! C'est Raphaël en ligne. Prêt pour tes développements, raccourcis Apple, projets Swift et composants web. Quel est ton projet ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n⚡ **Raphaël [Développeur & VAI Coding]** :\n\(raphGreeting)"
            
            completion(AgentResponse(
                agent: .raphael,
                text: fullText,
                spokenText: "\(transitionLine) \(raphGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: raphGreeting,
                handoffSourceAgent: sourceAgent
            ))
            
        case .yohan:
            let yohanGreeting = "Shalom Yoël ! 🇮🇱 C'est Yohan. Je suis là pour toute traduction, expression idiomatique ou question linguistique en hébreu ou en français. Que veux-tu traduire ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n🇮🇱 **Yohan [Traduction Français ⇄ Hébreu]** :\n\(yohanGreeting)"
            
            completion(AgentResponse(
                agent: .yohan,
                text: fullText,
                spokenText: "\(transitionLine) \(yohanGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: yohanGreeting,
                handoffSourceAgent: sourceAgent
            ))
            
        case .sarah:
            let sarahGreeting = "C'est Sarah ! Je reprends la main. Comment puis-je t'aider ou te coordonner ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n👑 **Sarah [Patronne & Pilote]** :\n\(sarahGreeting)"
            
            completion(AgentResponse(
                agent: .sarah,
                text: fullText,
                spokenText: "\(transitionLine) \(sarahGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: sarahGreeting,
                handoffSourceAgent: sourceAgent
            ))
        }
    }
    
    // MARK: - Traitements Spécialisés
    
    private func processWithYohan(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe-moi yoann", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi yoann", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi yoann", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi yoann", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "yoann", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let queryText = clean.isEmpty ? text : clean
        let result = YohanLexiconEngine.shared.translateExpert(text: queryText)
        
        let spoken = result
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
        
        completion(AgentResponse(
            agent: .yohan,
            text: result,
            spokenText: spoken,
            openStudio: false,
            generatedCode: nil
        ))
    }
    
    private func processWithRaphael(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "vas-y raphaël", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "vas-y raphael", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "vas y raphael", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe-moi raphaël", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi raphael", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi raphaël", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi raphael", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "raphaël", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "raphael", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let prompt = clean.isEmpty ? text : clean
        let lower = prompt.lowercased()
        
        if lower.contains("shortcut") || lower.contains("raccourci") {
            let (json, _) = VAICodeEngine.shared.generateAppleShortcut(title: "Automatisation Raphaël", prompt: prompt)
            let responseText = "⚡ **Raphaël [Export Apple Shortcut]**\n\nRaccourci Apple généré et compilé avec succès dans votre espace `Documents/VAI_Workspace/`.\n\n```json\n\(json)\n```"
            completion(AgentResponse(
                agent: .raphael,
                text: responseText,
                spokenText: "Raccourci Apple généré avec succès dans votre espace de travail.",
                openStudio: true,
                generatedCode: json
            ))
        } else {
            let html = VAICodeEngine.shared.generateWebUI(prompt: prompt)
            _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
            let responseText = "⚡ **Raphaël [Studio VAI Coding]**\n\nComposant interactif généré avec succès dans `Documents/VAI_Workspace/index.html`.\nAffichage en direct dans le Studio VAI Coding."
            completion(AgentResponse(
                agent: .raphael,
                text: responseText,
                spokenText: "C'est codé ! Voici le rendu interactif dans le studio VAI Coding.",
                openStudio: true,
                generatedCode: html
            ))
        }
    }
    
    private func processWithTom(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi tom", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi tom", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi tom", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi tom", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "tom", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let queryText = clean.isEmpty ? text : clean
        
        if let kbMatch = TomKnowledgeBase.shared.query(text: queryText) {
            completion(AgentResponse(
                agent: .tom,
                text: kbMatch,
                spokenText: kbMatch.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "#", with: ""),
                openStudio: false,
                generatedCode: nil
            ))
        } else {
            let response = "🌍 **Tom [Analyse Géopolitique & Débat]**\n\nConcernant « \(queryText) », les perspectives historiques et géopolitiques contemporaines mettent en lumière les équilibres stratégiques mondiaux depuis 1948."
            completion(AgentResponse(
                agent: .tom,
                text: response,
                spokenText: "Voici mon analyse géopolitique concernant cette question.",
                openStudio: false,
                generatedCode: nil
            ))
        }
    }
    
    private func processWithSarah(text: String, completion: @escaping (AgentResponse) -> Void) {
        let response = AIService.shared.generateSyncResponse(for: text)
        completion(AgentResponse(
            agent: .sarah,
            text: response,
            spokenText: response.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "#", with: ""),
            openStudio: false,
            generatedCode: nil
        ))
    }
}
