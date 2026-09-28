import Foundation
import UIKit
import WebKit

/// Résultat de recherche Web affichable dans les réponses de Sarah.
public struct WebSearchResult: Codable {
    public var id: String { url }
    public let title: String
    public let snippet: String
    public let url: String
    public let sourceName: String

    public init(title: String, snippet: String, url: String, sourceName: String) {
        self.title = title
        self.snippet = snippet
        self.url = url
        self.sourceName = sourceName
    }
}

/// Contexte réellement lu depuis la page ouverte dans le navigateur de Sarah.
public struct SarahWebPageContext {
    public let title: String
    public let url: String
    public let visibleText: String

    public init(title: String, url: String, visibleText: String) {
        self.title = title
        self.url = url
        self.visibleText = visibleText
    }
}

/// Recherche Internet + navigateur WebKit intégré à Sarah.
///
/// Principes :
/// - vraie navigation Web avec WKWebView, cookies et JavaScript standards ;
/// - aucune désactivation d'ATS, de TLS, de certificat ou de protection du site ;
/// - Sarah peut lire le texte visible de la page courante ;
/// - toute action qui modifie un compte, un panier ou un formulaire demande
///   une confirmation explicite ;
/// - le paiement final n'est jamais automatisé.
public final class WebSearchService {

    public static let shared = WebSearchService()

    private let urlSession: URLSession
    private weak var activeBrowser: SarahWebBrowserViewController?
    public private(set) var lastPageContext: SarahWebPageContext?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 18.0
        configuration.requestCachePolicy = .useProtocolCachePolicy
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - API conservée pour AIService / SarahBrainEngine

    @available(iOS 13.0, *)
    public func searchWebAsync(query: String) async -> (summary: String, results: [WebSearchResult]) {
        await withCheckedContinuation { continuation in
            searchWeb(query: query) { summary, results in
                continuation.resume(returning: (summary, results))
            }
        }
    }

    public func searchWeb(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion("Précise ce que tu veux rechercher sur Internet.", [])
            return
        }

        guard NetworkMonitor.shared.isOnline else {
            if let local = TomKnowledgeBase.shared.query(text: clean) {
                completion("🌍 **Mode hors ligne**\n\n\(local)", [])
            } else {
                completion("🌍 **Pas de connexion Internet**\n\nJe ne peux pas charger le Web pour le moment. Je peux continuer avec les connaissances disponibles localement.", [])
            }
            return
        }

        let normalized = normalize(clean)

        // Sarah peut répondre sur la page réellement ouverte dans son navigateur.
        if refersToCurrentPage(normalized), let context = lastPageContext {
            let excerpt = String(context.visibleText.prefix(12_000))
            let summary = """
            🌐 **Page actuellement ouverte dans Sarah**

            **\(context.title.isEmpty ? "Page Web" : context.title)**
            \(context.url)

            \(excerpt)
            """
            completion(summary, [
                WebSearchResult(
                    title: context.title.isEmpty ? "Page actuelle" : context.title,
                    snippet: String(excerpt.prefix(280)),
                    url: context.url,
                    sourceName: hostName(from: context.url)
                )
            ])
            return
        }

        // Une demande de navigation ouvre le vrai environnement WebKit de Sarah.
        if shouldOpenBrowser(normalized) {
            let target = browserURL(for: clean)
            openBrowser(url: target)
            completion(
                "🌐 **Navigateur Sarah ouvert**\n\nJ'ai ouvert le vrai Web dans l'application. Tu peux naviguer normalement, puis me demander « résume cette page » ou « qu'est-ce qu'il y a sur cette page ? ».",
                [WebSearchResult(title: "Ouvrir dans Sarah", snippet: "Navigation WebKit intégrée", url: target.absoluteString, sourceName: target.host ?? "Web")]
            )
            return
        }

