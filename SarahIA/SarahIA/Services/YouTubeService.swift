import Foundation
import UIKit

/// Modèle représentant une vidéo YouTube
public struct YouTubeVideoItem: Codable {
    public let id: String
    public let videoId: String
    public let title: String
    public let channelTitle: String
    public let thumbnailURL: String
    public let duration: String
    
    public var watchURL: URL? {
        return URL(string: "https://www.youtube.com/watch?v=\(videoId)")
    }
    
    public var embedURL: URL? {
        return URL(string: "https://www.youtube-nocookie.com/embed/\(videoId)?autoplay=1&playsinline=1&rel=0&modestbranding=1")
    }
    
    public init(id: String = UUID().uuidString, videoId: String, title: String, channelTitle: String, thumbnailURL: String, duration: String = "") {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailURL = thumbnailURL
        self.duration = duration
    }
}

/// Service de Recherche et Lecture YouTube 100% Gratuit & Compatible iOS 12 à 18 :
/// - Permet à Sarah de chercher et jouer des vidéos directement dans l'application
/// - Idéal pour l'iPhone 5S et appareils anciens où l'app YouTube officielle n'est plus supportée
/// - Moteur de recherche vidéo multi-sources résilient et ultra-léger
public final class YouTubeService: NSObject {
    
    public static let shared = YouTubeService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Recherche Vidéo YouTube
    
    /// Recherche des vidéos YouTube par mots-clés
    public func searchVideos(query: String, maxResults: Int = 10, completion: @escaping ([YouTubeVideoItem]) -> Void) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            completion([])
            return
        }
        
        guard NetworkMonitor.shared.isOnline else {
            completion([])
            return
        }
        
        let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery
        
        // 1. Recherche via Invidious / Piped Public API (Haute Fiabilité & Confidentialité)
        let endpoints = [
            "https://inv.tux.pizza/api/v1/search?q=\(encoded)&type=video",
            "https://invidious.nerdvpn.de/api/v1/search?q=\(encoded)&type=video",
            "https://pipedapi.kavin.rocks/search?q=\(encoded)&filter=videos"
        ]
        
        tryEndpointsSequentially(endpoints: endpoints, query: cleanQuery, maxResults: maxResults, completion: completion)
    }
    
    private func tryEndpointsSequentially(endpoints: [String], query: String, maxResults: Int, completion: @escaping ([YouTubeVideoItem]) -> Void) {
        guard let first = endpoints.first, let url = URL(string: first) else {
            // Fallback ultime : Extraction via DuckDuckGo Video Search HTML / Direct Video ID
            fallbackDuckDuckGoSearch(query: query, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_7 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data, error == nil,
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               !jsonArray.isEmpty {
                
                var results: [YouTubeVideoItem] = []
                for item in jsonArray.prefix(maxResults) {
                    let videoId = item["videoId"] as? String ?? ""
                    let title = item["title"] as? String ?? ""
                    let author = item["author"] as? String ?? item["uploaderName"] as? String ?? "YouTube"
                    let thumb = (item["videoThumbnails"] as? [[String: Any]])?.first?["url"] as? String ?? "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
                    let length = item["lengthSeconds"] as? Int ?? 0
                    let durationStr = length > 0 ? "\(length / 60):\(String(format: "%02d", length % 60))" : ""
                    
                    if !videoId.isEmpty && !title.isEmpty {
                        results.append(YouTubeVideoItem(
                            videoId: videoId,
                            title: title,
                            channelTitle: author,
                            thumbnailURL: thumb,
                            duration: durationStr
                        ))
                    }
                }
                
                if !results.isEmpty {
                    DispatchQueue.main.async { completion(results) }
                    return
                }
            }
            
            // Passer au endpoint suivant en cas d'échec
            let remaining = Array(endpoints.dropFirst())
            self?.tryEndpointsSequentially(endpoints: remaining, query: query, maxResults: maxResults, completion: completion)
        }
        task.resume()
    }
    
    private func fallbackDuckDuckGoSearch(query: String, completion: @escaping ([YouTubeVideoItem]) -> Void) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=site:youtube.com+watch+\(encoded)") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_7 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            var items: [YouTubeVideoItem] = []
            if let data = data, let html = String(data: data, encoding: .utf8) {
                // Regex extraction de liens YouTube v=ID
                let pattern = "v=([a-zA-Z0-9_-]{11})"
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let ns = html as NSString
                    let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                    var seen = Set<String>()
                    
                    for match in matches {
                        if match.numberOfRanges > 1 {
                            let videoId = ns.substring(with: match.range(at: 1))
                            if !seen.contains(videoId) {
                                seen.insert(videoId)
                                items.append(YouTubeVideoItem(
                                    videoId: videoId,
                                    title: "\(query) (Vidéo)",
                                    channelTitle: "YouTube",
                                    thumbnailURL: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
                                ))
                                if items.count >= 6 { break }
                            }
                        }
                    }
                }
            }
            
            DispatchQueue.main.async { completion(items) }
        }
        task.resume()
    }
    
    // MARK: - Génération de Réponse Spoken
    
    /// Génère un résumé parlé des résultats pour Sarah
    public func getSpokenSummary(for query: String, completion: @escaping (String, [YouTubeVideoItem]) -> Void) {
        searchVideos(query: query) { videos in
            guard let first = videos.first else {
                completion("Je n'ai pas trouvé de vidéo YouTube correspondant à « \(query) ».", [])
                return
            }
            
            let summary = "📺 J'ai trouvé la vidéo « \(first.title) » par \(first.channelTitle). Vous pouvez la visionner dès maintenant !"
            completion(summary, videos)
        }
    }
}
