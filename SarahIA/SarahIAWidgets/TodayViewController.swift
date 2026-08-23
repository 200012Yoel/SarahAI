import UIKit
import NotificationCenter

/// Contrôleur de Widget Today View 100% Natif iOS 12.0+ (iPhone 5S, 6, 7, 8, etc.) :
/// - Affichage du nombre de discussions et questions posées
/// - Graphique d'activité sur 7 jours avec barres verticales
/// - Compteur de souvenirs mémorisés dans le Brain Vault
/// - Raccourcis rapides interactifs (Vocal 🎙️, Nouveau ➕, Torche 🔦, Batterie 🔋)
public class TodayViewController: UIViewController, NCWidgetProviding {
    
    // MARK: - Éléments UI Principaux
    private let mainStack = UIStackView()
    
    // 1. En-tête (Header)
    private let headerView = UIView()
    private let avatarLabel = UILabel()
    private let titleLabel = UILabel()
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let usageBadge = UILabel()
    
    // 2. Grille de Statistiques (Discussions, Questions, Souvenirs)
    private let statsGrid = UIStackView()
    private let convsCard = UIView()
    private let convsNumberLabel = UILabel()
    private let convsTitleLabel = UILabel()
    
    private let questionsCard = UIView()
    private let questionsNumberLabel = UILabel()
    private let questionsTitleLabel = UILabel()
    
    private let memoriesCard = UIView()
    private let memoriesNumberLabel = UILabel()
    private let memoriesTitleLabel = UILabel()
    
    // 3. Section Dépliée : Graphique d'Activité 7 Jours
    private let expandedContainer = UIView()
    private let graphHeaderLabel = UILabel()
    private let graphStack = UIStackView()
    private var graphBarViews: [UIView] = []
    private var graphLabels: [UILabel] = []
    
    // 4. Dernier message / souvenir
    private let snippetCard = UIView()
    private let snippetLabel = UILabel()
    
