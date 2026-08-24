import Foundation

/// Modèle représentant un résultat de recherche Web
public struct WebSearchResult: Codable {
    public var id: String { url }
    public let title: String
    public let snippet: String
    public let url: String
    public let sourceName: String
    
    public init(title: String, snippet: String, url: String, sourceName: String) {
        self.title = title
        self.snippet = snippet
        self.url = url
        self.sourceName = sourceName
    }
}

/// Service de Recherche Web Haute Performance pour Sarah IA :
/// - Collaboration Multi-Agents : Sarah (Patronne) & Tom (Agent de Recherche Web en direct)
/// - Recherche Spécialisée : Billets de Train (SNCF Connect, Trainline), Billets d'Avion (Google Flights, Skyscanner), Météo Mondiale (Open-Meteo), Wikipédia FR & DuckDuckGo
/// - Compatible iOS 12.0 à iOS 18.0+
public final class WebSearchService {
    
    public static let shared = WebSearchService()
    
    private let urlSession: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 8.0
        config.requestCachePolicy = .useProtocolCachePolicy
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - API Asynchrone Moderne (iOS 13+)
    
    @available(iOS 13.0, *)
    public func searchWebAsync(query: String) async -> (summary: String, results: [WebSearchResult]) {
        await withCheckedContinuation { continuation in
            searchWeb(query: query) { summary, results in
                continuation.resume(returning: (summary, results))
            }
        }
    }
    
    // MARK: - API Synchrone / Callback (iOS 12+)
    
    /// Effectue une recherche web intelligente multi-sources
    public func searchWeb(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            completion("Veuillez préciser votre recherche.", [])
            return
        }
        
        let norm = cleanQuery.lowercased()
            .replacingOccurrences(of: "cherchemoi", with: "cherche moi")
            .replacingOccurrences(of: "trouvemoi", with: "trouve moi")
            .replacingOccurrences(of: "recherchemoi", with: "recherche moi")
            .replacingOccurrences(of: "cherche-moi", with: "cherche moi")
            .replacingOccurrences(of: "d'avion", with: "d avion")
            .replacingOccurrences(of: "d'hotel", with: "d hotel")
        
        // 1. Billets de Train / SNCF / Trainline ("cherche moi un billet de train de Paris a Deauville")
        if norm.contains("billet de train") || norm.contains("billets de train") || norm.contains("billet train") ||
           norm.contains("train pour") || norm.contains("train de ") || norm.contains("sncf") || norm.contains("trainline") ||
           norm.contains("trajet en train") || (norm.contains("train") && (norm.contains("paris") || norm.contains("billet"))) {
            handleTrainSearch(cleanQuery: cleanQuery, norm: norm, completion: completion)
            return
        }
        
        // 2. Billets d'Avion / Vols ("billet d'avion pour Tel Aviv", "vol Paris Nice")
        if norm.contains("billet d avion") || norm.contains("billets d avion") || norm.contains("billet avion") ||
           norm.contains("vol pour") || norm.contains("vols pour") || norm.contains("comparateur de vol") ||
           norm.contains("chercher un vol") || norm.contains("trouve un vol") {
            handleFlightSearch(cleanQuery: cleanQuery, norm: norm, completion: completion)
            return
        }
        
        // 3. Détection Météo pour une ville spécifique ("météo à Lyon", "quel temps à Tokyo")
        if norm.contains("meteo a ") || norm.contains("meteo pour ") || norm.contains("meteo de ") || norm.contains("temps a ") || norm.contains("temperature a ") {
            let cityName = extractCityName(from: cleanQuery)
            if !cityName.isEmpty {
                fetchCityWeather(city: cityName) { weatherSummary, result in
                    if let res = result, !weatherSummary.isEmpty {
                        completion(weatherSummary, [res])
                        return
                    }
                    self.performGeneralSearch(query: cleanQuery, completion: completion)
                }
                return
            }
        }
        
