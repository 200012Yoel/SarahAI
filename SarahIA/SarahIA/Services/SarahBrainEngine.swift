import Foundation
import UIKit
import AVFoundation
import ReplayKit

// MARK: - 1. Contexte Conversationnel & Résolution de Références

/// Contexte conversationnel persistant et fluide
public final class ConversationContext {
    public static let shared = ConversationContext()
    
    public var currentTopic: String?
    public var previousTopic: String?
    public var lastUserQuestion: String?
    public var lastSarahResponse: String?
    public var activeTask: String? // "travel_search", "web_query", "alert_monitoring", etc.
    
    // Entités et paramètres mémorisés dans la discussion
    public var origin: String?
    public var destination: String?
    public var travelDate: String?
    public var travelCriterion: String? // "moins cher", "plus rapide", "direct"
    public var detectedPerson: String?
    public var detectedPlace: String?
    public var pendingFollowUp: String?
    public var lastAlertEvent: AlertEvent?
    
    private init() {}
    
    public func reset() {
        currentTopic = nil
        previousTopic = nil
        lastUserQuestion = nil
        lastSarahResponse = nil
        activeTask = nil
        origin = nil
        destination = nil
        travelDate = nil
        travelCriterion = nil
        detectedPerson = nil
        detectedPlace = nil
        pendingFollowUp = nil
    }
}

/// Résolveur d'anaphores et de références pronominales (« celui-là », « le moins cher », « pour samedi », etc.)
public final class ReferenceResolver {
    public static let shared = ReferenceResolver()
    
    private init() {}
    
    public func resolveContextualQuery(_ query: String, context: ConversationContext) -> (resolvedQuery: String, intentCategory: String) {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Détection des cas de simulation / Test Alert
        if lower.contains("test alerte") || lower.contains("test alert") || lower.contains("simulation alerte") {
            return (query, "test_alert")
        }
        
        // 2. Détection de demande d'alerte officielle ou "c'est chaud en israël"
        if lower.contains("c'est chaud en israël") || lower.contains("c est chaud en israel") || lower.contains("alerte en direct") || lower.contains("alerte israel") || lower.contains("red alert") {
            return (query, "official_alert")
        }
        
        // 3. Résolution des références temporelles simples (« samedi », « demain », « ce week-end »)
        let days = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche", "demain", "ce soir", "ce week-end"]
        for day in days {
            if lower == day || lower == "pour \(day)" || lower == "le \(day)" {
                context.travelDate = day
                if let dest = context.destination {
                    return ("Billet pour \(dest) pour \(day)", "travel_search")
                }
                return (query, "date_specification")
            }
        }
        
        // 4. Résolution des superlatifs et critères (« le moins cher », « le plus rapide », « le deuxième »)
        if lower.contains("moins cher") || lower.contains("le moins cher") || lower.contains("prix") {
            context.travelCriterion = "le moins cher"
            if let dest = context.destination {
                let dateStr = context.travelDate != nil ? " pour \(context.travelDate!)" : ""
                return ("Option de transport la moins chère pour \(dest)\(dateStr)", "travel_search")
            }
        }
        
        if lower.contains("plus rapide") || lower.contains("direct") {
            context.travelCriterion = "le plus rapide"
            if let dest = context.destination {
                let dateStr = context.travelDate != nil ? " pour \(context.travelDate!)" : ""
                return ("Option de transport la plus rapide pour \(dest)\(dateStr)", "travel_search")
            }
        }
        
        // 5. Extraction de destination de voyage (« billet pour Londres », « vol pour Tokyo », « train vers Lyon »)
        if lower.contains("billet") || lower.contains("vol") || lower.contains("train") || lower.contains("voyage") || lower.contains("partir à") || lower.contains("aller à") {
            context.activeTask = "travel_search"
            context.currentTopic = "voyage"
            
            let patterns = ["pour ([a-zA-Zà-ÿÀ-Ý\\-\\s]+)", "vers ([a-zA-Zà-ÿÀ-Ý\\-\\s]+)", "à ([a-zA-Zà-ÿÀ-Ý\\-\\s]+)"]
            for pat in patterns {
                if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.count)) {
                    let extracted = (lower as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty && extracted.count < 30 {
                        context.destination = extracted.capitalized
                        break
                    }
                }
            }
            return (query, "travel_search")
        }
        
        return (query, "general_query")
    }
}

// MARK: - 2. Planificateur et Générateur de Réponses (ResponsePlanner)

public final class ResponsePlanner {
    public static let shared = ResponsePlanner()
    
    private init() {}
    