        // Pour une recherche classique, Sarah consulte une vraie source réseau.
        fetchDuckDuckGo(query: clean) { [weak self] summary, results in
            guard let self = self else { return }
            if !results.isEmpty || !summary.isEmpty {
                completion(summary, results)
                return
            }

            let google = self.googleSearchURL(for: clean)
            let duck = self.duckDuckGoSearchURL(for: clean)
            completion(
                "🌐 Je n'ai pas obtenu de réponse structurée suffisante. Voici les recherches Web réelles à ouvrir dans le navigateur de Sarah.",
                [
                    WebSearchResult(title: "Google · \(clean)", snippet: "Recherche Google", url: google.absoluteString, sourceName: "Google"),
                    WebSearchResult(title: "DuckDuckGo · \(clean)", snippet: "Recherche DuckDuckGo", url: duck.absoluteString, sourceName: "DuckDuckGo")
                ]
            )
        }
    }

    // MARK: - Navigateur Sarah

    public func openBrowser(query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        openBrowser(url: browserURL(for: clean.isEmpty ? "Google" : clean))
    }

    public func openBrowser(url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let current = self.activeBrowser, current.presentingViewController != nil {
                current.load(url: url)
                return
            }

            guard let presenter = self.topViewController() else { return }
            let browser = SarahWebBrowserViewController(service: self, initialURL: url)
            browser.modalPresentationStyle = .fullScreen
            self.activeBrowser = browser
            presenter.present(browser, animated: true)
        }
    }

    /// Les actions de lecture restent libres. Une mutation du site doit passer ici.
    public func requestAgentAction(
        description: String,
        javascript: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let normalized = normalize(description)

        // Le dernier geste financier reste toujours manuel.
        let paymentWords = ["payer", "paiement", "commander", "acheter maintenant", "checkout", "place order", "confirmer l achat", "confirmer la commande"]
        if paymentWords.contains(where: { normalized.contains($0) }) {
            completion(false, "Le paiement ou la confirmation finale d'une commande doit être fait manuellement par l'utilisateur.")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let browser = self?.activeBrowser, browser.presentingViewController != nil else {
                completion(false, "Le navigateur de Sarah n'est pas ouvert.")
                return
            }
            browser.confirmAgentAction(description: description, javascript: javascript, completion: completion)
        }
    }

    fileprivate func updatePageContext(title: String, url: String, visibleText: String) {
        let compactText = visibleText
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        lastPageContext = SarahWebPageContext(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            visibleText: String(compactText.prefix(24_000))
        )
    }

    fileprivate func browserDidClose(_ browser: SarahWebBrowserViewController) {
        if activeBrowser === browser {
            activeBrowser = nil
        }
    }

    // MARK: - Recherche réseau

    private func fetchDuckDuckGo(query: String, completion: @escaping (String, [WebSearchResult]) -> Void) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&no_redirect=1&skip_disambig=1") else {
            completion("", [])
            return
        }

        urlSession.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion("", []) }
                return
            }

            var results: [WebSearchResult] = []
            let abstract = (json["AbstractText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let abstractURL = (json["AbstractURL"] as? String) ?? ""
            let heading = (json["Heading"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? query
            let abstractSource = (json["AbstractSource"] as? String) ?? "DuckDuckGo"

            if !abstract.isEmpty, !abstractURL.isEmpty {
                results.append(WebSearchResult(
                    title: heading,
                    snippet: abstract,
                    url: abstractURL,
                    sourceName: abstractSource
                ))
            }

            if let topics = json["RelatedTopics"] as? [[String: Any]] {
                for topic in topics.prefix(6) {
                    if let text = topic["Text"] as? String,
                       let firstURL = topic["FirstURL"] as? String,
                       !text.isEmpty,
                       !firstURL.isEmpty {
                        results.append(WebSearchResult(
                            title: String(text.prefix(100)),
                            snippet: text,
                            url: firstURL,
                            sourceName: "DuckDuckGo"
                        ))
                    } else if let nested = topic["Topics"] as? [[String: Any]] {
                        for child in nested.prefix(2) {
                            guard let text = child["Text"] as? String,
                                  let firstURL = child["FirstURL"] as? String else { continue }
                            results.append(WebSearchResult(
                                title: String(text.prefix(100)),
                                snippet: text,
                                url: firstURL,
                                sourceName: "DuckDuckGo"
                            ))
                        }
                    }
                }
            }

            let summary: String
            if !abstract.isEmpty {
                summary = "🌐 **Recherche Web**\n\n\(abstract)"
            } else if let first = results.first {
                summary = "🌐 **Recherche Web**\n\n\(first.snippet)"
            } else {
                summary = ""
            }

            DispatchQueue.main.async {
                completion(summary, Array(results.prefix(8)))
            }
        }.resume()
    }

    // MARK: - Interprétation d'URL

    private func browserURL(for rawQuery: String) -> URL {
        let clean = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if let direct = firstExplicitURL(in: clean) {
            return direct
        }

        if clean.range(of: " ") == nil,
           clean.contains("."),
           let direct = URL(string: clean.hasPrefix("http") ? clean : "https://\(clean)") {
            return direct
        }

        let normalized = normalize(clean)
        if normalized.contains("amazon") {
            let query = removeNavigationWords(from: clean, extraWords: ["amazon"])
            if query.isEmpty, let home = URL(string: "https://www.amazon.fr/") { return home }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.amazon.fr/s?k=\(encoded)") ?? URL(string: "https://www.amazon.fr/")!
        }

        if normalized.contains("google") && !normalized.contains("cherche") && !normalized.contains("recherche") {
            return URL(string: "https://www.google.com/")!
        }

        let query = removeNavigationWords(from: clean, extraWords: ["google"])
        return googleSearchURL(for: query.isEmpty ? clean : query)
    }

    private func googleSearchURL(for query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(encoded)") ?? URL(string: "https://www.google.com/")!
    }

    private func duckDuckGoSearchURL(for query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://duckduckgo.com/?q=\(encoded)") ?? URL(string: "https://duckduckgo.com/")!
    }

    private func firstExplicitURL(in text: String) -> URL? {
        for token in text.components(separatedBy: .whitespacesAndNewlines) {
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",.;()[]{}<>\"'"))
            if (cleaned.hasPrefix("https://") || cleaned.hasPrefix("http://")), let url = URL(string: cleaned) {
                return url
            }
        }
        return nil
    }

    private func removeNavigationWords(from text: String, extraWords: [String]) -> String {
        var result = text
        let words = [
            "ouvre", "ouvrir", "va sur", "vas sur", "navigue sur", "navigateur",
            "cherche", "recherche", "trouve", "moi", "sur", "dans"
        ] + extraWords
        for word in words {
            result = result.replacingOccurrences(of: word, with: " ", options: [.caseInsensitive, .diacriticInsensitive])
        }
        return result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func shouldOpenBrowser(_ normalized: String) -> Bool {
        let browserWords = [
            "ouvre ", "ouvrir ", "va sur ", "vas sur ", "navigue ", "navigateur",
            "ouvre amazon", "sur amazon", "ouvre google", "sur google", "ouvre le site"
        ]
        return browserWords.contains(where: { normalized.contains($0) })
    }

    private func refersToCurrentPage(_ normalized: String) -> Bool {
        let phrases = [
            "cette page", "la page", "ce site", "site actuel", "page actuelle",
            "resume la page", "resume cette page", "qu est ce qu il y a sur cette page",
            "lis cette page", "lis la page", "explique cette page"
        ]
        return phrases.contains(where: { normalized.contains($0) })
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func hostName(from url: String) -> String {
        URL(string: url)?.host ?? "Web"
    }

    // MARK: - Présentation UIKit

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController?
        if let base = base {
            root = base
        } else if #available(iOS 13.0, *) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })
            root = window?.rootViewController
        } else {
            root = UIApplication.shared.keyWindow?.rootViewController
        }

        if let navigation = root as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let tabs = root as? UITabBarController, let selected = tabs.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}

