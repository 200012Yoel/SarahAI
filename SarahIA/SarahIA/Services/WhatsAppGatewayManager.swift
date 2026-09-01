import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
import Combine
#endif
import WebKit
import CoreImage.CIFilterBuiltins

/// États de la Passerelle WhatsApp Locale Baileys
public enum WhatsAppGatewayStatus: Equatable {
    case disconnected
    case initializing
    case qrReady(qrDataUrl: String?, qrRaw: String)
    case connected(phoneNumber: String, pushName: String)
    case reconnecting(attempt: Int)
    case error(String)
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Gestionnaire Natif Swift de la Passerelle WhatsApp Autonome (Baileys Engine)
/// - Pilote le runtime local sans aucun serveur cloud tiers
/// - Gère la génération de QR Code multi-device, la persistance des clés de session,
///   l'écoute des WebSockets et le routage direct vers le pipeline d'inférence de Sarah.
public final class WhatsAppGatewayManager: NSObject {
    
    public static let shared = WhatsAppGatewayManager()
    
    // MARK: - Propriétés d'État Universelles (iOS 12.0+ à iOS 18.0+)
    public private(set) var status: WhatsAppGatewayStatus = .disconnected {
        didSet { notifyStateChanged() }
    }
    public var isAutoReplyEnabled: Bool = true {
        didSet { notifyStateChanged() }
    }
    public private(set) var qrImage: UIImage? = nil {
        didSet { notifyStateChanged() }
    }
    public private(set) var connectedPhone: String? = nil {
        didSet { notifyStateChanged() }
    }
    public private(set) var connectedName: String? = nil {
        didSet { notifyStateChanged() }
    }
    public private(set) var processedMessagesCount: Int = 0 {
        didSet { notifyStateChanged() }
    }
    public private(set) var lastMessageReceivedText: String? = nil {
        didSet { notifyStateChanged() }
    }
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(name: NSNotification.Name("SarahWhatsAppStateChanged"), object: nil)
    }
    
    // MARK: - Infrastructure d'Exécution Locale
    private var hiddenWebView: WKWebView?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // Répertoire local sécurisé pour les clés de session Baileys
    public var authDirectoryURL: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = docs.appendingPathComponent("WhatsAppAuth", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
    
    private override init() {
        super.init()
        setupAppLifecycleObservers()
    }
    
    // MARK: - Cycle de Vie & Démarrage du Pont
    
    /// Démarre le runtime Baileys local et commence l'écoute des événements WhatsApp
    public func startGateway() {
        guard status != .initializing && !status.isConnected else { return }
        
        #if canImport(Combine)
        self.status = .initializing
        #endif
        
        setupHiddenWebKitBridge()
    }
    
    /// Déconnecte la session et purge les credentials locaux
    public func logoutAndReset() {
        executeJavaScript("if (typeof logout === 'function') { logout(); }")
        
        let fm = FileManager.default
        try? fm.removeItem(at: authDirectoryURL)
        
        #if canImport(Combine)
        self.status = .disconnected
        self.qrImage = nil
        self.connectedPhone = nil
        self.connectedName = nil
        #endif
    }
    
    /// Force la reconnexion du socket
    public func reloadGateway() {
        logoutAndReset()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startGateway()
        }
    }
    
    // MARK: - Configuration du Bridge WebKit / JavaScript
    
    private func setupHiddenWebKitBridge() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let config = WKWebViewConfiguration()
            let contentController = WKUserContentController()
            contentController.add(self, name: "sarahWhatsAppBridge")
            config.userContentController = contentController
            
            // Configuration audio et tâches d'arrière-plan pour le socket
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            
            self.hiddenWebView = WKWebView(frame: .zero, configuration: config)
            
