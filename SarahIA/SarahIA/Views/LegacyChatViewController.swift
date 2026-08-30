import UIKit
import AVFoundation
import Speech
import WebKit

/// Contrôleur UIKit 100% Natif de Secours (iOS 12 à iOS 14 / iPhone 5s, 6, 6 Plus)
/// avec l'interface EXACTEMENT IDENTIQUE à celle des iPhone 7 et iPhone 14 :
/// - Header avec bouton Hamburger ☰, Capsule d'agent actif (Sarah, Nathan, Esther, Tom, Yohan, Ethel) et Roue crantée ⚙️
/// - Raccourcis d'actions rapides (Allume la torche, Pikoud HaOref, i24News)
/// - Barre de saisie Capsule moderne avec +, Champ, Micro et Waveform
/// - Menu latéral (Sidebar) coulissant avec liste des agents et discussions
public final class LegacyChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    // MARK: - Propriétés UI
    
    private let topBar = UIView()
    private let menuButton = UIButton(type: .system)
    private let agentCapsuleButton = UIButton(type: .system)
    private let agentStatusDot = UIView()
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
    
    // Tiroir latéral (Sidebar)
    private let drawerOverlay = UIView()
    private let drawerView = UIView()
    private var isDrawerOpen = false
    private var drawerLeadingConstraint: NSLayoutConstraint?
    
    // Données
    private var messages: [Message] = []
    private var activeAgent: AgentType = .sarah
    private var isRecording: Bool = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupDrawer()
        setupSpeechPipeline()
        loadInitialMessages()
    }
    
    // MARK: - Configuration Interface Graphique
    
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
        
        // 3. Barre d'actions rapides (Allume la torche, Pikoud HaOref, i24News)
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
        inputTextField.placeholder = "Demander à Sarah..."
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: "Demander à Sarah...",
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
        inputTextField.placeholder = "Demander à \(activeAgent.rawValue)..."
    }
    
    // MARK: - Menu Tiroir (Sidebar)
    
    private func setupDrawer() {
        drawerOverlay.translatesAutoresizingMaskIntoConstraints = false
        drawerOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        drawerOverlay.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleDrawer))
        drawerOverlay.addGestureRecognizer(tap)
        view.addSubview(drawerOverlay)
        
        drawerView.translatesAutoresizingMaskIntoConstraints = false
        drawerView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        view.addSubview(drawerView)
        
        let drawerWidth = min(view.bounds.width * 0.82, 320)
        drawerLeadingConstraint = drawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -drawerWidth)
        
        NSLayoutConstraint.activate([
            drawerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            drawerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            drawerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            drawerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            drawerView.topAnchor.constraint(equalTo: view.topAnchor),
            drawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            drawerView.widthAnchor.constraint(equalToConstant: drawerWidth),
            drawerLeadingConstraint!
        ])
    }
    
    @objc private func toggleDrawer() {
        HapticService.shared.buttonTap()
        isDrawerOpen.toggle()
        
        let drawerWidth = min(view.bounds.width * 0.82, 320)
        drawerLeadingConstraint?.constant = isDrawerOpen ? 0 : -drawerWidth
        
        UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseOut], animations: {
            self.drawerOverlay.alpha = self.isDrawerOpen ? 1 : 0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc private func showAgentPicker() {
        HapticService.shared.buttonTap()
        let alert = UIAlertController(title: "Sélectionner un Agent", message: "Choisissez l'agent actif :", preferredStyle: .actionSheet)
        
        for agent in AgentType.allCases {
            alert.addAction(UIAlertAction(title: "\(agent.rawValue) — \(agent.roleDescription)", style: .default, handler: { [weak self] _ in
                self?.activeAgent = agent
                self?.updateAgentCapsuleTitle()
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
            self?.messages.removeAll()
            self?.loadInitialMessages()
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
    
    private func loadInitialMessages() {
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
        
        MultiAgentCoordinator.shared.routeAndProcess(query: text, currentAgent: activeAgent) { [weak self] response in
            guard let self = self else { return }
            self.activeAgent = response.agent
            self.updateAgentCapsuleTitle()
            
            let aiMsg = Message(content: response.text, isFromUser: false)
            self.messages.append(aiMsg)
            self.tableView.reloadData()
            self.scrollToBottom()
            
            MultiAgentVoiceManager.shared.speak(text: response.spokenText, for: response.agent)
        }
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    // MARK: - UITableViewDataSource
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