    // 5. Boutons d'Action Rapide
    private let actionsStack = UIStackView()
    private var liveTimer: Timer?
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Autoriser le mode compact et déplié sur iOS 10+
        if #available(iOS 10.0, *) {
            extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        } else {
            preferredContentSize = CGSize(width: 0, height: 110)
        }
        
        setupUI()
        setupRealTimeObservers()
        reloadWidgetData()
    }
    
    private func setupRealTimeObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(widgetDataDidChange),
            name: NSNotification.Name("SarahWidgetStatsDidUpdate"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(widgetDataDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Écoute des notifications inter-processus Darwin (iOS 12 Today View)
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let mySelf = Unmanaged<TodayViewController>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    mySelf.reloadWidgetData()
                }
            },
            "com.sarahia.app.widgetupdate" as CFString,
            nil,
            .deliverImmediately
        )
    }
    
    @objc private func widgetDataDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadWidgetData()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadWidgetData()
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.reloadWidgetData()
        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        liveTimer?.invalidate()
        liveTimer = nil
    }
    
    // MARK: - Protocole NCWidgetProviding (iOS 10 - iOS 14+)
    
    @objc public func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            preferredContentSize = CGSize(width: maxSize.width, height: 220)
            expandedContainer.isHidden = false
            snippetCard.isHidden = false
            actionsStack.isHidden = false
        } else {
            preferredContentSize = CGSize(width: maxSize.width, height: 110)
            expandedContainer.isHidden = true
            snippetCard.isHidden = true
            actionsStack.isHidden = true
        }
    }
    
    @objc public func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void) {
        reloadWidgetData()
        completionHandler(.newData)
    }
    
    // MARK: - Configuration UI
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.alignment = .fill
        mainStack.distribution = .fill
        view.addSubview(mainStack)
        
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 6),
            mainStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 10),
            mainStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -10),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -6)
        ])
        
        setupHeader()
        setupStatsGrid()
        setupGraphSection()
        setupSnippetCard()
        setupActionsStack()
        
        // État initial compact
        expandedContainer.isHidden = true
        snippetCard.isHidden = true
        actionsStack.isHidden = true
    }
    
    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 22).isActive = true
        mainStack.addArrangedSubview(headerView)
        
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.text = "👩🏻‍💼"
        avatarLabel.font = UIFont.systemFont(ofSize: 16)
        headerView.addSubview(avatarLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Sarah IA"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        headerView.addSubview(titleLabel)
        
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.backgroundColor = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
        statusDot.layer.cornerRadius = 3.5
        statusDot.clipsToBounds = true
        headerView.addSubview(statusDot)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "En ligne (60 FPS)"
        statusLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        statusLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        headerView.addSubview(statusLabel)
        
        usageBadge.translatesAutoresizingMaskIntoConstraints = false
        usageBadge.text = "85% Actif"
        usageBadge.textColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        usageBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        usageBadge.backgroundColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.15)
        usageBadge.layer.cornerRadius = 4
        usageBadge.clipsToBounds = true
        usageBadge.textAlignment = .center
        headerView.addSubview(usageBadge)
        
        NSLayoutConstraint.activate([
            avatarLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: avatarLabel.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            statusDot.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            statusDot.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 7),
            statusDot.heightAnchor.constraint(equalToConstant: 7),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 4),
            statusLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            usageBadge.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            usageBadge.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            usageBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),
            usageBadge.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
    
    private func setupStatsGrid() {
        statsGrid.translatesAutoresizingMaskIntoConstraints = false
        statsGrid.axis = .horizontal
        statsGrid.spacing = 8
        statsGrid.distribution = .fillEqually
        statsGrid.heightAnchor.constraint(equalToConstant: 58).isActive = true
        mainStack.addArrangedSubview(statsGrid)
        
        configureStatCard(convsCard, numberLabel: convsNumberLabel, titleLabel: convsTitleLabel, title: "Discussions", icon: "💬")
        configureStatCard(questionsCard, numberLabel: questionsNumberLabel, titleLabel: questionsTitleLabel, title: "Questions", icon: "❓")
        configureStatCard(memoriesCard, numberLabel: memoriesNumberLabel, titleLabel: memoriesTitleLabel, title: "Souvenirs", icon: "🧠")
        
        statsGrid.addArrangedSubview(convsCard)
        statsGrid.addArrangedSubview(questionsCard)
        statsGrid.addArrangedSubview(memoriesCard)
    }
    
    private func configureStatCard(_ card: UIView, numberLabel: UILabel, titleLabel: UILabel, title: String, icon: String) {
        card.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.85)
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor(white: 1.0, alpha: 0.1).cgColor
        card.clipsToBounds = true
        
        let iconView = UILabel()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.text = icon
        iconView.font = UIFont.systemFont(ofSize: 12)
        card.addSubview(iconView)
        
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.text = "0"
        numberLabel.textColor = .white
        numberLabel.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        card.addSubview(numberLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = UIColor(white: 0.65, alpha: 1.0)
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            iconView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            
            numberLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            numberLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4)
        ])
    }
    
    private func setupGraphSection() {
        expandedContainer.translatesAutoresizingMaskIntoConstraints = false
        expandedContainer.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 0.85)
        expandedContainer.layer.cornerRadius = 10
        expandedContainer.layer.borderWidth = 0.5
        expandedContainer.layer.borderColor = UIColor(white: 1.0, alpha: 0.1).cgColor
        expandedContainer.clipsToBounds = true
        expandedContainer.heightAnchor.constraint(equalToConstant: 58).isActive = true
        mainStack.addArrangedSubview(expandedContainer)
        
        graphHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        graphHeaderLabel.text = "📊 Activité & Questions (7 jours) :"
        graphHeaderLabel.textColor = UIColor(white: 0.75, alpha: 1.0)
        graphHeaderLabel.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        expandedContainer.addSubview(graphHeaderLabel)
        
        graphStack.translatesAutoresizingMaskIntoConstraints = false
        graphStack.axis = .horizontal
        graphStack.spacing = 6
        graphStack.distribution = .fillEqually
        graphStack.alignment = .bottom
        expandedContainer.addSubview(graphStack)
        
        NSLayoutConstraint.activate([
            graphHeaderLabel.topAnchor.constraint(equalTo: expandedContainer.topAnchor, constant: 4),
            graphHeaderLabel.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 8),
            
            graphStack.topAnchor.constraint(equalTo: graphHeaderLabel.bottomAnchor, constant: 4),
            graphStack.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 8),
            graphStack.trailingAnchor.constraint(equalTo: expandedContainer.trailingAnchor, constant: -8),
            graphStack.bottomAnchor.constraint(equalTo: expandedContainer.bottomAnchor, constant: -4)
        ])
        
        let days = ["L", "M", "M", "J", "V", "S", "D"]
        for (index, day) in days.enumerated() {
            let col = UIStackView()
            col.axis = .vertical
            col.alignment = .center
            col.spacing = 2
            
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            let isToday = (index == days.count - 1)
            bar.backgroundColor = isToday ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0) : UIColor(white: 0.35, alpha: 1.0)
            bar.layer.cornerRadius = 2
            bar.clipsToBounds = true
            bar.widthAnchor.constraint(equalToConstant: 8).isActive = true
            bar.heightAnchor.constraint(equalToConstant: 16).isActive = true
            graphBarViews.append(bar)
            col.addArrangedSubview(bar)
            
            let lbl = UILabel()
            lbl.text = day
            lbl.font = UIFont.systemFont(ofSize: 8, weight: isToday ? .bold : .regular)
            lbl.textColor = isToday ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0) : UIColor(white: 0.5, alpha: 1.0)
            graphLabels.append(lbl)
            col.addArrangedSubview(lbl)
            
            graphStack.addArrangedSubview(col)
        }
    }
    
    private func setupSnippetCard() {
        snippetCard.translatesAutoresizingMaskIntoConstraints = false
        snippetCard.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 0.9)
        snippetCard.layer.cornerRadius = 8
        snippetCard.layer.borderWidth = 0.5
        snippetCard.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        snippetCard.clipsToBounds = true
        snippetCard.heightAnchor.constraint(equalToConstant: 24).isActive = true
        mainStack.addArrangedSubview(snippetCard)
        
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false
        snippetLabel.text = "💡 Sarah : Toujours prête à répondre du tac au tac !"
        snippetLabel.textColor = UIColor(white: 0.85, alpha: 1.0)
        snippetLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        snippetCard.addSubview(snippetLabel)
        
        NSLayoutConstraint.activate([
            snippetLabel.leadingAnchor.constraint(equalTo: snippetCard.leadingAnchor, constant: 8),
            snippetLabel.trailingAnchor.constraint(equalTo: snippetCard.trailingAnchor, constant: -8),
            snippetLabel.centerYAnchor.constraint(equalTo: snippetCard.centerYAnchor)
        ])
    }
    
    private func setupActionsStack() {
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.axis = .horizontal
        actionsStack.spacing = 6
        actionsStack.distribution = .fillEqually
        actionsStack.heightAnchor.constraint(equalToConstant: 28).isActive = true
        mainStack.addArrangedSubview(actionsStack)
        
        let micBtn = createActionButton(title: "🎙️ Parler", color: UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.25), action: #selector(openAppVoice))
        let chatBtn = createActionButton(title: "➕ Nouveau", color: UIColor(red: 0.58, green: 0.20, blue: 0.95, alpha: 0.25), action: #selector(openAppChat))
        let torchBtn = createActionButton(title: "🔦 Torche", color: UIColor(red: 0.95, green: 0.75, blue: 0.0, alpha: 0.25), action: #selector(toggleTorchAction))
        let memoryBtn = createActionButton(title: "🧠 Mémoire", color: UIColor(red: 0.85, green: 0.20, blue: 0.55, alpha: 0.25), action: #selector(openAppMemory))
        
        actionsStack.addArrangedSubview(micBtn)
        actionsStack.addArrangedSubview(chatBtn)
        actionsStack.addArrangedSubview(torchBtn)
        actionsStack.addArrangedSubview(memoryBtn)
    }
    
    private func createActionButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 6
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        btn.clipsToBounds = true
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    // MARK: - Actions Raccourcis
    
    @objc private func openAppVoice() {
        if let url = URL(string: "sarahia://voice") {
            extensionContext?.open(url, completionHandler: nil)
        }
    }
    
    @objc private func openAppChat() {
        if let url = URL(string: "sarahia://newchat") {
            extensionContext?.open(url, completionHandler: nil)
        }
    }
    
    @objc private func openAppMemory() {
        if let url = URL(string: "sarahia://memory") {
            extensionContext?.open(url, completionHandler: nil)
        }
    }
    
    @objc private func toggleTorchAction() {
        if let url = URL(string: "sarahia://torch") {
            extensionContext?.open(url, completionHandler: nil)
        }
    }
    
    // MARK: - Rafraîchissement des Données
    
    private func reloadWidgetData() {
        let stats = SarahWidgetBridge.shared.getStats()
        
        convsNumberLabel.text = SarahWidgetBridge.formatCompactNumber(stats.totalConversations)
        questionsNumberLabel.text = SarahWidgetBridge.formatCompactNumber(stats.totalMessages)
        memoriesNumberLabel.text = SarahWidgetBridge.formatCompactNumber(stats.learnedMemoriesCount)
        usageBadge.text = "\(stats.usagePercentage)% Actif"
        
        // Mise à jour du graphique 7 jours
        let activity = stats.weeklyActivity
        for (index, bar) in graphBarViews.enumerated() {
            let val = index < activity.count ? activity[index] : 4
            let targetHeight = CGFloat(max(6, min(26, val * 2)))
            bar.constraints.first(where: { $0.firstAttribute == .height })?.constant = targetHeight
        }
        
        // Mise à jour du snippet (dernier souvenir ou message)
        if let trigger = stats.lastMemoryTrigger, let resp = stats.lastMemoryResponse {
            snippetLabel.text = "🧠 Souvenir : « \(trigger) » ➔ « \(resp) »"
        } else if let snippet = stats.lastMessageSnippet {
            snippetLabel.text = "💬 Dernier message : « \(snippet) »"
        } else {
            snippetLabel.text = "💡 Astuce : Dites « Apprends papa = au travail » !"
        }
    }
}
