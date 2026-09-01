import UIKit
import AVFoundation
import Speech
import WebKit

/// Contrôleur UIKit 100% Natif de Secours (iOS 12 à iOS 14 / iPhone 5s, 6, 6 Plus)
/// avec l'interface EXACTEMENT IDENTIQUE à celle des iPhone 7 et iPhone 14 :
/// - Header avec bouton Hamburger ☰, Capsule d'agent actif (Sarah, Nathan, Esther, Tom, Yohan, Ethel) et Roue crantée ⚙️
/// - Menu latéral (Sidebar) coulissant fluide avec historique des discussions, bouton "＋ Nouveau", sélecteur des 6 agents et bouton Réglages
/// - Geste universel de glissement gauche -> droite pour ouvrir le menu
/// - Raccourcis d'actions rapides (Allume la torche, Pikoud HaOref, i24News, WhatsApp)
/// - Barre de saisie Capsule moderne avec +, Champ, Micro, Waveform et Envoi
public final class LegacyChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Propriétés UI Principales
    
    private let topBar = UIView()
    private let menuButton = UIButton(type: .system)
    private let agentCapsuleButton = UIButton(type: .system)
    private let clearChatButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    
    private let tableView = UITableView()
    private let composerContainer = UIView()
    private var composerBottomConstraint: NSLayoutConstraint?
    private let inputTextField = UITextField()
    private let micButton = UIButton(type: .system)
    private let waveformButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    
    // MARK: - Menu Tiroir (Sidebar)
    
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
        setupPanGesture()
        setupSpeechPipeline()
        setupKeyboardObservers()
        
        if messages.isEmpty {
            loadInitialWelcomeMessage()
        }
    }
    
    // MARK: - Chargement & Sauvegarde
    
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
            let newConv = Conversation(id: currentId, title: String(title), createdAt: Date(), messages: messages)
            conversations.insert(newConv, at: 0)
        }
        
        var state = StorageService.shared.loadState()
        state.conversations = conversations
        state.currentConversationId = currentConversationId
        StorageService.shared.saveState(state)
        drawerTableView.reloadData()
    }
    
    // MARK: - Configuration Interface
    
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
        menuButton.backgroundColor = UIColor(white: 0.16, alpha: 1.0)
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
        
        // Bouton Effacer / Supprimer la discussion 🗑️
        clearChatButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "trash") {
            clearChatButton.setImage(img, for: .normal)
        } else {
            clearChatButton.setTitle("🗑️", for: .normal)
        }
        clearChatButton.tintColor = UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        clearChatButton.setTitleColor(UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0), for: .normal)
        clearChatButton.backgroundColor = UIColor(white: 0.16, alpha: 1.0)
        clearChatButton.layer.cornerRadius = 18
        clearChatButton.addTarget(self, action: #selector(confirmClearCurrentChat), for: .touchUpInside)
        topBar.addSubview(clearChatButton)
        
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
        settingsButton.backgroundColor = UIColor(white: 0.16, alpha: 1.0)
        settingsButton.layer.cornerRadius = 18
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        topBar.addSubview(settingsButton)
        
        NotificationCenter.default.addObserver(self, selector: #selector(presentVoiceCallModal), name: .sarahPresentVoiceCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(presentWhatsAppVoiceModal), name: .sarahPresentWhatsAppCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleDrawer), name: .sarahToggleSidebar, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: .sarahOpenSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startNewChat), name: .sarahStartNewChat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(confirmClearCurrentChat), name: .sarahClearCurrentChat, object: nil)
        
        // 2. TableView Messages
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        view.addSubview(tableView)
        
        // 3. Barre de Saisie Capsule
        composerContainer.translatesAutoresizingMaskIntoConstraints = false
        composerContainer.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        composerContainer.layer.cornerRadius = 22
        view.addSubview(composerContainer)
        
        // Champ texte étendu naturellement
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
        
        // Micro 🎤
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setTitle("🎤", for: .normal)
        micButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        composerContainer.addSubview(micButton)
        
        // Waveform 〰️
        waveformButton.translatesAutoresizingMaskIntoConstraints = false
        waveformButton.setTitle("〰️", for: .normal)
        waveformButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        waveformButton.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        waveformButton.layer.cornerRadius = 16
        waveformButton.addTarget(self, action: #selector(waveformTapped), for: .touchUpInside)
        composerContainer.addSubview(waveformButton)
        
        // Envoi ⬆️
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("⬆️", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        sendButton.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        sendButton.layer.cornerRadius = 16
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        composerContainer.addSubview(sendButton)
        
        let bottomConstraint = composerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        self.composerBottomConstraint = bottomConstraint
        
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
            
            clearChatButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            clearChatButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            clearChatButton.widthAnchor.constraint(equalToConstant: 36),
            clearChatButton.heightAnchor.constraint(equalToConstant: 36),
            
            settingsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 36),
            settingsButton.heightAnchor.constraint(equalToConstant: 36),
            
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -8),
            
            composerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            composerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bottomConstraint,
            composerContainer.heightAnchor.constraint(equalToConstant: 46),
            
            inputTextField.leadingAnchor.constraint(equalTo: composerContainer.leadingAnchor, constant: 14),
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
    
    // MARK: - Gestion du Clavier & Défilement
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrameVal = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        
        let convertedFrame = view.convert(keyboardFrameVal, from: nil)
        let keyboardHeight = max(0, view.bounds.height - convertedFrame.minY)
        let bottomSafe = view.safeAreaInsets.bottom
        let offset = -(max(keyboardHeight, 216) - bottomSafe + 6)
        
        composerBottomConstraint?.constant = offset
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.scrollToBottom()
        })
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        
        composerBottomConstraint?.constant = -8
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
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
    
    // MARK: - Configuration du Menu Latéral (Sidebar)
    
    private func setupDrawer() {
        drawerOverlay.translatesAutoresizingMaskIntoConstraints = false
        drawerOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        drawerOverlay.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(closeDrawerAnimated))
        drawerOverlay.addGestureRecognizer(tap)
        view.addSubview(drawerOverlay)
        
        drawerView.translatesAutoresizingMaskIntoConstraints = false
        drawerView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        view.addSubview(drawerView)
        
        let drawerWidth = min(view.bounds.width * 0.84, 330)
        drawerLeadingConstraint = drawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -drawerWidth)
        
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
        
        newChatDrawerButton.translatesAutoresizingMaskIntoConstraints = false
        newChatDrawerButton.setTitle("＋  Nouvelle discussion", for: .normal)
        newChatDrawerButton.setTitleColor(.white, for: .normal)
        newChatDrawerButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        newChatDrawerButton.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.20)
        newChatDrawerButton.layer.cornerRadius = 12
        newChatDrawerButton.addTarget(self, action: #selector(startNewChat), for: .touchUpInside)
        drawerView.addSubview(newChatDrawerButton)
        
        drawerTableView.translatesAutoresizingMaskIntoConstraints = false
        drawerTableView.backgroundColor = .clear
        drawerTableView.separatorStyle = .none
        drawerTableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        drawerTableView.sectionHeaderHeight = 0
        drawerTableView.dataSource = self
        drawerTableView.delegate = self
        drawerView.addSubview(drawerTableView)
        
        drawerSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        drawerSettingsButton.setTitle("⚙️  Réglages & Modes", for: .normal)
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
    
    // MARK: - Geste de Glissement (Swipe Left-to-Right)
    
    private func setupPanGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: view)
            if abs(velocity.x) > abs(velocity.y) * 1.1 {
                if !isDrawerOpen {
                    return velocity.x > 0
                } else {
                    return velocity.x < 0
                }
            }
            return false
        }
        return true
    }
    
    @objc private func handlePanGesture(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let velocity = pan.velocity(in: view)
        let drawerWidth = min(view.bounds.width * 0.84, 330)
        
        switch pan.state {
        case .began, .changed:
            if !isDrawerOpen {
                if translation.x > 0 {
                    let progress = min(translation.x / drawerWidth, 1.0)
                    drawerLeadingConstraint?.constant = -drawerWidth + (progress * drawerWidth)
                    drawerOverlay.alpha = progress
                    view.layoutIfNeeded()
                }
            } else {
                if translation.x < 0 {
                    let progress = max(0.0, 1.0 + (translation.x / drawerWidth))
                    drawerLeadingConstraint?.constant = -drawerWidth + (progress * drawerWidth)
                    drawerOverlay.alpha = progress
                    view.layoutIfNeeded()
                }
            }
        case .ended, .cancelled:
            if !isDrawerOpen {
                if translation.x > 60 || velocity.x > 250 {
                    openDrawerAnimated()
                } else {
                    closeDrawerAnimated()
                }
            } else {
                if translation.x < -60 || velocity.x < -250 {
                    closeDrawerAnimated()
                } else {
                    openDrawerAnimated()
                }
            }
        default:
            break
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
        SessionTimeoutManager.shared.recordAppBackgroundTime()
    }
    
    @objc private func confirmClearCurrentChat() {
        HapticService.shared.buttonTap()
        let alert = UIAlertController(
            title: "Effacer la discussion ?",
            message: "Cette action supprimera tous les messages de la conversation active.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Effacer", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            self.messages.removeAll()
            if let cid = self.currentConversationId, let idx = self.conversations.firstIndex(where: { $0.id == cid }) {
                self.conversations[idx].messages.removeAll()
            }
            self.loadInitialWelcomeMessage()
            self.tableView.reloadData()
            self.saveCurrentState()
            HapticService.shared.notificationSuccess()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func openSettingsFromDrawer() {
        closeDrawerAnimated()
        openSettings()
    }
    
    // MARK: - Actions Utilisateur
    
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
        let settingsVC = LegacySettingsViewController(activeAgent: activeAgent)
        settingsVC.onAgentChanged = { [weak self] newAgent in
            self?.activeAgent = newAgent
            self?.updateAgentCapsuleTitle()
            self?.drawerTableView.reloadData()
        }
        settingsVC.onResetConversation = { [weak self] in
            self?.startNewChat()
        }
        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true, completion: nil)
    }
    
    @objc private func presentVoiceCallModal() {
        let callVC = LegacyVoiceCallViewController()
        present(callVC, animated: true, completion: nil)
    }
    
    @objc private func presentWhatsAppVoiceModal() {
        let walkieVC = LegacyWhatsAppVoiceCallViewController()
        present(walkieVC, animated: true, completion: nil)
    }
    
    @objc private func plusTapped() {
        HapticService.shared.buttonTap()
        let alert = UIAlertController(title: "Écosystème Développeur & Multi-Agents", message: "Sélectionnez une action :", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "💬 Talkie-Walkie WhatsApp (Nathan & Yoann)", style: .default, handler: { [weak self] _ in
            if let c = VoiceCallContactManager.shared.contacts.first {
                OpenWAVoiceWalkieTalkieManager.shared.startSession(with: c)
            }
            self?.presentWhatsAppVoiceModal()
        }))
        alert.addAction(UIAlertAction(title: "📞 Appel Vocal WebRTC & Traduction IA", style: .default, handler: { [weak self] _ in
            if WebRTCVoiceCallManager.shared.callState == .idle, let c = VoiceCallContactManager.shared.contacts.first {
                WebRTCVoiceCallManager.shared.startOutboundCall(to: c)
            }
            self?.presentVoiceCallModal()
        }))
        alert.addAction(UIAlertAction(title: "🎨 Générer une Image HD (Flux.1 Open Source)", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Génère une photo de "
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "🎵 Composer une Musique 100% Locale (DSP)", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Génère une musique lo-fi"
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "👁️ Vision & Analyse Multimodale (OCR)", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Analyse cette photo et décris ce que tu vois"
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "💬 Nathan — Statut & Vidéo WhatsApp", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .nathan
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Nathan, je veux mettre une vidéo sur mon statut WhatsApp")
        }))
        alert.addAction(UIAlertAction(title: "📱 Nathan — Publier sur les Réseaux Sociaux", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .nathan
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Nathan, quels sont mes réseaux sociaux connectés ?")
        }))
        alert.addAction(UIAlertAction(title: "🎨 Ethel — Créativité & Studio Graphique", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .ethel
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Bonjour Ethel ! Raconte-moi ce que tu prépares.")
        }))
        alert.addAction(UIAlertAction(title: "🎵 Nathan — Générer une Musique Rapide", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .nathan
            self?.inputTextField.text = "Compose une musique "
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "🤖 Nathan — Meilleurs modèles d'IA", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .nathan
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Quels sont les meilleurs modèles d'IA disponibles en ce moment ?")
        }))
        alert.addAction(UIAlertAction(title: "💻 Studio VAI Coding & Build (Esther)", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .esther
            self?.updateAgentCapsuleTitle()
            self?.sendMessage("Esther, crée une interface interactive")
        }))
        alert.addAction(UIAlertAction(title: "🐙 Se Connecter à GitHub", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .esther
            self?.sendMessage("Connecte-toi à GitHub")
        }))
        alert.addAction(UIAlertAction(title: "📧 Boîte Google Gmail", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .esther
            self?.sendMessage("Ouvre mes mails Gmail")
        }))
        alert.addAction(UIAlertAction(title: "🔮 Ouvrir l'Orbe Vocal Immersif", style: .default, handler: { [weak self] _ in
            self?.waveformTapped()
        }))
        alert.addAction(UIAlertAction(title: "🇮🇱 Traduction Hébreu ⇄ Français (Yohan)", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .yohan
            self?.updateAgentCapsuleTitle()
            self?.inputTextField.text = "Comment on dit en hébreu : "
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "🌍 Débat Géopolitique & Histoire (Tom)", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .tom
            self?.updateAgentCapsuleTitle()
            self?.inputTextField.text = "Raconte-moi l'histoire de "
            self?.inputTextField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: "👑 Parler à Sarah (Pilote)", style: .default, handler: { [weak self] _ in
            self?.activeAgent = .sarah
            self?.updateAgentCapsuleTitle()
            self?.loadInitialWelcomeMessage()
        }))
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func waveformTapped() {
        HapticService.shared.buttonTap()
        if MultiAgentVoiceManager.shared.isSpeaking {
            MultiAgentVoiceManager.shared.stop()
        } else if let lastMsg = messages.last(where: { !$0.isFromUser }) {
            MultiAgentVoiceManager.shared.speak(text: lastMsg.content, for: activeAgent)
        } else {
            MultiAgentVoiceManager.shared.speak(text: "Bonjour ! Je suis Sarah, à votre écoute.", for: activeAgent)
        }
    }
    
    private func setupSpeechPipeline() {
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] text in
            guard let self = self else { return }
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            self.sendMessage(cleaned)
            self.isRecording = false
            self.micButton.setTitle("🎤", for: .normal)
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
        
        // Indicateur visuel immédiat pour l'utilisateur
        let placeholderMsg = Message(content: "⏳ \(activeAgent.rawValue) réfléchit...", isFromUser: false)
        messages.append(placeholderMsg)
        
        tableView.reloadData()
        scrollToBottom()
        saveCurrentState()
        
        let convId = currentConversationId?.uuidString ?? UUID().uuidString
        let userPersisted = SQLiteChatDatabase.PersistedMessage(
            id: userMsg.id.uuidString,
            conversationId: convId,
            agentId: activeAgent.rawValue,
            sender: "user",
            content: text,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            isAudio: false
        )
        SQLiteChatDatabase.shared.insertMessage(userPersisted)
        
        MultiAgentCoordinator.shared.routeAndProcess(query: text, currentAgent: activeAgent) { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.activeAgent = response.agent
                self.updateAgentCapsuleTitle()
                
                // Remplacer le placeholder par la réponse finale de l'IA
                if let lastIndex = self.messages.indices.last, self.messages[lastIndex].id == placeholderMsg.id {
                    self.messages.remove(at: lastIndex)
                }
                
                let responseText = response.text.isEmpty ? "[DEBUG] Le bouton fonctionne, mais le moteur IA n'a pas démarré." : response.text
                let aiMsg = Message(content: responseText, isFromUser: false)
                self.messages.append(aiMsg)
                self.tableView.reloadData()
                self.scrollToBottom()
                self.saveCurrentState()
                
                let aiPersisted = SQLiteChatDatabase.PersistedMessage(
                    id: aiMsg.id.uuidString,
                    conversationId: convId,
                    agentId: response.agent.rawValue,
                    sender: "assistant",
                    content: responseText,
                    timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                    isAudio: false
                )
                SQLiteChatDatabase.shared.insertMessage(aiPersisted)
                
                let spoken = response.spokenText.isEmpty ? responseText : response.spokenText
                MultiAgentVoiceManager.shared.speak(text: spoken, for: response.agent)
            }
        }
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    // MARK: - UITableViewDataSource & Delegate
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tableView {
            return messages.count
        } else {
            return conversations.count
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
            
            let stackView = UIStackView()
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.alignment = .fill
            bubble.addSubview(stackView)
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 15)
            label.textColor = .white
            label.text = msg.content
            stackView.addArrangedSubview(label)
            
            // 1. Support Image Générée (Flux / SDXL)
            if let imageURLStr = msg.detectedImageURL, let imgURL = URL(string: imageURLStr) {
                let imgContainer = UIView()
                imgContainer.translatesAutoresizingMaskIntoConstraints = false
                imgContainer.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
                imgContainer.layer.cornerRadius = 10
                imgContainer.clipsToBounds = true
                
                let imageView = UIImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imgContainer.addSubview(imageView)
                
                NSLayoutConstraint.activate([
                    imgContainer.heightAnchor.constraint(equalToConstant: 180),
                    imageView.topAnchor.constraint(equalTo: imgContainer.topAnchor),
                    imageView.bottomAnchor.constraint(equalTo: imgContainer.bottomAnchor),
                    imageView.leadingAnchor.constraint(equalTo: imgContainer.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: imgContainer.trailingAnchor)
                ])
                
                DispatchQueue.global(qos: .userInitiated).async {
                    if let data = try? Data(contentsOf: imgURL), let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            imageView.image = image
                        }
                    }
                }
                stackView.addArrangedSubview(imgContainer)
            }
            
            // 2. Support Musique Générative Locale (OpenSourceMusicEngine)
            if let musicStyle = msg.detectedMusicStyle {
                let musicCard = UIView()
                musicCard.translatesAutoresizingMaskIntoConstraints = false
                musicCard.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1.0)
                musicCard.layer.cornerRadius = 10
                musicCard.layer.borderColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.3).cgColor
                musicCard.layer.borderWidth = 1
                
                let musicTitle = UILabel()
                musicTitle.translatesAutoresizingMaskIntoConstraints = false
                musicTitle.font = UIFont.systemFont(ofSize: 12, weight: .bold)
                musicTitle.textColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
                musicTitle.text = "🎵 Sarah Music Engine • \(musicStyle)"
                musicCard.addSubview(musicTitle)
                
                let playBtn = UIButton(type: .system)
                playBtn.translatesAutoresizingMaskIntoConstraints = false
                let isCurrentPlaying = OpenSourceMusicEngine.shared.isPlaying
                playBtn.setTitle(isCurrentPlaying ? "⏹️ Arrêter" : "▶️ Écouter le morceau", for: .normal)
                playBtn.setTitleColor(.white, for: .normal)
                playBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
                playBtn.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.25)
                playBtn.layer.cornerRadius = 8
                
                let targetStyle = OpenSourceMusicEngine.MusicStyle.allCases.first(where: { musicStyle.contains($0.rawValue) }) ?? .lofi
                let handler = UIActionHandler {
                    if OpenSourceMusicEngine.shared.isPlaying {
                        OpenSourceMusicEngine.shared.stopMusic()
                        playBtn.setTitle("▶️ Écouter le morceau", for: .normal)
                    } else {
                        OpenSourceMusicEngine.shared.generateAndPlayTrack(style: targetStyle) { success, _ in
                            DispatchQueue.main.async {
                                playBtn.setTitle(success ? "⏹️ Arrêter" : "▶️ Écouter le morceau", for: .normal)
                            }
                        }
                    }
                }
                objc_setAssociatedObject(playBtn, "music_handler", handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                playBtn.addTarget(handler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
                musicCard.addSubview(playBtn)
                
                NSLayoutConstraint.activate([
                    musicTitle.topAnchor.constraint(equalTo: musicCard.topAnchor, constant: 8),
                    musicTitle.leadingAnchor.constraint(equalTo: musicCard.leadingAnchor, constant: 10),
                    musicTitle.trailingAnchor.constraint(equalTo: musicCard.trailingAnchor, constant: -10),
                    
                    playBtn.topAnchor.constraint(equalTo: musicTitle.bottomAnchor, constant: 6),
                    playBtn.leadingAnchor.constraint(equalTo: musicCard.leadingAnchor, constant: 10),
                    playBtn.trailingAnchor.constraint(equalTo: musicCard.trailingAnchor, constant: -10),
                    playBtn.bottomAnchor.constraint(equalTo: musicCard.bottomAnchor, constant: -8),
                    playBtn.heightAnchor.constraint(equalToConstant: 30)
                ])
                stackView.addArrangedSubview(musicCard)
            }
            
            // 3. Support Détection Code HTML & Rendu iPhone Virtuel / WebView
            if let htmlCode = msg.detectedHTMLCode {
                let htmlCard = UIView()
                htmlCard.translatesAutoresizingMaskIntoConstraints = false
                htmlCard.backgroundColor = UIColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1.0)
                htmlCard.layer.cornerRadius = 12
                htmlCard.layer.borderColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.35).cgColor
                htmlCard.layer.borderWidth = 1.2
                
                let cardStack = UIStackView()
                cardStack.translatesAutoresizingMaskIntoConstraints = false
                cardStack.axis = .vertical
                cardStack.spacing = 8
                htmlCard.addSubview(cardStack)
                
                // En-tête
                let hRow = UIView()
                hRow.translatesAutoresizingMaskIntoConstraints = false
                let iconLbl = UILabel()
                iconLbl.translatesAutoresizingMaskIntoConstraints = false
                iconLbl.text = "🌐"
                iconLbl.font = UIFont.systemFont(ofSize: 14)
                hRow.addSubview(iconLbl)
                
                let titleLbl = UILabel()
                titleLbl.translatesAutoresizingMaskIntoConstraints = false
                titleLbl.text = "Code HTML & Web Détecté"
                titleLbl.font = UIFont.systemFont(ofSize: 12, weight: .bold)
                titleLbl.textColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
                hRow.addSubview(titleLbl)
                
                let copyBtn = UIButton(type: .system)
                copyBtn.translatesAutoresizingMaskIntoConstraints = false
                copyBtn.setTitle("Copier", for: .normal)
                copyBtn.setTitleColor(.white, for: .normal)
                copyBtn.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .bold)
                copyBtn.backgroundColor = UIColor(white: 0.20, alpha: 1.0)
                copyBtn.layer.cornerRadius = 6
                let copyHandler = UIActionHandler {
                    UIPasteboard.general.string = htmlCode
                    HapticService.shared.notificationSuccess()
                    copyBtn.setTitle("Copié !", for: .normal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copyBtn.setTitle("Copier", for: .normal)
                    }
                }
                objc_setAssociatedObject(copyBtn, "copy_h", copyHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                copyBtn.addTarget(copyHandler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
                hRow.addSubview(copyBtn)
                
                NSLayoutConstraint.activate([
                    iconLbl.leadingAnchor.constraint(equalTo: hRow.leadingAnchor),
                    iconLbl.centerYAnchor.constraint(equalTo: hRow.centerYAnchor),
                    
                    titleLbl.leadingAnchor.constraint(equalTo: iconLbl.trailingAnchor, constant: 6),
                    titleLbl.centerYAnchor.constraint(equalTo: hRow.centerYAnchor),
                    
                    copyBtn.trailingAnchor.constraint(equalTo: hRow.trailingAnchor),
                    copyBtn.centerYAnchor.constraint(equalTo: hRow.centerYAnchor),
                    copyBtn.widthAnchor.constraint(equalToConstant: 50),
                    copyBtn.heightAnchor.constraint(equalToConstant: 22),
                    hRow.heightAnchor.constraint(equalToConstant: 24)
                ])
                cardStack.addArrangedSubview(hRow)
                
                // Question de Sarah
                let questionLbl = UILabel()
                questionLbl.text = "Veux-tu que j'ouvre ce rendu dans le Simulateur iPhone Virtuel ou dans la WebView standard ?"
                questionLbl.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                questionLbl.textColor = UIColor(white: 0.90, alpha: 1.0)
                questionLbl.numberOfLines = 0
                cardStack.addArrangedSubview(questionLbl)
                
                // Bouton 1 : Ouvrir dans l'iPhone Virtuel
                let iphoneBtn = UIButton(type: .system)
                iphoneBtn.translatesAutoresizingMaskIntoConstraints = false
                iphoneBtn.setTitle("📱  Ouvrir dans l'iPhone Virtuel", for: .normal)
                iphoneBtn.setTitleColor(.white, for: .normal)
                iphoneBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                iphoneBtn.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.90)
                iphoneBtn.layer.cornerRadius = 8
                let iphoneHandler = UIActionHandler { [weak self] in
                    guard let self = self else { return }
                    HapticService.shared.buttonTap()
                    let previewVC = LegacyVirtualIPhoneViewController(htmlContent: htmlCode, initialMode: .virtualIPhone)
                    self.present(previewVC, animated: true, completion: nil)
                }
                objc_setAssociatedObject(iphoneBtn, "iphone_h", iphoneHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                iphoneBtn.addTarget(iphoneHandler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
                iphoneBtn.heightAnchor.constraint(equalToConstant: 34).isActive = true
                cardStack.addArrangedSubview(iphoneBtn)
                
                // Bouton 2 : Ouvrir dans la WebView
                let webBtn = UIButton(type: .system)
                webBtn.translatesAutoresizingMaskIntoConstraints = false
                webBtn.setTitle("🌐  Ouvrir dans le WebView", for: .normal)
                webBtn.setTitleColor(.white, for: .normal)
                webBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                webBtn.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
                webBtn.layer.cornerRadius = 8
                let webHandler = UIActionHandler { [weak self] in
                    guard let self = self else { return }
                    HapticService.shared.buttonTap()
                    let previewVC = LegacyVirtualIPhoneViewController(htmlContent: htmlCode, initialMode: .standardWebView)
                    self.present(previewVC, animated: true, completion: nil)
                }
                objc_setAssociatedObject(webBtn, "web_h", webHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                webBtn.addTarget(webHandler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
                webBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true
                cardStack.addArrangedSubview(webBtn)
                
                NSLayoutConstraint.activate([
                    cardStack.topAnchor.constraint(equalTo: htmlCard.topAnchor, constant: 10),
                    cardStack.leadingAnchor.constraint(equalTo: htmlCard.leadingAnchor, constant: 10),
                    cardStack.trailingAnchor.constraint(equalTo: htmlCard.trailingAnchor, constant: -10),
                    cardStack.bottomAnchor.constraint(equalTo: htmlCard.bottomAnchor, constant: -10)
                ])
                
                stackView.addArrangedSubview(htmlCard)
            }
            
            cell.contentView.addSubview(bubble)
            
            if msg.isFromUser {
                bubble.backgroundColor = UIColor(red: 0.15, green: 0.50, blue: 0.95, alpha: 1.0)
                NSLayoutConstraint.activate([
                    bubble.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -14),
                    bubble.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                    bubble.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                    bubble.leadingAnchor.constraint(greaterThanOrEqualTo: cell.contentView.leadingAnchor, constant: 60),
                    
                    stackView.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
                    stackView.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
                    stackView.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
                    stackView.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12)
                ])
            } else {
                bubble.backgroundColor = UIColor(white: 0.14, alpha: 1.0)
                if msg.isVisionReport {
                    bubble.layer.borderColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.4).cgColor
                    bubble.layer.borderWidth = 1
                }
                NSLayoutConstraint.activate([
                    bubble.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 14),
                    bubble.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                    bubble.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                    bubble.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -60),
                    
                    stackView.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
                    stackView.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
                    stackView.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
                    stackView.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12)
                ])
            }
            
            return cell
        } else {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DrawerCell")
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            
            let conv = conversations[indexPath.row]
            let isCurrent = (conv.id == currentConversationId)
            
            cell.textLabel?.text = "💬  \(conv.title)"
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: isCurrent ? .bold : .medium)
            cell.textLabel?.textColor = isCurrent ? UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0) : .white
            
            cell.detailTextLabel?.text = "\(conv.messages.count) messages"
            cell.detailTextLabel?.textColor = isCurrent ? UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.8) : UIColor(white: 0.60, alpha: 1.0)
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 11)
            
            return cell
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == self.drawerTableView {
            HapticService.shared.buttonTap()
            tableView.deselectRow(at: indexPath, animated: true)
            
            let selectedConv = conversations[indexPath.row]
            saveCurrentState()
            self.currentConversationId = selectedConv.id
            self.messages = selectedConv.messages
            self.tableView.reloadData()
            self.scrollToBottom()
            closeDrawerAnimated()
        }
    }
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return tableView == self.drawerTableView
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if tableView == self.drawerTableView && editingStyle == .delete {
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

// MARK: - Contrôleur Réglages UIKit 100% Natif (Reproduction Fidèle de SettingsView SwiftUI)

public final class LegacySettingsViewController: UIViewController {
    
    public var onAgentChanged: ((AgentType) -> Void)?
    public var onResetConversation: (() -> Void)?
    
    private var activeAgent: AgentType
    
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    // Mode Hero Views
    private let heroAvatarCircle = UIView()
    private let heroIconLabel = UILabel()
    private let heroTitleLabel = UILabel()
    private let heroActiveBadge = UILabel()
    private let heroSubtitleLabel = UILabel()
    private var agentPills: [UIButton] = []
    
    // VAD & Voice
    private let vadValueLabel = UILabel()
    private let speechRateValueLabel = UILabel()
    
    public init(activeAgent: AgentType) {
        self.activeAgent = activeAgent
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.activeAgent = .sarah
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        setupNavigationBar()
        setupScrollView()
        buildAllSections()
    }
    
    private func setupNavigationBar() {
        title = "⚙️ Réglages"
        if let nav = navigationController {
            nav.navigationBar.barTintColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
            nav.navigationBar.tintColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
            nav.navigationBar.isTranslucent = false
            nav.navigationBar.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 17, weight: .bold)
            ]
        }
        
        let okBtn = UIBarButtonItem(title: "OK", style: .done, target: self, action: #selector(dismissSettings))
        okBtn.tintColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        navigationItem.rightBarButtonItem = okBtn
    }
    
    @objc private func dismissSettings() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -30),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func buildAllSections() {
        buildModeSection()
        buildSocialConnectionsSection()
        buildEcosystemSection()
        buildAudioVADSection()
        buildHistoryResetSection()
    }
    
    // MARK: - Section 1 : Mode de Fonctionnement
    private func buildModeSection() {
        let section = createSection(title: "✨ MODE DE FONCTIONNEMENT", titleColor: UIColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1.0))
        let card = createCardView()
        
        // 1. Hero Card
        let heroRow = UIView()
        heroRow.translatesAutoresizingMaskIntoConstraints = false
        
        heroAvatarCircle.translatesAutoresizingMaskIntoConstraints = false
        heroAvatarCircle.backgroundColor = activeAgent.uiColor.withAlphaComponent(0.20)
        heroAvatarCircle.layer.cornerRadius = 21
        heroAvatarCircle.layer.borderColor = activeAgent.uiColor.withAlphaComponent(0.40).cgColor
        heroAvatarCircle.layer.borderWidth = 1.2
        heroRow.addSubview(heroAvatarCircle)
        
        heroIconLabel.translatesAutoresizingMaskIntoConstraints = false
        heroIconLabel.text = agentIconEmoji(activeAgent)
        heroIconLabel.font = UIFont.systemFont(ofSize: 20)
        heroAvatarCircle.addSubview(heroIconLabel)
        
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 3
        heroRow.addSubview(textStack)
        
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .center
        
        heroTitleLabel.text = "Mode \(activeAgent.rawValue)"
        heroTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        heroTitleLabel.textColor = .white
        titleRow.addArrangedSubview(heroTitleLabel)
        
        heroActiveBadge.text = "  ACTIF  "
        heroActiveBadge.font = UIFont.systemFont(ofSize: 10, weight: .black)
        heroActiveBadge.textColor = .black
        heroActiveBadge.backgroundColor = activeAgent.uiColor
        heroActiveBadge.layer.cornerRadius = 8
        heroActiveBadge.clipsToBounds = true
        titleRow.addArrangedSubview(heroActiveBadge)
        titleRow.addArrangedSubview(UIView())
        
        heroSubtitleLabel.text = activeAgent.specialtySubtitle
        heroSubtitleLabel.font = UIFont.systemFont(ofSize: 12)
        heroSubtitleLabel.textColor = UIColor(white: 0.65, alpha: 1.0)
        heroSubtitleLabel.numberOfLines = 2
        
        textStack.addArrangedSubview(titleRow)
        textStack.addArrangedSubview(heroSubtitleLabel)
        
        NSLayoutConstraint.activate([
            heroAvatarCircle.leadingAnchor.constraint(equalTo: heroRow.leadingAnchor),
            heroAvatarCircle.centerYAnchor.constraint(equalTo: heroRow.centerYAnchor),
            heroAvatarCircle.widthAnchor.constraint(equalToConstant: 42),
            heroAvatarCircle.heightAnchor.constraint(equalToConstant: 42),
            
            heroIconLabel.centerXAnchor.constraint(equalTo: heroAvatarCircle.centerXAnchor),
            heroIconLabel.centerYAnchor.constraint(equalTo: heroAvatarCircle.centerYAnchor),
            
            textStack.leadingAnchor.constraint(equalTo: heroAvatarCircle.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: heroRow.trailingAnchor),
            textStack.topAnchor.constraint(equalTo: heroRow.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: heroRow.bottomAnchor)
        ])
        
        // 2. Horizontal Scroll des 6 Agents
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        
        let pillsStack = UIStackView()
        pillsStack.translatesAutoresizingMaskIntoConstraints = false
        pillsStack.axis = .horizontal
        pillsStack.spacing = 8
        scroll.addSubview(pillsStack)
        
        agentPills.removeAll()
        for agent in AgentType.allCases {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.setTitle("\(agentIconEmoji(agent)) \(agent.rawValue)", for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            btn.layer.cornerRadius = 15
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            
            let isSel = (agent == activeAgent)
            btn.backgroundColor = isSel ? agent.uiColor.withAlphaComponent(0.35) : UIColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1.0)
            btn.setTitleColor(isSel ? .white : UIColor.lightGray, for: .normal)
            btn.layer.borderColor = isSel ? agent.uiColor.cgColor : UIColor(white: 1.0, alpha: 0.08).cgColor
            btn.layer.borderWidth = 1.2
            
            let handler = UIActionHandler { [weak self, weak btn] in
                guard let self = self else { return }
                HapticService.shared.buttonTap()
                self.selectAgent(agent)
            }
            objc_setAssociatedObject(btn, "agent_handler", handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            btn.addTarget(handler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
            
            agentPills.append(btn)
            pillsStack.addArrangedSubview(btn)
        }
        
        NSLayoutConstraint.activate([
            pillsStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            pillsStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            pillsStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            pillsStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            pillsStack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])
        
        let cardStack = UIStackView(arrangedSubviews: [heroRow, scroll])
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.axis = .vertical
        cardStack.spacing = 14
        card.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: 34),
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }
    
    private func selectAgent(_ agent: AgentType) {
        activeAgent = agent
        heroTitleLabel.text = "Mode \(agent.rawValue)"
        heroActiveBadge.backgroundColor = agent.uiColor
        heroSubtitleLabel.text = agent.specialtySubtitle
        heroAvatarCircle.backgroundColor = agent.uiColor.withAlphaComponent(0.20)
        heroAvatarCircle.layer.borderColor = agent.uiColor.withAlphaComponent(0.40).cgColor
        heroIconLabel.text = agentIconEmoji(agent)
        
        for (i, a) in AgentType.allCases.enumerated() {
            guard i < agentPills.count else { continue }
            let btn = agentPills[i]
            let isSel = (a == agent)
            btn.backgroundColor = isSel ? a.uiColor.withAlphaComponent(0.35) : UIColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1.0)
            btn.setTitleColor(isSel ? .white : UIColor.lightGray, for: .normal)
            btn.layer.borderColor = isSel ? a.uiColor.cgColor : UIColor(white: 1.0, alpha: 0.08).cgColor
        }
        onAgentChanged?(agent)
    }
    
    // MARK: - Section 2 : Réseaux Sociaux & Connexions
    private func buildSocialConnectionsSection() {
        let section = createSection(title: "🔗 RÉSEAUX SOCIAUX & CONNEXIONS", titleColor: UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0))
        let card = createCardView()
        
        let connections: [(icon: String, name: String, sub: String, isConnected: Bool)] = [
            ("💬", "WhatsApp", "Publication de statuts, vidéos & messages", true),
            ("📸", "Instagram", "Stories, Reels & Directs", false),
            ("🎵", "TikTok", "Vidéos courtes & tendances", false),
            ("▶️", "YouTube", "Recherche de vidéos & streaming", false),
            ("✖️", "Twitter / X", "Veille d'actualités & publications", false),
            ("🐙", "GitHub", "Dépôts, commits & VAI Studio", false),
            ("🌐", "Google & Firebase", "Gmail, Cloud Auth & Base de données", true)
        ]
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        
        for (i, item) in connections.enumerated() {
            let row = createConnectionRow(icon: item.icon, name: item.name, sub: item.sub, isConnected: item.isConnected)
            stack.addArrangedSubview(row)
            if i < connections.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor(white: 1.0, alpha: 0.06)
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(sep)
            }
        }
        
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }
    
    private func createConnectionRow(icon: String, name: String, sub: String, isConnected: Bool) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLbl = UILabel()
        iconLbl.translatesAutoresizingMaskIntoConstraints = false
        iconLbl.text = icon
        iconLbl.font = UIFont.systemFont(ofSize: 22)
        row.addSubview(iconLbl)
        
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2
        row.addSubview(textStack)
        
        let nameLbl = UILabel()
        nameLbl.text = name
        nameLbl.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLbl.textColor = .white
        
        let subLbl = UILabel()
        subLbl.text = sub
        subLbl.font = UIFont.systemFont(ofSize: 11)
        subLbl.textColor = UIColor.gray
        
        textStack.addArrangedSubview(nameLbl)
        textStack.addArrangedSubview(subLbl)
        
        let isActuallyConnected = (name == "WhatsApp") ? WhatsAppGatewayManager.shared.status.isConnected : isConnected
        let pillText = isActuallyConnected ? "Connecté" : "Connecter"
        let pill = createStatusPill(text: pillText, isConnected: isActuallyConnected)
        
        if name == "WhatsApp" {
            let tap = UITapGestureRecognizer(target: self, action: #selector(openWhatsAppGatewayModal))
            row.isUserInteractionEnabled = true
            row.addGestureRecognizer(tap)
            
            let btnHandler = UIActionHandler { [weak self] in
                self?.openWhatsAppGatewayModal()
            }
            objc_setAssociatedObject(pill, "wa_h", btnHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            (pill as? UIButton)?.addTarget(btnHandler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
        }
        
        row.addSubview(pill)
        
        NSLayoutConstraint.activate([
            iconLbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconLbl.widthAnchor.constraint(equalToConstant: 30),
            
            textStack.leadingAnchor.constraint(equalTo: iconLbl.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: pill.leadingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: row.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            
            pill.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            pill.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        return row
    }
    
    @objc private func openWhatsAppGatewayModal() {
        HapticService.shared.buttonTap()
        WhatsAppGatewayManager.shared.startGateway()
        
        let alert = UIAlertController(
            title: "💬 Passerelle WhatsApp Locale",
            message: "Moteur Baileys pur WebSocket actif en local.\nStatut : \(WhatsAppGatewayManager.shared.status.isConnected ? "🟢 Connecté" : "🟡 En attente de scan QR")\n\nSarah peut répondre automatiquement à tous vos messages WhatsApp directement depuis l'iPhone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "🔄 Recharger Session & QR", style: .default, handler: { _ in
            WhatsAppGatewayManager.shared.reloadGateway()
        }))
        if WhatsAppGatewayManager.shared.status.isConnected {
            alert.addAction(UIAlertAction(title: "🔴 Déconnecter", style: .destructive, handler: { _ in
                WhatsAppGatewayManager.shared.logoutAndReset()
            }))
        }
        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func createStatusPill(text: String, isConnected: Bool) -> UIView {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(text, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        btn.layer.cornerRadius = 13
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        
        if isConnected {
            btn.backgroundColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 0.20)
            btn.setTitleColor(UIColor(red: 0.20, green: 0.95, blue: 0.45, alpha: 1.0), for: .normal)
            btn.layer.borderColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 0.40).cgColor
            btn.layer.borderWidth = 1.0
        } else {
            btn.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.15)
            btn.setTitleColor(UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0), for: .normal)
            btn.layer.borderColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.30).cgColor
            btn.layer.borderWidth = 1.0
        }
        return btn
    }
    
    // MARK: - Section 4 : Écosystème des 6 Agents Autonomes
    private func buildEcosystemSection() {
        let section = createSection(title: "👥 ÉCOSYSTÈME DES 6 AGENTS AUTONOMES", titleColor: UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0))
        let card = createCardView()
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        
        for (i, agent) in AgentType.allCases.enumerated() {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = agent.uiColor
            dot.layer.cornerRadius = 5
            row.addSubview(dot)
            
            let tStack = UIStackView()
            tStack.translatesAutoresizingMaskIntoConstraints = false
            tStack.axis = .vertical
            tStack.spacing = 2
            row.addSubview(tStack)
            
            let nameLbl = UILabel()
            nameLbl.text = "\(agent.rawValue) — Voix Siri \(agent.siriVoiceNumber)"
            nameLbl.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            nameLbl.textColor = .white
            
            let subLbl = UILabel()
            subLbl.text = agent.roleDescription
            subLbl.font = UIFont.systemFont(ofSize: 11)
            subLbl.textColor = UIColor.gray
            
            tStack.addArrangedSubview(nameLbl)
            tStack.addArrangedSubview(subLbl)
            
            let speakerBtn = UIButton(type: .system)
            speakerBtn.translatesAutoresizingMaskIntoConstraints = false
            speakerBtn.setTitle("🔊", for: .normal)
            speakerBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            speakerBtn.backgroundColor = UIColor(white: 0.16, alpha: 1.0)
            speakerBtn.layer.cornerRadius = 14
            
            let handler = UIActionHandler {
                HapticService.shared.buttonTap()
                MultiAgentVoiceManager.shared.speak(text: "Bonjour ! Je suis \(agent.rawValue).", for: agent)
            }
            objc_setAssociatedObject(speakerBtn, "speak_handler", handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            speakerBtn.addTarget(handler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
            row.addSubview(speakerBtn)
            
            NSLayoutConstraint.activate([
                dot.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                dot.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10),
                
                tStack.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
                tStack.trailingAnchor.constraint(lessThanOrEqualTo: speakerBtn.leadingAnchor, constant: -8),
                tStack.topAnchor.constraint(equalTo: row.topAnchor),
                tStack.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                
                speakerBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                speakerBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                speakerBtn.widthAnchor.constraint(equalToConstant: 28),
                speakerBtn.heightAnchor.constraint(equalToConstant: 28)
            ])
            
            stack.addArrangedSubview(row)
            if i < AgentType.allCases.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor(white: 1.0, alpha: 0.05)
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(sep)
            }
        }
        
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }
    
    // MARK: - Section 5 : Microphone & Détection Vocale VAD
    private func buildAudioVADSection() {
        let section = createSection(title: "🎙️ MICROPHONE & DÉTECTION VOCALE VAD", titleColor: UIColor(red: 0.70, green: 0.40, blue: 1.0, alpha: 1.0))
        let card = createCardView()
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        
        // Slider VAD
        let vadHeader = UIView()
        let vadTitle = UILabel()
        vadTitle.translatesAutoresizingMaskIntoConstraints = false
        vadTitle.text = "Sensibilité Détection VAD"
        vadTitle.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        vadTitle.textColor = .white
        vadHeader.addSubview(vadTitle)
        
        vadValueLabel.translatesAutoresizingMaskIntoConstraints = false
        vadValueLabel.text = "65%"
        vadValueLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        vadValueLabel.textColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        vadHeader.addSubview(vadValueLabel)
        
        NSLayoutConstraint.activate([
            vadTitle.leadingAnchor.constraint(equalTo: vadHeader.leadingAnchor),
            vadTitle.centerYAnchor.constraint(equalTo: vadHeader.centerYAnchor),
            vadValueLabel.trailingAnchor.constraint(equalTo: vadHeader.trailingAnchor),
            vadValueLabel.centerYAnchor.constraint(equalTo: vadHeader.centerYAnchor),
            vadHeader.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        let vadSlider = UISlider()
        vadSlider.minimumValue = 0.1
        vadSlider.maximumValue = 1.0
        vadSlider.value = 0.65
        vadSlider.tintColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        let vadHandler = UIActionHandler { [weak self, weak vadSlider] in
            guard let self = self, let s = vadSlider else { return }
            self.vadValueLabel.text = "\(Int(s.value * 100))%"
        }
        objc_setAssociatedObject(vadSlider, "vad_h", vadHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        vadSlider.addTarget(vadHandler, action: #selector(UIActionHandler.invoke), for: .valueChanged)
        
        // Slider Voix Siri
        let rateHeader = UIView()
        let rateTitle = UILabel()
        rateTitle.translatesAutoresizingMaskIntoConstraints = false
        rateTitle.text = "Vitesse de Parole Siri"
        rateTitle.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        rateTitle.textColor = .white
        rateHeader.addSubview(rateTitle)
        
        speechRateValueLabel.translatesAutoresizingMaskIntoConstraints = false
        speechRateValueLabel.text = "1.0x"
        speechRateValueLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        speechRateValueLabel.textColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        rateHeader.addSubview(speechRateValueLabel)
        
        NSLayoutConstraint.activate([
            rateTitle.leadingAnchor.constraint(equalTo: rateHeader.leadingAnchor),
            rateTitle.centerYAnchor.constraint(equalTo: rateHeader.centerYAnchor),
            speechRateValueLabel.trailingAnchor.constraint(equalTo: rateHeader.trailingAnchor),
            speechRateValueLabel.centerYAnchor.constraint(equalTo: rateHeader.centerYAnchor),
            rateHeader.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        let rateSlider = UISlider()
        rateSlider.minimumValue = 0.3
        rateSlider.maximumValue = 0.8
        rateSlider.value = 0.52
        rateSlider.tintColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        let rateHandler = UIActionHandler { [weak self, weak rateSlider] in
            guard let self = self, let s = rateSlider else { return }
            let mult = (s.value / 0.52)
            self.speechRateValueLabel.text = String(format: "%.1fx", mult)
        }
        objc_setAssociatedObject(rateSlider, "rate_h", rateHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rateSlider.addTarget(rateHandler, action: #selector(UIActionHandler.invoke), for: .valueChanged)
        
        stack.addArrangedSubview(vadHeader)
        stack.addArrangedSubview(vadSlider)
        stack.addArrangedSubview(rateHeader)
        stack.addArrangedSubview(rateSlider)
        
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }
    
    // MARK: - Section 6 : Historique de Discussion
    private func buildHistoryResetSection() {
        let section = createSection(title: "🧹 HISTORIQUE DE DISCUSSION", titleColor: UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0))
        let card = createCardView()
        
        let resetBtn = UIButton(type: .system)
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        resetBtn.setTitle("🗑️  Réinitialiser la conversation & Vider le cache", for: .normal)
        resetBtn.setTitleColor(UIColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1.0), for: .normal)
        resetBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        resetBtn.backgroundColor = UIColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 0.12)
        resetBtn.layer.cornerRadius = 12
        resetBtn.layer.borderColor = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 0.35).cgColor
        resetBtn.layer.borderWidth = 1.0
        
        let resetHandler = UIActionHandler { [weak self] in
            guard let self = self else { return }
            HapticService.shared.buttonTap()
            let alert = UIAlertController(
                title: "Réinitialiser la discussion ?",
                message: "Cette action effacera les messages actuels et réinitialisera le contexte conversationnel.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Réinitialiser", style: .destructive, handler: { [weak self] _ in
                self?.onResetConversation?()
                self?.dismissSettings()
            }))
            self.present(alert, animated: true, completion: nil)
        }
        objc_setAssociatedObject(resetBtn, "reset_h", resetHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        resetBtn.addTarget(resetHandler, action: #selector(UIActionHandler.invoke), for: .touchUpInside)
        
        card.addSubview(resetBtn)
        NSLayoutConstraint.activate([
            resetBtn.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            resetBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            resetBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            resetBtn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            resetBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }
    
    // MARK: - Helpers UI
    private func createSection(title: String, titleColor: UIColor) -> UIStackView {
        let sec = UIStackView()
        sec.axis = .vertical
        sec.spacing = 8
        
        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        lbl.textColor = titleColor
        lbl.textAlignment = .left
        sec.addArrangedSubview(lbl)
        
        return sec
    }
    
    private func createCardView() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0)
        v.layer.cornerRadius = 14
        v.layer.borderColor = UIColor(white: 1.0, alpha: 0.07).cgColor
        v.layer.borderWidth = 1.0
        return v
    }
    
    private func agentIconEmoji(_ agent: AgentType) -> String {
        switch agent {
        case .sarah:   return "👑"
        case .nathan:  return "⚡"
        case .esther:  return "💻"
        case .tom:     return "🌍"
        case .yohan:   return "🇮🇱"
        case .ethel:   return "🎨"
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

// MARK: - Contrôleur UIKit du Simulateur iPhone Virtuel & Plein Écran WebView

public final class LegacyVirtualIPhoneViewController: UIViewController {
    
    public enum DisplayMode {
        case virtualIPhone
        case standardWebView
    }
    
    private let rawHTML: String
    private var currentMode: DisplayMode
    
    private let topBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let modeSegment = UISegmentedControl(items: ["📱 iPhone Virtuel", "🌐 Plein Écran"])
    private let shareButton = UIButton(type: .system)
    
    private let iphoneFrame = UIView()
    private let iphoneScreen = UIView()
    private let dynamicIslandPill = UIView()
    private let safariBar = UIView()
    private let homeBar = UIView()
    
    private var webView: WKWebView!
    
    public init(htmlContent: String, initialMode: DisplayMode = .virtualIPhone) {
        self.rawHTML = htmlContent
        self.currentMode = initialMode
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        self.rawHTML = ""
        self.currentMode = .virtualIPhone
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        setupTopBar()
        setupWebView()
        setupIPhoneFrame()
        updateLayoutForMode()
    }
    
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        view.addSubview(topBar)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        closeButton.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        closeButton.layer.cornerRadius = 16
        closeButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        modeSegment.selectedSegmentIndex = (currentMode == .virtualIPhone) ? 0 : 1
        modeSegment.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        topBar.addSubview(modeSegment)
        
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.setTitle("📤", for: .normal)
        shareButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        shareButton.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        shareButton.layer.cornerRadius = 16
        shareButton.addTarget(self, action: #selector(shareContent), for: .touchUpInside)
        topBar.addSubview(shareButton)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 48),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            modeSegment.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            modeSegment.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            modeSegment.widthAnchor.constraint(equalToConstant: 240),
            
            shareButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -14),
            shareButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 32),
            shareButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        webView.scrollView.bounces = true
        
        let optimized = HTMLAdaptiveViewportOptimizer.optimizeHTMLForIPhoneScreen(html: rawHTML)
        webView.loadHTMLString(optimized, baseURL: nil)
    }
    
    private func setupIPhoneFrame() {
        iphoneFrame.translatesAutoresizingMaskIntoConstraints = false
        iphoneFrame.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        iphoneFrame.layer.cornerRadius = 38
        iphoneFrame.layer.borderColor = UIColor(white: 0.28, alpha: 1.0).cgColor
        iphoneFrame.layer.borderWidth = 3.0
        iphoneFrame.clipsToBounds = true
        view.addSubview(iphoneFrame)
        
        iphoneScreen.translatesAutoresizingMaskIntoConstraints = false
        iphoneScreen.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        iphoneScreen.layer.cornerRadius = 32
        iphoneScreen.clipsToBounds = true
        iphoneFrame.addSubview(iphoneScreen)
        
        // Status & Dynamic Island
        let statusBar = UIView()
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        iphoneScreen.addSubview(statusBar)
        
        let timeLbl = UILabel()
        timeLbl.translatesAutoresizingMaskIntoConstraints = false
        timeLbl.text = "9:41"
        timeLbl.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        timeLbl.textColor = .white
        statusBar.addSubview(timeLbl)
        
        dynamicIslandPill.translatesAutoresizingMaskIntoConstraints = false
        dynamicIslandPill.backgroundColor = .black
        dynamicIslandPill.layer.cornerRadius = 11
        let diLabel = UILabel()
        diLabel.translatesAutoresizingMaskIntoConstraints = false
        diLabel.text = "● Sarah Web"
        diLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        diLabel.textColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        dynamicIslandPill.addSubview(diLabel)
        statusBar.addSubview(dynamicIslandPill)
        
        // Safari Bar
        safariBar.translatesAutoresizingMaskIntoConstraints = false
        safariBar.backgroundColor = UIColor(white: 0.14, alpha: 1.0)
        safariBar.layer.cornerRadius = 7
        
        let lockLbl = UILabel()
        lockLbl.translatesAutoresizingMaskIntoConstraints = false
        lockLbl.text = "🔒 sarah.local / app.html"
        lockLbl.font = UIFont(name: "Menlo-Bold", size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .medium)
        lockLbl.textColor = UIColor(white: 0.85, alpha: 1.0)
        safariBar.addSubview(lockLbl)
        iphoneScreen.addSubview(safariBar)
        
        // Home Bar
        let homeContainer = UIView()
        homeContainer.translatesAutoresizingMaskIntoConstraints = false
        homeContainer.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        
        homeBar.translatesAutoresizingMaskIntoConstraints = false
        homeBar.backgroundColor = UIColor(white: 1.0, alpha: 0.60)
        homeBar.layer.cornerRadius = 2
        homeContainer.addSubview(homeBar)
        iphoneScreen.addSubview(homeContainer)
        
        NSLayoutConstraint.activate([
            iphoneScreen.topAnchor.constraint(equalTo: iphoneFrame.topAnchor, constant: 5),
            iphoneScreen.leadingAnchor.constraint(equalTo: iphoneFrame.leadingAnchor, constant: 5),
            iphoneScreen.trailingAnchor.constraint(equalTo: iphoneFrame.trailingAnchor, constant: -5),
            iphoneScreen.bottomAnchor.constraint(equalTo: iphoneFrame.bottomAnchor, constant: -5),
            
            statusBar.topAnchor.constraint(equalTo: iphoneScreen.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: iphoneScreen.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: iphoneScreen.trailingAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 34),
            
            timeLbl.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 18),
            timeLbl.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            
            dynamicIslandPill.centerXAnchor.constraint(equalTo: statusBar.centerXAnchor),
            dynamicIslandPill.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            dynamicIslandPill.widthAnchor.constraint(equalToConstant: 90),
            dynamicIslandPill.heightAnchor.constraint(equalToConstant: 22),
            
            diLabel.centerXAnchor.constraint(equalTo: dynamicIslandPill.centerXAnchor),
            diLabel.centerYAnchor.constraint(equalTo: dynamicIslandPill.centerYAnchor),
            
            safariBar.topAnchor.constraint(equalTo: statusBar.bottomAnchor, constant: 2),
            safariBar.leadingAnchor.constraint(equalTo: iphoneScreen.leadingAnchor, constant: 10),
            safariBar.trailingAnchor.constraint(equalTo: iphoneScreen.trailingAnchor, constant: -10),
            safariBar.heightAnchor.constraint(equalToConstant: 24),
            
            lockLbl.centerXAnchor.constraint(equalTo: safariBar.centerXAnchor),
            lockLbl.centerYAnchor.constraint(equalTo: safariBar.centerYAnchor),
            
            homeContainer.leadingAnchor.constraint(equalTo: iphoneScreen.leadingAnchor),
            homeContainer.trailingAnchor.constraint(equalTo: iphoneScreen.trailingAnchor),
            homeContainer.bottomAnchor.constraint(equalTo: iphoneScreen.bottomAnchor),
            homeContainer.heightAnchor.constraint(equalToConstant: 16),
            
            homeBar.centerXAnchor.constraint(equalTo: homeContainer.centerXAnchor),
            homeBar.centerYAnchor.constraint(equalTo: homeContainer.centerYAnchor),
            homeBar.widthAnchor.constraint(equalToConstant: 100),
            homeBar.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
    
    private func updateLayoutForMode() {
        webView.removeFromSuperview()
        
        if currentMode == .virtualIPhone {
            iphoneFrame.isHidden = false
            iphoneScreen.addSubview(webView)
            
            NSLayoutConstraint.activate([
                iphoneFrame.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
                iphoneFrame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                iphoneFrame.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
                iphoneFrame.widthAnchor.constraint(equalTo: iphoneFrame.heightAnchor, multiplier: 390.0 / 844.0),
                
                webView.topAnchor.constraint(equalTo: safariBar.bottomAnchor, constant: 2),
                webView.leadingAnchor.constraint(equalTo: iphoneScreen.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: iphoneScreen.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: iphoneScreen.subviews.last!.topAnchor)
            ])
        } else {
            iphoneFrame.isHidden = true
            view.addSubview(webView)
            
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }
    
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        HapticService.shared.buttonTap()
        currentMode = (sender.selectedSegmentIndex == 0) ? .virtualIPhone : .standardWebView
        updateLayoutForMode()
    }
    
    @objc private func shareContent() {
        let av = UIActivityViewController(activityItems: [rawHTML], applicationActivities: nil)
        present(av, animated: true, completion: nil)
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true, completion: nil)
    }
}
