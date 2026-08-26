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
    }
    
    private init() {}
    
    /// Analyse la phrase utilisateur et route vers l'agent adéquat
    public func routeAndProcess(
        query: String,
        explicitAgent: AgentType? = nil,
        completion: @escaping (AgentResponse) -> Void
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        
        // 1. Détection explicite de passage d'agent (Switching verbal)
        let targetAgent: AgentType
        if let explicit = explicitAgent {
            targetAgent = explicit
        } else {
            targetAgent = detectTargetAgent(normalized: normalized)
        }
        
        // 2. Exécution selon l'agent
        switch targetAgent {
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
    
    // MARK: - Détection d'Agent
    
    private func detectTargetAgent(normalized: String) -> AgentType {
        // Yohan (Traduction Français <-> Hébreu)
        if normalized.contains("yohan") || normalized.contains("yoan") || normalized.contains("johan") ||
           normalized.contains("en hébreu") || normalized.contains("en hebreu") ||
           normalized.contains("en français") || normalized.contains("en francais") ||
           normalized.contains("traduis") || normalized.contains("traduit") ||
           normalized.contains("comment on dit") || normalized.contains("comment dit on") ||
           YohanLexiconEngine.shared.isHebrew(normalized) {
            return .yohan
        }
        
        // Raphaël (Code, VAI Coding, Shortcuts, HTML/JS, Swift, Python, Figma)
        if normalized.contains("raphael") || normalized.contains("raphaël") ||
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
           normalized.contains("histoire") || normalized.contains("geopolitique") || normalized.contains("géopolitique") ||
           normalized.contains("1948") || normalized.contains("ben gourion") || normalized.contains("guerre des six jours") ||
           normalized.contains("kippour") || normalized.contains("abraham") || normalized.contains("de gaulle") ||
           normalized.contains("ve republique") || normalized.contains("guerre froide") || normalized.contains("otan") ||
           normalized.contains("actualites") || normalized.contains("actualite") || normalized.contains("politique") {
            return .tom
        }
        
        // Par défaut : Sarah (Patronne & Pilote)
        return .sarah
    }
    
    // MARK: - Traitements Spécialisés
    
    private func processWithYohan(text: String, completion: @escaping (AgentResponse) -> Void) {
        let clean = text
            .replacingOccurrences(of: "passe-moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passe moi yohan", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "yohan", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let queryText = clean.isEmpty ? text : clean
        let result = YohanLexiconEngine.shared.translateExpert(text: queryText)
        
        // Extraction pour synthèse vocale fluide
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
