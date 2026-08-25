import UIKit

/// Contrôleur Dashboard des 8 Widgets 100% Natif UIKit (iOS 12.0+ / iPhone 5S, 6, 7, 8, etc.) :
/// Permet à tous les utilisateurs d'iPhone 5S et modèles antérieurs d'avoir un accès complet, fluide et interactif aux 8 widgets.
public final class LegacyWidgetsViewController: UIViewController {
    
    // MARK: - Propriétés UI
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    // Callbacks
    public var onVoiceTapped: (() -> Void)?
    public var onTorchTapped: (() -> Void)?
    public var onMemoryTapped: (() -> Void)?
    public var onScreenShareTapped: (() -> Void)?
    
    private var stats: WidgetStatsData = SarahWidgetBridge.shared.getStats()
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        reloadWidgetsData()
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // 1. Barre Supérieure
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
        titleLabel.text = "📊 8 Widgets Sarah IA"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.setTitle("🔄", for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        topBar.addSubview(refreshButton)
        
        // 2. ScrollView & Stack Contenu
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        scrollView.addSubview(contentStack)
        
        // AutoLayout TopBar & ScrollView
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            refreshButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -14),
            refreshButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -28)
        ])
        
        buildAllWidgets()
    }
    
    // MARK: - Construction des 8 Widgets
    
    private func buildAllWidgets() {
        // En-tête informatif
        let infoCard = createCardView()
        let infoLabel = UILabel()
        infoLabel.numberOfLines = 0
        infoLabel.text = "⚡ Tous les 8 widgets sont actifs et synchronisés en direct avec votre application Sarah IA (iPhone 5S, 6, 7, 8, X jusqu'à 16)."
        infoLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        infoLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        infoCard.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 12),
            infoLabel.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -12),
            infoLabel.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 14),
            infoLabel.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14)
        ])
        contentStack.addArrangedSubview(infoCard)
        
        // 1. Widget Discussions
        contentStack.addArrangedSubview(buildWidget1ConversationsCard())
        
        // 2. Widget Questions
        contentStack.addArrangedSubview(buildWidget2QuestionsCard())
        
        // 3. Widget Sarah Brain / Connaissances
        contentStack.addArrangedSubview(buildWidget3KnowledgeCard())
        
        // 4. Widget Statut Sarah
        contentStack.addArrangedSubview(buildWidget4StatusCard())
        
        // 5. Widget Tom Vision
        contentStack.addArrangedSubview(buildWidget5TomVisionCard())
        
        // 6. Widget Mémoire
        contentStack.addArrangedSubview(buildWidget6MemoryCard())
        
        // 7. Widget Activité Récente
        contentStack.addArrangedSubview(buildWidget7ActivityCard())
        
        // 8. Widget Quick Sarah
        contentStack.addArrangedSubview(buildWidget8QuickSarahCard())
    }
    
    // MARK: - Builders des 8 Widgets
    
    private func buildWidget1ConversationsCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 1, title: "Discussions")
        
        let countLabel = UILabel()
        countLabel.text = "\(stats.totalConversations)"
        countLabel.font = UIFont.systemFont(ofSize: 32, weight: .heavy)
        countLabel.textColor = .white
        
        let subLabel = UILabel()
        subLabel.text = stats.totalConversations <= 1 ? "discussion active" : "discussions actives"
        subLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subLabel.textColor = .gray
        
        let stack = UIStackView(arrangedSubviews: [title, countLabel, subLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget2QuestionsCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 2, title: "Questions Posées")
        
        let countLabel = UILabel()
        countLabel.text = "\(stats.totalMessages)"
        countLabel.font = UIFont.systemFont(ofSize: 32, weight: .heavy)
        countLabel.textColor = .white
        
        let subLabel = UILabel()
        subLabel.text = stats.totalMessages <= 1 ? "question posée à Sarah" : "questions posées à Sarah"
        subLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subLabel.textColor = .gray
        
        let stack = UIStackView(arrangedSubviews: [title, countLabel, subLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget3KnowledgeCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 3, title: "Cerveau & Savoir Sarah")
        
        let countLabel = UILabel()
        countLabel.text = SarahWidgetBridge.formatCompactNumber(stats.knowledgeCount)
        countLabel.font = UIFont.systemFont(ofSize: 32, weight: .heavy)
        countLabel.textColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        
        let subLabel = UILabel()
        subLabel.text = stats.knowledgeCount <= 1 ? "élément de connaissance indexé" : "éléments de connaissances indexés"
        subLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subLabel.textColor = .gray
        
        let stack = UIStackView(arrangedSubviews: [title, countLabel, subLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget4StatusCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 4, title: "Statut Sarah")
        
        let statusRow = UIStackView()
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center
        
        let dot = UIView()
        dot.backgroundColor = stats.sarahStatus == "En réflexion" ? .yellow : (stats.sarahStatus == "Occupée" ? .orange : UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0))
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
        
        let label = UILabel()
        label.text = "● Sarah : \(stats.sarahStatus)"
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        
        statusRow.addArrangedSubview(dot)
        statusRow.addArrangedSubview(label)
        
        let stack = UIStackView(arrangedSubviews: [title, statusRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget5TomVisionCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 5, title: "Tom Vision")
        
        let statusRow = UIStackView()
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center
        
        let dot = UIView()
        dot.backgroundColor = stats.screenSharingActive ? .red : (stats.cameraActive ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0) : .gray)
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
        
        let label = UILabel()
        label.text = "● Tom : \(stats.tomStatus)"
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        
        statusRow.addArrangedSubview(dot)
        statusRow.addArrangedSubview(label)
        
        let stack = UIStackView(arrangedSubviews: [title, statusRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget6MemoryCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 6, title: "Mémoire Sarah (\(stats.learnedMemoriesCount) souvenirs)")
        
        let memLabel = UILabel()
        memLabel.numberOfLines = 2
        if let trig = stats.lastMemoryTrigger, let resp = stats.lastMemoryResponse {
            memLabel.text = "Dernier apprentissage : « \(trig) » ➔ « \(resp) »"
        } else {
            memLabel.text = "Dites « Apprends [mot] » à Sarah pour lui enseigner des souvenirs personnalisés !"
        }
        memLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        memLabel.textColor = UIColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 1.0)
        
        let stack = UIStackView(arrangedSubviews: [title, memLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget7ActivityCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 7, title: "Activité Récente")
        
        let actLabel = UILabel()
        actLabel.numberOfLines = 0
        actLabel.text = "• \(stats.totalMessages) questions posées au total\n• \(stats.learnedMemoriesCount) nouveaux souvenirs mémorisés\n• \(stats.totalConversations) discussions actives"
        actLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        actLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        
        let stack = UIStackView(arrangedSubviews: [title, actLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    private func buildWidget8QuickSarahCard() -> UIView {
        let card = createCardView()
        let title = createSectionHeader(number: 8, title: "Quick Sarah")
        
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        
        let b1 = createActionButton(title: "🎙️ Parler", action: #selector(voiceButtonTapped))
        let b2 = createActionButton(title: "🖥️ Écran", action: #selector(screenShareAction))
        let b3 = createActionButton(title: "🧠 Mémoire", action: #selector(memoryAction))
        row.addArrangedSubview(b1)
        row.addArrangedSubview(b2)
        row.addArrangedSubview(b3)
        
        let stack = UIStackView(arrangedSubviews: [title, row])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }
    
    // MARK: - Utilitaires de Cartes
    
    private func createCardView() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 0.8
        v.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        v.clipsToBounds = true
        return v
    }
    
    private func createSectionHeader(number: Int, title: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 6
        container.alignment = .center
        
        let badge = UILabel()
        badge.text = "#\(number)"
        badge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badge.textColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        badge.backgroundColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.18)
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.widthAnchor.constraint(equalToConstant: 26).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 18).isActive = true
        
        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        lbl.textColor = .white
        
        container.addArrangedSubview(badge)
        container.addArrangedSubview(lbl)
        return container
    }
    
    private func createStatBlock(number: String, label: String) -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        
        let numLabel = UILabel()
        numLabel.text = number
        numLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        numLabel.textColor = .white
        numLabel.textAlignment = .center
        
        let subLabel = UILabel()
        subLabel.text = label
        subLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        subLabel.textColor = .gray
        subLabel.textAlignment = .center
        
        let stack = UIStackView(arrangedSubviews: [numLabel, subLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 60)
        ])
        return v
    }
    
    private func createActionButton(title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        b.backgroundColor = UIColor(white: 0.18, alpha: 0.8)
        b.layer.cornerRadius = 10
        b.heightAnchor.constraint(equalToConstant: 38).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func refreshTapped() {
        reloadWidgetsData()
    }
    
    @objc private func voiceButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onVoiceTapped?()
        }
    }
    
    @objc private func torchAction() {
        _ = DeviceController.shared.toggleTorch(enable: nil)
    }
    
    @objc private func screenShareAction() {
        dismiss(animated: true) { [weak self] in
            self?.onScreenShareTapped?()
        }
    }
    
    @objc private func memoryAction() {
        dismiss(animated: true) { [weak self] in
            self?.onMemoryTapped?()
        }
    }
    
    private func reloadWidgetsData() {
        self.stats = SarahWidgetBridge.shared.getStats()
        // Animation de rafraîchissement
        UIView.animate(withDuration: 0.25, animations: {
            self.refreshButton.transform = CGAffineTransform(rotationAngle: .pi)
        }, completion: { _ in
            self.refreshButton.transform = .identity
        })
    }
}
