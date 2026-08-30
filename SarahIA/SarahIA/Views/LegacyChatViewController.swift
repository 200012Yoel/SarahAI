import UIKit
import AVFoundation
import Speech
import WebKit

/// Contrôleur UIKit 100% Natif de Secours (iOS 12 à iOS 14 / iPhone 5s, 6, 6 Plus)
/// avec l'interface EXACTEMENT IDENTIQUE à celle des iPhone 7 et iPhone 14 :
/// - Header avec bouton Hamburger ☰, Capsule d'agent actif (Sarah, Nathan, Esther, Tom, Yohan, Ethel) et Roue crantée ⚙️
/// - Menu latéral (Sidebar) coulissant avec historique des discussions, bouton "＋ Nouveau", sélecteur des 6 agents et bouton Réglages
/// - Geste de glissement universel de gauche vers la droite pour ouvrir le menu
/// - Raccourcis d'actions rapides (Allume la torche, Pikoud HaOref, i24News, WhatsApp)
/// - Barre de saisie Capsule moderne avec +, Champ, Micro, Waveform et Envoi
public final class LegacyChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    // MARK: - Propriétés UI Principales
    
    private let topBar = UIView()
    private let menuButton = UIButton(type: .system)
    private let agentCapsuleButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    
    private let quickActionsScrollView = UIScrollView()
    private let quickActionsStack = UIStackView()
    
    private let tableView = UITableView()
    private let composerContainer = UIView()
    private let plusButton = UIButton(type: .system)
    private let inputTextField = UITextField()
    private let micButton = UIButton(type: .system)
    private let waveformButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    
    // MARK: - Menu Tiroir (Sidebar) Complet
    
    private let drawerOverlay = UIView()
    private let drawerView = UIView()
    private var isDrawerOpen = false
    private var drawerLeadingConstraint: NSLayoutConstraint?
    
    private let drawerHeaderView = UIView()
    private let drawerLogoView = UIView()
    private let drawerTitleLabel = UILabel()
    private let drawerSubtitleLabel = UILabel()
    private let drawerCloseButton = UIButton(type: .system)
    
    private let newChatDrawerButton = UIButton(type: .system)
    private let drawerTableView = UITableView()
    private let drawerSettingsButton = UIButton(type: .system)
    
    // MARK: - Données & États
    
    private var conversations: [Conversation] = []
    private var currentConversationId: UUID? = nil
    private var messages: [Message] = []
    private var activeAgent: AgentType = .sarah
    private var isRecording: Bool = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        loadSavedData()
        setupUI()
        setupDrawer()
        setupGestureRecognizers()
        setupSpeechPipeline()
        
        if messages.isEmpty {
            loadInitialWelcomeMessage()
        }
    }
    
    // MARK: - Chargement des Données
    
    private func loadSavedData() {
        let state = StorageService.shared.loadState()
        self.conversations = state.conversations
        if let currentId = state.currentConversationId,
           let existing = self.conversations.first(where: { $0.id == currentId }) {
            self.currentConversationId = existing.id
            self.messages = existing.messages
        } else if let first = self.conversations.first {
            self.currentConversationId = first.id
            self.messages = first.messages
        } else {
            self.currentConversationId = UUID()
            self.messages = []
        }
    }
    
    private func saveCurrentState() {
        guard let currentId = currentConversationId else { return }
        if let index = conversations.firstIndex(where: { $0.id == currentId }) {
            conversations[index].messages = messages
        } else if !messages.isEmpty {
            let title = messages.first(where: { $0.isFromUser })?.content.prefix(30) ?? "Nouvelle discussion"
            let newConv = Conversation(id: currentId, title: String(title), messages: messages, createdAt: Date())
            conversations.insert(newConv, at: 0)
        }
        
        var state = StorageService.shared.loadState()
        state.conversations = conversations
        state.currentConversationId = currentConversationId
        StorageService.shared.saveState(state)
        drawerTableView.reloadData()
    }
    
    // MARK: - Configuration de l'Interface Principale
    
    private func setupUI() {
        // 1. Topbar
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        view.addSubview(topBar)
        
        // Bouton Hamburger ☰
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "line.3.horizontal") {
            menuButton.setImage(img, for: .normal)
        } else {
            menuButton.setTitle("☰", for: .normal)
        }
        menuButton.tintColor = .white
        menuButton.setTitleColor(.white, for: .normal)
        menuButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        menuButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        menuButton.layer.cornerRadius = 20
        menuButton.addTarget(self, action: #selector(toggleDrawer), for: .touchUpInside)
        topBar.addSubview(menuButton)
        
        // Capsule Agent actif (Centre)
        agentCapsuleButton.translatesAutoresizingMaskIntoConstraints = false
        agentCapsuleButton.backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        agentCapsuleButton.layer.cornerRadius = 16
        agentCapsuleButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        agentCapsuleButton.addTarget(self, action: #selector(showAgentPicker), for: .touchUpInside)
        topBar.addSubview(agentCapsuleButton)
        
        updateAgentCapsuleTitle()
        
        // Bouton Paramètres ⚙️
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "gearshape.fill") {
            settingsButton.setImage(img, for: .normal)
        } else {
            settingsButton.setTitle("⚙️", for: .normal)
        }
        settingsButton.tintColor = .white
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        settingsButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        settingsButton.layer.cornerRadius = 20
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        topBar.addSubview(settingsButton)
        
        // 2. TableView (Fil de discussion)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        view.addSubview(tableView)
        
        // 3. Barre d'actions rapides (Allume la torche, Pikoud HaOref, i24News, WhatsApp)
        quickActionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsScrollView.showsHorizontalScrollIndicator = false
        view.addSubview(quickActionsScrollView)
        
        quickActionsStack.translatesAutoresizingMaskIntoConstraints = false
        quickActionsStack.axis = .horizontal
        quickActionsStack.spacing = 8
        quickActionsScrollView.addSubview(quickActionsStack)
        
        setupQuickActionChips()
        
        // 4. Barre de Saisie Capsule (Bas)
        composerContainer.translatesAutoresizingMaskIntoConstraints = false
        composerContainer.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        composerContainer.layer.cornerRadius = 22
        view.addSubview(composerContainer)
        
        // Bouton Plus ＋
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.setTitle("＋", for: .normal)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        plusButton.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        plusButton.layer.cornerRadius = 16
        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        composerContainer.addSubview(plusButton)
        
        // Champ texte
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: "Demander à \(activeAgent.rawValue)...",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray]
        )
        inputTextField.textColor = .white
        inputTextField.font = UIFont.systemFont(ofSize: 15)
        inputTextField.delegate = self
        inputTextField.returnKeyType = .send
        composerContainer.addSubview(inputTextField)
        
        // Bouton Micro 🎤
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setTitle("🎤", for: .normal)
        micButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        composerContainer.addSubview(micButton)
        
        // Bouton Waveform 〰️
        waveformButton.translatesAutoresizingMaskIntoConstraints = false
        waveformButton.setTitle("〰️", for: .normal)
        waveformButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        waveformButton.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        waveformButton.layer.cornerRadius = 16
        waveformButton.addTarget(self, action: #selector(waveformTapped), for: .touchUpInside)
        composerContainer.addSubview(waveformButton)
        
        // Bouton Envoi ⬆️
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("⬆️", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        sendButton.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        sendButton.layer.cornerRadius = 16
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        composerContainer.addSubview(sendButton)
        
        // Contraintes AutoLayout
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 54),
            
            menuButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            menuButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40),
            
            agentCapsuleButton.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            agentCapsuleButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            agentCapsuleButton.heightAnchor.constraint(equalToConstant: 34),
            
            settingsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -14),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 40),
            settingsButton.heightAnchor.constraint(equalToConstant: 40),
            
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: quickActionsScrollView.topAnchor, constant: -6),
            
            quickActionsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            quickActionsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            quickActionsScrollView.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -8),
            quickActionsScrollView.heightAnchor.constraint(equalToConstant: 36),
            
            quickActionsStack.topAnchor.constraint(equalTo: quickActionsScrollView.topAnchor),
            quickActionsStack.leadingAnchor.constraint(equalTo: quickActionsScrollView.leadingAnchor),
            quickActionsStack.trailingAnchor.constraint(equalTo: quickActionsScrollView.trailingAnchor),
            quickActionsStack.bottomAnchor.constraint(equalTo: quickActionsScrollView.bottomAnchor),
            quickActionsStack.heightAnchor.constraint(equalTo: quickActionsScrollView.heightAnchor),
            
            composerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            composerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            composerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            composerContainer.heightAnchor.constraint(equalToConstant: 46),
            
            plusButton.leadingAnchor.constraint(equalTo: composerContainer.leadingAnchor, constant: 6),
            plusButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 32),
            plusButton.heightAnchor.constraint(equalToConstant: 32),
            
            inputTextField.leadingAnchor.constraint(equalTo: plusButton.trailingAnchor, constant: 10),
            inputTextField.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -6),
            inputTextField.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            
            micButton.trailingAnchor.constraint(equalTo: waveformButton.leadingAnchor, constant: -6),
            micButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 32),
            micButton.heightAnchor.constraint(equalToConstant: 32),
            
            waveformButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -6),
            waveformButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            waveformButton.widthAnchor.constraint(equalToConstant: 32),
            waveformButton.heightAnchor.constraint(equalToConstant: 32),
            
            sendButton.trailingAnchor.constraint(equalTo: composerContainer.trailingAnchor, constant: -6),
            sendButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupQuickActionChips() {
        let chip1 = createChip(title: "🔦 Allume la torche", color: UIColor(white: 0.18, alpha: 1.0)) { [weak self] in
            _ = DeviceController.shared.toggleTorch(enable: nil)
        }
        let chip2 = createChip(title: "🚨 Pikoud HaOref", color: UIColor(red: 0.40, green: 0.10, blue: 0.12, alpha: 1.0)) { [weak self] in
            self?.sendMessage("Alertes Pikoud HaOref")
        }
        let chip3 = createChip(title: "📰 i24news", color: UIColor(red: 0.10, green: 0.25, blue: 0.50, alpha: 1.0)) { [weak self] in
            self?.sendMessage("Actualités i24news")
        }
        let chip4 = createChip(title: "💬 WhatsApp", color: UIColor(red: 0.10, green: 0.45, blue: 0.20, alpha: 1.0)) { [weak self] in
            self?.activeAgent = .nathan
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Nathan, je veux poster une vidéo sur mon statut WhatsApp")
        }
        
        quickActionsStack.addArrangedSubview(chip1)
        quickActionsStack.addArrangedSubview(chip2)
        quickActionsStack.addArrangedSubview(chip3)
        quickActionsStack.addArrangedSubview(chip4)
    }
    
    private func createChip(title: String, color: UIColor, action: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        
        let actionHandler = UIActionHandler(action: action)
        btn.addTarget(actionHandler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
        return btn
    }
    
    private func updateAgentCapsuleTitle() {
        let title = "● \(activeAgent.rawValue) ▼"
        agentCapsuleButton.setTitle(title, for: .normal)
        agentCapsuleButton.setTitleColor(.white, for: .normal)
        agentCapsuleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: "Demander à \(activeAgent.rawValue)...",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray]
        )
    }
    
    // MARK: - Configuration Complète du Menu Latéral (Sidebar)
    
    private func setupDrawer() {
        // Voile sombre
        drawerOverlay.translatesAutoresizingMaskIntoConstraints = false
        drawerOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        drawerOverlay.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(closeDrawerAnimated))
        drawerOverlay.addGestureRecognizer(tap)
        view.addSubview(drawerOverlay)
        
        // Conteneur du menu
        drawerView.translatesAutoresizingMaskIntoConstraints = false
        drawerView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        view.addSubview(drawerView)
        
        let drawerWidth = min(view.bounds.width * 0.84, 330)
        drawerLeadingConstraint = drawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -drawerWidth)
        
        // En-tête du tiroir
        drawerHeaderView.translatesAutoresizingMaskIntoConstraints = false
        drawerView.addSubview(drawerHeaderView)
        
        drawerLogoView.translatesAutoresizingMaskIntoConstraints = false
        drawerLogoView.backgroundColor = UIColor(red: 1.0, green: 0.18, blue: 0.65, alpha: 1.0)
        drawerLogoView.layer.cornerRadius = 10
        drawerHeaderView.addSubview(drawerLogoView)
        
        let sLabel = UILabel()
        sLabel.translatesAutoresizingMaskIntoConstraints = false
        sLabel.text = "S"
        sLabel.font = UIFont.boldSystemFont(ofSize: 18)
        sLabel.textColor = .white
        drawerLogoView.addSubview(sLabel)
        
        drawerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        drawerTitleLabel.text = "Sarah IA"
        drawerTitleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        drawerTitleLabel.textColor = .white
        drawerHeaderView.addSubview(drawerTitleLabel)
        
        drawerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        drawerSubtitleLabel.text = "Multi-Agents Intelligents"
        drawerSubtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        drawerSubtitleLabel.textColor = .gray
        drawerHeaderView.addSubview(drawerSubtitleLabel)
        
        drawerCloseButton.translatesAutoresizingMaskIntoConstraints = false
        drawerCloseButton.setTitle("✕", for: .normal)
        drawerCloseButton.setTitleColor(.white, for: .normal)
        drawerCloseButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        drawerCloseButton.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        drawerCloseButton.layer.cornerRadius = 16
        drawerCloseButton.addTarget(self, action: #selector(closeDrawerAnimated), for: .touchUpInside)
        drawerHeaderView.addSubview(drawerCloseButton)
        
        // Bouton ＋ Nouveau Chat
        newChatDrawerButton.translatesAutoresizingMaskIntoConstraints = false
        newChatDrawerButton.setTitle("＋  Nouvelle discussion", for: .normal)
        newChatDrawerButton.setTitleColor(.white, for: .normal)
        newChatDrawerButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        newChatDrawerButton.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.20)
        newChatDrawerButton.layer.cornerRadius = 12
        newChatDrawerButton.addTarget(self, action: #selector(startNewChat), for: .touchUpInside)
        drawerView.addSubview(newChatDrawerButton)
        
        // TableView des discussions & agents
        drawerTableView.translatesAutoresizingMaskIntoConstraints = false
        drawerTableView.backgroundColor = .clear
        drawerTableView.separatorStyle = .singleLine
        drawerTableView.separatorColor = UIColor(white: 0.15, alpha: 1.0)
        drawerTableView.dataSource = self
        drawerTableView.delegate = self
        drawerView.addSubview(drawerTableView)
        
        // Bouton Réglages du bas
        drawerSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        drawerSettingsButton.setTitle("⚙️  Réglages de l'application", for: .normal)
        drawerSettingsButton.setTitleColor(.white, for: .normal)
        drawerSettingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        drawerSettingsButton.backgroundColor = UIColor(white: 0.14, alpha: 1.0)
        drawerSettingsButton.layer.cornerRadius = 12
        drawerSettingsButton.addTarget(self, action: #selector(openSettingsFromDrawer), for: .touchUpInside)
        drawerView.addSubview(drawerSettingsButton)
        
        NSLayoutConstraint.activate([
            drawerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            drawerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            drawerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            drawerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            drawerView.topAnchor.constraint(equalTo: view.topAnchor),
            drawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            drawerView.widthAnchor.constraint(equalToConstant: drawerWidth),
            drawerLeadingConstraint!,
            
            drawerHeaderView.topAnchor.constraint(equalTo: drawerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            drawerHeaderView.leadingAnchor.constraint(equalTo: drawerView.leadingAnchor, constant: 16),
            drawerHeaderView.trailingAnchor.constraint(equalTo: drawerView.trailingAnchor, constant: -16),
            drawerHeaderView.heightAnchor.constraint(equalToConstant: 44),
            
            drawerLogoView.leadingAnchor.constraint(equalTo: drawerHeaderView.leadingAnchor),
            drawerLogoView.centerYAnchor.constraint(equalTo: drawerHeaderView.centerYAnchor),
            drawerLogoView.widthAnchor.constraint(equalToConstant: 36),
            drawerLogoView.heightAnchor.constraint(equalToConstant: 36),
            
            sLabel.centerXAnchor.constraint(equalTo: drawerLogoView.centerXAnchor),
            sLabel.centerYAnchor.constraint(equalTo: drawerLogoView.centerYAnchor),
            
            drawerTitleLabel.leadingAnchor.constraint(equalTo: drawerLogoView.trailingAnchor, constant: 10),
            drawerTitleLabel.topAnchor.constraint(equalTo: drawerLogoView.topAnchor, constant: 1),
            
            drawerSubtitleLabel.leadingAnchor.constraint(equalTo: drawerLogoView.trailingAnchor, constant: 10),
            drawerSubtitleLabel.bottomAnchor.constraint(equalTo: drawerLogoView.bottomAnchor, constant: -1),
            
            drawerCloseButton.trailingAnchor.constraint(equalTo: drawerHeaderView.trailingAnchor),
            drawerCloseButton.centerYAnchor.constraint(equalTo: drawerHeaderView.centerYAnchor),
            drawerCloseButton.widthAnchor.constraint(equalToConstant: 32),
            drawerCloseButton.heightAnchor.constraint(equalToConstant: 32),
            
            newChatDrawerButton.topAnchor.constraint(equalTo: drawerHeaderView.bottomAnchor, constant: 14),
            newChatDrawerButton.leadingAnchor.constraint(equalTo: drawerView.leadingAnchor, constant: 16),
            newChatDrawerButton.trailingAnchor.constraint(equalTo: drawerView.trailingAnchor, constant: -16),
            newChatDrawerButton.heightAnchor.constraint(equalToConstant: 40),
            
            drawerTableView.topAnchor.constraint(equalTo: newChatDrawerButton.bottomAnchor, constant: 12),
            drawerTableView.leadingAnchor.constraint(equalTo: drawerView.leadingAnchor),
            drawerTableView.trailingAnchor.constraint(equalTo: drawerView.trailingAnchor),
            drawerTableView.bottomAnchor.constraint(equalTo: drawerSettingsButton.topAnchor, constant: -10),
            
            drawerSettingsButton.leadingAnchor.constraint(equalTo: drawerView.leadingAnchor, constant: 16),
            drawerSettingsButton.trailingAnchor.constraint(equalTo: drawerView.trailingAnchor, constant: -16),
            drawerSettingsButton.bottomAnchor.constraint(equalTo: drawerView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            drawerSettingsButton.heightAnchor.constraint(equalToConstant: 42)
        ])
    }
    
    // MARK: - Gestes Universels de Glissement (Gauche vers la Droite)
    
    private func setupGestureRecognizers() {
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleScreenEdgePan(_:)))
        edgePan.edges = .left
        view.addGestureRecognizer(edgePan)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(closeDrawerAnimated))
        swipeLeft.direction = .left
        drawerView.addGestureRecognizer(swipeLeft)
    }
    
    @objc private func handleScreenEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        let drawerWidth = min(view.bounds.width * 0.84, 330)
        
        if recognizer.state == .changed {
            if translation.x > 0 {
                let progress = min(translation.x / drawerWidth, 1.0)
                drawerLeadingConstraint?.constant = -drawerWidth + (progress * drawerWidth)
                drawerOverlay.alpha = progress
                view.layoutIfNeeded()
            }
        } else if recognizer.state == .ended || recognizer.state == .cancelled {
            if translation.x > drawerWidth * 0.35 {
                openDrawerAnimated()
            } else {
                closeDrawerAnimated()
            }
        }
    }
    
    @objc private func toggleDrawer() {
        HapticService.shared.buttonTap()
        if isDrawerOpen {
            closeDrawerAnimated()
        } else {
            openDrawerAnimated()
        }
    }
    
    @objc private func openDrawerAnimated() {
        isDrawerOpen = true
        drawerLeadingConstraint?.constant = 0
        drawerTableView.reloadData()
        
        UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseOut], animations: {
            self.drawerOverlay.alpha = 1.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc private func closeDrawerAnimated() {
        isDrawerOpen = false
        let drawerWidth = min(view.bounds.width * 0.84, 330)
        drawerLeadingConstraint?.constant = -drawerWidth
        
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseIn], animations: {
            self.drawerOverlay.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc private func startNewChat() {
        HapticService.shared.buttonTap()
        saveCurrentState()
        
        self.currentConversationId = UUID()
        self.messages = []
        loadInitialWelcomeMessage()
        closeDrawerAnimated()
    }
    
    @objc private func openSettingsFromDrawer() {
        closeDrawerAnimated()
        openSettings()
    }
    
    // MARK: - Actions & Menus
    
    @objc private func showAgentPicker() {
        HapticService.shared.buttonTap()
        let alert = UIAlertController(title: "Sélectionner un Agent", message: "Choisissez l'agent actif :", preferredStyle: .actionSheet)
        
        for agent in AgentType.allCases {
            alert.addAction(UIAlertAction(title: "\(agent.rawValue) — \(agent.roleDescription)", style: .default, handler: { [weak self] _ in
                self?.activeAgent = agent
                self?.updateAgentCapsuleTitle()
                self?.drawerTableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func openSettings() {
        HapticService.shared.buttonTap()
        let alert = UIAlertController(
            title: "⚙️ Réglages & Modes",
            message: "Agent Actif: \(activeAgent.rawValue)\nModèle: Sarah Neural Core Flagship v4\nVoix: Siri Apple Natif",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Nouvelle discussion", style: .default, handler: { [weak self] _ in
            self?.startNewChat()
        }))
        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func plusTapped() {
        HapticService.shared.buttonTap()
        let alert = UIAlertController(title: "Actions Multi-Agents", message: "Sélectionnez une action :", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "💬 Nathan — Vidéo & Statut WhatsApp", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .nathan
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Nathan, je veux mettre une vidéo sur mon statut WhatsApp")
        }))
        alert.addAction(UIAlertAction(title: "💻 Esther — Studio VAI Coding & Build", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .esther
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Esther, crée une interface interactive")
        }))
        alert.addAction(UIAlertAction(title: "🌍 Tom — Histoire & Géopolitique", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .tom
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Tom, analyse la situation géopolitique")
        }))
        alert.addAction(UIAlertAction(title: "🇮🇱 Yohan — Traduction Hébreu ⇄ Français", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .yohan
            self?.updateAgentCapsuleTitle()
            self?.inputTextField.text = "Comment on dit en hébreu : "
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "✨ Ethel — Créativité & Modules", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .ethel
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Bonjour Ethel ! Raconte-moi ce que tu prépares.")
        }))
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func waveformTapped() {
        HapticService.shared.buttonTap()
        MultiAgentVoiceManager.shared.speak(text: "Je suis à votre écoute avec ma voix Siri.", for: activeAgent)
    }
    
    private func setupSpeechPipeline() {
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] text in
            self?.sendMessage(text)
        }
    }
    
    private func loadInitialWelcomeMessage() {
        let welcome = Message(
            content: "Bonjour ! 👋 Je suis **Sarah**, votre patronne et assistante IA. Dites-moi simplement « *Passe-moi Tom* », « *Passe-moi Esther* », « *Donne-moi Yoann* », « *Passe-moi Nathan* » ou « *Passe-moi Ethel* » pour basculer à tout moment !",
            isFromUser: false
        )
        messages.append(welcome)
        tableView.reloadData()
    }
    
    @objc private func micTapped() {
        HapticService.shared.buttonTap()
        if isRecording {
            AppleSpeechRecognizer.shared.stopListening()
            isRecording = false
            micButton.setTitle("🎤", for: .normal)
        } else {
            AppleSpeechRecognizer.shared.startListening()
            isRecording = true
            micButton.setTitle("🔴", for: .normal)
        }
    }
    
    @objc private func sendTapped() {
        guard let text = inputTextField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sendMessage(text)
        inputTextField.text = ""
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        textField.resignFirstResponder()
        return true
    }
    
    private func sendMessage(_ text: String) {
        let userMsg = Message(content: text, isFromUser: true)
        messages.append(userMsg)
        tableView.reloadData()
        scrollToBottom()
        saveCurrentState()
        
        MultiAgentCoordinator.shared.routeAndProcess(query: text, currentAgent: activeAgent) { [weak self] response in
            guard let self = self else { return }
            self.activeAgent = response.agent
            self.updateAgentCapsuleTitle()
            
            let aiMsg = Message(content: response.text, isFromUser: false)
            self.messages.append(aiMsg)
            self.tableView.reloadData()
            self.scrollToBottom()
            self.saveCurrentState()
            
            MultiAgentVoiceManager.shared.speak(text: response.spokenText, for: response.agent)
        }
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    // MARK: - UITableViewDataSource & Delegate (Fil de Discussion + Drawer)
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == self.tableView {
            return 1
        } else {
            // Drawer a 2 sections : 1. Écosystème des 6 Agents, 2. Discussions Récentes
            return 2
        }
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tableView {
            return messages.count
        } else {
            if section == 0 {
                return AgentType.allCases.count
            } else {
                return conversations.count
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == self.drawerTableView {
            return section == 0 ? "AGENTS IA" : "DISCUSSIONS RÉCENTES"
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor(white: 0.55, alpha: 1.0)
            header.textLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == self.tableView {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            let msg = messages[indexPath.row]
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            
            let bubble = UIView()
            bubble.translatesAutoresizingMaskIntoConstraints = false
            bubble.layer.cornerRadius = 14
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 15)
            label.textColor = .white
            label.text = msg.content
            bubble.addSubview(label)
            
            cell.contentView.addSubview(bubble)
            
            if msg.isFromUser {
                bubble.backgroundColor = UIColor(red: 0.15, green: 0.50, blue: 0.95, alpha: 1.0)
                NSLayoutConstraint.activate([
                    bubble.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -14),
                    bubble.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                    bubble.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                    bubble.leadingAnchor.constraint(greaterThanOrEqualTo: cell.contentView.leadingAnchor, constant: 60),
                    
                    label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
                    label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
                    label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
                    label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12)
                ])
            } else {
                bubble.backgroundColor = UIColor(white: 0.14, alpha: 1.0)
                NSLayoutConstraint.activate([
                    bubble.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 14),
                    bubble.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                    bubble.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                    bubble.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -60),
                    
                    label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
                    label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
                    label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
                    label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12)
                ])
            }
            
            return cell
        } else {
            // Cellule du Menu Latéral (Drawer)
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DrawerCell")
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .white
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            cell.detailTextLabel?.textColor = UIColor.gray
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 11)
            
            if indexPath.section == 0 {
                let agent = AgentType.allCases[indexPath.row]
                let isSelected = (agent == activeAgent)
                cell.textLabel?.text = "\(isSelected ? "● " : "")\(agent.rawValue)"
                cell.textLabel?.textColor = isSelected ? UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0) : .white
                cell.detailTextLabel?.text = agent.roleDescription
            } else {
                let conv = conversations[indexPath.row]
                let isCurrent = (conv.id == currentConversationId)
                cell.textLabel?.text = conv.title
                cell.textLabel?.textColor = isCurrent ? UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0) : .white
                cell.detailTextLabel?.text = "\(conv.messages.count) messages"
            }
            
            return cell
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == self.drawerTableView {
            HapticService.shared.buttonTap()
            tableView.deselectRow(at: indexPath, animated: true)
            
            if indexPath.section == 0 {
                let agent = AgentType.allCases[indexPath.row]
                self.activeAgent = agent
                self.updateAgentCapsuleTitle()
                closeDrawerAnimated()
            } else {
                let selectedConv = conversations[indexPath.row]
                saveCurrentState()
                self.currentConversationId = selectedConv.id
                self.messages = selectedConv.messages
                self.tableView.reloadData()
                self.scrollToBottom()
                closeDrawerAnimated()
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if tableView == self.drawerTableView && indexPath.section == 1 {
            return true
        }
        return false
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if tableView == self.drawerTableView && indexPath.section == 1 && editingStyle == .delete {
            let conv = conversations.remove(at: indexPath.row)
            if currentConversationId == conv.id {
                currentConversationId = conversations.first?.id ?? UUID()
                messages = conversations.first?.messages ?? []
                tableView.reloadData()
            }
            saveCurrentState()
            drawerTableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}

// MARK: - UIActionHandler Helper
private final class UIActionHandler: NSObject {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
    }
    @objc func invoke() {
        action()
    }
}
