import Foundation
import UIKit
import AVFoundation
import ReplayKit

// MARK: - 1. Entités et Modèles de Données du Cerveau de Sarah

/// Rôle dans l'échange multi-agents
public enum AgentRole: String, Codable {
    case sarah = "Sarah (Patronne & Routeur Central)"
    case tom = "Tom (Sous-Agent Web & Veille)"
    case vision = "Vision (Moteur OCR & Screen Stream)"
    case system = "Système / Autonomie"
}

/// Structure d'une intention analysée par le Cerveau
public struct BrainIntent: Codable {
    public let primaryTopic: String
    public let confidence: Double
    public let requiresWebAgent: Bool
    public let requiresVisionAgent: Bool
    public let requiresMediaStream: Bool
    public let parameters: [String: String]
    
    public init(
        primaryTopic: String,
        confidence: Double = 1.0,
        requiresWebAgent: Bool = false,
        requiresVisionAgent: Bool = false,
        requiresMediaStream: Bool = false,
        parameters: [String: String] = [:]
    ) {
        self.primaryTopic = primaryTopic
        self.confidence = confidence
        self.requiresWebAgent = requiresWebAgent
        self.requiresVisionAgent = requiresVisionAgent
        self.requiresMediaStream = requiresMediaStream
        self.parameters = parameters
    }
}

/// Rapport structuré d'exécution multi-agents
public struct BrainExecutionReport: Codable {
    public let leadAgent: String
    public let delegatorMessage: String?
    public let specializedAgentReport: String?
    public let finalNaturalResponse: String
    public let sources: [String]
    public let timestamp: Date
    
    public init(
        leadAgent: String = "Sarah",
        delegatorMessage: String? = nil,
        specializedAgentReport: String? = nil,
        finalNaturalResponse: String,
        sources: [String] = [],
        timestamp: Date = Date()
    ) {
        self.leadAgent = leadAgent
        self.delegatorMessage = delegatorMessage
        self.specializedAgentReport = specializedAgentReport
        self.finalNaturalResponse = finalNaturalResponse
        self.sources = sources
        self.timestamp = timestamp
    }
}

// MARK: - 2. Cerveau Central de Sarah (SarahBrainEngine)

/// Cerveau Souverain et Routeur Central Multi-Agents de Sarah :
/// - Routeur Sémantique d'Intentions & Désambiguïsation Contextuelle
/// - Gestionnaire de l'Agent Tom (Recherche Web, Billets de Train/Avion, Météo, Wikipedia)
/// - Module de Computer Vision (OCR Haute Densité & Partage d'Écran ReplayKit Live)
/// - Moteur d'Autonomie & Mémoire Persistante Sécurisée
/// - Compatible 100% avec l'écosystème iOS (iPhone 5S / iOS 12 jusqu'à iOS 18+)
public final class SarahBrainEngine {
    
    public static let shared = SarahBrainEngine()
    
    private let webSearch = WebSearchService.shared
    private let mediaService = MediaStreamingService.shared
    private let visionEngine = LocalVisionEngine.shared
    private let screenShare = ScreenShareService.shared
    private let storage = StorageService.shared
    
    private var sessionHistory: [(query: String, response: String, timestamp: Date)] = []
    
    private init() {}
    
    // MARK: - 3. Traitement Principal d'une Requête (Pipeline Asynchrone & Multi-Agents)
    
    /// Analyse, route et résout une requête utilisateur via le cerveau autonome de Sarah
    public func processQuery(
        _ userQuery: String,
        screenContext: UIImage? = nil,
        completion: @escaping (BrainExecutionReport) -> Void
    ) {
        let cleanText = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            let emptyReport = BrainExecutionReport(
                leadAgent: "Sarah",
                finalNaturalResponse: "Je suis là ! Dites-moi ce que vous souhaitez accomplir ou savoir. ✨"
            )
            completion(emptyReport)
            return
        }
        
        // 1. Analyse Sémantique & Résolution d'Intentions
        let intent = resolveIntent(from: cleanText, hasVisualContext: screenContext != nil)
        
        // 2. Aiguillage vers les Sous-Agents Spécialisés
        
        // A. Sous-Agent Vision & OCR
        if intent.requiresVisionAgent, let image = screenContext {
            processVisionPipeline(query: cleanText, image: image, completion: completion)
            return
        }
        
        // B. Sous-Agent Tom (Recherche Web, Transports, Météo, Actualités)
        if intent.requiresWebAgent {
            processWebAgentTomPipeline(query: cleanText, intent: intent, completion: completion)
            return
        }
        
