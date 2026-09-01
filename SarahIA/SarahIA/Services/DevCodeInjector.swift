import Foundation
import WebKit

// ============================================================================
// DEV CODE INJECTOR — LIVE PREVIEW DANS L'ÉCRAN VIRTUEL (AGENT DÉVELOPPEUR)
// ============================================================================
// Réservé à l'Agent Développeur (Tom / Studio VAI).
// Injecte en direct le code HTML/CSS/JS généré dans le viewport du simulateur
// iPhone virtuel pour valider le rendu responsive, les Safe Areas et la Dynamic Island.
// ============================================================================

public final class DevCodeInjector {
    
    public static let shared = DevCodeInjector()
    
    private init() {}
    
    /// Injecte et affiche le rendu HTML/CSS/JS dans le téléphone virtuel (index.html)
    public static func injectRender(html: String, css: String, js: String, in webView: WKWebView? = nil) {
        let targetWebView = webView ?? VirtualPhoneManager.shared.activeWebView
        guard let target = targetWebView else {
            print("⚠️ [DevCodeInjector] Aucune WKWebView active pour le rendu Live Preview.")
            return
        }
        
        let sanitizedHTML = sanitize(html)
        let sanitizedCSS = sanitize(css)
        let sanitizedJS = sanitize(js)
        
        let script = """
        (function() {
            if (window.SarahVirtualPhoneBridge && typeof window.SarahVirtualPhoneBridge.injectDevPreview === 'function') {
                window.SarahVirtualPhoneBridge.injectDevPreview('\(sanitizedHTML)', '\(sanitizedCSS)', '\(sanitizedJS)');
            } else {
                // Fallback direct dans le DOM du simulateur
                let container = document.getElementById('preview-viewport') || document.getElementById('screen-content') || document.body;
                
                // Injection du Style CSS
                let existingStyle = document.getElementById('dev-injected-style');
                if (!existingStyle) {
                    existingStyle = document.createElement('style');
                    existingStyle.id = 'dev-injected-style';
                    document.head.appendChild(existingStyle);
                }
                existingStyle.textContent = '\(sanitizedCSS)';
                
                // Injection du Contenu HTML avec Safe Area
                container.innerHTML = `
                    <div class="dev-preview-wrapper" style="width: 100%; height: 100%; overflow-y: auto; -webkit-overflow-scrolling: touch; padding: env(safe-area-inset-top, 20px) 12px env(safe-area-inset-bottom, 20px) 12px; box-sizing: border-box;">
                        \(sanitizedHTML)
                    </div>
                `;
                
                // Exécution du Script JS
                try {
                    const runScript = new Function('\(sanitizedJS)');
                    runScript();
                } catch(e) {
                    console.error('[DevCodeInjector] Erreur JS:', e);
                }
            }
        })();
        """
        
        DispatchQueue.main.async {
            target.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ [DevCodeInjector] Échec evaluateJavaScript: \(error.localizedDescription)")
                } else {
                    print("✅ [DevCodeInjector] Code HTML/CSS/JS injecté avec succès dans le Live Preview !")
                    HapticService.shared.buttonTap()
                }
            }
        }
    }
    
    private static func sanitize(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
