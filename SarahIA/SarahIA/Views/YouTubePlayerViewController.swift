import UIKit
import WebKit

/// Contrôleur de lecture vidéo YouTube 100% UIKit & Universel (iOS 12 à 18) :
/// - Lecteur vidéo fluide et réactif sans pub pour iPhone 5S, 6, 7, 8, SE, X, 11, 12, 13, 14, 15, 16
/// - Moteur de recherche intégré par mots-clés
/// - Liste de vidéos suggérées et résultats en dessous du lecteur
/// - Compatible 100% iOS 12.0+ avec gestion de la mémoire optimisée
public final class YouTubePlayerViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, WKNavigationDelegate {
    
    // MARK: - Propriétés UI
    private let topBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let searchBar = UISearchBar()
    
    private var webView: WKWebView!
    private let videoContainer = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .white)
    
    private let tableView = UITableView()
    private var videoResults: [YouTubeVideoItem] = []
    public var initialQuery: String?
    public var currentVideo: YouTubeVideoItem?
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        setupTopBar()
        setupPlayer()
        setupTableView()
        setupConstraints()
        
        if let query = initialQuery, !query.isEmpty {
            searchBar.text = query
            performSearch(query: query)
        } else if let video = currentVideo {
            loadVideo(video)
        } else {
            performSearch(query: "musique relaxante")
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }
    
    // MARK: - Configuration UI
    
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
        view.addSubview(topBar)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕ Fermer", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        closeButton.backgroundColor = UIColor(white: 0.25, alpha: 0.8)
        closeButton.layer.cornerRadius = 14
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "📺 Sarah Vidéos (YouTube)"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        topBar.addSubview(titleLabel)
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self
        searchBar.placeholder = "Rechercher une vidéo ou une musique..."
        searchBar.barStyle = .black
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        if let tf = searchBar.value(forKey: "searchField") as? UITextField {
            tf.textColor = .white
            tf.font = UIFont.systemFont(ofSize: 14)
        }
        view.addSubview(searchBar)
    }
    
    private func setupPlayer() {
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.backgroundColor = .black
        videoContainer.layer.cornerRadius = 12
        videoContainer.clipsToBounds = true
        view.addSubview(videoContainer)
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.navigationDelegate = self
        videoContainer.addSubview(webView)
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        videoContainer.addSubview(loadingIndicator)
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(YouTubeVideoCell.self, forCellReuseIdentifier: "YouTubeCell")
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        let videoHeight: CGFloat = (UIScreen.main.bounds.width > 350) ? 210 : 180
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            closeButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            
            searchBar.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.heightAnchor.constraint(equalToConstant: 44),
            
            videoContainer.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 6),
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            videoContainer.heightAnchor.constraint(equalToConstant: videoHeight),
            
            webView.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            webView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: videoContainer.centerYAnchor),
            
            tableView.topAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions & Logique
    
    @objc private func closeTapped() {
        HapticService.shared.buttonTap()
        dismiss(animated: true, completion: nil)
    }
    
    public func performSearch(query: String) {
        guard !query.isEmpty else { return }
        loadingIndicator.startAnimating()
        
        YouTubeService.shared.searchVideos(query: query) { [weak self] results in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.videoResults = results
            self.tableView.reloadData()
            
            if let first = results.first, self.currentVideo == nil {
                self.loadVideo(first)
            }
        }
    }
    
    public func loadVideo(_ video: YouTubeVideoItem) {
        currentVideo = video
        titleLabel.text = "▶ \(video.title)"
        loadingIndicator.startAnimating()
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        body, html { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; display:flex; justify-content:center; align-items:center; }
        iframe { width:100%; height:100%; border:none; }
        </style>
        </head>
        <body>
        <iframe src="https://www.youtube-nocookie.com/embed/\(video.videoId)?autoplay=1&playsinline=1&rel=0&modestbranding=1" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let text = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            performSearch(query: text)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoResults.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "YouTubeCell", for: indexPath) as! YouTubeVideoCell
        let video = videoResults[indexPath.row]
        let isSelected = video.videoId == currentVideo?.videoId
        cell.configure(with: video, isSelected: isSelected)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 78
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticService.shared.buttonTap()
        let video = videoResults[indexPath.row]
        loadVideo(video)
        tableView.reloadData()
    }
}

// MARK: - Cellule de Liste Vidéo YouTube

final class YouTubeVideoCell: UITableViewCell {
    private let cardView = UIView()
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let channelLabel = UILabel()
    private let playIcon = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0)
        cardView.layer.cornerRadius = 10
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.backgroundColor = .black
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 6
        cardView.addSubview(thumbnailImageView)
        
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playIcon.text = "▶"
        playIcon.textColor = .white
        playIcon.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        thumbnailImageView.addSubview(playIcon)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.numberOfLines = 2
        cardView.addSubview(titleLabel)
        
        channelLabel.translatesAutoresizingMaskIntoConstraints = false
        channelLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        channelLabel.font = UIFont.systemFont(ofSize: 11)
        cardView.addSubview(channelLabel)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            thumbnailImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            thumbnailImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 96),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 54),
            
            playIcon.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor),
            playIcon.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            
            channelLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            channelLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 10),
            channelLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func configure(with video: YouTubeVideoItem, isSelected: Bool) {
        titleLabel.text = video.title
        channelLabel.text = video.channelTitle
        
        if isSelected {
            cardView.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0).cgColor
            cardView.layer.borderWidth = 1.5
            titleLabel.textColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        } else {
            cardView.layer.borderWidth = 0
            titleLabel.textColor = .white
        }
        
        // Téléchargement asynchrone sécurisé de la miniature
        thumbnailImageView.image = nil
        if let url = URL(string: video.thumbnailURL) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.thumbnailImageView.image = img
                    }
                }
            }.resume()
        }
    }
}