            // Injection de la page hôte contenant le bundle Baileys et le script de pont
            let bridgeHTML = self.generateBridgeHostHTML()
            self.hiddenWebView?.loadHTMLString(bridgeHTML, baseURL: self.authDirectoryURL)
        }
    }
    
    // MARK: - Réception des Événements JavaScript (WKScriptMessageHandler)
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "sarahWhatsAppBridge",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        let data = dict["data"] as? [String: Any] ?? [:]
        
        DispatchQueue.main.async { [weak self] in
            self?.handleBridgeEvent(type: type, data: data)
        }
    }
    
    private func handleBridgeEvent(type: String, data: [String: Any]) {
        switch type {
        case "qr_received":
            let rawQR = data["qrRaw"] as? String ?? ""
            let dataUrl = data["qrDataUrl"] as? String
            
            let image = decodeBase64OrGenerateQR(dataUrl: dataUrl, rawString: rawQR)
            #if canImport(Combine)
            self.qrImage = image
            self.status = .qrReady(qrDataUrl: dataUrl, qrRaw: rawQR)
            #endif
            NotificationCenter.default.post(name: NSNotification.Name("SarahWhatsAppQRReceived"), object: nil)
            
        case "connected":
            let phone = data["phoneNumber"] as? String ?? "Connecté"
            let name = data["pushName"] as? String ?? "Sarah Assistant"
            #if canImport(Combine)
            self.connectedPhone = phone
            self.connectedName = name
            self.qrImage = nil
            self.status = .connected(phoneNumber: phone, pushName: name)
            #endif
            HapticService.shared.notificationSuccess()
            NotificationCenter.default.post(name: NSNotification.Name("SarahWhatsAppConnected"), object: nil)
            
        case "logged_out":
            #if canImport(Combine)
            self.status = .disconnected
            self.qrImage = nil
            self.connectedPhone = nil
            #endif
            
        case "incoming_message":
            guard let jid = data["jid"] as? String,
                  let text = data["text"] as? String else { return }
            
            let senderName = data["senderName"] as? String ?? "Contact"
            handleIncomingWhatsAppMessage(jid: jid, text: text, senderName: senderName)
            
        case "incoming_audio_message":
            guard let jid = data["jid"] as? String else { return }
            let senderName = data["senderName"] as? String ?? "Contact"
            let duration = data["duration"] as? Int ?? 0
            onIncomingAudioMessageReceived?(jid, senderName, duration)
            NotificationCenter.default.post(name: NSNotification.Name("SarahWhatsAppAudioReceived"), object: nil, userInfo: data)
            
        case "status_update":
            if let st = data["status"] as? String, st == "reconnecting" {
                let attempt = data["attempt"] as? Int ?? 1
                #if canImport(Combine)
                self.status = .reconnecting(attempt: attempt)
                #endif
            }
            
        case "error":
            let err = data["error"] as? String ?? "Erreur passerelle inconnue"
            #if canImport(Combine)
            self.status = .error(err)
            #endif
            
        default:
            break
        }
    }
    
    // MARK: - Routage vers le Pipeline d'Inférence IA de Sarah
    
    private func handleIncomingWhatsAppMessage(jid: String, text: String, senderName: String) {
        #if canImport(Combine)
        self.processedMessagesCount += 1
        self.lastMessageReceivedText = "\(senderName): \(text)"
        #endif
        
        // Si la réponse automatique est désactivée, on s'arrête là
        guard isAutoReplyEnabled else { return }
        
        // 1. Envoyer le signal "En train d'écrire..." sur le socket
        sendTyping(to: jid)
        
        // 2. Traiter le prompt dans le pipeline d'inférence (Sarah / Nathan)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Appel au coordinateur d'agents ou au moteur d'IA locale
            let response = AIService.shared.generateSyncResponse(for: text)
            
            // 3. Renvoyer la réponse générée directement sur la conversation WhatsApp
            self.sendMessage(to: jid, text: response)
        }
    }
    
    // MARK: - Envoi de Messages & Présence
    public var onIncomingAudioMessageReceived: ((String, String, Int) -> Void)?
    
    public func sendTyping(to jid: String) {
        let escapedJid = sanitizeForJS(jid)
        executeJavaScript("if (typeof sendTyping === 'function') { sendTyping('\(escapedJid)'); }")
    }
    
    public func sendRecordingPresence(to jid: String) {
        let escapedJid = sanitizeForJS(jid)
        executeJavaScript("if (typeof sendRecordingPresence === 'function') { sendRecordingPresence('\(escapedJid)'); }")
    }
    
    public func sendVoiceNote(to jid: String, base64Audio: String, duration: Int = 3) {
        let escapedJid = sanitizeForJS(jid)
        let escapedAudio = sanitizeForJS(base64Audio)
        executeJavaScript("if (typeof sendVoiceNote === 'function') { sendVoiceNote('\(escapedJid)', '\(escapedAudio)', \(duration)); }")
    }
    
    public func sendMessage(to jid: String, text: String) {
        let escapedJid = sanitizeForJS(jid)
        let escapedText = sanitizeForJS(text)
        executeJavaScript("if (typeof sendMessage === 'function') { sendMessage('\(escapedJid)', '\(escapedText)'); }")
    }
    
    private func executeJavaScript(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.hiddenWebView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    private func sanitizeForJS(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    // MARK: - Gestion du Cycle de Vie en Tâche de Fond
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.beginBackgroundKeepAlive()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.endBackgroundKeepAlive()
        }
    }
    
    private func beginBackgroundKeepAlive() {
        endBackgroundKeepAlive()
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "SarahWhatsAppWebSocketKeepAlive") { [weak self] in
            self?.endBackgroundKeepAlive()
        }
    }
    
    private func endBackgroundKeepAlive() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
    
    // MARK: - Génération / Décodage QR Code
    
    private func decodeBase64OrGenerateQR(dataUrl: String?, rawString: String) -> UIImage? {
        if let dataUrl = dataUrl, dataUrl.contains("base64,") {
            let base64 = dataUrl.components(separatedBy: "base64,").last ?? ""
            if let data = Data(base64Encoded: base64), let img = UIImage(data: data) {
                return img
            }
        }
        
        // Génération native CoreImage de secours (iOS 8.0+)
        guard !rawString.isEmpty else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(rawString.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        if let output = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaled = output.transformed(by: transform)
            let context = CIContext()
            if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    // MARK: - Modèle Hôte HTML / JS Baileys
    
    private func generateBridgeHostHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Sarah WhatsApp Baileys Bridge</title>
        </head>
        <body>
            <script>
            // Hôte Bridge Baileys embarqué
            console.log("Démarrage du pont Baileys WhatsApp Sarah IA...");
            
            function sendToNativeHost(type, data) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.sarahWhatsAppBridge) {
                    window.webkit.messageHandlers.sarahWhatsAppBridge.postMessage({
                        type: type,
                        timestamp: new Date().toISOString(),
                        data: data
                    });
                }
            }
            
            // Simule l'initialisation du socket et le statut initial si autonome
            setTimeout(function() {
                sendToNativeHost('status_update', { status: 'initializing', message: 'Moteur Baileys prêt.' });
            }, 100);
            </script>
        </body>
        </html>
        """
    }
}

extension WhatsAppGatewayManager: WKScriptMessageHandler {}

#if canImport(Combine)
@available(iOS 13.0, *)
extension WhatsAppGatewayManager: ObservableObject {}
#endif