// MARK: - Vrai navigateur intégré

public final class SarahWebBrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {

    private unowned let service: WebSearchService
    private let webView: WKWebView
    private let initialURL: URL
    private let topBar = UIView()
    private let bottomBar = UIView()
    private let addressField = UITextField()
    private let statusLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private let sarahButton = UIButton(type: .system)

    public init(service: WebSearchService, initialURL: URL) {
        self.service = service
        self.initialURL = initialURL

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureWebView()
        configureChrome()
        configureConstraints()
        load(url: initialURL)
    }

    deinit {
        service.browserDidClose(self)
    }

    public func load(url: URL) {
        guard isViewLoaded else { return }
        addressField.text = url.absoluteString
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    private func configureWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        view.addSubview(webView)
    }

    private func configureChrome() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.96)
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.96)
        view.addSubview(topBar)
        view.addSubview(bottomBar)

        let close = UIButton(type: .system)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.setTitle("×", for: .normal)
        close.setTitleColor(.white, for: .normal)
        close.titleLabel?.font = UIFont.systemFont(ofSize: 30, weight: .regular)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(close)

        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressField.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        addressField.textColor = .white
        addressField.tintColor = .white
        addressField.font = UIFont.systemFont(ofSize: 15)
        addressField.layer.cornerRadius = 18
        addressField.layer.masksToBounds = true
        addressField.clearButtonMode = .whileEditing
        addressField.returnKeyType = .go
        addressField.keyboardType = .webSearch
        addressField.autocorrectionType = .no
        addressField.autocapitalizationType = .none
        addressField.placeholder = "Rechercher ou saisir une adresse"
        addressField.delegate = self
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        addressField.leftView = spacer
        addressField.leftViewMode = .always
        topBar.addSubview(addressField)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Sarah · Web"
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.56)
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textAlignment = .center
        topBar.addSubview(statusLabel)

        configureBottomButton(backButton, title: "‹", action: #selector(backTapped))
        configureBottomButton(forwardButton, title: "›", action: #selector(forwardTapped))
        configureBottomButton(reloadButton, title: "↻", action: #selector(reloadTapped))
        configureBottomButton(sarahButton, title: "Sarah", action: #selector(sarahTapped))

        let stack = UIStackView(arrangedSubviews: [backButton, forwardButton, reloadButton, sarahButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        bottomBar.addSubview(stack)

        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 10),
            close.centerYAnchor.constraint(equalTo: addressField.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 38),
            close.heightAnchor.constraint(equalToConstant: 38),

            addressField.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 6),
            addressField.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            addressField.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 9),
            addressField.heightAnchor.constraint(equalToConstant: 38),

            statusLabel.topAnchor.constraint(equalTo: addressField.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: addressField.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: addressField.trailingAnchor),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: topBar.bottomAnchor, constant: -5),

            stack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 4),
            stack.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func configureBottomButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.25), for: .disabled)
        button.titleLabel?.font = UIFont.systemFont(ofSize: title == "Sarah" ? 15 : 27, weight: title == "Sarah" ? .semibold : .regular)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 62),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 54),

            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return true }

        if let url = URL(string: text), let scheme = url.scheme, scheme == "http" || scheme == "https" {
            load(url: url)
        } else if text.contains("."), !text.contains(" "), let url = URL(string: "https://\(text)") {
            load(url: url)
        } else {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            load(url: URL(string: "https://www.google.com/search?q=\(encoded)")!)
        }
        return true
    }

    @objc private func closeTapped() {
        service.browserDidClose(self)
        dismiss(animated: true)
    }

    @objc private func backTapped() {
        if webView.canGoBack { webView.goBack() }
    }

    @objc private func forwardTapped() {
        if webView.canGoForward { webView.goForward() }
    }

    @objc private func reloadTapped() {
        webView.reload()
    }

    @objc private func sarahTapped() {
        capturePageContext(showFeedback: true)
    }

    fileprivate func confirmAgentAction(
        description: String,
        javascript: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let alert = UIAlertController(
            title: "Autoriser Sarah ?",
            message: "Sarah veut : \(description)\n\nCette action peut modifier la page, un formulaire, un compte ou un panier.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Refuser", style: .cancel) { _ in
            completion(false, "Action refusée.")
        })
        alert.addAction(UIAlertAction(title: "Autoriser", style: .default) { [weak self] _ in
            guard let self = self else {
                completion(false, "Navigateur fermé.")
                return
            }
            self.webView.evaluateJavaScript(javascript) { _, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    self.capturePageContext(showFeedback: false)
                    completion(true, nil)
                }
            }
        })
        present(alert, animated: true)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        statusLabel.text = "Chargement…"
        updateNavigationButtons()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        addressField.text = webView.url?.absoluteString ?? addressField.text
        statusLabel.text = webView.title?.isEmpty == false ? webView.title : "Sarah · Web"
        updateNavigationButtons()
        capturePageContext(showFeedback: false)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        statusLabel.text = "Impossible de charger la page"
        updateNavigationButtons()
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        statusLabel.text = "Erreur réseau"
        updateNavigationButtons()
    }

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    private func updateNavigationButtons() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }

    private func capturePageContext(showFeedback: Bool) {
        let title = webView.title ?? ""
        let url = webView.url?.absoluteString ?? ""
        webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] value, _ in
            guard let self = self else { return }
            let text = value as? String ?? ""
            self.service.updatePageContext(title: title, url: url, visibleText: text)
            if showFeedback {
                self.statusLabel.text = text.isEmpty ? "Page non lisible" : "Page transmise à Sarah"
            }
        }
    }
}
