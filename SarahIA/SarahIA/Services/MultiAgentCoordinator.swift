import Foundation
import UIKit
import AVFoundation

/// Coordinateur Central Multi-Agents (Sarah, Tom, Raphaël, Yohan).
/// Analyse les requêtes utilisateur pour identifier l'agent expert approprié,
/// effectue le routage instantané, bascule l'orbe et synthétise la voix Siri correspondante.
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
        
        public init(
            agent: AgentType,
            text: String,
            spokenText: String,
            openStudio: Bool = false,
            generatedCode: String? = nil,
            handoffSarahTransition: String? = nil,
            handoffAgentGreeting: String? = nil
        ) {
            self.agent = agent
            self.text = text
            self.spokenText = spokenText
            self.openStudio = openStudio
            self.generatedCode = generatedCode
            self.handoffSarahTransition = handoffSarahTransition
            self.handoffAgentGreeting = handoffAgentGreeting
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
        
        // 1. Détection prioritaire d'un ordre explicite de passage / bascule d'agent
        if let switchMatch = detectSwitchCommand(normalized: normalized, original: trimmed) {
            handleAgentHandoff(to: switchMatch.targetAgent, residualPrompt: switchMatch.residualPrompt, completion: completion)
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
            "bascule sur ", "bascule vers ", "bascule a ", "bascule ",
            "switch to ", "switch sur ", "switch ",
            "je veux parler a ", "je veux parler avec ", "je voudrais parler a ", "fais moi parler a ",
            "mets moi ", "mets-moi ", "metsmoi ", "mets ",
            "appelle ", "reviens sur ", "reprends la main ", "reprend la main "
        ]
        
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
        
        // Cible Tom
        let tomNames = ["tom", "thomas"]
        for kw in switchKeywords {
            for name in tomNames {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .tom, residualPrompt: residual)
                }
            }
        }
        
        // Cible Raphaël
        let raphaelNames = ["raphael", "raphaël", "raph", "rafael"]
        for kw in switchKeywords {
            for name in raphaelNames {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .raphael, residualPrompt: residual)
                }
            }
        }
        
        // Cible Yohan
        let yohanNames = ["yohan", "yoan", "johan", "yoann", "yohan traducteur"]
        for kw in switchKeywords {
            for name in yohanNames {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .yohan, residualPrompt: residual)
                }
            }
        }
        
        // Cible Sarah
        let sarahNames = ["sarah", "sara", "la patronne", "pilote"]
        for kw in switchKeywords {
            for name in sarahNames {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .sarah, residualPrompt: residual)
                }
            }
        }
        
        // Commandes directes d'appel en début de phrase ou isolées
        if normalized == "tom" || normalized.starts(with: "tom ") {
            let res = normalized.replacingOccurrences(of: "tom", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SwitchCommandMatch(targetAgent: .tom, residualPrompt: res)
        }
        if normalized == "raphael" || normalized.starts(with: "raphael ") || normalized == "raphael code" {
            let res = normalized.replacingOccurrences(of: "raphael", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SwitchCommandMatch(targetAgent: .raphael, residualPrompt: res)
        }
        if normalized == "yohan" || normalized.starts(with: "yohan ") {
            let res = normalized.replacingOccurrences(of: "yohan", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SwitchCommandMatch(targetAgent: .yohan, residualPrompt: res)
        }
        if normalized == "sarah" || normalized.starts(with: "sarah ") {
            let res = normalized.replacingOccurrences(of: "sarah", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SwitchCommandMatch(targetAgent: .sarah, residualPrompt: res)
        }
        
        return nil
    }
    
    // MARK: - Détection Thématique d'Agent Spécialisé
    
    private func detectTargetAgent(normalized: String) -> AgentType {
        // Yohan (Traduction Français <-> Hébreu)
        if normalized.contains("yohan") || normalized.contains("yoan") || normalized.contains("johan") ||
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
        
        // Accueil naturel de passation : Sarah dit "Attends, ne quitte pas, je te le passe !" puis Tom/Raphaël/Yohan répond avec sa voix
        switch targetAgent {
        case .tom:
            let sarahVoiceLine = "Attends, ne quitte pas, je te le passe !"
            let tomGreeting = "Bonjour Yoël ! C'est Tom. Je prends la suite. De quoi souhaites-tu discuter ? Conflits du Moyen-Orient, histoire politique mondiale depuis 1948 ou grands débats internationaux ?"
            let fullText = "👑 **Sarah** : *Attends, ne quitte pas, je te le passe !*\n\n🌍 **Tom [Histoire & Géopolitique]** :\n\(tomGreeting)"
            
            completion(AgentResponse(
                agent: .tom,
                text: fullText,
                spokenText: "\(sarahVoiceLine) \(tomGreeting)",
                handoffSarahTransition: sarahVoiceLine,
                handoffAgentGreeting: tomGreeting
            ))
            
        case .raphael:
            let sarahVoiceLine = "Attends, ne quitte pas, je te le passe !"
            let raphGreeting = "Salut Yoël ! C'est Raphaël en ligne. Prêt pour tes développements, raccourcis Apple, projets Swift et composants web. Quel est ton projet ?"
            let fullText = "👑 **Sarah** : *Attends, ne quitte pas, je te le passe !*\n\n⚡ **Raphaël [Développeur & VAI Coding]** :\n\(raphGreeting)"
            
            completion(AgentResponse(
                agent: .raphael,
                text: fullText,
                spokenText: "\(sarahVoiceLine) \(raphGreeting)",
                handoffSarahTransition: sarahVoiceLine,
                handoffAgentGreeting: raphGreeting
            ))
            
        case .yohan:
            let sarahVoiceLine = "Attends, ne quitte pas, je te le passe !"
            let yohanGreeting = "Shalom Yoël ! 🇮🇱 C'est Yohan. Je suis là pour toute traduction, expression idiomatique ou question linguistique en hébreu ou en français. Que veux-tu traduire ?"
            let fullText = "👑 **Sarah** : *Attends, ne quitte pas, je te le passe !*\n\n🇮🇱 **Yohan [Traduction Français ⇄ Hébreu]** :\n\(yohanGreeting)"
            
            completion(AgentResponse(
                agent: .yohan,
                text: fullText,
                spokenText: "\(sarahVoiceLine) \(yohanGreeting)",
                handoffSarahTransition: sarahVoiceLine,
                handoffAgentGreeting: yohanGreeting
            ))
            
        case .sarah:
            let greeting = "👑 **Sarah [Patronne & Pilote]**\n\n— C'est Sarah ! Je reprends la main. Comment puis-je t'aider ou te coordonner ?"
            let spoken = "C'est Sarah ! Je reprends la main. Comment puis-je t'aider ?"
            completion(AgentResponse(agent: .sarah, text: greeting, spokenText: spoken))
        }
    }
    
    // MARK: - Traitements Spécialisés
    
    private func processWithYohan(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "yohan", with: "", options: .caseInsensitive)
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
