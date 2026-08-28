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
        
        // 2. Détermination de l'agent actif
        let resolvedAgent = explicitAgent ?? currentAgent ?? detectTargetAgent(normalized: normalized)
        
        // 2.5 Détection de question sur l'identité ("Tu es qui ?", "Qui es-tu ?", "C'est quoi les noms des agents ?", "Quels sont les agents ?")
        if let identityResponse = evaluateAgentIdentityAndTeam(normalized: normalized, activeAgent: resolvedAgent) {
            completion(identityResponse)
            return
        }
        
        // 3. Exécution selon l'agent
        switch resolvedAgent {
        case .yohan:
            processWithYohan(text: trimmed, completion: completion)
            
        case .raphael:
            processWithRaphael(text: trimmed, completion: completion)
            
        case .tom:
            processWithTom(text: trimmed, completion: completion)
            
        case .sarah:
            processWithSarah(text: trimmed, completion: completion)
            
        case .nathan:
            processWithNathan(text: trimmed, completion: completion)
        }
    }
    
    // MARK: - Conscience de Soi & Connaissance de l'Équipe (Sarah, Tom, Raphaël, Yohan)
    
    private func evaluateAgentIdentityAndTeam(normalized: String, activeAgent: AgentType) -> AgentResponse? {
        let isAskingTeam = normalized.contains("noms des agents") || normalized.contains("nom des agents") ||
                           normalized.contains("les agents") || normalized.contains("quels sont les agents") ||
                           normalized.contains("qui sont les agents") || normalized.contains("qui sont tes collegues") ||
                           normalized.contains("qui compose l equipe") || normalized.contains("qui travaille avec toi") ||
                           normalized.contains("liste des agents") || normalized.contains("tous les agents")
        
        let isAskingSelf = normalized == "qui es tu" || normalized == "qui t es" || normalized == "t es qui" ||
                           normalized == "tu es qui" || normalized.starts(with: "qui es tu") ||
                           normalized.starts(with: "tu es qui") || normalized.starts(with: "t es qui") ||
                           normalized.contains("c est quoi ton nom") || normalized.contains("comment tu t appelles") ||
                           normalized.contains("quel est ton nom") || normalized.contains("presente toi")
        
        if isAskingTeam {
            let teamDescription = """
            Voici l'équipe complète de vos 5 agents intégrés :

            👑 **Sarah [Patronne & Pilote]** : Coordination générale, mémoire locale, flash, batterie et requêtes du quotidien.
            🌍 **Tom [Histoire & Géopolitique]** : Histoire mondiale depuis 1948, conflits internationaux et débats politiques.
            ⚡ **Raphaël [Développeur & VAI Coding]** : Création de code, Apple Shortcuts, intégrations web et studio de code.
            🇮🇱 **Yohan [Traducteur Français ⇔ Hébreu]** : Dictionnaire expert bilingue, grammaire, racines hébraïques et phonétique.
            🤖 **Nathan [Expert IA & Créatif]** : Veille sur les derniers modèles d'IA, génération vidéo (Voo) et musicale (Suno).

            *Vous pouvez parler à n'importe lequel d'entre nous en disant par exemple : « Passe-moi Tom », « Je veux parler à Nathan » ou « Donne-moi Yohan » !*
            """
            return AgentResponse(
                agent: activeAgent,
                text: teamDescription,
                spokenText: "Nous sommes 5 agents dans cette application : Sarah la patronne et pilote, Tom pour l'histoire et la géopolitique, Raphaël pour le code et les raccourcis, Yohan pour la traduction en hébreu, et Nathan l'expert en intelligence artificielle et création.",
                openStudio: false,
                generatedCode: nil
            )
        }
        
        if isAskingSelf {
            switch activeAgent {
            case .yohan:
                let text = "🇮🇱 **Yohan [Traducteur Français ⇄ Hébreu]**\n\nJe m'appelle **Yohan** ! Je suis votre agent expert en langue hébraïque et française. Je maîtrise la traduction bilingue, les racines sémitiques, le vocabulaire idiomatique et la phonétique. Vous pouvez me poser n'importe quelle question de traduction ou me demander d'analyser un texte en hébreu."
                let spoken = "Je suis Yohan, votre agent traducteur en hébreu et en français. Que souhaitez-vous traduire ou apprendre en hébreu ?"
                return AgentResponse(agent: .yohan, text: text, spokenText: spoken)
                
            case .tom:
                let text = "🌍 **Tom [Histoire & Géopolitique]**\n\nJe suis **Tom**, votre agent spécialisé en histoire politique contemporaine et relations internationales depuis 1948. Je peux vous éclairer sur les conflits du Moyen-Orient, la Ve République, la guerre froide ou les dynamiques géopolitiques mondiales."
                let spoken = "Je m'appelle Tom ! Je suis votre agent expert en histoire contemporaine et géopolitique mondiale depuis 1948. De quel sujet historique ou politique souhaites-tu débattre ?"
                return AgentResponse(agent: .tom, text: text, spokenText: spoken)
                
            case .raphael:
                let text = "⚡ **Raphaël [Développeur & VAI Coding]**\n\nJe m'appelle **Raphaël**, développeur et architecte logiciel de l'équipe. Je conçois des composants interactifs Web, du code Swift, Python, des raccourcis Apple Shortcuts et je pilote le Studio VAI Coding directement sur votre iPhone."
                let spoken = "Je m'appelle Raphaël, développeur de l'équipe Sarah IA. Je crée du code, des raccourcis Apple et des interfaces interactives. Quel est votre projet de développement ?"
                return AgentResponse(agent: .raphael, text: text, spokenText: spoken)
                
            case .sarah:
                let text = "👑 **Sarah [Patronne & Pilote]**\n\nJe suis **Sarah**, la patronne et l'intelligence artificielle principale de l'application ! Je pilote l'équipe avec Tom, Raphaël, Yohan et Nathan, je gère votre mémoire locale, les commandes système de votre iPhone et vos requêtes du quotidien."
                let spoken = "Je suis Sarah, l'intelligence artificielle principale et la patronne de l'application. Je coordonne Tom, Raphaël, Yohan, Nathan et moi-même pour vous assister au mieux."
                return AgentResponse(agent: .sarah, text: text, spokenText: spoken)
                
            case .nathan:
                let text = "🤖 **Nathan [Expert IA & Création]**\n\nJe suis **Nathan**, l'expert intelligence artificielle de l'équipe ! Je suis connecté aux dernières nouveautés du monde de l'IA : modèles de langage, génération vidéo avec **Voo**, composition musicale avec **Suno**, et tout ce qui sort de nouveau. Posez-moi vos questions sur les dernières innovations en intelligence artificielle !"
                let spoken = "Je suis Nathan, expert en intelligence artificielle ! Je connais tous les derniers modèles qui sortent, GPT, Claude, Gemini, et je peux vous aider à créer des vidéos et de la musique. Qu'est-ce que vous souhaitez explorer ?"
                return AgentResponse(agent: .nathan, text: text, spokenText: spoken)
            }
        }
        
        return nil
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
        let nathanTokens = ["nathan", "natan", "l expert ia", "expert ia"]
        
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
        
        // 5. Cible Nathan
        for kw in switchKeywords {
            for name in nathanTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .nathan, residualPrompt: residual)
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
        for name in nathanTokens {
            if normalized == name || normalized.starts(with: name + " ") {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .nathan, residualPrompt: res)
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
        
        // Nathan (Expert IA, modèles, vidéo, musique)
        if normalized.contains("nathan") || normalized.contains("natan") ||
           normalized.contains("meilleur modele") || normalized.contains("dernier modele") ||
           normalized.contains("modele ia") || normalized.contains("intelligence artificielle") ||
           normalized.contains("chatgpt") || normalized.contains("claude") || normalized.contains("gemini") ||
           normalized.contains("generate une video") || normalized.contains("genere une video") ||
           normalized.contains("compose une musique") || normalized.contains("cree une musique") ||
           normalized.contains("voo") || normalized.contains("suno") ||
           normalized.contains("nouveau modele") || normalized.contains("nouveaux modeles") {
            return .nathan
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
            case .nathan:
                processWithNathan(text: cleanResidual, completion: completion)
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
        case .nathan:
            transitionLine = "Je te le passe de suite, let's go !"
            sourceName = "🤖 **Nathan**"
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
            
        case .nathan:
            let nathanGreeting = "Yo ! C'est Nathan ! 🤖 Je suis branché sur tous les derniers modèles d'IA. GPT, Claude, Gemini, Llama, Mistral... je suis au courant de tout ce qui sort. Dis-moi ce que tu cherches : un modèle pour coder, pour discuter, pour générer des vidéos avec Voo, ou de la musique avec Suno ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n🤖 **Nathan [Expert IA & Création]** :\n\(nathanGreeting)"
            
            completion(AgentResponse(
                agent: .nathan,
                text: fullText,
                spokenText: "\(transitionLine) \(nathanGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: nathanGreeting,
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
        
        // 1. Déploiement en ligne direct
        if lower.contains("met en ligne") || lower.contains("mettre en ligne") || lower.contains("deploie") || lower.contains("deploiement") || lower.contains("deploy") || lower.contains("publie") {
            let currentCode = VAICodeEngine.shared.generateWebUI(prompt: "dashboard")
            let (liveURL, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-App", htmlCode: currentCode)
            completion(AgentResponse(
                agent: .raphael,
                text: status,
                spokenText: "Votre projet a été déployé et mis en ligne avec succès sur \(liveURL).",
                openStudio: true,
                generatedCode: currentCode
            ))
        }
        // 2. Connexion GitHub
        else if lower.contains("github") || lower.contains("connecte a github") || lower.contains("connexion github") || lower.contains("login github") {
            let authURL = VAICodeEngine.shared.getGitHubAuthURL()
            DispatchQueue.main.async {
                UIApplication.shared.open(authURL, options: [:], completionHandler: nil)
            }
            let responseText = "⚡ **Raphaël [GitHub Integration & OAuth]**\n\nJ'ai ouvert le portail officiel de connexion GitHub : [github.com/login](\(authURL.absoluteString)).\nUne fois connecté, vos dépôts distants et vos déploiements automatiques seront synchronisés !"
            completion(AgentResponse(
                agent: .raphael,
                text: responseText,
                spokenText: "J'ai lancé la connexion à GitHub. Vous pouvez vous identifier directement sur la page sécurisée.",
                openStudio: false,
                generatedCode: nil
            ))
        }
        // 3. Google / Gmail
        else if lower.contains("gmail") || lower.contains("google mail") || lower.contains("mes mails") || lower.contains("boite mail") {
            let mailURL = VAICodeEngine.shared.getGoogleMailURL()
            DispatchQueue.main.async {
                UIApplication.shared.open(mailURL, options: [:], completionHandler: nil)
            }
            let responseText = "⚡ **Raphaël [Intégration Google & Gmail]**\n\nOuverture de votre messagerie Gmail en cours : [mail.google.com](\(mailURL.absoluteString))."
            completion(AgentResponse(
                agent: .raphael,
                text: responseText,
                spokenText: "J'ouvre votre boîte de réception Gmail.",
                openStudio: false,
                generatedCode: nil
            ))
        }
        // 4. Google Play Store / Console Développeur
        else if lower.contains("google play") || lower.contains("play store") || lower.contains("play console") || lower.contains("console developpeur") {
            let consoleURL = VAICodeEngine.shared.getGooglePlayConsoleURL()
            DispatchQueue.main.async {
                UIApplication.shared.open(consoleURL, options: [:], completionHandler: nil)
            }
            let manifest = VAICodeEngine.shared.generateGooglePlayManifest(appName: "Sarah IA", packageName: "com.sarahia.app")
            _ = VAICodeEngine.shared.saveFile(filename: "AndroidManifest.xml", content: manifest)
            let responseText = "⚡ **Raphaël [Google Play Developer Console]**\n\nAccès direct au tableau de bord Google Play Console : [play.google.com/console](\(consoleURL.absoluteString)).\nLe fichier de configuration `AndroidManifest.xml` a été compilé dans votre espace `Documents/VAI_Workspace/`."
            completion(AgentResponse(
                agent: .raphael,
                text: responseText,
                spokenText: "Je vous connecte à la console développeur Google Play Store.",
                openStudio: true,
                generatedCode: manifest
            ))
        }
        // 5. Raccourcis Apple Shortcuts
        else if lower.contains("shortcut") || lower.contains("raccourci") {
            let (json, _) = VAICodeEngine.shared.generateAppleShortcut(title: "Automatisation Raphaël", prompt: prompt)
            let responseText = "⚡ **Raphaël [Export Apple Shortcut]**\n\nRaccourci Apple généré et compilé avec succès dans votre espace `Documents/VAI_Workspace/`.\n\n```json\n\(json)\n```"
            completion(AgentResponse(
                agent: .raphael,
                text: responseText,
                spokenText: "Raccourci Apple généré avec succès dans votre espace de travail.",
                openStudio: true,
                generatedCode: json
            ))
        }
        // 6. Code & Studio VAI Coding par défaut
        else {
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
    
    // MARK: - Nathan (Expert IA, Modèles, Vidéo, Musique)
    
    private func processWithNathan(text: String, completion: @escaping (AgentResponse) -> Void) {
        let lower = text.lowercased()
        
        // Voo — Génération Vidéo
        if lower.contains("voo") || lower.contains("génère une vidéo") || lower.contains("genere une video") || lower.contains("générer une vidéo") {
            let vooURL = URL(string: "https://voo.ai")!
            DispatchQueue.main.async {
                UIApplication.shared.open(vooURL)
            }
            let responseText = "🤖 **Nathan [Génération Vidéo — Voo AI]**\n\nJ'ai ouvert **Voo** pour toi ! C'est l'un des meilleurs outils IA de génération vidéo.\n\n🎬 Tu peux y décrire ta scène en français ou en anglais et Voo va générer une vidéo complète avec des visuels réalistes ou animés.\n\n*Tu veux que je t'aide à rédiger un prompt vidéo efficace ?*"
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: "J'ai ouvert Voo, le meilleur outil de génération vidéo par intelligence artificielle. Tu peux décrire ta scène et Voo va créer la vidéo pour toi.",
                openStudio: false,
                generatedCode: nil
            ))
            return
        }
        
        // Suno — Génération Musicale
        if lower.contains("suno") || lower.contains("compose une musique") || lower.contains("génère une musique") || lower.contains("crée une chanson") || lower.contains("cree une chanson") {
            let sunoURL = URL(string: "https://suno.com")!
            DispatchQueue.main.async {
                UIApplication.shared.open(sunoURL)
            }
            let responseText = "🤖 **Nathan [Composition Musicale — Suno AI]**\n\nJ'ai lancé **Suno** ! C'est l'outil de composition musicale le plus puissant du moment.\n\n🎵 Describe ton ambiance, ton genre musical, tes paroles, et Suno va composer une chanson complète avec voix et instruments.\n\n*Genres disponibles : Pop, Hip-Hop, Jazz, Classique, Electro, Rock, K-Pop, Rai, Mizrahi...*"
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: "J'ai ouvert Suno, l'outil de composition musicale par IA. Tu peux décrire le style et les paroles que tu veux, et Suno va créer la chanson complète.",
                openStudio: false,
                generatedCode: nil
            ))
            return
        }
        
        // Comparaison ou information sur les modèles IA
        if lower.contains("meilleur modèle") || lower.contains("meilleur modele") || lower.contains("dernier modèle") ||
           lower.contains("dernier modele") || lower.contains("modèle ia") || lower.contains("modele ia") ||
           lower.contains("chatgpt") || lower.contains("claude") || lower.contains("gemini") ||
           lower.contains("gpt") || lower.contains("llama") || lower.contains("mistral") ||
           lower.contains("nouveau modèle") || lower.contains("nouveau modele") {
            let responseText = """
            🤖 **Nathan [Veille IA Mondiale — Meilleurs Modèles 2025]**

            Voici un état des lieux des modèles d'IA les plus puissants en ce moment :

            **🏆 Meilleur pour le texte & raisonnement :**
            • **Claude Sonnet 4.5 / Opus 4** (Anthropic) — Excellence en raisonnement complexe et code
            • **GPT-4o** (OpenAI) — Polyvalent, rapide, multimodal
            • **Gemini 1.5 Pro / Ultra** (Google) — Très long contexte (1M tokens)

            **📱 Meilleur sur iPhone (local, hors-ligne) :**
            • **iPhone 14 Pro / 15 Pro / 16** : GPT-4o mini, Phi-3 Medium
            • **iPhone 12 / 13 / 14** : Llama 3.1 8B Q4, Mistral 7B
            • **iPhone 11 / XR** : Phi-3 Mini, Gemini Nano
            • **iPhone 5s / 6 / 7 / 8** : TinyLlama 1.1B, Phi-2

            **🎨 Génération image :**
            • **Midjourney v7**, **DALL-E 3**, **Stable Diffusion 3.5**

            **🎬 Génération vidéo :**
            • **Voo AI**, **Runway Gen-3**, **Sora** (OpenAI)

            **🎵 Génération musicale :**
            • **Suno v4**, **Udio**, **MusicGen** (Meta)

            *Tu veux que j'ouvre un de ces outils ?*
            """
            let spoken = "Voici les meilleurs modèles d'intelligence artificielle du moment. Pour le texte : Claude, GPT-4o et Gemini. Pour les vidéos : Voo et Runway. Pour la musique : Suno et Udio."
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: spoken,
                openStudio: false,
                generatedCode: nil
            ))
            return
        }
        
        // Réponse générale Nathan
        let responseText = "🤖 **Nathan [Expert IA & Création]**\n\nBonjour ! Je suis Nathan, ton expert en intelligence artificielle !\n\nJe peux t'aider à :\n• **Trouver le meilleur modèle d'IA** selon ton téléphone et tes besoins\n• **Générer des vidéos** avec Voo AI\n• **Composer de la musique** avec Suno\n• **Rester informé** des derniers modèles qui sortent (GPT, Claude, Gemini, Llama...)\n\n*Sur ton iPhone, voici le meilleur modèle disponible maintenant : \(getBestModelForCurrentDevice())*"
        let spoken = "Bonjour ! Je suis Nathan, expert en intelligence artificielle. Dis-moi ce que tu veux faire : trouver le meilleur modèle, générer une vidéo avec Voo, ou composer de la musique avec Suno ?"
        completion(AgentResponse(
            agent: .nathan,
            text: responseText,
            spokenText: spoken,
            openStudio: false,
            generatedCode: nil
        ))
    }
    
    private func getBestModelForCurrentDevice() -> String {
        let memory = ProcessInfo.processInfo.physicalMemory
        if memory >= 6 * 1024 * 1024 * 1024 {
            return "GPT-4o / Claude Sonnet 4.5 (iPhone haut de gamme)"
        } else if memory >= 3 * 1024 * 1024 * 1024 {
            return "Llama 3.1 8B / Mistral 7B Q4 (iPhone milieu de gamme)"
        } else {
            return "TinyLlama 1.1B / Phi-2 (iPhone compact)"
        }
    }
}