        // C. Module Média (Radio en direct, Apple Podcasts, Musique)
        if intent.requiresMediaStream {
            processMediaPipeline(query: cleanText, intent: intent, completion: completion)
            return
        }
        
        // D. Routeur Central Local & Cognition Sarah
        processLocalCognitionPipeline(query: cleanText, intent: intent, completion: completion)
    }
    
    // MARK: - 4. Résolution d'Intentions & NLP Local
    
    private func resolveIntent(from query: String, hasVisualContext: Bool) -> BrainIntent {
        let norm = normalize(query)
        
        // Intent Vision / OCR / Partage d'écran / Lecture de texte
        if hasVisualContext || norm.contains("partage mon ecran") || norm.contains("analyse mon ecran") || norm.contains("que vois tu") || norm.contains("lis le texte") || norm.contains("lis ce texte") || norm.contains("lis l ecran") || norm.contains("lis ce qui est ecrit") || norm.contains("qu est ce qui est ecrit") || norm.contains("tu peux lire") || norm.contains("peux tu lire") {
            return BrainIntent(primaryTopic: "vision_ocr", requiresVisionAgent: true)
        }
        
        // Intent Alertes de Sécurité Pikoud HaOref (Israël)
        if norm.contains("alerte") || norm.contains("pikoud") || norm.contains("sirene") || norm.contains("tzeva adom") || (norm.contains("israel") && (norm.contains("securite") || norm.contains("attaque") || norm.contains("roquette"))) {
            return BrainIntent(primaryTopic: "red_alert")
        }
        
        // Intent Météo GPS Temps Réel
        if norm.contains("meteo") || norm.contains("quel temps") || norm.contains("temperature") || norm.contains("pleuvoir") || norm.contains("il pleut") || norm.contains("il fait froid") || norm.contains("il fait chaud") {
            return BrainIntent(primaryTopic: "weather")
        }
        
        // Intent Actualités en Direct (Franceinfo & i24NEWS)
        if norm.contains("actualite") || norm.contains("actualites") || norm.contains("les infos") || norm.contains("les informations") || norm.contains("dernieres nouvelles") || norm.contains("titres du jour") || norm.contains("franceinfo") || norm.contains("i24") {
            return BrainIntent(primaryTopic: "news")
        }
        
        // Intent Vidéos YouTube en Direct
        if norm.contains("youtube") || norm.contains("video de") || norm.contains("lance la video") || norm.contains("mets la video") || norm.contains("regarder la video") || norm.contains("cherche la video") {
            return BrainIntent(primaryTopic: "youtube")
        }
        
        // Intent Radio / Podcasts / Musique
        if norm.contains("radio") || norm.contains("podcast") || norm.contains("musique") || norm.contains("spotify") || norm.contains("apple music") || norm.contains("skyrock") || norm.contains("france inter") || norm.contains("nrj") || norm.contains("rtl") {
            return BrainIntent(primaryTopic: "media_stream", requiresMediaStream: true)
        }
        
        // Intent Recherche Web (Agent Tom)
        if AIService.shared.isWebSearchIntent(norm) || norm.contains("train") || norm.contains("sncf") || norm.contains("vol") || norm.contains("billet") || norm.contains("qui est") || norm.contains("c est quoi") {
            return BrainIntent(primaryTopic: "web_search", requiresWebAgent: true)
        }
        
        return BrainIntent(primaryTopic: "general_cognition")
    }
    
    // MARK: - 5. Pipelines d'Exécution Spécialisés
    
    // Pipeline A : Agent Tom (Recherche Web & Extraction Structurée)
    private func processWebAgentTomPipeline(query: String, intent: BrainIntent, completion: @escaping (BrainExecutionReport) -> Void) {
        webSearch.searchWeb(query: query) { [weak self] fullReport, results in
            let sourcesList = results.map { "\($0.sourceName) : \($0.url)" }
            let report = BrainExecutionReport(
                leadAgent: "Sarah & Tom",
                delegatorMessage: "D'accord ! Je confie cette recherche à Tom, mon agent web en direct.",
                specializedAgentReport: fullReport,
                finalNaturalResponse: fullReport,
                sources: sourcesList
            )
            self?.recordExchange(query: query, response: fullReport)
            completion(report)
        }
    }
    
    // Pipeline B : Agent Vision (OCR Haute Densité & Reconnaissance UI)
    private func processVisionPipeline(query: String, image: UIImage, completion: @escaping (BrainExecutionReport) -> Void) {
        let norm = normalize(query)
        let isTextReading = norm.contains("lis") || norm.contains("lire") || norm.contains("texte") || norm.contains("ecrit")
        
        if isTextReading {
            visionEngine.extractText(from: image) { [weak self] ocrText in
                let cleanOcr = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                let reply = !cleanOcr.isEmpty
                    ? "Sur votre écran, il est écrit : « \(cleanOcr) » 📄"
                    : "Je regarde l'écran, mais je ne détecte aucun texte lisible pour le moment."
                
                let report = BrainExecutionReport(
                    leadAgent: "Sarah (Moteur OCR)",
                    finalNaturalResponse: reply,
                    sources: ["Local Vision Engine (Apple Vision OCR)"]
                )
                self?.recordExchange(query: query, response: reply)
                completion(report)
            }
            return
        }
        
        visionEngine.recognizeObject(in: image) { [weak self] result in
            var text = result.naturalSpokenResponse
            if !result.detectedText.isEmpty {
                text += "\n\n📄 **Texte extrait (OCR)** : « \(result.detectedText) »"
            }
            let report = BrainExecutionReport(
                leadAgent: "Vision Engine",
                finalNaturalResponse: text,
                sources: ["Local Vision Engine (CoreML/OCR)"]
            )
            self?.recordExchange(query: query, response: text)
            completion(report)
        }
    }
    
    // Pipeline C : Média & Flux Audio
    private func processMediaPipeline(query: String, intent: BrainIntent, completion: @escaping (BrainExecutionReport) -> Void) {
        let norm = normalize(query)
        let response: String
        
        if norm.contains("arrete") || norm.contains("stop") || norm.contains("coupe") {
            response = mediaService.stopRadio()
        } else if norm.contains("podcast") {
            response = mediaService.launchApplePodcasts(query: query)
        } else if norm.contains("musique") || norm.contains("spotify") || norm.contains("apple music") {
            response = mediaService.launchMusic(query: query)
        } else {
            response = mediaService.playRadio(stationName: query)
        }
        
        let report = BrainExecutionReport(leadAgent: "Sarah", finalNaturalResponse: response)
        recordExchange(query: query, response: response)
        completion(report)
    }
    
    // Pipeline D : Cognition Locale & Nouveaux Services Connectés
    private func processLocalCognitionPipeline(query: String, intent: BrainIntent, completion: @escaping (BrainExecutionReport) -> Void) {
        if intent.primaryTopic == "red_alert" {
            RedAlertService.shared.getSecurityStatusSummary { [weak self] summary in
                let report = BrainExecutionReport(leadAgent: "Sarah (Pikoud HaOref)", finalNaturalResponse: summary, sources: ["Pikoud HaOref (Front Intérieur)"])
                self?.recordExchange(query: query, response: summary)
                completion(report)
            }
            return
        }
        
        if intent.primaryTopic == "weather" {
            WeatherService.shared.fetchWeather { [weak self] weatherInfo in
                let summary = weatherInfo?.naturalSpokenSummary ?? "Je n'ai pas pu obtenir la météo locale pour l'instant."
                let report = BrainExecutionReport(leadAgent: "Sarah (Météo)", finalNaturalResponse: summary, sources: ["Open-Meteo & GPS"])
                self?.recordExchange(query: query, response: summary)
                completion(report)
            }
            return
        }
        
        if intent.primaryTopic == "youtube" {
            let cleanQuery = query
                .replacingOccurrences(of: "cherche sur youtube", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "sur youtube", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "lance la vidéo de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "lance la video de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la vidéo de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la video de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la vidéo", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la video", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "youtube", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let q = cleanQuery.isEmpty ? query : cleanQuery
            
            YouTubeService.shared.getSpokenSummary(for: q) { [weak self] summary, videos in
                let sources = videos.prefix(3).map { "\($0.title) (\($0.channelTitle))" }
                let report = BrainExecutionReport(leadAgent: "Sarah (YouTube)", finalNaturalResponse: summary, sources: sources)
                NotificationCenter.default.post(name: NSNotification.Name("SarahLaunchYouTubePlayer"), object: q)
                self?.recordExchange(query: query, response: summary)
                completion(report)
            }
            return
        }
        
        let response = AIService.shared.generateSyncResponse(for: query)
        let report = BrainExecutionReport(leadAgent: "Sarah", finalNaturalResponse: response)
        recordExchange(query: query, response: response)
        completion(report)
    }
    
    // MARK: - 6. Enregistrement & Continuité Contextuelle Inter-Sessions
    
    private func recordExchange(query: String, response: String) {
        sessionHistory.append((query: query, response: response, timestamp: Date()))
        if sessionHistory.count > 50 {
            sessionHistory.removeFirst(sessionHistory.count - 50)
        }
    }
    
    private func normalize(_ text: String) -> String {
        return text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
