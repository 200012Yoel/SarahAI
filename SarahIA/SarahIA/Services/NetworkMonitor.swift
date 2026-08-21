import Foundation
import SystemConfiguration
#if canImport(Network)
import Network
#endif

#if canImport(Combine)
import Combine
#endif

/// Moniteur Réseau Universel et Résilient (iOS 12.0+ à iOS 18.0+) :
/// - Détecte instantanément les transitions En-Ligne ⇄ Hors-Ligne
/// - Utilise NWPathMonitor sur iOS 13+ et SCNetworkReachability sur iOS 12
/// - Permet de basculer du Cloud OpenAI vers le moteur local hors-ligne en 0ms sans latence
public final class NetworkMonitor: NSObject {
    
    public static let shared = NetworkMonitor()
    
    #if canImport(Combine)
    @Published public private(set) var isConnected: Bool = true
    #else
    public private(set) var isConnected: Bool = true
    #endif
    
    private let queue = DispatchQueue(label: "com.sarahai.network.monitor", qos: .utility)
    
    #if canImport(Network)
    private var pathMonitor: Any?
    #endif
    
    private var reachabilityRef: SCNetworkReachability?
    
    public override init() {
        super.init()
        self.isConnected = checkInitialReachability()
        startMonitoring()
    }
    
    private func checkInitialReachability() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return true
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return true
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return isReachable && !needsConnection
    }
    
    private func startMonitoring() {
        if #available(iOS 13.0, *) {
            #if canImport(Network)
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                let reachable = (path.status == .satisfied)
                DispatchQueue.main.async {
                    self?.isConnected = reachable
                }
            }
            monitor.start(queue: queue)
            self.pathMonitor = monitor
            return
            #endif
        }
        
        // Fallback natif SCNetworkReachability pour iOS 12.0 (iPhone 5S, 6)
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, $0)
            }
        }) else { return }
        
        self.reachabilityRef = reachability
        var context = SCNetworkReachabilityContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        
        if SCNetworkReachabilitySetCallback(reachability, { (_, flags, info) in
            guard let info = info else { return }
            let instance = Unmanaged<NetworkMonitor>.fromOpaque(info).takeUnretainedValue()
            let isReachable = flags.contains(.reachable)
            let needsConnection = flags.contains(.connectionRequired)
            let reachable = isReachable && !needsConnection
            
            DispatchQueue.main.async {
                instance.isConnected = reachable
            }
        }, &context) {
            SCNetworkReachabilitySetDispatchQueue(reachability, queue)
        }
    }
    
    public var isOnline: Bool {
        return isConnected
    }
    
    deinit {
        if #available(iOS 13.0, *) {
            #if canImport(Network)
            if let monitor = pathMonitor as? NWPathMonitor {
                monitor.cancel()
            }
            #endif
        }
        if let reachability = reachabilityRef {
            SCNetworkReachabilitySetCallback(reachability, nil, nil)
            SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        }
    }
}
