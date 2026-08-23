import Foundation
import AVFoundation
import UIKit

/// Service de Streaming Radio & Lanceur Multimédia (Radios en direct, Apple Podcasts, Musique) :
/// - Compatible 100% avec iOS 12.0 jusqu'à iOS 18.0+ (iPhone 5S, SE, 6, 7, 8, X, 11, 12, 13, 14, 15, 16)
/// - Flux audio en direct (NRJ, France Inter, Skyrock, RTL, Nostalgie, FIP, Jazz Radio, etc.)
/// - Intégration Apple Podcasts (podcasts://) & Apple Music / Spotify
public final class MediaStreamingService {
    
    public static let shared = MediaStreamingService()
    
    private var player: AVPlayer?
    public private(set) var isPlayingRadio: Bool = false
    public private(set) var currentStationName: String? = nil
    
    // Dictionnaire des flux officiels Radio en direct (MP3 / AAC Streams)
    public let radioStations: [String: (name: String, streamUrl: String, icon: String)] = [
        "nrj": (name: "NRJ", streamUrl: "https://scdn.nrjaudio.fm/audio1/fr/30001/mp3_128.mp3", icon: "📻"),
        "france inter": (name: "France Inter", streamUrl: "https://icecast.radiofrance.fr/franceinter-midfi.mp3", icon: "🎙️"),
        "franceinfo": (name: "France Info", streamUrl: "https://icecast.radiofrance.fr/franceinfo-midfi.mp3", icon: "📰"),
        "france info": (name: "France Info", streamUrl: "https://icecast.radiofrance.fr/franceinfo-midfi.mp3", icon: "📰"),
        "skyrock": (name: "Skyrock", streamUrl: "https://icecast.skyrock.net/s/natio_mp3_128k", icon: "🔥"),
        "rtl": (name: "RTL", streamUrl: "https://streamer-02.rtl.fr/rtl-1-44-128", icon: "📻"),
        "fun radio": (name: "Fun Radio", streamUrl: "https://streamer-02.rtl.fr/fun-1-44-128", icon: "🎉"),
        "nostalgie": (name: "Nostalgie", streamUrl: "https://scdn.nrjaudio.fm/audio1/fr/30601/mp3_128.mp3", icon: "🎶"),
        "cherie fm": (name: "Chérie FM", streamUrl: "https://scdn.nrjaudio.fm/audio1/fr/30201/mp3_128.mp3", icon: "💖"),
        "fip": (name: "FIP", streamUrl: "https://icecast.radiofrance.fr/fip-midfi.mp3", icon: "🎷"),
        "rmc": (name: "RMC", streamUrl: "https://audio.bfmtv.com/rmcradio_128.mp3", icon: "⚽"),
        "europe 1": (name: "Europe 1", streamUrl: "https://stream.europe1.fr/europe1.mp3", icon: "📻"),
        "radio fg": (name: "Radio FG", streamUrl: "https://stream.rcs.revma.com/fg_mp3", icon: "🎧"),
        "fg": (name: "Radio FG", streamUrl: "https://stream.rcs.revma.com/fg_mp3", icon: "🎧"),
        "jazz radio": (name: "Jazz Radio", streamUrl: "https://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3", icon: "🎺"),
        "jazz": (name: "Jazz Radio", streamUrl: "https://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3", icon: "🎺"),
        "classique": (name: "Radio Classique", streamUrl: "https://radioclassique.ice.infomaniak.ch/radioclassique-high.mp3", icon: "🎻"),
        "radio classique": (name: "Radio Classique", streamUrl: "https://radioclassique.ice.infomaniak.ch/radioclassique-high.mp3", icon: "🎻")
    ]
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("MediaStreamingService audio session error: \(error)")
        }
    }
    
    // MARK: - 1. Lecture de la Radio en Direct
    
    /// Lance la radio demandée par nom ou par défaut (NRJ / France Inter)
    public func playRadio(stationName: String? = nil) -> String {
        configureAudioSession()
        
        let targetKey: String
        let stationInfo: (name: String, streamUrl: String, icon: String)
        
        if let requested = stationName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !requested.isEmpty {
            if let matched = radioStations.first(where: { requested.contains($0.key) || $0.key.contains(requested) }) {
                targetKey = matched.key
                stationInfo = matched.value
            } else {
                targetKey = "nrj"
                stationInfo = radioStations["nrj"]!
            }
        } else {
            targetKey = "france inter"
            stationInfo = radioStations["france inter"]!
        }
        
        guard let url = URL(string: stationInfo.streamUrl) else {
            return "Impossible de charger le flux audio de \(stationInfo.name)."
        }
        
        stopRadio()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        isPlayingRadio = true
        currentStationName = stationInfo.name
        
        return "Je lance la radio **\(stationInfo.name)** en direct pour vous ! \(stationInfo.icon)📻\nBonne écoute !"
    }
    
    /// Arrête la lecture radio
    public func stopRadio() -> String {
        if isPlayingRadio {
            player?.pause()
            player = nil
            isPlayingRadio = false
            let name = currentStationName ?? "la radio"
            currentStationName = nil
            return "J'ai arrêté \(name). ⏹️"
        }
        return "Aucune radio n'était en cours de lecture."
    }
    
    // MARK: - 2. Apple Podcasts Launcher & Recherche
    
    /// Ouvre l'application Apple Podcasts ou effectue une recherche ciblée
    public func launchApplePodcasts(query: String? = nil) -> String {
        var urlToOpen: URL?
        let cleanQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !cleanQuery.isEmpty {
            let enc = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let customUrl = URL(string: "podcasts://search?term=\(enc)") {
                urlToOpen = customUrl
            } else {
                urlToOpen = URL(string: "https://podcasts.apple.com/fr/search?term=\(enc)")
            }
        } else {
            urlToOpen = URL(string: "podcasts://") ?? URL(string: "https://podcasts.apple.com/fr/browse")
        }
        
        DispatchQueue.main.async {
            guard let finalUrl = urlToOpen else { return }
            if UIApplication.shared.canOpenURL(finalUrl) {
                UIApplication.shared.open(finalUrl, options: [:], completionHandler: nil)
            } else if let webUrl = URL(string: "https://podcasts.apple.com/fr/browse") {
                UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
            }
        }
        
        if !cleanQuery.isEmpty {
            return "J'ouvre **Apple Podcasts** pour vous avec la recherche « **\(cleanQuery)** » ! 🎙️"
        } else {
            return "J'ouvre l'application **Apple Podcasts** ! 🎙️ Découvrez les meilleurs épisodes du moment."
        }
    }
    
    // MARK: - 3. Musique (Apple Music & Spotify)
    
    /// Lance la musique via Apple Music ou Spotify
    public func launchMusic(query: String? = nil) -> String {
        let cleanQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var urlToOpen: URL?
        
        if !cleanQuery.isEmpty {
            let enc = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let spotifyUrl = URL(string: "spotify:search:\(enc)"), UIApplication.shared.canOpenURL(spotifyUrl) {
                urlToOpen = spotifyUrl
            } else if let musicUrl = URL(string: "music://search?term=\(enc)") {
                urlToOpen = musicUrl
            } else {
                urlToOpen = URL(string: "https://music.apple.com/fr/search?term=\(enc)")
            }
        } else {
            if let musicUrl = URL(string: "music://"), UIApplication.shared.canOpenURL(musicUrl) {
                urlToOpen = musicUrl
            } else if let spotifyUrl = URL(string: "spotify://"), UIApplication.shared.canOpenURL(spotifyUrl) {
                urlToOpen = spotifyUrl
            } else {
                urlToOpen = URL(string: "https://music.apple.com/fr/browse")
            }
        }
        
        DispatchQueue.main.async {
            guard let finalUrl = urlToOpen else { return }
            if UIApplication.shared.canOpenURL(finalUrl) {
                UIApplication.shared.open(finalUrl, options: [:], completionHandler: nil)
            } else if let webUrl = URL(string: "https://music.apple.com/fr/browse") {
                UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
            }
        }
        
        if !cleanQuery.isEmpty {
            return "Je lance la musique « **\(cleanQuery)** » sur votre lecteur musical ! 🎵🎧"
        } else {
            return "J'ouvre votre lecteur de musique ! 🎵✨ Montez le son !"
        }
    }
}
