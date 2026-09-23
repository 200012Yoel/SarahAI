import Foundation
import WebKit

// ============================================================================
// DEV CODE INJECTOR — LIVE PREVIEW DANS L'ÉCRAN VIRTUEL (AGENT DÉVELOPPEUR)
// ============================================================================
// Réservé à l'Agent Développeur / Studio VAI Coding.
// Isole le code généré dans une iframe sandboxée pour éviter toute collision
// avec l'application hôte tout en conservant une vraie prévisualisation HTML.
// ============================================================================

public final class DevCodeInjector {
    
    public static let shared = DevCodeInjector()
    
    private init() {}
    
    /// Injecte HTML/CSS/JS séparés dans une iframe sandboxée.
    ///
    /// Le document est encodé en Base64 avant d'être transmis à JavaScript.
    /// Cela évite de casser le rendu avec des retours à la ligne, backticks,
    /// guillemets ou template literals présents dans le code généré par Raphaël.
    public static func injectRender(html: String, css: String, js: String, in webView: WKWebView? = nil) {
        let safeCSS = css
            .replacingOccurrences(of: "</style>", with: "<\\/style>")
        let safeJS = js
            .replacingOccurrences(of: "</script>", with: "<\\/script>")

        let fullDocument = """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                html, body { min-height: 100%; }
                body {
                    margin: 0;
                    padding: env(safe-area-inset-top, 20px) 14px env(safe-area-inset-bottom, 20px) 14px;
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    background: transparent;
                    color: #FFFFFF;
                    overflow-y: auto;
                    overflow-x: hidden;
                    -webkit-overflow-scrolling: touch;
                }
                \(safeCSS)
            </style>
        </head>
        <body>
            \(html)
            <script>
                try {
                    \(safeJS)
                } catch (error) {
                    console.error('[Sarah Live Preview JS Error]', error);
                    document.documentElement.dataset.previewError = String(error && error.message ? error.message : error);
                }
            </script>
        </body>
        </html>
        """

        renderDocument(fullDocument, in: webView)
    }

    /// Affiche directement un fichier HTML monopage complet produit par Raphaël.
    /// Utile pour les projets HTML/CSS/JS autonomes générés dans le Studio.
    public static func injectFullDocument(html: String, in webView: WKWebView? = nil) {
        renderDocument(html, in: webView)
    }

    private static func renderDocument(_ document: String, in webView: WKWebView?) {
        let targetWebView = webView ?? VirtualPhoneManager.shared.activeWebView
        guard let target = targetWebView else {
            print("⚠️ [DevCodeInjector] Aucune WKWebView active pour le rendu Live Preview.")
            return
        }

        guard let data = document.data(using: .utf8) else {
            print("❌ [DevCodeInjector] Impossible d'encoder le document UTF-8.")
            return
        }

        let encodedDocument = data.base64EncodedString()
        let script = """
        (function() {
            let container = document.getElementById('preview-viewport') ||
                            document.querySelector('.iphone-screen') ||
                            document.getElementById('screen-content') ||
                            document.body;

            if (!container) return;

            container.style.overflowY = 'auto';
            container.style.overflowX = 'hidden';
            container.style.webkitOverflowScrolling = 'touch';

            let iframe = document.getElementById('dev-live-preview-frame');
            if (!iframe) {
                iframe = document.createElement('iframe');
                iframe.id = 'dev-live-preview-frame';
                iframe.style.width = '100%';
                iframe.style.height = '100%';
                iframe.style.minHeight = '100%';
                iframe.style.border = 'none';
                iframe.style.display = 'block';
                iframe.style.backgroundColor = 'transparent';

                container.innerHTML = '';
                container.appendChild(iframe);
            }

            iframe.setAttribute('sandbox', 'allow-scripts allow-forms allow-modals');
            iframe.removeAttribute('srcdoc');
            iframe.src = 'data:text/html;base64,\(encodedDocument)';
        })();
        """

        DispatchQueue.main.async {
            target.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ [DevCodeInjector] Échec du rendu Live Preview: \(error.localizedDescription)")
                } else {
                    print("✅ [DevCodeInjector] Live Preview actualisée avec succès.")
                    HapticService.shared.buttonTap()
                }
            }
        }
    }
}
