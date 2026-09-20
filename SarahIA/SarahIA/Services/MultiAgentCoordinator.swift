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
        public let generatedImageData: Data?
        public let generatedImageURL: String?
        public let imageGenerationPrompt: String?
        
        public init(
            agent: AgentType,
            text: String,
            spokenText: String,
            openStudio: Bool = false,
            generatedCode: String? = nil,
            handoffSarahTransition: String? = nil,
            handoffAgentGreeting: String? = nil,
            handoffSourceAgent: AgentType? = nil,
            generatedImageData: Data? = nil,
            generatedImageURL: String? = nil,
            imageGenerationPrompt: String? = nil
        ) {
            self.agent = agent
            self.text = text
            self.spokenText = spokenText
            self.openStudio = openStudio
            self.generatedCode = generatedCode
            self.handoffSarahTransition = handoffSarahTransition
            self.handoffAgentGreeting = handoffAgentGreeting
            self.handoffSourceAgent = handoffSourceAgent
            self.generatedImageData = generatedImageData
            self.generatedImageURL = generatedImageURL
            self.imageGenerationPrompt = imageGenerationPrompt
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
        
        // 1.5 Les salutations simples sont conversationnelles, jamais des commandes.
        // Ce garde-fou passe avant les moteurs musique, média, code et autres outils.
        if isSimpleGreeting(normalized) {
            completion(makeGreetingResponse(for: sourceAgent))
            return
        }
        
        // 1.7 Une demande de création visuelle va directement au studio créatif.
        // Elle doit être détectée avant la conversation générale et avant tout média.
        let visualIntent = OpenSourceImageGenerationService.shared.isImageGenerationIntent(trimmed)
        if visualIntent.isIntent {
            processWithEthel(text: trimmed, completion: completion)
            return
        }
        
        // 2. Détermination de l'agent actif. Le sélecteur visuel reste le contexte
        // par défaut, mais une demande qui cite un spécialiste doit être routée
        // vers celui-ci (ex. « Raphaël, génère un site Internet »).
        let detectedAgent = detectTargetAgent(normalized: normalized)
        let resolvedAgent = explicitAgent ?? (detectedAgent == .sarah ? sourceAgent : detectedAgent)
        
        // 2.5 Détection de question sur l'identité ("Tu es qui ?", "Qui es-tu ?", "C'est quoi les noms des agents ?", "Quels sont les agents ?")
        if let identityResponse = evaluateAgentIdentityAndTeam(normalized: normalized, activeAgent: resolvedAgent) {
            completion(identityResponse)
            return
        }
        
        // 3. Exécution selon l'agent
        switch resolvedAgent {
        case .yohan:
            processWithYohan(text: trimmed, completion: completion)
            
        case .esther:
            processWithEsther(text: trimmed, completion: completion)
            
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
    
    private func isSimpleGreeting(_ normalized: String) -> Bool {
        let greetings: Set<String> = [
            "bonjour", "salut", "coucou", "hello", "bonsoir",
            "yo", "wesh", "re",
            "bonjour sarah", "salut sarah", "coucou sarah", "bonsoir sarah"
        ]
        return greetings.contains(normalized)
    }
    
    private func makeGreetingResponse(for agent: AgentType) -> AgentResponse {
        let text: String
        let spoken: String
        
        switch agent {
        case .sarah:
            text = "👋 **Bonjour !** Je suis Sarah. Qu’est-ce que je peux faire pour toi ?"
            spoken = "Bonjour ! Je suis Sarah. Qu'est-ce que je peux faire pour toi ?"
        case .tom:
            text = "🌍 **Bonjour !** Tom à l’écoute. De quoi veux-tu parler ?"
            spoken = "Bonjour ! Tom à l'écoute. De quoi veux-tu parler ?"
        case .esther:
            text = "💻 **Bonjour !** Raphaël à l’écoute. Qu’est-ce qu’on construit ?"
            spoken = "Bonjour ! Raphaël à l'écoute. Qu'est-ce qu'on construit ?"
        case .yohan:
            text = "🇮🇱 **Bonjour !** Yohan à l’écoute. Que veux-tu traduire ou apprendre ?"
            spoken = "Bonjour ! Yohan à l'écoute. Que veux-tu traduire ou apprendre ?"
        case .nathan:
            text = "🤖 **Bonjour !** Nathan à l’écoute. Qu’est-ce que tu veux préparer ?"
            spoken = "Bonjour ! Nathan à l'écoute. Qu'est-ce que tu veux préparer ?"
        case .ethel:
            text = "✨ **Bonjour !** Ethel à l’écoute. Qu’est-ce qu’on imagine ?"
            spoken = "Bonjour ! Ethel à l'écoute. Qu'est-ce qu'on imagine ?"
        }
        
        return AgentResponse(
            agent: agent,
            text: text,
            spokenText: spoken,
            openStudio: false,
            generatedCode: nil
        )
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
            💻 **Raphaël [Développeur]** : Sites web, apps iOS, SwiftUI, scripts, raccourcis Apple et studio de code.
            🇮🇱 **Yohan [Traducteur Français ⇔ Hébreu]** : Dictionnaire expert bilingue, grammaire, racines hébraïques et phonétique.
            🤖 **Nathan [Réseaux Sociaux & IA]** : Création de contenus, préparation de publications et veille IA.
            ✨ **Ethel [Intelligence Créative & Spécialisée]** : Agent féminin polyvalent au thème Bleu & Rouge, prête pour ses futurs modules dédiés.

            *Vous pouvez parler à n'importe lequel d'entre nous en disant par exemple : « Passe-moi Tom », « Je veux parler à Raphaël », « Donne-moi Yoann » ou « Passe-moi Ethel » !*
            """
            return AgentResponse(
                agent: activeAgent,
                text: teamDescription,
                spokenText: "Nous sommes 6 agents dans cette application : Sarah la patronne, Tom pour l'histoire, Raphaël pour le développement, Yoann pour la traduction en hébreu, Nathan pour les réseaux sociaux et Ethel pour la créativité.",
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
                
            case .esther:
                let text = "💻 **Raphaël [Développeur]**\n\nJe m'appelle **Raphaël**, l'agent développeur de l'équipe. Je peux préparer des maquettes web, des bases SwiftUI pour iPhone, des scripts Python, des raccourcis Apple et des prototypes à améliorer avec vous dans le chat."
                let spoken = "Je m'appelle Raphaël, votre agent développeur. Je prépare des sites web, du code iOS SwiftUI, des scripts et des prototypes. Quel est votre projet ?"
                return AgentResponse(agent: .esther, text: text, spokenText: spoken)
                
            case .sarah:
                let text = "👑 **Sarah [Patronne & Pilote]**\n\nJe suis **Sarah**, la patronne et l'intelligence artificielle principale de l'application ! Je pilote l'équipe avec Tom, Raphaël, Yoann, Nathan et Ethel, je gère votre mémoire locale, les commandes système de votre iPhone et vos requêtes du quotidien."
                let spoken = "Je suis Sarah, l'intelligence artificielle principale et la patronne de l'application. Je coordonne Tom, Raphaël, Yoann, Nathan, Ethel et moi-même pour vous assister au mieux."
                return AgentResponse(agent: .sarah, text: text, spokenText: spoken)
                
            case .nathan:
                let text = "🤖 **Nathan [Réseaux Sociaux & IA]**\n\nJe suis **Nathan**, l'agent expert réseaux sociaux et intelligence artificielle. Je vous aide à préparer des contenus pour Instagram, TikTok, YouTube, Twitter/X et Facebook, à organiser vos idées et à suivre les tendances IA."
                let spoken = "Je suis Nathan, expert en réseaux sociaux et intelligence artificielle. Je vous aide à préparer vos contenus, vos vidéos et vos idées de publication."
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
            "demande a ", "demande au ", "demande a la ",
            "demandez a ", "demandez au ", "demandez a la ",
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
        let estherTokens = ["esther", "ester", "esther code", "raphael", "raphaël", "raph", "rafael"]
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
        
        // 3. Cible Esther (Voice Coding & Build)
        for kw in switchKeywords {
            for name in estherTokens {
                let targetPattern = kw + name
                if norm.contains(" " + targetPattern) || norm.hasPrefix(targetPattern) || norm.contains(targetPattern) {
                    let residual = extractResidual(trigger: kw, agentToken: name)
                    return SwitchCommandMatch(targetAgent: .esther, residualPrompt: residual)
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
        for name in estherTokens {
            if normalized == name || normalized.starts(with: name + " ") || normalized == "\(name) code" {
                let res = normalized.replacingOccurrences(of: name, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return SwitchCommandMatch(targetAgent: .esther, residualPrompt: res)
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
        
        // Esther (Code, VAI Coding, Shortcuts, HTML/JS, Swift, Python, Figma)
        if normalized.contains("esther") || normalized.contains("raphael") ||
           normalized.contains("code") || normalized.contains("programme") ||
           normalized.contains("shortcut") || normalized.contains("raccourci") ||
           normalized.contains("html") || normalized.contains("swift") ||
           normalized.contains("python") || normalized.contains("figma") ||
           normalized.contains("stitch") || normalized.contains("calculatrice") ||
           normalized.contains("composant web") || normalized.contains("studio") {
            return .esther
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
        
        // Nathan (Réseaux Sociaux, Instagram, TikTok, YouTube, Partage)
        if normalized.contains("nathan") ||
           normalized.contains("reseaux sociaux") || normalized.contains("reseau social") ||
           normalized.contains("instagram") || normalized.contains("tiktok") ||
           normalized.contains("youtube") || normalized.contains("twitter") ||
           normalized.contains("story") || normalized.contains("publie") ||
           normalized.contains("poster") {
            return .nathan
        }
        
        // Ethel (Créativité, Studio Graphique, Génération d'Images & Photoréalisme)
        if normalized.contains("ethel") ||
           normalized.contains("genere une image") || normalized.contains("génère une image") ||
           normalized.contains("genere une photo") || normalized.contains("génère une photo") ||
           normalized.contains("dessine") || normalized.contains("illustration") ||
           normalized.contains("cree une image") || normalized.contains("crée une image") ||
           normalized.contains("photorealisme") || normalized.contains("photoréalisme") {
            return .ethel
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
            case .esther:
                processWithEsther(text: cleanResidual, completion: completion)
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
        case .esther:
            transitionLine = "Ça marche, je te la passe tout de suite !"
            sourceName = "💻 **Raphaël**"
        case .yohan:
            transitionLine = "Beseder Yoël, je te le passe !"
            sourceName = "🇮🇱 **Yohan**"
        case .nathan:
            transitionLine = "Je te le passe de suite, let's go !"
            sourceName = "🤖 **Nathan**"
        case .ethel:
            transitionLine = "Pas de souci Yoël, je te la passe !"
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
            
        case .esther:
            let estherGreeting = "Salut Yoël ! C'est Raphaël en ligne. Je peux préparer des sites web, des projets SwiftUI, des scripts et des raccourcis Apple. Quel est ton projet ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n💻 **Raphaël [Développeur]** :\n\(estherGreeting)"
            
            completion(AgentResponse(
                agent: .esther,
                text: fullText,
                spokenText: "\(transitionLine) \(estherGreeting)",
                handoffSarahTransition: transitionLine,
                handoffAgentGreeting: estherGreeting,
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
            let nathanGreeting = "Yo ! C'est Nathan ! Je travaille avec Instagram, TikTok, YouTube et les derniers modèles d'IA. Tu veux préparer une vidéo, une publication ou une idée de contenu ?"
            let fullText = "\(sourceName) : *\(transitionLine)*\n\n🤖 **Nathan [Réseaux Sociaux & IA]** :\n\(nathanGreeting)"
            
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
    
    // MARK: - Ethel (Intelligence Créative & Génération d'Images HD Photoréaliste)
    
    private func processWithEthel(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi ethel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "ethel", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let trimmed = clean.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : clean
        let imageCheck = OpenSourceImageGenerationService.shared.isImageGenerationIntent(trimmed)
        let prompt = imageCheck.isIntent ? imageCheck.cleanedPrompt : trimmed
        let profile = SarahGenerativeModelCatalog.imageProfile()

        OpenSourceImageGenerationService.shared.generateImage(prompt: prompt) { result in
            let imageData = result.image?.jpegData(compressionQuality: 0.92)
            
            if result.isSuccess {
                let locality = result.modelName.hasPrefix("Cloud ·")
                    ? "via le réseau"
                    : "localement sur l’iPhone"
                
                completion(AgentResponse(
                    agent: .ethel,
                    text: locality == "localement sur l’iPhone"
                        ? "🎨 Image créée localement."
                        : "🎨 Image créée via le réseau.",
                    spokenText: "L'image est prête.",
                    generatedImageData: imageData,
                    generatedImageURL: result.imageURL?.absoluteString,
                    imageGenerationPrompt: prompt
                ))
            } else {
                let reason = result.errorMessage ?? "ressources locales indisponibles"
                completion(AgentResponse(
                    agent: .ethel,
                    text: """
                    🎨 **Impossible de créer l’image**

                    \(reason)

                    Si le modèle n’est pas installé, ouvre **Création locale** puis **Installer tout**.
                    """,
                    spokenText: "Je n'ai pas pu terminer la génération de l'image.",
                    imageGenerationPrompt: nil
                ))
            }
        }
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
    
    private func processWithEsther(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "vas-y esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "vas y esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe-moi esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne-moi esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "donne moi esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "esther", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "raphaël", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "raphael", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let prompt = clean.isEmpty ? text : clean
        let lower = prompt.lowercased()
        
        // 1. Préparation de publication : ne jamais inventer une URL publique.
        if lower.contains("met en ligne") || lower.contains("mettre en ligne") || lower.contains("deploie") || lower.contains("deploiement") || lower.contains("deploy") || lower.contains("publie") {
            let currentCode = VAICodeEngine.shared.generateWebUI(prompt: "dashboard")
            let (_, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-App", htmlCode: currentCode)
            completion(AgentResponse(
                agent: .esther,
                text: status,
                spokenText: "Le fichier de votre projet est prêt localement. Il faut encore le publier via un hébergeur ou un dépôt connecté.",
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
            let responseText = "💻 **Raphaël [GitHub]**\n\nJ'ai ouvert le portail officiel de connexion GitHub : [github.com/login](\(authURL.absoluteString)).\nUne fois connecté, vos dépôts distants et vos déploiements automatiques pourront être synchronisés."
            completion(AgentResponse(
                agent: .esther,
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
            let responseText = "💻 **Raphaël [Google et Gmail]**\n\nOuverture de votre messagerie Gmail en cours : [mail.google.com](\(mailURL.absoluteString))."
            completion(AgentResponse(
                agent: .esther,
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
            let responseText = "💻 **Raphaël [Google Play Developer Console]**\n\nAccès direct au tableau de bord Google Play Console : [play.google.com/console](\(consoleURL.absoluteString)).\nLe fichier de configuration `AndroidManifest.xml` a été préparé dans votre espace `Documents/VAI_Workspace/`."
            completion(AgentResponse(
                agent: .esther,
                text: responseText,
                spokenText: "Je vous connecte à la console développeur Google Play Store.",
                openStudio: true,
                generatedCode: manifest
            ))
        }
        // 5. Raccourcis Apple Shortcuts — 100 % local
        else if lower.contains("shortcut") || lower.contains("raccourci") {
            let title = "Automatisation Sarah"

            do {
                let draft = try ShortcutGenerator.shared.createDraft(
                    title: title,
                    prompt: prompt
                )
                let plan = ShortcutGenerator.shared.proposePlan(for: prompt)
                let planText = plan.enumerated()
                    .map { "\($0.offset + 1). \($0.element.title)" }
                    .joined(separator: "\n")

                DispatchQueue.main.async {
                    ShortcutGenerator.shared.openShortcutCreation()
                }

                let responseText = """
                💻 **Raphaël [Apple Raccourcis · Local]**

                J’ai préparé localement **« \(draft.title) »** avec **\(draft.actionCount) action(s)**.

                **Plan proposé :**
                \(planText)

                Rien n’a été envoyé sur Internet. J’ouvre maintenant Apple Raccourcis pour la finalisation que iOS exige.
                """

                completion(AgentResponse(
                    agent: .esther,
                    text: responseText,
                    spokenText: "Le raccourci a été préparé entièrement en local. J'ouvre Apple Raccourcis pour la finalisation.",
                    openStudio: true,
                    generatedCode: draft.plistString
                ))
            } catch {
                completion(AgentResponse(
                    agent: .esther,
                    text: "💻 **Raphaël [Apple Raccourcis]**\n\nImpossible de préparer le raccourci : \(error.localizedDescription)",
                    spokenText: "Je n'ai pas pu préparer ce raccourci.",
                    openStudio: false,
                    generatedCode: nil
                ))
            }
        }

        // 6. Base de code adaptée au langage demandé. Une vraie app iOS n'est jamais
        // prétendue compilée ici : Raphaël prépare le fichier et laisse le Studio en option.
        else if lower.contains("swiftui") || lower.contains("swift") || lower.contains("ios") || lower.contains("iphone") || lower.contains("ipad") {
            let swift = VAICodeEngine.shared.generateSwiftUIStarter(prompt: prompt)
            _ = VAICodeEngine.shared.saveFile(filename: "RaphaelGeneratedView.swift", content: swift)
            let responseText = "💻 **Raphaël [Prototype SwiftUI]**\n\nJ’ai préparé une première base SwiftUI pour iPhone dans `Documents/VAI_Workspace/RaphaelGeneratedView.swift`. Décris-moi maintenant les écrans, les données et les actions que tu veux améliorer."
            completion(AgentResponse(
                agent: .esther,
                text: responseText,
                spokenText: "J'ai préparé une première base SwiftUI. Dis-moi quels écrans et actions tu veux ajouter.",
                openStudio: true,
                generatedCode: swift
            ))
        }
        else if lower.contains("python") {
            let python = VAICodeEngine.shared.generatePythonStarter(prompt: prompt)
            _ = VAICodeEngine.shared.saveFile(filename: "raphael_prototype.py", content: python)
            let responseText = "💻 **Raphaël [Prototype Python]**\n\nJ’ai préparé une base Python dans `Documents/VAI_Workspace/raphael_prototype.py`. Dis-moi les entrées, les données et le résultat attendu pour que je l’améliore."
            completion(AgentResponse(
                agent: .esther,
                text: responseText,
                spokenText: "J'ai préparé une base Python. Dis-moi ce que le programme doit faire exactement.",
                openStudio: true,
                generatedCode: python
            ))
        }
        // 7. Projet web par défaut
        else {
            let html = VAICodeEngine.shared.generateWebUI(prompt: prompt)
            _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
            DevCodeInjector.injectRender(html: html, css: "", js: "")
            let responseText = "💻 **Raphaël [Prototype web]**\n\nJ’ai préparé un composant web dans `Documents/VAI_Workspace/index.html`. Ouvre le Studio si tu veux voir la prévisualisation, puis demande-moi les améliorations souhaitées."
            completion(AgentResponse(
                agent: .esther,
                text: responseText,
                spokenText: "Le prototype web est prêt. Tu peux ouvrir le Studio pour le voir, puis me demander des améliorations.",
                openStudio: true,
                generatedCode: html
            ))
        }
    }
    
    // Alias rétrocompatible
    private func processWithRaphael(text: String, completion: @escaping (AgentResponse) -> Void) {
        processWithEsther(text: text, completion: completion)
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
        AIService.shared.processQuery(text) { response in
            completion(AgentResponse(
                agent: .sarah,
                text: response,
                spokenText: response.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "#", with: ""),
                openStudio: false,
                generatedCode: nil
            ))
        }
    }
    
    // MARK: - Nathan (Réseaux Sociaux, Vidéos & IA)
    
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
                🚀 **Nathan [Publication Réseaux]**

                ✅ C'est parti ! Ta vidéo **« \(videoName) »** a été envoyée et mise en ligne sans hashtags directement sur **\(destination)** !

                📲 *Ouverture de l'application en cours pour finaliser...*
                """
                let spoken = "C'est parti ! Ta vidéo \(videoName) est mise en ligne sans hashtags sur \(destination)."
                
                // Ouverture de la feuille de partage système.
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
                🚀 **Nathan [Publication Réseaux]**

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
            🤖 **Nathan [Réseaux Sociaux & IA]**

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
        
        // 3. ÉTAPE 2 : L'utilisateur répond où poster (Instagram, TikTok, YouTube, etc.)
        if case .waitingForDestination = nathanStep {
            let destination = detectDestination(lower: lower)
            nathanStep = .waitingForVideoName(destination: destination)
            
            let responseText = """
            🤖 **Nathan [Réseaux Sociaux & IA]**

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
        
        // 4. Génération vidéo locale : prioritaire sur le flux de publication.
        let localVideoIntent = SarahLocalVideoGenEngine.shared.detectVideoIntent(trimmed)
        if localVideoIntent.isIntent {
            let profile = SarahLocalVideoGenEngine.shared.profile
            let responseText = """
            🎬 **Sarah & Nathan [Création vidéo]**

            Modèle sélectionné : **\(profile.displayName)** · \(profile.licenseName).

            \(SarahLocalVideoGenEngine.shared.availabilityMessage())
            """
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: SarahLocalVideoGenEngine.shared.availabilityMessage()
            ))
            return
        }

        // 5. Flux de publication d'une vidéo existante.
        if lower.contains("poster") || lower.contains("publier") || lower.contains("mettre en ligne") || lower.contains("partager ma vidéo") || lower.contains("partager ma video") {
            nathanStep = .waitingForDestination
            let responseText = """
            🤖 **Nathan [Réseaux Sociaux]**

            Où veux-tu préparer le partage de ta vidéo ?
            • **Instagram**
            • **TikTok**
            • **YouTube**
            • **Twitter / X**
            """
            let spoken = "Où veux-tu préparer le partage de ta vidéo ?"
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
        
        // 9. Génération musicale locale via Core AI sur iOS 27
        if #available(iOS 27.0, *) {
            let musicCheck = SarahLocalMusicGenEngine.shared.detectIntent(trimmed)
            if musicCheck.isIntent {
                if musicCheck.wantsLyrics {
                    let profile = SarahGenerativeModelCatalog.vocalSongProfile()
                    let responseText = """
                    🎤 **Sarah & Nathan [Chanson avec paroles]**

                    Cible : **\(profile.displayName)** · \(profile.licenseName)

                    \(SarahLocalMusicGenEngine.shared.vocalSongAvailabilityMessage())
                    """
                    completion(AgentResponse(
                        agent: .nathan,
                        text: responseText,
                        spokenText: "Le moteur de chanson chantée est encore expérimental sur iPhone."
                    ))
                    return
                }

                let profile = SarahGenerativeModelCatalog.musicProfile()

                guard SarahLocalMusicGenEngine.shared.isInstrumentalModelInstalled else {
                    let responseText = """
                    🎵 **Sarah & Nathan [Musique locale]**

                    **\(profile.displayName)** doit d'abord être téléchargé dans Réglages → Création locale.
                    Après installation, la génération s'exécute entièrement sur l'iPhone.
                    """
                    completion(AgentResponse(
                        agent: .nathan,
                        text: responseText,
                        spokenText: "Le modèle musical local doit d'abord être installé."
                    ))
                    return
                }

                SarahLocalMusicGenEngine.shared.generateInstrumental(
                    prompt: musicCheck.prompt
                ) { _ in }

                let responseText = """
                🎵 **Sarah & Nathan [Musique locale]**

                Génération lancée avec **\(profile.displayName)**.
                L'inférence s'exécute localement sur l'iPhone.
                """
                completion(AgentResponse(
                    agent: .nathan,
                    text: responseText,
                    spokenText: "Je lance la génération musicale locale."
                ))
                return
            }
        }
        
        // 9.5 Génération d'images : même routeur local que Sarah.
        if lower.contains("génère une image") || lower.contains("génère une photo") || lower.contains("dessine") || lower.contains("crée une image") || lower.contains("crée une photo") || lower.contains("fais une image") || lower.contains("fais une photo") || lower.contains("genere une image") || lower.contains("genere une photo") {
            let imageCheck = OpenSourceImageGenerationService.shared.isImageGenerationIntent(trimmed)
            if imageCheck.isIntent {
                let prompt = imageCheck.cleanedPrompt
                let profile = SarahGenerativeModelCatalog.imageProfile()
                OpenSourceImageGenerationService.shared.generateImage(prompt: prompt) { _ in }

                let responseText = """
                🎨 **Sarah & Nathan [Création visuelle]**

                Création lancée pour : « **\(prompt)** »
                Profil : **\(profile.displayName)** · \(profile.licenseName).
                """
                completion(AgentResponse(
                    agent: .nathan,
                    text: responseText,
                    spokenText: "Je lance la création de votre image avec le modèle adapté à cet iPhone."
                ))
                return
            }
        }
        
        // 10. Modèles IA & architecture Sarah Engine
        if lower.contains("modèle") || lower.contains("modele") || lower.contains("local") || lower.contains("architecture") || lower.contains("moteur ia") {
            let image = SarahGenerativeModelCatalog.imageProfile()
            let video = SarahGenerativeModelCatalog.videoProfile()
            let music = SarahGenerativeModelCatalog.musicProfile()
            let vocals = SarahGenerativeModelCatalog.vocalSongProfile()
            let responseText = """
            🤖 **Sarah Engine [Architecture locale d'abord]**

            • 🧠 **Texte** : modèle local choisi selon la RAM.
            • 🎨 **Image** : **\(image.displayName)**.
            • 🎬 **Vidéo** : **\(video.displayName)**.
            • 🎵 **Musique** : **\(music.displayName)**.
            • 🎤 **Chanson chantée** : **\(vocals.displayName)**.
            • 👁️ **Vision** : frameworks Apple Vision/Core ML.
            • 🔒 **Réseau** : jamais présenté comme local ; le fallback génératif distant est optionnel.
            """
            completion(AgentResponse(
                agent: .nathan,
                text: responseText,
                spokenText: "Sarah Engine choisit automatiquement les modèles selon les capacités de cet iPhone."
            ))
            return
        }
        
        // Réponse générale Nathan
        let responseText = """
        🤖 **Nathan [Expert Réseaux Sociaux & IA]**

        Salut ! Je suis **Nathan**, ton agent dédié aux réseaux sociaux et à l'IA :
        • 📸 **Instagram / TikTok / YouTube / X** : Partage multi-plateformes
        • 🎵 **Création Musicale Polyphonique** : Synthèse locale
        • 🧠 **Veille IA** : Meilleurs modèles embarqués et on-device

        *Dis-moi : « Nathan, quels sont mes réseaux sociaux ? » ou donne-moi ton ordre !*
        """
        let spoken = "Salut ! Je suis Nathan, ton expert en réseaux sociaux et intelligence artificielle. Dis-moi sur quel réseau tu veux créer du contenu !"
        completion(AgentResponse(agent: .nathan, text: responseText, spokenText: spoken))
    }
    
    private func detectDestination(lower: String) -> String {
        if lower.contains("instagram") || lower.contains("insta") {
            return "Instagram (Reels)"
        } else if lower.contains("tiktok") {
            return "TikTok"
        } else if lower.contains("youtube") {
            return "YouTube"
        } else if lower.contains("twitter") || lower.contains(" x") {
            return "Twitter / X"
        } else {
            return "Réseaux Sociaux"
        }
    }
    
    private func triggerSocialShare(destination: String, title: String, hashtags: String) {
        DispatchQueue.main.async {
            let fullCaption = hashtags.isEmpty ? title : "\(title) \(hashtags)"
            
            // Partage système natif
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
            return "Sarah Neural Core Ultra v4 (Apple Neural Engine 6GB+)"
        } else if memory >= 3 * 1024 * 1024 * 1024 {
            return "Sarah Neural Core Pro v4 (Apple Neural Engine 4GB)"
        } else {
            return "Sarah Core Nano v4 (Apple Silicon 2GB)"
        }
    }
}
