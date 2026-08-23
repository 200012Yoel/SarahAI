import Foundation
import UIKit
import CoreImage
#if canImport(Darwin)
import Darwin
#endif

/// Service de Serveur Local & Synchronisation P2P par QR Code (100% Hors-Ligne & Wi-Fi Local) :
/// - Démarre un serveur HTTP local ultra-léger sur socket natif POSIX / CFSocket
/// - Détecte l'adresse IP locale Wi-Fi (en0)
/// - Génère un QR Code HD sécurisé prêt à scanner
/// - Transfère et fusionne l'intégralité des discussions, messages et souvenirs mémorisés (Brain Vault)
/// - Compatible 100% avec tous les iPhone (iPhone 5S, 6, 7, 8, X, 11, 12, 13, 14, 15, 16 sur iOS 12 à 18)
public final class LocalSyncServerService: NSObject {
    
    public static let shared = LocalSyncServerService()
    
    // MARK: - Propriétés Serveur
    public private(set) var isServerRunning: Bool = false
    public private(set) var serverPort: UInt16 = 8765
    public private(set) var serverToken: String = UUID().uuidString.prefix(8).lowercased()
    
    private var listeningSocket: CFSocket?
    private let serverQueue = DispatchQueue(label: "com.sarahia.localsync.server", qos: .userInitiated)
    
    public static let didCompleteSyncNotification = NSNotification.Name("SarahSyncDidCompleteNotification")
    
    private override init() {
        super.init()
    }
    
    // MARK: - 1. Démarrage & Arrêt du Serveur Local
    
