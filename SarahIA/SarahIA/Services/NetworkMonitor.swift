import Foundation
import Network

/// Moniteur Réseau Temps Réel pour iOS :
/// - Détecte instantanément les transitions En-Ligne ⇄ Hors-Ligne
/// - Permet de basculer du cloud OpenAI vers les modèles locaux hors-ligne en 0ms
@available(iOS 13.0, *)
public final class NetworkMonitor: ObservableObject {
    
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SarahAI.NetworkMonitor")
    
    @Published public private(set) var isConnected: Bool = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
