//
//  Avatar3DView.swift
//  SarahIA
//
//  Rendu de l'Avatar 3D authentique de Sarah (VRM + Three.js + Metal)
//  Synchronisation labiale, clignement des yeux et animations gestuelles temps réel.
//

import SwiftUI
import WebKit

/// Vue intégrant l'avatar 3D officiel de Sarah avec rendu haute performance et synchronisation vocale
public struct Avatar3DView: View {
    public var isSpeaking: Bool = false
    
    public init(isSpeaking: Bool = false) {
        self.isSpeaking = isSpeaking
    }
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            AvatarVRMContainerView(isSpeaking: isSpeaking)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

/// Conteneur WKWebView haute performance pour le rendu 3D VRM de Sarah
struct AvatarVRMContainerView: UIViewRepresentable {
    var isSpeaking: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        
        // Chargement du moteur 3D de Sarah
        if let htmlUrl = Bundle.main.url(forResource: "sarah_ai_web", withExtension: "html") {
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: Bundle.main.bundleURL)
        } else if let path = Bundle.main.path(forResource: "sarah_ai_web", ofType: "html"),
                  let htmlString = try? String(contentsOfFile: path, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        }
        
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Synchronisation du mouvement des lèvres et de l'animation d'élocution
        let js = "if (window.setSpeaking) { window.setSpeaking(\(isSpeaking ? "true" : "false")); }"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [Avatar3DView] Avatar 3D de Sarah initialisé avec succès.")
        }
    }
}

