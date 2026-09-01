import UIKit
import WebKit

// ============================================================================
// VIRTUAL PHONE VIEW CONTROLLER — VUE HÔTE DE L'ÉCRAN VIRTUEL (iOS 12.0+)
// ============================================================================
// Affiche l'écran virtuel complet, purge le cache WebKit au rechargement et
// connecte le bridge bidirectionnel avec le VirtualPhoneManager et l'Agent IA.
// ============================================================================

public final class VirtualPhoneViewController: UIViewController {
    
    private var webView: WKWebView!
    private let closeButton = SarahIconButton(type: .close)
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SarahDesignSystem.Colors.background
        clearWebKitCacheIfNeeded { [weak self] in
            self?.setupWebView()
            self?.setupUI()
        }
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences
        
        // Utilisation d'un store non persistant en dev pour éliminer les caches figés
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        VirtualPhoneManager.shared.loadIndexHTML(into: webView)
    }
    
    private func setupUI() {
        closeButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])
    }
    
    // Purge des données de site pour garantir que le HTML/CSS/JS rechargé est toujours à jour
    private func clearWebKitCacheIfNeeded(completion: @escaping () -> Void) {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let epoch = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: epoch) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    @objc private func dismissModal() {
        HapticService.shared.buttonTap()
        dismiss(animated: true, completion: nil)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanupWebKitHandlers()
    }
    
    deinit {
        cleanupWebKitHandlers()
    }
    
    private func cleanupWebKitHandlers() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "sarahVirtualPhone")
    }
}