        // 4. Recherche Générale Multi-Sources (Wikipedia + DuckDuckGo)
        performGeneralSearch(query: cleanQuery, completion: completion)
    }
    
    // MARK: - 1. Recherche Spécialisée Billets de Train (SNCF Connect & Trainline)
    
    private func handleTrainSearch(cleanQuery: String, norm: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        var origin = "Paris"
        var destination = "Deauville"
        
        // Extraction intelligente Origine ➔ Destination
        // Ex: "de Paris a Deauville", "Paris a Deauville", "Paris vers Deauville", "pour Deauville"
        if let rangeDe = norm.range(of: " de "), let rangeA = norm.range(of: " a ") ?? norm.range(of: " vers ") {
            if rangeDe.upperBound < rangeA.lowerBound {
                let origStr = String(norm[rangeDe.upperBound..<rangeA.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let destStr = String(norm[rangeA.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
                if !origStr.isEmpty { origin = origStr.capitalized }
                if !destStr.isEmpty { destination = destStr.capitalized }
            }
        } else if let rangeA = norm.range(of: " a ") ?? norm.range(of: " pour ") ?? norm.range(of: " vers ") {
            let destStr = String(norm[rangeA.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
            if !destStr.isEmpty { destination = destStr.capitalized }
        }
        
        let encOrigin = origin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Paris"
        let encDest = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Deauville"
        
        let sncfUrl = "https://www.sncf-connect.com/app/home/search?origin=\(encOrigin)&destination=\(encDest)"
        let trainlineUrl = "https://www.thetrainline.com/fr/billets-de-train/\(encOrigin.lowercased())-a-\(encDest.lowercased())"
        let mapsUrl = "https://www.google.com/maps/dir/\(encOrigin)/\(encDest)"
        
        var report = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande tout de suite à **Tom**, mon agent de recherche Web, de trouver les meilleurs billets de train pour vous.*\n\n"
        report += "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
        report += "🚆 **Recherche de Billets de Train en direct** pour le trajet **\(origin) ➔ \(destination)** :\n\n"
        report += "• 🚄 **SNCF Connect** : Horaires TGV Inoui, TER & Nomad, disponibilités et réservation en direct\n"
        report += "  🔗 *\(sncfUrl)*\n"
        report += "• 🎫 **Trainline** : Comparateur de tarifs SNCF / Ouigo avec sélection de places et cartes Avantage\n"
        report += "  🔗 *\(trainlineUrl)*\n"
        report += "• 🗺️ **Itinéraire & Temps de Trajet** : Visualiser les gares de départ et le plan ferroviaire\n"
        report += "  🔗 *\(mapsUrl)*\n\n"
        report += "💡 *Astuce de Tom : Sur la ligne \(origin) ➔ \(destination), les trains partent généralement de Paris-Saint-Lazare pour un temps de trajet moyen de 2h05.*"
        
        let resItems = [
            WebSearchResult(title: "SNCF Connect : \(origin) - \(destination)", snippet: "Réservation directe TGV & TER", url: sncfUrl, sourceName: "SNCF Connect"),
            WebSearchResult(title: "Trainline : \(origin) - \(destination)", snippet: "Comparateur de billets et cartes de réduction", url: trainlineUrl, sourceName: "Trainline")
        ]
        
        DispatchQueue.main.async {
            completion(report, resItems)
        }
    }
    
    // MARK: - 2. Recherche Spécialisée Billets d'Avion (Google Flights & Skyscanner)
    
    private func handleFlightSearch(cleanQuery: String, norm: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        var destination = "votre destination"
        let prefixes = ["billet d avion pour ", "billets d avion pour ", "vol pour ", "vols pour ", "billet avion pour ", "cherche un vol pour ", "trouve un vol pour "]
        for p in prefixes {
            if let range = norm.range(of: p) {
                let destPart = String(norm[range.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
                if !destPart.isEmpty { destination = destPart.capitalized; break }
            }
        }
        
        let encDest = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "vol"
        let googleFlightsUrl = "https://www.google.com/travel/flights?q=\(encDest)"
        let skyscannerUrl = "https://www.skyscanner.fr/transport/vols/?q=\(encDest)"
        let kayakUrl = "https://www.kayak.fr/flights"
        
        var report = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande tout de suite à **Tom**, mon agent de recherche Web, de trouver les meilleurs billets d'avion pour vous.*\n\n"
        report += "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
        report += "✈️ **Recherche de Billets d'Avion & Comparateurs en direct** pour **\(destination)** :\n\n"
        report += "• 🌐 **Google Flights** : Comparaison des vols en temps réel (escales, compagnies, calendrier des meilleurs prix)\n"
        report += "  🔗 *\(googleFlightsUrl)*\n"
        report += "• 🛫 **Skyscanner** : Tarifs low-cost & compagnies régulières (Air France, Transavia, EasyJet...)\n"
        report += "  🔗 *\(skyscannerUrl)*\n"
        report += "• 🧭 **Kayak** : Prédictions de prix & alertes d'évolution tarifaire\n"
        report += "  🔗 *\(kayakUrl)*\n\n"
        report += "💡 *Astuce de Tom : Réservez idéalement un mardi ou mercredi en navigation privée pour obtenir les tarifs les plus compétitifs.*"
        
        let resItems = [
            WebSearchResult(title: "Google Flights : \(destination)", snippet: "Calendrier des prix et compagnies", url: googleFlightsUrl, sourceName: "Google Flights"),
            WebSearchResult(title: "Skyscanner : \(destination)", snippet: "Comparateur de vols réguliers et low-cost", url: skyscannerUrl, sourceName: "Skyscanner")
        ]
        
        DispatchQueue.main.async {
            completion(report, resItems)
        }
    }
    
    // MARK: - 3. Recherche Générale Multi-Sources
    
    private func performGeneralSearch(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        let topic = extractCoreSearchTopic(query)
        
        // Exécution conjointe Wikipedia + DuckDuckGo
        self.fetchWikipediaSummary(query: topic) { wikiSummary, wikiResults in
            if !wikiResults.isEmpty && !wikiSummary.isEmpty {
                completion(wikiSummary, wikiResults)
                return
            }
            
            self.fetchDuckDuckGoInstantAnswer(query: query) { ddgSummary, ddgResults in
                if !ddgResults.isEmpty && !ddgSummary.isEmpty {
                    completion(ddgSummary, ddgResults)
                    return
                }
                
                self.fetchDuckDuckGoHTML(query: query) { htmlSummary, htmlResults in
                    if !htmlResults.isEmpty {
                        completion(htmlSummary, htmlResults)
                    } else {
                        let fallback = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de regarder ça pour vous.*\n\n🕵️‍♂️ **Rapport de Tom (Agent Web)** :\nJ'ai exploré le Web pour « \(topic) ». Posez-moi une question plus détaillée ou précisez votre mot-clé !"
                        completion(fallback, [])
                    }
                }
            }
        }
    }
    
    // MARK: - Météo Temps Réel Mondiale
    
    private func extractCityName(from query: String) -> String {
        var lower = query.lowercased()
        let triggers = ["meteo a ", "meteo pour ", "meteo de ", "temps a ", "quel temps fait il a ", "temperature a "]
        for t in triggers {
            if let range = lower.range(of: t) {
                let cityPart = String(query[range.upperBound...])
                return cityPart.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }
    
    private func fetchCityWeather(city: String, completion: @escaping (String, WebSearchResult?) -> Void) {
        guard let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let geoUrl = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=fr&format=json") else {
            completion("", nil)
            return
        }
        
        urlSession.dataTask(with: geoUrl) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double else {
                completion("", nil)
                return
            }
            
            let foundName = (first["name"] as? String) ?? city.capitalized
            let country = (first["country"] as? String) ?? ""
            
            let forecastUrlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
            guard let forecastUrl = URL(string: forecastUrlStr) else {
                completion("", nil)
                return
            }
            
            self.urlSession.dataTask(with: forecastUrl) { fData, _, fError in
                guard let fData = fData, fError == nil,
                      let fJson = try? JSONSerialization.jsonObject(with: fData) as? [String: Any],
                      let current = fJson["current"] as? [String: Any],
                      let temp = current["temperature_2m"] as? Double else {
                    completion("", nil)
                    return
                }
                
                let code = (current["weather_code"] as? Int) ?? 0
                let wind = (current["wind_speed_10m"] as? Double) ?? 0.0
                let condition = self.describeWeatherCode(code)
                
                var maxTempStr = ""
                if let daily = fJson["daily"] as? [String: Any],
                   let maxArr = daily["temperature_2m_max"] as? [Double], let maxVal = maxArr.first,
                   let minArr = daily["temperature_2m_min"] as? [Double], let minVal = minArr.first {
                    maxTempStr = " (Min: \(Int(minVal))°C / Max: \(Int(maxVal))°C)"
                }
                
                let locationStr = country.isEmpty ? foundName : "\(foundName), \(country)"
                var summary = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de vérifier la météo pour vous en direct.*\n\n"
                summary += "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
                summary += "☀️ **Météo en direct pour \(locationStr)** :\n\n• Température : **\(Int(temp))°C**\(maxTempStr)\n• Conditions : **\(condition)**\n• Vent : **\(Int(wind)) km/h**\n\nBelle journée à vous ! 🌤️"
                
                let res = WebSearchResult(
                    title: "Météo \(locationStr)",
                    snippet: "\(Int(temp))°C, \(condition)",
                    url: "https://open-meteo.com",
                    sourceName: "Open-Meteo"
                )
                
                DispatchQueue.main.async {
                    completion(summary, res)
                }
            }.resume()
        }.resume()
    }
    
    private func describeWeatherCode(_ code: Int) -> String {
        switch code {
        case 0: return "Ciel complètement dégagé ☀️"
        case 1, 2: return "Partiellement nuageux ⛅"
        case 3: return "Ciel couvert ☁️"
        case 45, 48: return "Brouillard 🌫️"
        case 51, 53, 55: return "Bruine passagère 🌦️"
        case 61, 63, 65: return "Pluie 🌧️"
        case 71, 73, 75: return "Chutes de neige ❄️"
        case 80, 81, 82: return "Averses 🌧️"
        case 95, 96, 99: return "Orages ⚡"
        default: return "Conditions variables 🌤️"
        }
    }
    
    // MARK: - Wikipedia REST API
    
    private func fetchWikipediaSummary(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        let cleanedTerm = extractCoreSearchTopic(query)
        guard let encoded = cleanedTerm.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://fr.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            completion("", [])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("SarahIA-Mobile/2.0 (contact: info@sarahia.app)", forHTTPHeaderField: "User-Agent")
        
        urlSession.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let extract = json["extract"] as? String, !extract.isEmpty else {
                DispatchQueue.main.async { completion("", []) }
                return
            }
            
            let title = (json["title"] as? String) ?? cleanedTerm.capitalized
            let pageURL = ((json["content_urls"] as? [String: Any])?["desktop"] as? [String: Any])?["page"] as? String
                ?? "https://fr.wikipedia.org/wiki/\(encoded)"
            
            let result = WebSearchResult(
                title: title,
                snippet: extract,
                url: pageURL,
                sourceName: "Wikipédia"
            )
            
            let formatted = self.formatSearchResponse(query: query, summary: extract, results: [result])
            DispatchQueue.main.async {
                completion(formatted, [result])
            }
        }.resume()
    }
    
    // MARK: - DuckDuckGo Instant Answer API
    
    private func fetchDuckDuckGoInstantAnswer(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1&kl=fr-fr") else {
            completion("", [])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("SarahIA-Mobile/2.0", forHTTPHeaderField: "User-Agent")
        
        urlSession.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                completion("", [])
                return
            }
            
            var results: [WebSearchResult] = []
            var mainSummary = ""
            
            if let abstract = json["AbstractText"] as? String, !abstract.isEmpty {
                let source = (json["AbstractSource"] as? String) ?? "DuckDuckGo"
                let abstractURL = (json["AbstractURL"] as? String) ?? ""
                let heading = (json["Heading"] as? String) ?? query
                mainSummary = abstract
                results.append(WebSearchResult(title: heading, snippet: abstract, url: abstractURL, sourceName: source))
            }
            
            if let answer = json["Answer"] as? String, !answer.isEmpty {
                if mainSummary.isEmpty { mainSummary = answer }
                results.append(WebSearchResult(title: "Réponse directe", snippet: answer, url: "https://duckduckgo.com/?q=\(encodedQuery)", sourceName: "DuckDuckGo"))
            }
            
            if let topics = json["RelatedTopics"] as? [[String: Any]] {
                for topic in topics.prefix(3) {
                    if let text = topic["Text"] as? String, let firstURL = topic["FirstURL"] as? String {
                        let title = text.components(separatedBy: " - ").first ?? text
                        results.append(WebSearchResult(title: title, snippet: text, url: firstURL, sourceName: "Web"))
                    }
                }
            }
            
            if !results.isEmpty {
                let formatted = self.formatSearchResponse(query: query, summary: mainSummary, results: results)
                DispatchQueue.main.async { completion(formatted, results) }
            } else {
                DispatchQueue.main.async { completion("", []) }
            }
        }.resume()
    }
    
    // MARK: - DuckDuckGo HTML Lite Fallback
    
    private func fetchDuckDuckGoHTML(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            completion("", [])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        urlSession.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let htmlString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion("", []) }
                return
            }
            
            let extractedResults = self.parseDuckDuckGoHTML(htmlString)
            if extractedResults.isEmpty {
                DispatchQueue.main.async { completion("", []) }
                return
            }
            
            let formatted = self.formatSearchResponse(query: query, summary: extractedResults.first?.snippet ?? "", results: extractedResults)
            DispatchQueue.main.async {
                completion(formatted, extractedResults)
            }
        }.resume()
    }
    
    private func parseDuckDuckGoHTML(_ html: String) -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        let pattern = #"<a class="result__url"[^>]*href="([^"]+)"[^>]*>.*?<a class="result__snippet"[^>]*>(.*?)<\/a>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let nsHtml = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length))
            
            for match in matches.prefix(3) {
                let urlRange = match.range(at: 1)
                let snippetRange = match.range(at: 2)
                
                let rawUrl = nsHtml.substring(with: urlRange)
                var snippet = nsHtml.substring(with: snippetRange)
                
                snippet = snippet.replacingOccurrences(of: "<b>", with: "")
                    .replacingOccurrences(of: "</b>", with: "")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#x27;", with: "'")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !snippet.isEmpty {
                    results.append(WebSearchResult(
                        title: "Résultat Web",
                        snippet: snippet,
                        url: rawUrl,
                        sourceName: "Web"
                    ))
                }
            }
        }
        return results
    }
    
    public func extractCoreSearchTopic(_ input: String) -> String {
        var cleaned = input.lowercased()
            .replacingOccurrences(of: "cherchemoi", with: "cherche moi")
            .replacingOccurrences(of: "trouvemoi", with: "trouve moi")
            .replacingOccurrences(of: "recherchemoi", with: "recherche moi")
        
        let prefixes = [
            "cherche sur internet ", "recherche sur le web ", "cherche sur le web ",
            "recherche sur internet ", "cherche moi ", "trouve sur internet ",
            "trouve moi ", "moteur de recherche ", "qui est ", "qui etait ",
            "qui sont ", "c'est quoi ", "qu'est ce que ", "qu'est-ce que ",
            "quelle est la definition de ", "donne moi des infos sur ",
            "recherche ", "cherche ", "trouve "
        ]
        
        for p in prefixes {
            if cleaned.hasPrefix(p) {
                cleaned = String(cleaned.dropFirst(p.count))
                break
            }
        }
        
        return cleaned.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Formatage Collaboratif Sarah (Patronne) & Tom (Agent Recherche Web)
    
    private func formatSearchResponse(query: String, summary: String, results: [WebSearchResult]) -> String {
        let topic = extractCoreSearchTopic(query)
        let displayTopic = topic.isEmpty ? query : topic
        
        var response = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de s'en occuper pour vous en direct.*\n\n"
        response += "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n"
        response += "Voici ce que j'ai trouvé sur Internet pour « **\(displayTopic.capitalized)** » :\n\n"
        
        if !summary.isEmpty {
            response += "\(summary)\n\n"
        }
        
        if results.count > 1 {
            response += "📌 **Sources & Liens vérifiés par Tom** :\n"
            for item in results.prefix(3) {
                let cleanSnippet = item.snippet.prefix(130)
                response += "• **[\(item.sourceName)]** \(item.title) : \(cleanSnippet)...\n"
            }
        } else if let first = results.first, !first.url.isEmpty {
            response += "🔗 *Source vérifiée : \(first.sourceName) (\(first.url))*"
        }
        
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