    public func planNaturalResponse(
        intentCategory: String,
        query: String,
        context: ConversationContext,
        webResult: String? = nil,
        alertEvent: AlertEvent? = nil
    ) -> String {
        switch intentCategory {
        case "test_alert":
            if let alert = alertEvent {
                return "🟠 **SIMULATION D'ALERTE (TEST ISOLÉ)**\nUne alerte fictive a été générée pour tester l'affichage cartographique sur la zone de **\(alert.cityName)**.\n*(Aucune mise à l'abri réelle requise — Source : \(alert.source))*"
            }
            return "🟠 Simulation d'alerte en cours d'affichage sur la carte interactive."
            
        case "official_alert":
            if let alert = alertEvent {
                return "⚠️ **ALERTE OFFICIELLE DU FRONT INTÉRIEUR**\nUne alerte officielle vient d'être signalée dans la zone de **\(alert.cityName)** (\(alert.affectedAreas.joined(separator: ", "))).\n*Consultez la carte interactive ci-dessous et rejoignez l'abri le plus proche si vous êtes dans le secteur.*"
            }
            return "🟢 Aucun tir ni alerte active signalée en Israël par le Commandement du Front intérieur pour le moment. Tout est calme."
            
        case "travel_search":
            if let dest = context.destination {
                if context.travelDate == nil {
                    context.pendingFollowUp = "date"
                    return "J'ai bien noté votre recherche pour **\(dest)** ✈️🚆. Pour quelle date ou quel jour souhaitez-vous partir ?"
                } else if context.travelCriterion == "le moins cher" {
                    return "Pour votre voyage vers **\(dest)** prévu **\(context.travelDate!)**, l'option la plus économique identifiée est le trajet direct en seconde classe ou vol éco à tarif réduit 🎫. Voulez-vous que je réserve ou vérifie les horaires précis ?"
                } else {
                    return "Voici les meilleures options trouvées pour **\(dest)** le **\(context.travelDate!)** 🚆. Souhaitez-vous le billet le moins cher ou le trajet le plus rapide ?"
                }
            }
            return webResult ?? "Je recherche les meilleurs billets et disponibilités pour votre voyage."
            
        default:
            return webResult ?? "Je suis à votre disposition. Que puis-je faire pour vous ?"
        }
    }
}

// MARK: - 3. Entités et Modèles de Données du Cerveau de Sarah

public enum AgentRole: String, Codable {
    case sarah = "Sarah (Patronne & Routeur Central)"
    case tom = "Tom (Sous-Agent Web & Veille)"
    case vision = "Vision (Moteur OCR & Screen Stream)"
    case system = "Système / Autonomie"
}

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

public struct BrainExecutionReport: Codable {
    public let leadAgent: String
    public let delegatorMessage: String?
    public let specializedAgentReport: String?
    public let finalNaturalResponse: String
    public let sources: [String]
    public let timestamp: Date
    public let alertEvent: AlertEvent?
    
    public init(
        leadAgent: String = "Sarah",
        delegatorMessage: String? = nil,
        specializedAgentReport: String? = nil,
        finalNaturalResponse: String,
        sources: [String] = [],
        timestamp: Date = Date(),
        alertEvent: AlertEvent? = nil
    ) {
        self.leadAgent = leadAgent
        self.delegatorMessage = delegatorMessage
        self.specializedAgentReport = specializedAgentReport
        self.finalNaturalResponse = finalNaturalResponse
        self.sources = sources
        self.timestamp = timestamp
        self.alertEvent = alertEvent
    }
}

// MARK: - 4. Cerveau Central de Sarah (SarahBrainEngine)

public final class SarahBrainEngine {
    public static let shared = SarahBrainEngine()
    
    private let webSearch = WebSearchService.shared
    private let mediaService = MediaStreamingService.shared
    private let visionEngine = LocalVisionEngine.shared
    private let screenShare = ScreenShareService.shared
    private let storage = StorageService.shared
    private let alertService = IsraelAlertService.shared
    private let testAlertEngine = AlertTestEngine.shared
    private let context = ConversationContext.shared
    private let referenceResolver = ReferenceResolver.shared
    private let responsePlanner = ResponsePlanner.shared
    private var sessionHistory: [(query: String, response: String, timestamp: Date)] = []
    
    private init() {}
    
    // MARK: - Traitement Principal d'une Requête
    
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
        
        context.lastUserQuestion = cleanText
        
        // 1. Résolution de références et désambiguïsation contextuelle
        let (resolvedText, intentCategory) = referenceResolver.resolveContextualQuery(cleanText, context: context)
        
        // 2. Traitement Spécial : TEST ALERTE (100% Isolé)
        if intentCategory == "test_alert" {
            let testEvent = testAlertEngine.generateTestAlert()
            context.lastAlertEvent = testEvent
            let response = responsePlanner.planNaturalResponse(intentCategory: intentCategory, query: cleanText, context: context, alertEvent: testEvent)
            
            let report = BrainExecutionReport(
                leadAgent: "Sarah",
                finalNaturalResponse: response,
                sources: ["Simulation Interne Sarah IA (Test)"],
                alertEvent: testEvent
            )
            completion(report)
            return
        }
        
        // 3. Traitement Spécial : Alertes Officielles / Surveillance Israël
        if intentCategory == "official_alert" {
            alertService.checkOfficialAlerts { [weak self] alerts in
                guard let self = self else { return }
                let active = alerts.first
                self.context.lastAlertEvent = active
                let response = self.responsePlanner.planNaturalResponse(intentCategory: intentCategory, query: cleanText, context: self.context, alertEvent: active)
                
                let report = BrainExecutionReport(
                    leadAgent: "Sarah",
                    finalNaturalResponse: response,
                    sources: active != nil ? ["Commandement du Front intérieur"] : ["Pikoud HaOref"],
                    alertEvent: active
                )
                completion(report)
            }
            return
        }
        
        // 4. Traitement Vision / OCR
        if let image = screenContext {
            processVisionPipeline(query: cleanText, image: image, completion: completion)
            return
        }
        
        // 5. Traitement Sémantique Général & Recherche
        let intent = resolveIntent(from: resolvedText, hasVisualContext: screenContext != nil)
        if intent.requiresWebAgent || intentCategory == "travel_search" {
            processWebAgentTomPipeline(query: resolvedText, intent: intent, completion: completion)
            return
        }
        
        // 6. Module Média (Radio en direct, Apple Podcasts, Musique)
        if intent.requiresMediaStream {
            processMediaPipeline(query: cleanText, intent: intent, completion: completion)
            return
        }
        
        // 7. Routeur Central Local & Cognition Sarah
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