    /// Démarre le serveur local de synchronisation et renvoie l'URL et l'image du QR Code
    public func startServer(completion: @escaping (Bool, String?, UIImage?) -> Void) {
        if isServerRunning {
            let qrString = getSyncURLString()
            let qrImage = generateQRCodeImage(from: qrString)
            completion(true, qrString, qrImage)
            return
        }
        
        serverToken = UUID().uuidString.prefix(8).lowercased()
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
            let success = self.setupSocketServer()
            DispatchQueue.main.async {
                if success {
                    self.isServerRunning = true
                    let qrString = self.getSyncURLString()
                    let qrImage = self.generateQRCodeImage(from: qrString)
                    completion(true, qrString, qrImage)
                } else {
                    self.isServerRunning = false
                    // Fallback vers payload QR direct encodé si socket indisponible
                    let fallbackString = self.getDirectPayloadQRString()
                    let fallbackImage = self.generateQRCodeImage(from: fallbackString)
                    completion(true, fallbackString, fallbackImage)
                }
            }
        }
    }
    
    /// Arrête le serveur local
    public func stopServer() {
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            if let socket = self.listeningSocket {
                CFSocketInvalidate(socket)
                self.listeningSocket = nil
            }
            DispatchQueue.main.async {
                self.isServerRunning = false
            }
        }
    }
    
    // MARK: - 2. Configuration Socket HTTP Local (POSIX / CFSocket)
    
    private func setupSocketServer() -> Bool {
        var context = CFSocketContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: { info in
                guard let info = info else { return }
                Unmanaged<LocalSyncServerService>.fromOpaque(info).release()
            },
            copyDescription: nil
        )
        
        guard let socket = CFSocketCreate(
            kCFAllocatorDefault,
            PF_INET,
            SOCK_STREAM,
            IPPROTO_TCP,
            CFSocketCallBackType.acceptCallBack.rawValue,
            { (socket, callbackType, address, data, info) in
                guard let info = info, callbackType == .acceptCallBack, let data = data else { return }
                let service = Unmanaged<LocalSyncServerService>.fromOpaque(info).takeUnretainedValue()
                let nativeHandle = data.load(as: CFSocketNativeHandle.self)
                service.handleIncomingConnection(nativeHandle)
            },
            &context
        ) else {
            return false
        }
        
        var reuse: Int32 = 1
        setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = serverPort.bigEndian
        address.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let addressData = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_in>.size) {
                Data(bytes: $0, count: MemoryLayout<sockaddr_in>.size)
            }
        }
        
        guard CFSocketSetAddress(socket, addressData as CFData) == .success else {
            CFSocketInvalidate(socket)
            return false
        }
        
        let runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        self.listeningSocket = socket
        return true
    }
    
    private func handleIncomingConnection(_ handle: CFSocketNativeHandle) {
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
            var buffer = [UInt8](repeating: 0, count: 2048)
            let bytesRead = recv(handle, &buffer, buffer.count, 0)
            guard bytesRead > 0, let requestString = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) else {
                close(handle)
                return
            }
            
            // Vérification de la requête et du token
            if requestString.contains("/sync") && requestString.contains(self.serverToken) {
                let state = StorageService.shared.loadState()
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                
                if let jsonData = try? encoder.encode(state) {
                    let headers = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(jsonData.count)\r\nConnection: close\r\n\r\n"
                    if let headerData = headers.data(using: .utf8) {
                        headerData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                            if let base = ptr.baseAddress {
                                _ = send(handle, base, headerData.count, 0)
                            }
                        }
                        jsonData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                            if let base = ptr.baseAddress {
                                _ = send(handle, base, jsonData.count, 0)
                            }
                        }
                    }
                }
            } else {
                let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                if let data = notFound.data(using: .utf8) {
                    data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                        if let base = ptr.baseAddress {
                            _ = send(handle, base, data.count, 0)
                        }
                    }
                }
            }
            close(handle)
        }
    }
    
    // MARK: - 3. Génération d'URL & QR Code
    
    /// Construit l'URL personnalisée de synchronisation
    public func getSyncURLString() -> String {
        let ip = getLocalIPAddress() ?? "127.0.0.1"
        return "sarahsync://\(ip):\(serverPort)/sync?token=\(serverToken)"
    }
    
    /// Génère un paquet compact de données directes au format sarahpayload://
    public func getDirectPayloadQRString() -> String {
        let state = StorageService.shared.loadState()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) {
            let base64 = data.base64EncodedString()
            return "sarahpayload://\(base64)"
        }
        return getSyncURLString()
    }
    
    /// Génère une image UIImage nette de QR Code à partir d'une chaîne
    public func generateQRCodeImage(from string: String, size: CGFloat = 260) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return nil }
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Détecte l'adresse IP locale Wi-Fi (en0)
    public func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" || name == "bridge0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    if name == "en0" { break }
                }
            }
        }
        return address
    }
    
    // MARK: - 4. Client Récepteur (Synchronisation & Fusion des Données)
    
    /// Effectue la synchronisation à partir d'un code QR scanné (sarahsync:// ou sarahpayload://)
    public func performSync(with qrString: String, completion: @escaping (Bool, String) -> Void) {
        if qrString.hasPrefix("sarahpayload://") {
            // Décodage direct hors-ligne
            let base64 = String(qrString.dropFirst("sarahpayload://".count))
            guard let data = Data(base64Encoded: base64) else {
                completion(false, "Format de synchronisation direct invalide.")
                return
            }
            self.mergeReceivedData(data, completion: completion)
            return
        }
        
        // Extraction de l'URL HTTP
        var httpURLString = qrString
        if qrString.hasPrefix("sarahsync://") {
            httpURLString = "http://" + qrString.dropFirst("sarahsync://".count)
        } else if qrString.hasPrefix("sarah://sync?") {
            // Format paramétrique
            httpURLString = qrString.replacingOccurrences(of: "sarah://", with: "http://")
        }
        
        guard let url = URL(string: httpURLString) else {
            completion(false, "URL de synchronisation invalide : \(qrString)")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 8.0)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Impossible de joindre le téléphone émetteur : \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let receivedData = data else {
                DispatchQueue.main.async {
                    completion(false, "Réponse incorrecte du serveur local Sarah.")
                }
                return
            }
            
            self.mergeReceivedData(receivedData, completion: completion)
        }
        task.resume()
    }
    
    /// Fusionne atomiquement les données reçues dans l'application locale
    private func mergeReceivedData(_ data: Data, completion: @escaping (Bool, String) -> Void) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let remoteState = try? decoder.decode(AppPersistedState.self, from: data) else {
            DispatchQueue.main.async {
                completion(false, "Format de données JSON reçu corrompu.")
            }
            return
        }
        
        var localState = StorageService.shared.loadState()
        
        // 1. Fusion des discussions (sans doublons d'UUID)
        var existingConvIds = Set(localState.conversations.map { $0.id })
        var newConvCount = 0
        var newMsgCount = 0
        
        for remoteConv in remoteState.conversations {
            if !existingConvIds.contains(remoteConv.id) {
                localState.conversations.append(remoteConv)
                existingConvIds.insert(remoteConv.id)
                newConvCount += 1
                newMsgCount += remoteConv.messages.count
            } else if let index = localState.conversations.firstIndex(where: { $0.id == remoteConv.id }) {
                // Fusion des messages au sein d'une même discussion
                var existingMsgIds = Set(localState.conversations[index].messages.map { $0.id })
                for msg in remoteConv.messages where !existingMsgIds.contains(msg.id) {
                    localState.conversations[index].messages.append(msg)
                    existingMsgIds.insert(msg.id)
                    newMsgCount += 1
                }
                localState.conversations[index].messages.sort { $0.timestamp < $1.timestamp }
            }
        }
        
        // 2. Fusion des souvenirs mémorisés (Brain Vault)
        var newMemoriesCount = 0
        for (trigger, response) in remoteState.learnedMemories {
            let key = trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if localState.learnedMemories[key] == nil {
                localState.learnedMemories[key] = response
                newMemoriesCount += 1
            }
        }
        
        localState.lastActiveTimestamp = Date()
        StorageService.shared.saveState(localState)
        
        // Synchronisation des widgets
        SarahWidgetBridge.shared.syncStats(
            conversationsCount: localState.conversations.count,
            messagesCount: localState.conversations.reduce(0) { $0 + $1.messages.count },
            memoriesCount: localState.learnedMemories.count,
            lastMessage: localState.conversations.last?.messages.last?.content
        )
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: LocalSyncServerService.didCompleteSyncNotification,
                object: nil,
                userInfo: [
                    "newConversations": newConvCount,
                    "newMessages": newMsgCount,
                    "newMemories": newMemoriesCount
                ]
            )
            
            let message = "✅ Synchronisation réussie ! \(newConvCount) discussion(s), \(newMsgCount) message(s) et \(newMemoriesCount) souvenir(s) transférés."
            completion(true, message)
        }
    }
}
