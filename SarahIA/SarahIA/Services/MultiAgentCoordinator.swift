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
            
        case .ethel:
            processWithEthel(text: trimmed, completion: completion)
        }
    }
    
    // MARK: - Conscience de Soi & Connaissance de l'Équipe (Sarah, Tom, Raphaël, Yohan, Nathan, Ethel)
    
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
            Voici l'équipe complète de vos 6 agents intégrés :

            👑 **Sarah [Patronne & Pilote]** : Coordination générale, mémoire locale, flash, batterie et requêtes du quotidien.
            🌍 **Tom [Histoire & Géopolitique]** : Histoire mondiale depuis 1948, conflits internationaux et débats politiques.
            ⚡ **Raphaël [Développeur & VAI Coding]** : Création de code, Apple Shortcuts, intégrations web et studio de code.
            🇮🇱 **Yohan [Traducteur Français ⇔ Hébreu]** : Dictionnaire expert bilingue, grammaire, racines hébraïques et phonétique.
            🤖 **Nathan [Réseaux Sociaux, WhatsApp & IA]** : Accès à tous vos réseaux sociaux, publication de statuts & vidéos WhatsApp, veille IA.
            ✨ **Ethel [Intelligence Créative & Spécialisée]** : Agent féminin polyvalent au thème Bleu & Rouge, prête pour ses futurs modules dédiés.

            *Vous pouvez parler à n'importe lequel d'entre nous en disant par exemple : « Passe-moi Tom », « Je veux parler à Ethel » ou « Donne-moi Yoann » !*
            """
            return AgentResponse(
                agent: activeAgent,
                text: teamDescription,
                spokenText: "Nous sommes 6 agents dans cette application : Sarah la patronne, Tom pour l'histoire, Raphaël pour le code, Yoann pour la traduction en hébreu, Nathan pour les réseaux sociaux et WhatsApp, et Ethel, notre nouvel agent créatif.",
                openStudio: false,
                generatedCode: nil
            )
        }
        
        if isAskingSelf {
            switch activeAgent {
            case .yohan:
                let text = "🇮🇱 **Yohan [Traducteur Français ⇄ Hébreu]**\n\nJe m'appelle **Yoann** ! Je suis votre agent expert en langue hébraïque et française. Je maîtrise la traduction bilingue, les racines sémitiques, le vocabulaire idiomatique et la phonétique. Vous pouvez me poser n'importe quelle question de traduction ou me demander d'analyser un texte en hébreu."
                let spoken = "Je suis Yoann, votre agent traducteur en hébreu et en français. Que souhaitez-vous traduire ou apprendre en hébreu ?"
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
                let text = "👑 **Sarah [Patronne & Pilote]**\n\nJe suis **Sarah**, la patronne et l'intelligence artificielle principale de l'application ! Je pilote l'équipe avec Tom, Raphaël, Yoann, Nathan et Ethel, je gère votre mémoire locale, les commandes système de votre iPhone et vos requêtes du quotidien."
                let spoken = "Je suis Sarah, l'intelligence artificielle principale et la patronne de l'application. Je coordonne Tom, Raphaël, Yoann, Nathan, Ethel et moi-même pour vous assister au mieux."
                return AgentResponse(agent: .sarah, text: text, spokenText: spoken)
                
            case .nathan:
                let text = "🤖 **Nathan [Réseaux Sociaux, WhatsApp & IA]**\n\nJe suis **Nathan**, l'agent expert réseaux sociaux et intelligence artificielle ! J'ai accès à tous vos réseaux sociaux (WhatsApp, Instagram, TikTok, YouTube, Twitter/X, Facebook) et je peux poster vos statuts WhatsApp, gérer vos vidéos, et vous connecter aux derniers modèles d'IA."
                let spoken = "Je suis Nathan, expert en réseaux sociaux, WhatsApp et intelligence artificielle ! J'ai accès à tous vos réseaux sociaux pour publier vos vidéos, statuts WhatsApp, et créer du contenu."
                return AgentResponse(agent: .nathan, text: text, spokenText: spoken)
                
            case .ethel:
                let text = "✨ **Ethel [Intelligence Créative & Spécialisée]**\n\nJe m'appelle **Ethel** ! Je suis votre nouvel agent féminin à l'interface Bleu et Rouge. Mon socle est en place et je suis prête pour recevoir les futurs modules et fonctionnalités que vous allez m'attribuer."
                let spoken = "Bonjour ! Je suis Ethel, votre nouvel agent féminin. Je suis prête et j'attends vos instructions !"
                return AgentResponse(agent: .ethel, text: text, spokenText: spoken)
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
        let ethelTokens = ["ethel", "etel", "aethel", "ehtel"]
        
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
        
        // 6. Cible Ethel
        for kw in switchKeywords {
            for name in ethelTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .ethel, residualPrompt: residual)
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
        for name in ethelTokens {
            if normalized == name || normalized.starts(with: name + " ") {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .ethel, residualPrompt: res)
            }
        }
        
        return nil
    }
    
    // MARK: - Détection Thématique d'Agent Spécialisé
    
    private func detectTargetAgent(normalized: String) -> AgentType {
        // Ethel (Intelligence Créative & Spécialisée)
        if normalized.contains("ethel") || normalized.contains("etel") || normalized.contains("aethel") {
            return .ethel
        }
        
        // Yohan / Yoann (Traduction Français <-> Hébreu)
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
           normalized.contains("guerre") || normalized.contains("conflit") ||
           normalized.contains("debat") || normalized.contains("politique") ||
           normalized.contains("moyen orient") || normalized.contains("gaza") ||
           normalized.contains("israel histoire") || normalized.contains("1948") ||
           normalized.contains("president") || normalized.contains("onu") ||
           normalized.contains("otan") || normalized.contains("europe") {
            return .tom
        }
        
        // Nathan (Réseaux Sociaux, WhatsApp, Vidéos, Statuts, Musique Suno, Voo, IA)
        if normalized.contains("nathan") ||
           normalized.contains("reseaux sociaux") || normalized.contains("reseau social") ||
           normalized.contains("whatsapp") || normalized.contains("instagram") ||
           normalized.contains("tiktok") || normalized.contains("youtube") ||
           normalized.contains("statut") || normalized.contains("story") ||
           normalized.contains("publie") || normalized.contains("poster") ||
           normalized.contains("video ia") || normalized.contains("suno") ||
           normalized.contains("voo") || normalized.contains("veo") {
            return .nathan
        }
        
        // Par défaut : Sarah
        return .sarah
    }
    
    // MARK: - Passation d'Agent Sécurisée & Handoff Vocal
    
    private func handleAgentHandoff(
        from sourceAgent: AgentType,
        to targetAgent: AgentType,
        residualPrompt: String,
        completion: @escaping (AgentResponse) -> Void
    ) {
        let cleanResidual = residualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si une question de fond accompagnait l'ordre de passage
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
            case .ethel:
                processWithEthel(text: cleanResidual, completion: completion)
            }
            return
        }
        
        // Phrase de transition personnalisée selon qui passe la main
        let transitionLine: String
        let sourceName: String
        switch sourceAgent {
        case .sarah:
            if targetAgent == .yohan {
                transitionLine = "Attends, ne quitte pas, je te passe Yoann !"
            } else if targetAgent == .ethel {
                transitionLine = "Attends, ne quitte pas, je te passe Ethel !"
            } else {
                transitionLine = "Attends, ne quitte pas, je te le passe !"
            }
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
        case .ethel:
            transitionLine = "Pas de souci Yoël, je te le passe !"
            sourceName = "✨ **Ethel**"
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
            let yohanGreeting = "Shalom Yoël ! 🇮🇱 C'est Yoann. Je suis là pour toute traduction, expression idiomatique ou question linguistique en hébreu ou en français. Que veux-tu traduire ?"
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
            let nathanGreeting = "Yo ! C'est Nathan ! 🤖 Je suis branché sur tous tes réseaux sociaux (WhatsApp, Instagram, TikTok, YouTube...) et sur les derniers modèles d'IA. Tu veux poster une vidéo ou un statut WhatsApp, publier sur tes réseaux, ou créer des vidéos et de la musique ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n🤖 **Nathan [Réseaux Sociaux & WhatsApp]** :\n\(nathanGreeting)"
            
            completion(AgentResponse(
                agent: .nathan,
                text: fullText,
                spokenText: "\(transitionLine) \(nathanGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: nathanGreeting,
                handoffSourceAgent: sourceAgent
            ))
            
        case .ethel:
            let ethelGreeting = "Bonjour Yoël ! ✨ C'est Ethel. Je suis ravie d'être avec toi ! Mon espace est prêt et j'attends tes prochaines instructions pour activer mes fonctionnalités."
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n✨ **Ethel [Intelligence Créative & Spécialisée]** :\n\(ethelGreeting)"
            
            completion(AgentResponse(
                agent: .ethel,
                text: fullText,
                spokenText: "\(transitionLine) \(ethelGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: ethelGreeting,
                handoffSourceAgent: sourceAgent
            ))
        }
    }
    
    // MARK: - Traitements Spécialisés
    
    private func processWithEthel(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "ethel", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let responseText = "✨ **Ethel [Intelligence Créative & Spécialisée]** :\n\nBonjour Yoël ! C'est **Ethel**. Mon socle Bleu & Rouge est parfaitement opérationnel. Je suis à ton écoute et prête pour recevoir le nouveau code et les prochaines spécialités que tu souhaites me confier !"
        let spoken = "Bonjour Yoël ! C'est Ethel. Mon socle est opérationnel et je suis à ton écoute pour la suite."
        completion(AgentResponse(agent: .ethel, text: responseText, spokenText: spoken))
    }
    
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
    
    // MARK: - Nathan (Réseaux Sociaux, WhatsApp, Statuts, Vidéos & IA)
    
    private enum NathanVideoStep {
        case idle
        case waitingForDestination
        case waitingForVideoName(destination: String)
        case waitingForHashtags(destination: String, videoName: String)
    }
    
    private var nathanStep: NathanVideoStep = .idle
    
    private func processWithNathan(text: String, completion: @escaping (AgentResponse) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // 1. ÉTAPE 4 : L'utilisateur répond pour les hashtags / "non ne mets rien vas-y envoie"
        if case .waitingForHashtags(let destination, let videoName) = nathanStep {
            let isNoHashtag = lower.contains("non") || lower.contains("rien") || lower.contains("ne mets rien") ||
                              lower.contains("ne met rien") || lower.contains("vas-y envoie") || lower.contains("vas y envoie") ||
                              lower.contains("envoie") || lower.contains("sans hashtag") || lower.contains("aucun") ||
                              lower.contains("pas de hashtag") || lower.contains("envoie la vidéo") || lower.contains("envoie la video")
            
            nathanStep = .idle
            
            if isNoHashtag {
                let responseText = """
                🚀 **Nathan [Publication WhatsApp & Réseaux]**

                ✅ C'est parti ! Ta vidéo **« \(videoName) »** a été envoyée et mise en ligne sans hashtags directement sur **\(destination)** !

                📲 *Ouverture de l'application en cours pour finaliser...*
                """
                let spoken = "C'est parti ! Ta vidéo \(videoName) est mise en ligne sans hashtags sur \(destination)."
                
                // Déclenchement de l'ouverture WhatsApp / Partage
                triggerSocialShare(destination: destination, title: videoName, hashtags: "")
                
                completion(AgentResponse(
                    agent: .nathan,
                    text: responseText,
                    spokenText: spoken,
                    openStudio: false,
                    generatedCode: nil
                ))
                return
            } else {
                let hashtags = trimmed
                let responseText = """
                🚀 **Nathan [Publication WhatsApp & Réseaux]**

                ✅ C'est parti ! Ta vidéo **« \(videoName) »** avec les hashtags `\(hashtags)` a été préparée et mise en ligne avec succès sur **\(destination)** !

                📲 *Ouverture de l'application en cours...*
                """
                let spoken = "C'est parti ! Ta vidéo \(videoName) avec tes hashtags est mise en ligne sur \(destination)."
                
                triggerSocialShare(destination: destination, title: videoName, hashtags: hashtags)
                
                completion(AgentResponse(
                    agent: .nathan,
                    text: responseText,
                    spokenText: spoken,
                    openStudio: false,
                    generatedCode: nil
                ))
                return
            }
        }
        
        // 2. ÉTAPE 3 : L'utilisateur donne le nom / titre de la vidéo (ex: "raph la vidéo", "blague Didier", etc.)
        if case .waitingForVideoName(let destination) = nathanStep {
            let videoTitle = trimmed
                .replacingOccurrences(of: "le nom c'est", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "le titre c'est", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "appelle la", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "nom :", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let finalTitle = videoTitle.isEmpty ? "Ma Super Vidéo" : videoTitle
            nathanStep = .waitingForHashtags(destination: destination, videoName: finalTitle)
            
            let responseText = """
            🤖 **Nathan [Réseaux Sociaux & WhatsApp]**

            Parfait, titre enregistré : **« \(finalTitle) »** 🎬

            Veux-tu ajouter des **hashtags** ou une légende particulière ?
            *(Si tu ne veux rien ajouter, dis simplement : « Non, ne mets rien, vas-y envoie »)*
            """
            let spoken = "Parfait, titre enregistré : \(finalTitle). Veux-tu ajouter des hashtags ou une légende ? Si tu ne veux rien mettre, dis-moi : non, ne mets rien, vas-y envoie."
            
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: spoken,
                openStudio: false,
                generatedCode: nil
            ))
            return
        }
        
        // 3. ÉTAPE 2 : L'utilisateur répond où poster (WhatsApp, statut, insta, etc.)
        if case .waitingForDestination = nathanStep {
            let destination = detectDestination(lower: lower)
            nathanStep = .waitingForVideoName(destination: destination)
            
            let responseText = """
            🤖 **Nathan [Réseaux Sociaux & WhatsApp]**

            Super, destination choisie : **\(destination)** ! 📲

            Quel est le **nom ou le titre de la vidéo** ?
            """
            let spoken = "Super, c'est noté pour \(destination) ! Quel est le nom de la vidéo ?"
            
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: spoken,
                openStudio: false,
                generatedCode: nil
            ))
            return
        }
        
        // 4. ÉTAPE 1 : Déclenchement d'un flux vidéo ou statut
        if lower.contains("vidéo") || lower.contains("video") || lower.contains("statut") || lower.contains("poster") || lower.contains("publier") || lower.contains("mettre en ligne") {
            if lower.contains("whatsapp") || lower.contains("statut") {
                nathanStep = .waitingForVideoName(destination: "WhatsApp (Statut & Messages)")
                let responseText = """
                🤖 **Nathan [Réseaux Sociaux & WhatsApp]**

                Je m'occupe de ton statut & partage **WhatsApp** ! 📲

                Quel est le **nom ou le titre de ta vidéo** ?
                """
                let spoken = "Je m'occupe de ton statut WhatsApp ! Quel est le nom de ta vidéo ?"
                completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
                return
            } else {
                nathanStep = .waitingForDestination
                let responseText = """
                🤖 **Nathan [Réseaux Sociaux & WhatsApp]**

                Que veux-tu que je fasse avec ta vidéo ?
                • La mettre en **Statut WhatsApp** ou l'envoyer sur **WhatsApp**
                • La publier sur **Instagram** (Reels / Post)
                • La poster sur **TikTok**
                • La mettre sur **YouTube**
                • La publier sur **Twitter / X**
                """
                let spoken = "Que veux-tu que je fasse avec ta vidéo ? Tu veux que je la mette en statut sur WhatsApp, ou sur Instagram, TikTok, ou YouTube ?"
                completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
                return
            }
        }
        
        // 5. WhatsApp direct
        if lower.contains("whatsapp") || lower.contains("whatsap") {
            let whatsappURL = URL(string: "whatsapp://")!
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(whatsappURL) {
                    UIApplication.shared.open(whatsappURL)
                } else if let web = URL(string: "https://web.whatsapp.com") {
                    UIApplication.shared.open(web)
                }
            }
            let responseText = "🤖 **Nathan [WhatsApp Integration]**\n\nJ'ai accès direct à **WhatsApp** ! Je peux publier tes statuts, envoyer tes vidéos et messages.\n\n📲 [Ouvrir WhatsApp](whatsapp://)\n\n*Dis-moi : « Poste ma vidéo sur WhatsApp » quand tu es prêt !*"
            let spoken = "J'ai ouvert WhatsApp pour toi. Dis-moi si tu veux poster une vidéo ou un statut !"
            completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
            return
        }
        
        // 6. Instagram direct
        if lower.contains("instagram") || lower.contains("insta") {
            let instaURL = URL(string: "instagram://app") ?? URL(string: "https://instagram.com")!
            DispatchQueue.main.async {
                UIApplication.shared.open(instaURL)
            }
            let responseText = "🤖 **Nathan [Instagram Integration]**\n\nOuverture d'**Instagram** ! Je peux préparer tes posts, stories et reels vidéo."
            let spoken = "J'ouvre Instagram pour toi."
            completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
            return
        }
        
        // 7. TikTok direct
        if lower.contains("tiktok") {
            let tiktokURL = URL(string: "tiktok://") ?? URL(string: "https://tiktok.com")!
            DispatchQueue.main.async {
                UIApplication.shared.open(tiktokURL)
            }
            let responseText = "🤖 **Nathan [TikTok Integration]**\n\nOuverture de **TikTok** ! Prêt pour le partage de tes vidéos courtes."
            let spoken = "J'ouvre TikTok pour toi."
            completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
            return
        }
        
        // 8. Voo — Génération Vidéo
        if lower.contains("voo") || lower.contains("génère une vidéo") || lower.contains("genere une video") || lower.contains("générer une vidéo") {
            let vooURL = URL(string: "https://voo.ai")!
            DispatchQueue.main.async {
                UIApplication.shared.open(vooURL)
            }
            let responseText = "🤖 **Nathan [Génération Vidéo — Voo AI]**\n\nJ'ai ouvert **Voo** pour toi ! C'est l'un des meilleurs outils IA de génération vidéo.\n\n🎬 Tu peux y décrire ta scène et Voo va générer une vidéo complète."
            completion(AgentResponse(agent: .nathan, text: responseText, spokenText: "J'ai ouvert Voo, le meilleur outil de génération vidéo par intelligence artificielle."))
            return
        }
        
        // 9. Suno — Génération Musicale
        if lower.contains("suno") || lower.contains("compose une musique") || lower.contains("génère une musique") || lower.contains("crée une chanson") || lower.contains("cree une chanson") {
            let sunoURL = URL(string: "https://suno.com")!
            DispatchQueue.main.async {
                UIApplication.shared.open(sunoURL)
            }
            let responseText = "🤖 **Nathan [Composition Musicale — Suno AI]**\n\nJ'ai lancé **Suno** ! Décris ton ambiance ou tes paroles et Suno composera ta musique."
            completion(AgentResponse(agent: .nathan, text: responseText, spokenText: "J'ai ouvert Suno pour composer ta musique par intelligence artificielle."))
            return
        }
        
        // 10. Modèles IA
        if lower.contains("modèle") || lower.contains("modele") || lower.contains("chatgpt") || lower.contains("claude") || lower.contains("gemini") || lower.contains("gpt") {
            let responseText = """
            🤖 **Nathan [Veille IA & Modèles 2025]**

            Voici les meilleurs modèles disponibles :
            • **Claude Sonnet 4.5** : Raisonnement complexe & Code
            • **GPT-4o** : Polyvalent & Multimodal
            • **Gemini 1.5 Pro** : Contexte massif (1M tokens)
            • **Voo & Runway Gen-3** : Génération Vidéo
            • **Suno v4** : Composition Musicale
            """
            completion(AgentResponse(agent: .nathan, text: responseText, spokenText: "Voici les modèles d'IA les plus performants du moment."))
            return
        }
        
        // Réponse générale Nathan
        let responseText = """
        🤖 **Nathan [Expert Réseaux Sociaux, WhatsApp & IA]**

        Salut ! Je suis **Nathan**, ton agent dédié aux réseaux sociaux et à l'IA :
        • 💬 **WhatsApp** : Publication de statuts, envoi de vidéos et messages
        • 📸 **Instagram / TikTok / YouTube / Twitter** : Partage multi-plateformes
        • 🎬 **Création Vidéo & Musique** : Voo AI et Suno AI
        • 🧠 **Veille IA** : Meilleurs modèles du moment

        *Dis-moi : « Nathan, je veux poster une vidéo sur WhatsApp » ou donne-moi ton ordre !*
        """
        let spoken = "Salut ! Je suis Nathan, ton expert en réseaux sociaux et WhatsApp. Dis-moi quelle vidéo tu veux poster ou sur quel réseau tu veux publier !"
        completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
    }
    
    private func detectDestination(lower: String) -> String {
        if lower.contains("whatsapp") || lower.contains("statut") {
            return "WhatsApp (Statut & Messages)"
        } else if lower.contains("instagram") || lower.contains("insta") {
            return "Instagram (Reels)"
        } else if lower.contains("tiktok") {
            return "TikTok"
        } else if lower.contains("youtube") {
            return "YouTube"
        } else if lower.contains("twitter") || lower.contains(" x") {
            return "Twitter / X"
        } else {
            return "WhatsApp & Réseaux Sociaux"
        }
    }
    
    private func triggerSocialShare(destination: String, title: String, hashtags: String) {
        DispatchQueue.main.async {
            let fullCaption = hashtags.isEmpty ? title : "\(title) \(hashtags)"
            let encoded = fullCaption.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            if destination.lowercased().contains("whatsapp") {
                if let url = URL(string: "whatsapp://send?text=\(encoded)"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    return
                }
            }
            
            // Fallback partage système
            var rootVC: UIViewController? = nil
            if #available(iOS 13.0, *) {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
                }
            } else {
                rootVC = UIApplication.shared.keyWindow?.rootViewController
            }
            
            if let rootVC = rootVC {
                let activityVC = UIActivityViewController(activityItems: [fullCaption], applicationActivities: nil)
                rootVC.present(activityVC, animated: true)
            }
        }
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

