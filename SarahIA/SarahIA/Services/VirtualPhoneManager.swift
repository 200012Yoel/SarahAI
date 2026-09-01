import Foundation
import WebKit
import UIKit

// ============================================================================
// SARAH VIRTUAL PHONE MANAGER — PILOTAGE DE L'ÉCRAN VIRTUEL PAR TOOL CALLS
// ============================================================================
// Permet à l'agent IA (Sarah / Nathan / Tom / Yoann) d'interagir visuellement
// avec l'écran virtuel (index.html) en exécutant des tool calls et en animant
// les fausses applications en temps réel.
// ============================================================================

public final class VirtualPhoneManager: NSObject {
    
    public static let shared = VirtualPhoneManager()
    
    public weak var activeWebView: WKWebView?
    
    // Callback pour informer l'IA de la fin d'une action visuelle
    public var onToolExecutionCompleted: ((String, [String: Any]) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 1. Schéma JSON du Tool Call pour le LLM (OpenAI / Local GGUF)
    
    public static let toolDefinitionSchema: [String: Any] = [
        "name": "interactWithVirtualPhone",
        "description": "Pilote l'écran du téléphone virtuel de Sarah pour afficher visuellement ses actions à l'utilisateur.",
        "parameters": [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "enum": ["openApp", "closeCurrentApp", "typeText", "showNotification", "simulateTap", "scroll"],
                    "description": "L'action à exécuter sur l'écran virtuel"
                ],
                "appId": [
                    "type": "string",
                    "description": "L'identifiant de l'app virtuelle (ex: 'whatsapp', 'photos', 'settings', 'notes', 'weather')"
                ],
                "text": [
                    "type": "string",
                    "description": "Texte à saisir dans le champ cible"
                ],
                "targetSelector": [
                    "type": "string",
                    "description": "Sélecteur CSS de l'élément cible (ex: '#search-input', '#chat-input')"
                ],
                "notification": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string"],
                        "body": ["type": "string"],
                        "app": ["type": "string"]
                    ],
                    "required": ["title", "body"]
                ]
            ],
            "required": ["command"]
        ]
    ]
    
    // MARK: - 2. Exécution d'un Tool Call reçu de l'Agent IA
    
    public func executeToolCall(parameters: [String: Any]) {
        guard let command = parameters["command"] as? String else { return }
        
        switch command {
        case "openApp":
            if let appId = parameters["appId"] as? String {
                openApp(appId: appId)
            }
        case "closeCurrentApp":
            closeCurrentApp()
            
        case "typeText":
            let text = parameters["text"] as? String ?? ""
            let selector = parameters["targetSelector"] as? String ?? "#input"
            typeText(targetSelector: selector, text: text)
            
        case "showNotification":
            if let notif = parameters["notification"] as? [String: Any] {
                let title = notif["title"] as? String ?? "Sarah IA"
                let body = notif["body"] as? String ?? ""
                let app = notif["app"] as? String ?? "Sarah"
                showNotification(app: app, title: title, body: body)
            }
            
        case "simulateTap":
            if let selector = parameters["targetSelector"] as? String {
                simulateTap(targetSelector: selector)
            }
            
        case "scroll":
            let direction = parameters["direction"] as? String ?? "down"
            scroll(direction: direction)
            
        default:
            break
        }
    }
    
    // MARK: - 3. Commandes Directes vers JavaScript avec Watchdog Timeout (5.0s)
    private var watchdogTimer: Timer?
    
    private func armWatchdogTimer(for toolName: String) {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            print("⏱️ [VirtualPhoneManager] Watchdog Timeout (5s) atteint pour: \(toolName) — Déblocage automatique de l'agent.")
            self?.onToolExecutionCompleted?(toolName, ["status": "timeout_auto_unblocked"])
        }
    }
    
    public func openApp(appId: String) {
        armWatchdogTimer(for: "openApp")
        let escaped = sanitize(appId)
        executeJS("if (window.SarahVirtualPhoneBridge) { window.SarahVirtualPhoneBridge.openApp('\(escaped)'); }")
    }
    
    public func closeCurrentApp() {
        executeJS("if (window.SarahVirtualPhoneBridge) { window.SarahVirtualPhoneBridge.closeCurrentApp(); }")
    }
    
    public func typeText(targetSelector: String, text: String, speedMs: Int = 40) {
        armWatchdogTimer(for: "typeText")
        let escapedSelector = sanitize(targetSelector)
        let escapedText = sanitize(text)
        executeJS("if (window.SarahVirtualPhoneBridge) { window.SarahVirtualPhoneBridge.typeText('\(escapedSelector)', '\(escapedText)', \(speedMs)); }")
    }
    
    public func showNotification(app: String, title: String, body: String) {
        armWatchdogTimer(for: "showNotification")
        let escapedApp = sanitize(app)
        let escapedTitle = sanitize(title)
        let escapedBody = sanitize(body)
        executeJS("if (window.SarahVirtualPhoneBridge) { window.SarahVirtualPhoneBridge.showNotification('\(escapedApp)', '\(escapedTitle)', '\(escapedBody)'); }")
    }
    
    public func simulateTap(targetSelector: String) {
        armWatchdogTimer(for: "simulateTap")
        let escaped = sanitize(targetSelector)
        executeJS("if (window.SarahVirtualPhoneBridge) { window.SarahVirtualPhoneBridge.simulateTap('\(escaped)'); }")
    }
    
    public func scroll(direction: String) {
        armWatchdogTimer(for: "scroll")
        let escaped = sanitize(direction)
        executeJS("if (window.SarahVirtualPhoneBridge) { window.SarahVirtualPhoneBridge.scroll('\(escaped)'); }")
    }
    
    /// Rôle exclusif Agent Développeur : Injection Live Preview
    public func injectDevCode(html: String, css: String, js: String) {
        DevCodeInjector.injectRender(html: html, css: css, js: js, in: activeWebView)
    }
    
    // MARK: - 4. Chargement Propre d'index.html dans WKWebView
    
    public func loadIndexHTML(into webView: WKWebView) {
        self.activeWebView = webView
        
        // Configuration du message handler pour les retours Web -> Swift
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sarahVirtualPhone")
        webView.configuration.userContentController.add(self, name: "sarahVirtualPhone")
        
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            let fileUrl = URL(fileURLWithPath: htmlPath)
            let baseDir = fileUrl.deletingLastPathComponent()
            webView.loadFileURL(fileUrl, allowingReadAccessTo: baseDir)
        } else if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let localIndexPath = docsURL.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: localIndexPath.path) {
                webView.loadFileURL(localIndexPath, allowingReadAccessTo: docsURL)
            }
        }
    }
    
    private func executeJS(_ code: String) {
        DispatchQueue.main.async { [weak self] in
            self?.activeWebView?.evaluateJavaScript(code, completionHandler: nil)
        }
    }
    
    private func sanitize(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

// MARK: - 5. Réception des Événements JavaScript (WKScriptMessageHandler)

extension VirtualPhoneManager: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "sarahVirtualPhone",
              let dict = message.body as? [String: Any],
              let event = dict["event"] as? String else { return }
        
        let data = dict["data"] as? [String: Any] ?? [:]
        
        DispatchQueue.main.async { [weak self] in
            switch event {
            case "typing_finished":
                HapticService.shared.buttonTap()
                self?.onToolExecutionCompleted?("typeText", data)
                
            case "app_opened":
                HapticService.shared.buttonTap()
                self?.onToolExecutionCompleted?("openApp", data)
                
            case "notification_shown":
                HapticService.shared.notificationSuccess()
                self?.onToolExecutionCompleted?("showNotification", data)
                
            case "scroll_finished":
                self?.onToolExecutionCompleted?("scroll", data)
                
            case "user_interaction":
                HapticService.shared.buttonTap()
                
            default:
                break
            }
        }
    }
}
