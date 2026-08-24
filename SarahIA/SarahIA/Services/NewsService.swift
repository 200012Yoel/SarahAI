import Foundation

/// Service d'Agrégation des Informations en Direct (Franceinfo & i24NEWS) :
/// - 100% Gratuit, sans clé API, interroge les flux RSS / XML temps réel
/// - Extrait les titres d'actualité majeurs et leurs résumés
/// - Formate une synthèse claire et fluide prête à être lue par Sarah
public final class NewsService: NSObject, XMLParserDelegate {
    
    public static let shared = NewsService()
    
    public struct NewsArticle: Identifiable {
        public let id = UUID()
        public let title: String
        public let summary: String
        public let source: String
        public let pubDate: String
    }
    
    public enum NewsSource: String, CaseIterable {
        case franceinfo = "Franceinfo"
        case i24news = "i24NEWS"
        
        public var feedURL: URL? {
            switch self {
            case .franceinfo:
                return URL(string: "https://www.francetvinfo.fr/titres.rss")
            case .i24news:
                return URL(string: "https://www.i24news.tv/fr/rss")
            }
        }
    }
    
    public private(set) var latestArticles: [NewsArticle] = []
    
    private override init() {
        super.init()
    }
    
    // MARK: - Récupération des Actualités
    
    public func fetchLatestNews(source: NewsSource = .franceinfo, limit: Int = 4, completion: @escaping ([NewsArticle]) -> Void) {
        guard let url = source.feedURL else {
            completion([])
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let articles = self.parseRSS(data: data, source: source.rawValue, limit: limit)
            DispatchQueue.main.async {
                self.latestArticles = articles
                completion(articles)
            }
        }
        task.resume()
    }
    
    /// Génère un résumé parlé complet des actualités pour Sarah
    public func getSpokenNewsSummary(preferredSource: NewsSource? = nil, completion: @escaping (String) -> Void) {
        let src = preferredSource ?? .franceinfo
        fetchLatestNews(source: src, limit: 4) { [weak self] articles in
            guard let self = self, !articles.isEmpty else {
                // Fallback sur l'autre source si la première échoue
                let fallback = (src == .franceinfo) ? NewsSource.i24news : NewsSource.franceinfo
                self?.fetchLatestNews(source: fallback, limit: 4) { fallbackArticles in
                    if fallbackArticles.isEmpty {
                        completion("Je n'ai pas pu récupérer les dernières informations en direct pour l'instant. Vérifiez votre connexion Internet.")
                    } else {
                        completion(self?.formatArticlesForSpeech(fallbackArticles, sourceName: fallback.rawValue) ?? "")
                    }
                }
                return
            }
            
            completion(self.formatArticlesForSpeech(articles, sourceName: src.rawValue))
        }
    }
    
    private func formatArticlesForSpeech(_ articles: [NewsArticle], sourceName: String) -> String {
        var summary = "Voici les principaux titres d'actualité en direct sur \(sourceName) :\n"
        for (index, article) in articles.prefix(3).enumerated() {
            summary += "\n\(index + 1). \(article.title)."
            if !article.summary.isEmpty && article.summary.count < 150 {
                summary += " \(article.summary)"
            }
        }
        return summary
    }
    
    // MARK: - Analyse XML / RSS
    
    private func parseRSS(data: Data, source: String, limit: Int) -> [NewsArticle] {
        guard let xmlString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return []
        }
        
        var articles: [NewsArticle] = []
        let itemPattern = "<item>(.*?)</item>"
        
        if let regex = try? NSRegularExpression(pattern: itemPattern, options: [.dotMatchesLineSeparators]) {
            let nsString = xmlString as NSString
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.prefix(limit) {
                let itemContent = nsString.substring(with: match.range)
                let title = extractTag("title", from: itemContent)
                let description = extractTag("description", from: itemContent)
                let pubDate = extractTag("pubDate", from: itemContent)
                
                let cleanedTitle = cleanHTML(title)
                let cleanedDesc = cleanHTML(description)
                
                if !cleanedTitle.isEmpty {
                    articles.append(NewsArticle(
                        title: cleanedTitle,
                        summary: cleanedDesc,
                        source: source,
                        pubDate: pubDate
                    ))
                }
            }
        }
        
        return articles
    }
    
    private func extractTag(_ tag: String, from xml: String) -> String {
        let pattern = "<\(tag)>(.*?)</\(tag)>|<\\(tag)[^>]*><!\\[CDATA\\[(.*?)\\]\\]></\(tag)>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let nsString = xml as NSString
            if let match = regex.firstMatch(in: xml, options: [], range: NSRange(location: 0, length: nsString.length)) {
                for i in 1..<match.numberOfRanges {
                    let r = match.range(at: i)
                    if r.location != NSNotFound {
                        return nsString.substring(with: r)
                    }
                }
            }
        }
        return ""
    }
    
    private func cleanHTML(_ string: String) -> String {
        var str = string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        str = str.replacingOccurrences(of: "&amp;", with: "&")
        str = str.replacingOccurrences(of: "&quot;", with: "\"")
        str = str.replacingOccurrences(of: "&#039;", with: "'")
        str = str.replacingOccurrences(of: "&apos;", with: "'")
        str = str.replacingOccurrences(of: "&lt;", with: "<")
        str = str.replacingOccurrences(of: "&gt;", with: ">")
        str = str.replacingOccurrences(of: "&nbsp;", with: " ")
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
