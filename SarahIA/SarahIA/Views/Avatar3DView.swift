import SwiftUI
import WebKit

/// Vue SwiftUI intégrant l'avatar 3D complet avec Three.js, VRM, shaders MToon, gestuelle et lipsync temps réel.
public struct Avatar3DView: View {
    @ObservedObject var avatarEngine = AvatarEngine.shared
    public var isSpeaking: Bool = false
    
    public init(isSpeaking: Bool = false) {
        self.isSpeaking = isSpeaking
    }
    
    public var body: some View {
        AvatarVRMWebContainerView(isSpeaking: isSpeaking)
            .background(Color.black)
            .edgesIgnoringSafeArea(.all)
    }
}

/// Conteneur WKWebView haute performance pour le rendu 3D VRM 60/120 FPS avec Metal
struct AvatarVRMWebContainerView: UIViewRepresentable {
    var isSpeaking: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Autoriser l'accès aux fichiers locaux (VRM, textures, scripts JS)
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        
        // 1. Recherche du fichier HTML dans le Bundle principal
        if let htmlUrl = Bundle.main.url(forResource: "sarah_ai_web", withExtension: "html") {
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: Bundle.main.bundleURL)
        } else if let path = Bundle.main.path(forResource: "sarah_ai_web", ofType: "html"),
                  let htmlString = try? String(contentsOfFile: path, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        } else {
            // 2. Recherche dans Documents ou Application Support
            let fileManager = FileManager.default
            let docUrls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            if let docUrl = docUrls.first?.appendingPathComponent("sarah_ai_web.html"), fileManager.fileExists(atPath: docUrl.path) {
                webView.loadFileURL(docUrl, allowingReadAccessTo: docUrl.deletingLastPathComponent())
            }
        }
        
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Synchronisation temps réel de la voix et du mouvement des lèvres
        let js = "if (window.setSpeaking) { window.setSpeaking(\(isSpeaking ? "true" : "false")); }"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [Avatar3DView] Avatar 3D VRM chargé avec succès dans l'application iOS.")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("⚠️ [Avatar3DView] Erreur navigation WKWebView: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("⚠️ [Avatar3DView] Erreur navigation provisoire WKWebView: \(error.localizedDescription)")
        }
    }
}

