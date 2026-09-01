import Foundation
import WebKit

// ============================================================================
// DEV CODE INJECTOR — LIVE PREVIEW DANS L'ÉCRAN VIRTUEL (AGENT DÉVELOPPEUR)
// ============================================================================
// Réservé à l'Agent Développeur (Tom / Studio VAI Coding).
// Isole le code injecté dans une iframe sandboxée pour éviter toute collision
// avec les variables globales (window.SarahVirtualPhoneBridge) tout en
// garantissant le défilement fluide et le respect des Safe Areas / Dynamic Island.
// ============================================================================

public final class DevCodeInjector {
    
    public static let shared = DevCodeInjector()
    
    private init() {}
    
    /// Injecte et affiche le rendu HTML/CSS/JS dans le simulateur virtuel via une iframe sandboxée isolée
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
            // Conteneur d'affichage de l'iPhone virtuel
            let container = document.getElementById('preview-viewport') || 
                            document.querySelector('.iphone-screen') || 
                            document.getElementById('screen-content') || 
                            document.body;
            
            if (!container) return;
            
            // Stylisation du conteneur parent pour garantir le défilement fluide sans casser le cadre iPhone
            container.style.overflowY = 'auto';
            container.style.overflowX = 'hidden';
            container.style.webkitOverflowScrolling = 'touch';
            
            // Création ou récupération de l'iframe sandboxée pour isoler le scope global
            let iframe = document.getElementById('dev-live-preview-frame');
            if (!iframe) {
                iframe = document.createElement('iframe');
                iframe.id = 'dev-live-preview-frame';
                iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms');
                iframe.style.width = '100%';
                iframe.style.height = '100%';
                iframe.style.border = 'none';
                iframe.style.display = 'block';
                iframe.style.backgroundColor = 'transparent';
                iframe.style.overflowY = 'auto';
                iframe.style.overflowX = 'hidden';
                
                // Nettoyage des anciens aperçus et injection
                container.innerHTML = '';
                container.appendChild(iframe);
            }
            
            // Document complet isolé injecté dans l'iframe
            const fullDoc = `
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
                    <style>
                        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                        body {
                            margin: 0;
                            padding: env(safe-area-inset-top, 44px) 14px env(safe-area-inset-bottom, 34px) 14px;
                            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                            background: transparent;
                            color: #FFFFFF;
                            overflow-y: auto;
                            overflow-x: hidden;
                            -webkit-overflow-scrolling: touch;
                        }
                        \(sanitizedCSS)
                    </style>
                </head>
                <body>
                    \(sanitizedHTML)
                    <script>
                        try {
                            \(sanitizedJS)
                        } catch(e) {
                            console.error('[LivePreview JS Error]', e);
                        }
                    <\\/script>
                </body>
                </html>
            `;
            
            iframe.srcdoc = fullDoc;
        })();
        """
        
        DispatchQueue.main.async {
            target.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ [DevCodeInjector] Échec injection iframe: \(error.localizedDescription)")
                } else {
                    print("✅ [DevCodeInjector] Code HTML/CSS/JS rendu dans l'iframe sandboxée avec succès !")
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
