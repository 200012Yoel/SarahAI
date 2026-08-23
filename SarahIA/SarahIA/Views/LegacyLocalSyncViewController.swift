import UIKit

/// Contrôleur UIKit 100% Natif de Synchronisation QR Code (iOS 12.0+ / iPhone 5S, 6, 7, 8, etc.) :
/// Permet d'afficher le QR Code de synchronisation et de recevoir les discussions sur iPhone 5S.
public final class LegacyLocalSyncViewController: UIViewController {
    
    // MARK: - Propriétés UI
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    private let qrImageView = UIImageView()
    private let statusLabel = UILabel()
    private let ipInfoLabel = UILabel()
    private let scanButton = UIButton(type: .system)
    private let resultBanner = UILabel()
    
    public var onScanRequested: (() -> Void)?
    public var onSyncCompleted: (() -> Void)?
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        startSyncServer()
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        LocalSyncServerService.shared.stopServer()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // 1. TopBar
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        view.addSubview(topBar)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕ Fermer", for: .normal)
        closeButton.setTitleColor(UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0), for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "📱 Synchronisation QR Code"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        
        // 2. ScrollView & Content Stack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        scrollView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        buildCards()
    }
    
    private func buildCards() {
        // 1. Carte explicative
        let headerCard = createCardView()
        let headerLabel = UILabel()
        headerLabel.numberOfLines = 0
        headerLabel.text = "⚡ Scannez ce QR Code avec l'appareil photo Sarah d'un autre iPhone pour transférer immédiatement toutes les discussions et souvenirs."
        headerLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        headerLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        headerCard.addSubview(headerLabel)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 12),
            headerLabel.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -12),
            headerLabel.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 14),
            headerLabel.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -14)
        ])
        contentStack.addArrangedSubview(headerCard)
        
        // 2. Carte QR Code
        let qrCard = createCardView()
        let qrContainer = UIStackView()
        qrContainer.axis = .vertical
        qrContainer.alignment = .center
        qrContainer.spacing = 14
        qrContainer.translatesAutoresizingMaskIntoConstraints = false
        qrCard.addSubview(qrContainer)
        
        let whiteBg = UIView()
        whiteBg.backgroundColor = .white
        whiteBg.layer.cornerRadius = 16
        whiteBg.clipsToBounds = true
        whiteBg.translatesAutoresizingMaskIntoConstraints = false
        whiteBg.widthAnchor.constraint(equalToConstant: 220).isActive = true
        whiteBg.heightAnchor.constraint(equalToConstant: 220).isActive = true
        
        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.contentMode = .scaleAspectFit
        whiteBg.addSubview(qrImageView)
        NSLayoutConstraint.activate([
            qrImageView.centerXAnchor.constraint(equalTo: whiteBg.centerXAnchor),
            qrImageView.centerYAnchor.constraint(equalTo: whiteBg.centerYAnchor),
            qrImageView.widthAnchor.constraint(equalToConstant: 200),
            qrImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        statusLabel.text = "● Démarrage du serveur local..."
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textColor = .yellow
        statusLabel.textAlignment = .center
        
        qrContainer.addArrangedSubview(whiteBg)
        qrContainer.addArrangedSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            qrContainer.topAnchor.constraint(equalTo: qrCard.topAnchor, constant: 16),
            qrContainer.bottomAnchor.constraint(equalTo: qrCard.bottomAnchor, constant: -16),
            qrContainer.leadingAnchor.constraint(equalTo: qrCard.leadingAnchor, constant: 14),
            qrContainer.trailingAnchor.constraint(equalTo: qrCard.trailingAnchor, constant: -14)
        ])
        contentStack.addArrangedSubview(qrCard)
        
        // 3. Carte Réseau
        let netCard = createCardView()
        let netStack = UIStackView()
        netStack.axis = .vertical
        netStack.spacing = 8
        netStack.translatesAutoresizingMaskIntoConstraints = false
        netCard.addSubview(netStack)
        
        let netTitle = UILabel()
        netTitle.text = "🌐 Réseau Local P2P"
        netTitle.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        netTitle.textColor = .white
        
        ipInfoLabel.text = "IP : Recherche en cours..."
        ipInfoLabel.font = UIFont.systemFont(ofSize: 12)
        ipInfoLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        
        netStack.addArrangedSubview(netTitle)
        netStack.addArrangedSubview(ipInfoLabel)
        
        NSLayoutConstraint.activate([
            netStack.topAnchor.constraint(equalTo: netCard.topAnchor, constant: 12),
            netStack.bottomAnchor.constraint(equalTo: netCard.bottomAnchor, constant: -12),
            netStack.leadingAnchor.constraint(equalTo: netCard.leadingAnchor, constant: 14),
            netStack.trailingAnchor.constraint(equalTo: netCard.trailingAnchor, constant: -14)
        ])
        contentStack.addArrangedSubview(netCard)
        
        // 4. Bouton Scan Caméra
        scanButton.setTitle("📷 Scanner un QR Code sur l'autre iPhone", for: .normal)
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        scanButton.backgroundColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        scanButton.layer.cornerRadius = 16
        scanButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(scanButton)
        
        // 5. Bannière de résultat (masquée par défaut)
        resultBanner.numberOfLines = 0
        resultBanner.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        resultBanner.textColor = .white
        resultBanner.backgroundColor = UIColor(red: 0.1, green: 0.25, blue: 0.1, alpha: 0.9)
        resultBanner.layer.cornerRadius = 12
        resultBanner.clipsToBounds = true
        resultBanner.textAlignment = .center
        resultBanner.isHidden = true
        contentStack.addArrangedSubview(resultBanner)
    }
    
    private func createCardView() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 0.8
        v.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        v.clipsToBounds = true
        return v
    }
    
    // MARK: - Logique Serveur & Actions
    
    private func startSyncServer() {
        let ip = LocalSyncServerService.shared.getLocalIPAddress() ?? "Wi-Fi local"
        ipInfoLabel.text = "IP : \(ip) • Port : \(LocalSyncServerService.shared.serverPort)"
        
        LocalSyncServerService.shared.startServer { [weak self] success, qrString, image in
            guard let self = self else { return }
            if success {
                self.qrImageView.image = image
                self.statusLabel.text = "● Serveur local actif & prêt"
                self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
            } else {
                self.statusLabel.text = "● Mode QR Direct actif"
                self.statusLabel.textColor = .yellow
                self.qrImageView.image = image
            }
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func scanButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onScanRequested?()
        }
    }
}
