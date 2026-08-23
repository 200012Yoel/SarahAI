import UIKit
import AVFoundation
import Speech

/// Contrôleur de discussion universel 100% UIKit :
/// - Animation Vague Siri Vocale dynamique et réactive en temps réel
/// - Enregistrement instantané au TAC au TAC
/// - Voix féminine naturelle avec intonation réaliste
/// - Titrage automatique des discussions
/// - 100% compatible iOS 12.0+ (iPhone 5S, 6, 7, 8, etc.)
public final class LegacyChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Composants UI Principaux
    private let topBar = UIView()
    private let menuButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let settingsHeaderButton = UIButton(type: .system)
    
    private let tableView = UITableView()
    private let suggestionsScrollView = UIScrollView()
    private let suggestionsStackView = UIStackView()
    
    // Barre de Saisie
    private let composerContainer = UIView()
    private let actionPlusButton = UIButton(type: .system)
    private let inputTextField = UITextField()
    private let cameraButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    
    // MARK: - Vague Siri Vocale Animée (Waveform Overlay)
    private let siriWaveOverlay = UIView()
    private let waveBarsStack = UIStackView()
    private var waveBarViews: [UIView] = []
    private let waveStatusLabel = UILabel()
    private let waveStopButton = UIButton(type: .system)
    private var waveAnimationTimer: Timer?
    
    // MARK: - Menu Latéral Moderne (Sidebar Drawer)
    private let drawerScrim = UIView()
    private let drawerView = UIView()
    private var drawerLeadingConstraint: NSLayoutConstraint?
    private var isDrawerOpen: Bool = false
    private let drawerTableView = UITableView()
    
    private var composerBottomConstraint: NSLayoutConstraint?
    private var isKeyboardPresented: Bool = false
    
    // MARK: - Données & Persistance
    private var messages: [Message] = []
    private var conversations: [Conversation] = []
    private var currentConversationId: UUID = UUID()
    private var isRecording: Bool = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Moteur Microphone & Reconnaissance Vocale Native iOS 10+
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var accumulatedSpokenText: String = ""
    
    // Suggestions rapides
    private let quickSuggestions = [
        "🔦 Allume la torche",
        "🔋 Niveau de batterie",
        "⏰ Quelle heure est-il ?",
        "☀️ Quel temps fait-il ?",
        "😂 Raconte une blague",
        "✨ Donne-moi une citation",
        "🧠 Apprends papa",
        "🧮 Calcule 15 * 8",
        "💡 Que sais-tu faire ?"
    ]
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSiriWaveOverlay()
        setupDrawerUI()
        setupSuggestions()
        setupKeyboardNotifications()
        setupGestures()
        setupDeepLinkObserver()
        loadPersistedState()
        saveState()
        prewarmAudioSession()
    }
    
    private func setupDeepLinkObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SarahOpenDeepLink"), object: nil, queue: .main) { [weak self] notif in
            guard let self = self, let action = notif.object as? String else { return }
            switch action {
            case "voice":
                self.toggleMicTapped()
            case "newchat":
                self.newChatTapped()
            case "memory":
                self.openMemoryVault()
            case "camera":
                self.cameraButtonTapped()
            case "screenshare":
                self.startScreenShareAnalysis()
            default:
                break
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SarahLaunchCamera"), object: nil, queue: .main) { [weak self] _ in
            self?.cameraButtonTapped()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SarahLaunchScreenShare"), object: nil, queue: .main) { [weak self] _ in
            self?.startScreenShareAnalysis()
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !isKeyboardPresented {
            composerBottomConstraint?.constant = -8
        }
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func prewarmAudioSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
    }
    
    // MARK: - Configuration UI Principale
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 1. Barre Supérieure
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        view.addSubview(topBar)
        
        // Bouton Menu Hamburger (☰)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.setTitle("☰", for: .normal)
        menuButton.setTitleColor(.white, for: .normal)
        menuButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        menuButton.addTarget(self, action: #selector(toggleDrawer), for: .touchUpInside)
        topBar.addSubview(menuButton)
        
        // Titre et Statut (Centre)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Sarah IA"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
        topBar.addSubview(titleLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "● En ligne"
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        topBar.addSubview(statusLabel)
        
        // Bouton Réglages (⚙️)
        settingsHeaderButton.translatesAutoresizingMaskIntoConstraints = false
        settingsHeaderButton.setTitle("⚙️", for: .normal)
        settingsHeaderButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        settingsHeaderButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        topBar.addSubview(settingsHeaderButton)
        
        // 2. TableView des Messages
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LegacyUserCell.self, forCellReuseIdentifier: "UserCell")
        tableView.register(LegacyAICell.self, forCellReuseIdentifier: "AICell")
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        
        // 3. Barre de Suggestions Horizontale
        suggestionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsScrollView.showsHorizontalScrollIndicator = false
        suggestionsScrollView.backgroundColor = .clear
        view.addSubview(suggestionsScrollView)
        
        suggestionsStackView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsStackView.axis = .horizontal
        suggestionsStackView.spacing = 8
        suggestionsStackView.alignment = .center
        suggestionsScrollView.addSubview(suggestionsStackView)
        
        // 4. Barre de Saisie (Composer)
        composerContainer.translatesAutoresizingMaskIntoConstraints = false
        composerContainer.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
        composerContainer.layer.cornerRadius = 23
        composerContainer.layer.borderWidth = 0.5
        composerContainer.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        composerContainer.clipsToBounds = true
        view.addSubview(composerContainer)
        
        // Stack View Horizontale pour la saisie et les boutons (évite toute superposition de boutons sur iPhone 5S/7/8 jusqu'à 14/15)
        let composerStack = UIStackView()
        composerStack.translatesAutoresizingMaskIntoConstraints = false
        composerStack.axis = .horizontal
        composerStack.spacing = 6
        composerStack.alignment = .center
        composerStack.distribution = .fill
        composerContainer.addSubview(composerStack)
        
        // Bouton Plus ➕
        actionPlusButton.translatesAutoresizingMaskIntoConstraints = false
        actionPlusButton.setTitle("➕", for: .normal)
        actionPlusButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        actionPlusButton.addTarget(self, action: #selector(actionPlusTapped), for: .touchUpInside)
        actionPlusButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        actionPlusButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        composerStack.addArrangedSubview(actionPlusButton)
        
        // Champ de Texte
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.backgroundColor = .clear
        inputTextField.textColor = .white
        inputTextField.tintColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        inputTextField.font = UIFont.systemFont(ofSize: 15)
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: "Message pour Sarah...",
            attributes: [.foregroundColor: UIColor(white: 0.55, alpha: 1.0)]
        )
        inputTextField.returnKeyType = .send
        inputTextField.delegate = self
        inputTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        inputTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inputTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        composerStack.addArrangedSubview(inputTextField)
        
        // Bouton Caméra 📷 (Reconnaissance d'objets ultra-rapide et locale)
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let camImg = UIImage(systemName: "camera.fill") {
            cameraButton.setImage(camImg, for: .normal)
            cameraButton.tintColor = UIColor(white: 0.85, alpha: 1.0)
        } else {
            cameraButton.setTitle("📷", for: .normal)
            cameraButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        }
        cameraButton.backgroundColor = UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
        cameraButton.layer.cornerRadius = 15
        cameraButton.clipsToBounds = true
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
        cameraButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        cameraButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        composerStack.addArrangedSubview(cameraButton)
        
        // Bouton Micro 🎙️
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setTitle("🎙️", for: .normal)
        micButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        micButton.backgroundColor = UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
        micButton.layer.cornerRadius = 15
        micButton.clipsToBounds = true
        micButton.addTarget(self, action: #selector(toggleMicTapped), for: .touchUpInside)
        micButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        micButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        composerStack.addArrangedSubview(micButton)
        
        // Bouton Envoyer ⬆
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("▲", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .black)
        sendButton.backgroundColor = UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0)
        sendButton.layer.cornerRadius = 16
        sendButton.clipsToBounds = true
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        sendButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        sendButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        composerStack.addArrangedSubview(sendButton)
        
        // Layout Constraints adaptatives iPhone 5S/7 jusqu'à iPhone 14/15/16
        let composerBottom = composerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        self.composerBottomConstraint = composerBottom
        
        NSLayoutConstraint.activate([
            // TopBar avec ancrage safeAreaLayoutGuide pour s'adapter à la fois aux petits écrans et au Dynamic Island
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            
            menuButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            menuButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 26),
            menuButton.widthAnchor.constraint(equalToConstant: 36),
            menuButton.heightAnchor.constraint(equalToConstant: 36),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            
            statusLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            settingsHeaderButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            settingsHeaderButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 26),
            settingsHeaderButton.widthAnchor.constraint(equalToConstant: 36),
            settingsHeaderButton.heightAnchor.constraint(equalToConstant: 36),
            
            // TableView
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: suggestionsScrollView.topAnchor, constant: -4),
            
            // Suggestions
            suggestionsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -8),
            suggestionsScrollView.heightAnchor.constraint(equalToConstant: 36),
            
            suggestionsStackView.topAnchor.constraint(equalTo: suggestionsScrollView.topAnchor),
            suggestionsStackView.leadingAnchor.constraint(equalTo: suggestionsScrollView.leadingAnchor, constant: 14),
            suggestionsStackView.trailingAnchor.constraint(equalTo: suggestionsScrollView.trailingAnchor, constant: -14),
            suggestionsStackView.bottomAnchor.constraint(equalTo: suggestionsScrollView.bottomAnchor),
            suggestionsStackView.heightAnchor.constraint(equalTo: suggestionsScrollView.heightAnchor),
            
            // Composer Container
            composerContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            composerContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            composerBottom,
            composerContainer.heightAnchor.constraint(equalToConstant: 46),
            
            // Composer Stack
            composerStack.leadingAnchor.constraint(equalTo: composerContainer.leadingAnchor, constant: 8),
            composerStack.trailingAnchor.constraint(equalTo: composerContainer.trailingAnchor, constant: -7),
            composerStack.topAnchor.constraint(equalTo: composerContainer.topAnchor),
            composerStack.bottomAnchor.constraint(equalTo: composerContainer.bottomAnchor)
        ])
    }
    
    // MARK: - Configuration de la Vague Siri Vocale Animée Pleine Longueur
    
    private func setupSiriWaveOverlay() {
        siriWaveOverlay.translatesAutoresizingMaskIntoConstraints = false
        siriWaveOverlay.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 0.98)
        siriWaveOverlay.layer.cornerRadius = 23
        siriWaveOverlay.layer.borderWidth = 1.5
        siriWaveOverlay.layer.borderColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9).cgColor
        siriWaveOverlay.clipsToBounds = true
        siriWaveOverlay.alpha = 0
        siriWaveOverlay.isHidden = true
        composerContainer.addSubview(siriWaveOverlay)
        
        // Stack des barres animées réparties sur TOUTE la longueur jusqu'au micro
        waveBarsStack.translatesAutoresizingMaskIntoConstraints = false
        waveBarsStack.axis = .horizontal
        waveBarsStack.alignment = .center
        waveBarsStack.distribution = .equalSpacing
        waveBarsStack.spacing = 3
        siriWaveOverlay.addSubview(waveBarsStack)
        
        let barColors: [UIColor] = [
            UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0),   // Cyan
            UIColor(red: 0.15, green: 0.70, blue: 1.0, alpha: 1.0),  // Bleu ciel
            UIColor(red: 0.35, green: 0.50, blue: 1.0, alpha: 1.0),  // Bleu roi
            UIColor(red: 0.55, green: 0.30, blue: 0.95, alpha: 1.0), // Violet
            UIColor(red: 0.75, green: 0.20, blue: 0.90, alpha: 1.0), // Pourpre
            UIColor(red: 0.95, green: 0.18, blue: 0.70, alpha: 1.0), // Rose fluo
            UIColor(red: 1.0, green: 0.30, blue: 0.50, alpha: 1.0),  // Corail
            UIColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 1.0),  // Orange
            UIColor(red: 0.90, green: 0.85, blue: 0.10, alpha: 1.0), // Or
            UIColor(red: 0.20, green: 0.90, blue: 0.60, alpha: 1.0), // Vert menthe
            UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0),   // Cyan
            UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1.0),  // Bleu
            UIColor(red: 0.60, green: 0.25, blue: 0.95, alpha: 1.0), // Violet
            UIColor(red: 0.90, green: 0.20, blue: 0.80, alpha: 1.0), // Magenta
            UIColor(red: 0.0, green: 0.90, blue: 0.90, alpha: 1.0)   // Turquoise
        ]
        
        for color in barColors {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = color
            bar.layer.cornerRadius = 2.5
            bar.clipsToBounds = true
            bar.widthAnchor.constraint(equalToConstant: 5).isActive = true
            bar.heightAnchor.constraint(equalToConstant: 10).isActive = true
            waveBarsStack.addArrangedSubview(bar)
            waveBarViews.append(bar)
        }
        
        // Bouton Arrêter / Envoyer au bout de la barre
        waveStopButton.translatesAutoresizingMaskIntoConstraints = false
        waveStopButton.setTitle("✓", for: .normal)
        waveStopButton.setTitleColor(.white, for: .normal)
        waveStopButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        waveStopButton.backgroundColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        waveStopButton.layer.cornerRadius = 16
        waveStopButton.clipsToBounds = true
        waveStopButton.addTarget(self, action: #selector(toggleMicTapped), for: .touchUpInside)
        siriWaveOverlay.addSubview(waveStopButton)
        
        NSLayoutConstraint.activate([
            siriWaveOverlay.topAnchor.constraint(equalTo: composerContainer.topAnchor),
            siriWaveOverlay.leadingAnchor.constraint(equalTo: composerContainer.leadingAnchor),
            siriWaveOverlay.trailingAnchor.constraint(equalTo: composerContainer.trailingAnchor),
            siriWaveOverlay.bottomAnchor.constraint(equalTo: composerContainer.bottomAnchor),
            
            waveBarsStack.leadingAnchor.constraint(equalTo: siriWaveOverlay.leadingAnchor, constant: 14),
            waveBarsStack.trailingAnchor.constraint(equalTo: waveStopButton.leadingAnchor, constant: -12),
            waveBarsStack.centerYAnchor.constraint(equalTo: siriWaveOverlay.centerYAnchor),
            waveBarsStack.heightAnchor.constraint(equalToConstant: 28),
            
            waveStopButton.trailingAnchor.constraint(equalTo: siriWaveOverlay.trailingAnchor, constant: -7),
            waveStopButton.centerYAnchor.constraint(equalTo: siriWaveOverlay.centerYAnchor),
            waveStopButton.widthAnchor.constraint(equalToConstant: 32),
            waveStopButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func startWaveAnimation() {
        siriWaveOverlay.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.siriWaveOverlay.alpha = 1.0
        }
        
        waveAnimationTimer?.invalidate()
        var phase: Double = 0.0
        waveAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            phase += 0.35
            for (index, bar) in self.waveBarViews.enumerated() {
                let waveSin = sin(phase + (Double(index) * 0.45))
                let normalized = (waveSin + 1.0) / 2.0 // 0.0 à 1.0
                let targetHeight = CGFloat(6 + (normalized * 20))
                UIView.animate(withDuration: 0.08, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                    bar.constraints.first(where: { $0.firstAttribute == .height })?.constant = targetHeight
                    bar.superview?.layoutIfNeeded()
                }, completion: nil)
            }
        }
    }
    
    private func stopWaveAnimation() {
        waveAnimationTimer?.invalidate()
        waveAnimationTimer = nil
        
        UIView.animate(withDuration: 0.2, animations: {
            self.siriWaveOverlay.alpha = 0.0
        }, completion: { _ in
            self.siriWaveOverlay.isHidden = true
        })
    }
    
    // MARK: - Configuration Menu Latéral Moderne
    
    private func setupDrawerUI() {
        drawerScrim.translatesAutoresizingMaskIntoConstraints = false
        drawerScrim.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        drawerScrim.alpha = 0
        drawerScrim.isHidden = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleDrawer))
        drawerScrim.addGestureRecognizer(tap)
        view.addSubview(drawerScrim)
        
        drawerView.translatesAutoresizingMaskIntoConstraints = false
        drawerView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0)
        drawerView.layer.shadowColor = UIColor.black.cgColor
        drawerView.layer.shadowOpacity = 0.8
        drawerView.layer.shadowRadius = 20
        view.addSubview(drawerView)
        
        let drawerWidth = UIScreen.main.bounds.width * 0.84
        let leading = drawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -drawerWidth)
        self.drawerLeadingConstraint = leading
        
        let drawerHeader = UIView()
        drawerHeader.translatesAutoresizingMaskIntoConstraints = false
        drawerHeader.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        drawerView.addSubview(drawerHeader)
        
        let appTitle = UILabel()
        appTitle.translatesAutoresizingMaskIntoConstraints = false
        appTitle.text = "👩🏻‍💼 Sarah IA"
        appTitle.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        appTitle.textColor = .white
        drawerHeader.addSubview(appTitle)
        
        let appSubtitle = UILabel()
        appSubtitle.translatesAutoresizingMaskIntoConstraints = false
        appSubtitle.text = "Historique des discussions"
        appSubtitle.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        appSubtitle.textColor = UIColor(white: 0.6, alpha: 1.0)
        drawerHeader.addSubview(appSubtitle)
        
        let newChatBtn = UIButton(type: .system)
        newChatBtn.translatesAutoresizingMaskIntoConstraints = false
        newChatBtn.setTitle("➕ Nouvelle discussion", for: .normal)
        newChatBtn.setTitleColor(.white, for: .normal)
        newChatBtn.backgroundColor = UIColor(red: 0.0, green: 0.55, blue: 0.95, alpha: 0.35)
        newChatBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        newChatBtn.layer.cornerRadius = 12
        newChatBtn.layer.borderWidth = 1
        newChatBtn.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.4).cgColor
        newChatBtn.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        drawerHeader.addSubview(newChatBtn)
        
        drawerTableView.translatesAutoresizingMaskIntoConstraints = false
        drawerTableView.backgroundColor = .clear
        drawerTableView.separatorStyle = .none
        drawerTableView.dataSource = self
        drawerTableView.delegate = self
        drawerTableView.register(LegacyDrawerCell.self, forCellReuseIdentifier: "DrawerCell")
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleDrawerLongPress(_:)))
        drawerTableView.addGestureRecognizer(longPress)
        drawerView.addSubview(drawerTableView)
        
        NSLayoutConstraint.activate([
            drawerScrim.topAnchor.constraint(equalTo: view.topAnchor),
            drawerScrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            drawerScrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            drawerScrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            drawerView.topAnchor.constraint(equalTo: view.topAnchor),
            drawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            leading,
            drawerView.widthAnchor.constraint(equalToConstant: drawerWidth),
            
            drawerHeader.topAnchor.constraint(equalTo: drawerView.topAnchor),
            drawerHeader.leadingAnchor.constraint(equalTo: drawerView.leadingAnchor),
            drawerHeader.trailingAnchor.constraint(equalTo: drawerView.trailingAnchor),
            drawerHeader.heightAnchor.constraint(equalToConstant: 135),
            
            appTitle.leadingAnchor.constraint(equalTo: drawerHeader.leadingAnchor, constant: 16),
            appTitle.topAnchor.constraint(equalTo: drawerHeader.topAnchor, constant: 36),
            
            appSubtitle.leadingAnchor.constraint(equalTo: drawerHeader.leadingAnchor, constant: 16),
            appSubtitle.topAnchor.constraint(equalTo: appTitle.bottomAnchor, constant: 2),
            
            newChatBtn.leadingAnchor.constraint(equalTo: drawerHeader.leadingAnchor, constant: 14),
            newChatBtn.trailingAnchor.constraint(equalTo: drawerHeader.trailingAnchor, constant: -14),
            newChatBtn.bottomAnchor.constraint(equalTo: drawerHeader.bottomAnchor, constant: -10),
            newChatBtn.heightAnchor.constraint(equalToConstant: 38),
            
            drawerTableView.topAnchor.constraint(equalTo: drawerHeader.bottomAnchor, constant: 6),
            drawerTableView.leadingAnchor.constraint(equalTo: drawerView.leadingAnchor),
            drawerTableView.trailingAnchor.constraint(equalTo: drawerView.trailingAnchor),
            drawerTableView.bottomAnchor.constraint(equalTo: drawerView.bottomAnchor)
        ])
    }
    
    // MARK: - Appui Long sur une Discussion (Supprimer / Renommer)
    
    @objc private func handleDrawerLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: drawerTableView)
        guard let indexPath = drawerTableView.indexPathForRow(at: point) else { return }
        
        let conv = conversations[indexPath.row]
        let sheet = UIAlertController(
            title: "Discussion",
            message: "« \(conv.title) »",
            preferredStyle: .actionSheet
        )
        
        sheet.addAction(UIAlertAction(title: "✏️ Renommer", style: .default, handler: { [weak self] _ in
            self?.promptRenameConversation(at: indexPath.row)
        }))
        
        sheet.addAction(UIAlertAction(title: "🗑️ Supprimer la discussion", style: .destructive, handler: { [weak self] _ in
            self?.deleteConversation(at: indexPath.row)
        }))
        
        sheet.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func promptRenameConversation(at index: Int) {
        let conv = conversations[index]
        let alert = UIAlertController(title: "Renommer", message: "Nouveau titre pour la discussion :", preferredStyle: .alert)
        alert.addTextField { $0.text = conv.title }
        alert.addAction(UIAlertAction(title: "Enregistrer", style: .default, handler: { [weak self] _ in
            guard let newTitle = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines), !newTitle.isEmpty else { return }
            self?.conversations[index].title = newTitle
            self?.saveState()
            self?.drawerTableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func deleteConversation(at index: Int) {
        guard conversations.indices.contains(index) else { return }
        let deletedConv = conversations.remove(at: index)
        
        if conversations.isEmpty {
            newChatTapped()
        } else if deletedConv.id == currentConversationId {
            let first = conversations[0]
            currentConversationId = first.id
            messages = first.messages
            tableView.reloadData()
        }
        
        saveState()
        drawerTableView.reloadData()
    }
    
    // MARK: - Suggestions Horizontales
    
    private func setupSuggestions() {
        for suggestion in quickSuggestions {
            let btn = UIButton(type: .system)
            btn.setTitle(suggestion, for: .normal)
            btn.setTitleColor(UIColor(white: 0.9, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            btn.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
            btn.layer.cornerRadius = 14
            btn.layer.borderWidth = 0.5
            btn.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            btn.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            suggestionsStackView.addArrangedSubview(btn)
        }
    }
    
    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let text = sender.title(for: .normal) else { return }
        inputTextField.text = text
        sendButtonTapped()
    }
    
    // MARK: - Gestion du Clavier & Gestes
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        isKeyboardPresented = true
        let bottomInset = view.safeAreaInsets.bottom
        let bottomPadding: CGFloat = -(frame.height - bottomInset + 8)
        composerBottomConstraint?.constant = bottomPadding
        
        UIView.animate(withDuration: duration, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.scrollToBottom(animated: true)
        })
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        isKeyboardPresented = false
        composerBottomConstraint?.constant = -8
        
        UIView.animate(withDuration: duration, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Actions TopBar & Drawer
    
    @objc private func toggleDrawer() {
        isDrawerOpen.toggle()
        dismissKeyboard()
        
        let drawerWidth = UIScreen.main.bounds.width * 0.84
        drawerLeadingConstraint?.constant = isDrawerOpen ? 0 : -drawerWidth
        
        if isDrawerOpen {
            drawerScrim.isHidden = false
            drawerTableView.reloadData()
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.drawerScrim.alpha = self.isDrawerOpen ? 1.0 : 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            if !self.isDrawerOpen {
                self.drawerScrim.isHidden = true
            }
        })
    }
    
    @objc private func newChatTapped() {
        var newConv = Conversation(title: "Nouvelle discussion")
        currentConversationId = newConv.id
        conversations.insert(newConv, at: 0)
        messages = []
        newConv.messages = []
        AIService.shared.syncHistoryFromMessages([])
        
        saveState()
        tableView.reloadData()
        drawerTableView.reloadData()
        
        if isDrawerOpen {
            toggleDrawer()
        }
    }
    
    // MARK: - Réglages
    
    @objc private func openSettings() {
        dismissKeyboard()
        let alert = UIAlertController(
            title: "⚙️ Synthèse Vocale & Réglages de Sarah",
            message: "• Voix : Féminine / Siri (Haute Définition)\n• Reconnaissance : Instantanée & Vague Siri\n• Mode : Natif iOS 12+ (60 FPS)",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "🔊 Tester la voix féminine", style: .default, handler: { [weak self] _ in
            self?.speak(text: "Bonjour ! Je suis Sarah. Ma voix féminine est configurée avec une intonation naturelle et fluide pour vous répondre.")
        }))
        
        alert.addAction(UIAlertAction(title: "🧠 Mémorisation & Apprentissage (Coffre)", style: .default, handler: { [weak self] _ in
            self?.openMemoryVault()
        }))
        
        alert.addAction(UIAlertAction(title: "📊 Statistiques d'usage", style: .default, handler: { [weak self] _ in
            self?.widgetsModalTapped()
        }))
        
        alert.addAction(UIAlertAction(title: "🗑️ Nouvelle discussion", style: .destructive, handler: { [weak self] _ in
            self?.newChatTapped()
        }))
        
        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func openMemoryVault() {
        let memories = StorageService.shared.loadState().learnedMemories
        var memoryText = ""
        if memories.isEmpty {
            memoryText = "Aucun souvenir appris pour le moment.\n\nDites par exemple : « Apprends papa » pour enseigner une réponse personnalisée à Sarah !"
        } else {
            memoryText = memories.map { "• « \($0.key) » ➔ « \($0.value) »" }.joined(separator: "\n\n")
        }
        
        let alert = UIAlertController(
            title: "🧠 Coffre Mémoire (Brain Vault)",
            message: memoryText,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "➕ Enseigner un mot", style: .default, handler: { [weak self] _ in
            self?.promptTeachMemory()
        }))
        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func promptTeachMemory() {
        let alert = UIAlertController(
            title: "🧠 Enseigner à Sarah",
            message: "Entrez le déclencheur et ce que Sarah doit répondre :",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Mot déclencheur (ex: Papa)" }
        alert.addTextField { $0.placeholder = "Réponse (ex: Il est au travail)" }
        
        alert.addAction(UIAlertAction(title: "Enregistrer", style: .default, handler: { [weak self] _ in
            guard let trigger = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let response = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trigger.isEmpty, !response.isEmpty else { return }
            
            var state = StorageService.shared.loadState()
            state.learnedMemories[trigger.lowercased()] = response
            StorageService.shared.saveState(state)
            
            let confirmation = Message(content: "C'est appris ! 🧠 Dès que vous me direz « \(trigger) », je répondrai : « \(response) ».", isFromUser: false)
            self?.appendMessage(confirmation)
            self?.saveState()
        }))
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func widgetsModalTapped() {
        dismissKeyboard()
        HapticService.shared.buttonTap()
        let vc = LegacyWidgetsViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onVoiceTapped = { [weak self] in
            self?.toggleMicTapped()
        }
        vc.onTorchTapped = {
            _ = DeviceController.shared.toggleTorch(enable: nil)
        }
        vc.onMemoryTapped = { [weak self] in
            self?.openMemoryVault()
        }
        vc.onScreenShareTapped = { [weak self] in
            self?.startScreenShareAnalysis()
        }
        present(vc, animated: true, completion: nil)
    }
    
    // MARK: - Reconnaissance d'Objets par Caméra (Local Vision Engine) & Partage d'Écran
    
    @objc private func cameraButtonTapped() {
        dismissKeyboard()
        HapticService.shared.buttonTap()
        
        let cameraVC = LiveCameraViewController()
        cameraVC.modalPresentationStyle = .fullScreen
        
        cameraVC.onPhotoAnalyzed = { [weak self] image, result in
            guard let self = self else { return }
            
            let processedData = LocalVisionEngine.prepareImageForAnalysis(image, maxDimension: 800, quality: 0.7)?.data ?? image.jpegData(compressionQuality: 0.7)
            
            // 1. Bulle photo de l'utilisateur
            let userPhotoMsg = Message(
                content: "📷 [Photo analysée]",
                isFromUser: true,
                timestamp: Date(),
                imageData: processedData
            )
            self.appendMessage(userPhotoMsg)
            
            // 2. Réponse formulée par Sarah
            let responseText = result.naturalSpokenResponse
            let aiMsg = Message(content: responseText, isFromUser: false)
            self.appendMessage(aiMsg)
            self.speak(text: responseText)
            self.saveState()
        }
        
        cameraVC.onScreenShareRequested = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.startScreenShareAnalysis()
            }
        }
        
        present(cameraVC, animated: true, completion: nil)
    }
    
    @objc private func startScreenShareAnalysis() {
        dismissKeyboard()
        HapticService.shared.buttonTap()
        
        statusLabel.text = "● 🔴 Écran partagé"
        statusLabel.textColor = .systemRed
        
        let introText = "🔴 Partage d'écran en direct activé ! J'observe votre écran en continu."
        let userMsg = Message(
            content: "🖥️ [Lancement du partage d'écran en temps réel]",
            isFromUser: true,
            timestamp: Date()
        )
        self.appendMessage(userMsg)
        
        let aiMsg = Message(content: introText, isFromUser: false)
        self.appendMessage(aiMsg)
        self.speak(text: introText)
        self.saveState()
        
        ScreenShareService.shared.startLiveScreenSharing(from: self, onFrameAnalyzed: { [weak self] result, image in
            guard let self = self else { return }
            if !result.detectedText.isEmpty || result.objectLabel != "inconnu" {
                let frameMsg = Message(
                    content: result.naturalSpokenResponse,
                    isFromUser: false,
                    imageData: image.jpegData(compressionQuality: 0.6)
                )
                self.appendMessage(frameMsg)
                self.speak(text: result.naturalSpokenResponse)
                self.saveState()
            }
        }) { [weak self] success, message in
            guard let self = self else { return }
            if !success {
                self.statusLabel.text = "● En ligne"
                self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
                let errMsg = Message(content: "⚠️ \(message)", isFromUser: false)
                self.appendMessage(errMsg)
            }
        }
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let rawImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
        
        statusLabel.text = "● Analyse visuelle..."
        statusLabel.textColor = .yellow
        
        // Traitement asynchrone en arrière-plan avec compression et réduction mémoire anti-crash (iPhone 5S / 7)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(rawImage, maxDimension: 800, quality: 0.7) else { return }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 1. Message de l'utilisateur avec photo immédiatement affichée dans la discussion
                let userPhotoMsg = Message(
                    content: "📷 [Photo analysée]",
                    isFromUser: true,
                    timestamp: Date(),
                    imageData: processed.data
                )
                self.appendMessage(userPhotoMsg)
                
                // 2. Reconnaissance d'objets légère 100% Locale
                LocalVisionEngine.shared.recognizeObject(in: processed.image) { [weak self] result in
                    guard let self = self else { return }
                    self.statusLabel.text = "● En ligne"
                    self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
                    
                    let responseText = result.naturalSpokenResponse
                    let aiMsg = Message(content: responseText, isFromUser: false)
                    self.appendMessage(aiMsg)
                    self.speak(text: responseText)
                    self.saveState()
                }
            }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Actions Rapides (+)
    
    @objc private func actionPlusTapped() {
        let sheet = UIAlertController(title: "Actions Rapides", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "🖥️ Lancer le partage d'écran", style: .default, handler: { [weak self] _ in
            self?.startScreenShareAnalysis()
        }))
        sheet.addAction(UIAlertAction(title: "📊 8 Widgets Sarah IA", style: .default, handler: { [weak self] _ in
            self?.widgetsModalTapped()
        }))
        sheet.addAction(UIAlertAction(title: "📷 Reconnaissance photo", style: .default, handler: { [weak self] _ in
            self?.cameraButtonTapped()
        }))
        sheet.addAction(UIAlertAction(title: "🌐 Recherche sur Internet", style: .default, handler: { [weak self] _ in
            self?.promptWebSearch()
        }))
        sheet.addAction(UIAlertAction(title: "📻 Écouter la radio en direct", style: .default, handler: { [weak self] _ in
            self?.promptRadioSelection()
        }))
        sheet.addAction(UIAlertAction(title: "🎙️ Apple Podcasts", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Ouvre Apple Podcast"
            self?.sendButtonTapped()
        }))
        sheet.addAction(UIAlertAction(title: "🎵 Lancer de la musique", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Mets de la musique"
            self?.sendButtonTapped()
        }))
        sheet.addAction(UIAlertAction(title: "🔦 Lampe torche (On/Off)", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Allume la torche"
            self?.sendButtonTapped()
        }))
        sheet.addAction(UIAlertAction(title: "🧠 Enseigner un mot", style: .default, handler: { [weak self] _ in
            self?.promptTeachMemory()
        }))
        sheet.addAction(UIAlertAction(title: "🔋 Niveau de batterie", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Quel est le niveau de batterie ?"
            self?.sendButtonTapped()
        }))
        sheet.addAction(UIAlertAction(title: "⏰ Demander l'heure", style: .default, handler: { [weak self] _ in
            self?.inputTextField.text = "Quelle heure est-il ?"
            self?.sendButtonTapped()
        }))
        sheet.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func promptRadioSelection() {
        let radioSheet = UIAlertController(title: "📻 Choisir une Radio en Direct", message: "Sélectionnez votre station :", preferredStyle: .actionSheet)
        let stations = [
            ("NRJ", "Mets NRJ"),
            ("France Inter", "Mets France Inter"),
            ("Skyrock", "Mets Skyrock"),
            ("RTL", "Mets RTL"),
            ("Nostalgie", "Mets Nostalgie"),
            ("Fun Radio", "Mets Fun Radio"),
            ("FIP", "Mets FIP"),
            ("Jazz Radio", "Mets Jazz Radio"),
            ("Radio Classique", "Mets Radio Classique"),
            ("France Info", "Mets France Info"),
            ("⏹️ Arrêter la radio", "Arrête la radio")
        ]
        for st in stations {
            radioSheet.addAction(UIAlertAction(title: st.0, style: .default, handler: { [weak self] _ in
                self?.inputTextField.text = st.1
                self?.sendButtonTapped()
            }))
        }
        radioSheet.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(radioSheet, animated: true, completion: nil)
    }
    
    private func promptWebSearch() {
        let alert = UIAlertController(
            title: "🌐 Recherche Web Intégrée",
            message: "Entrez votre recherche (Sarah interroge le Web, Wikipédia et DuckDuckGo) :",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Ex: Qui a inventé l'iPhone ?" }
        alert.addAction(UIAlertAction(title: "Rechercher", style: .default, handler: { [weak self] _ in
            guard let query = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return }
            self?.inputTextField.text = "Cherche sur internet : \(query)"
            self?.sendButtonTapped()
        }))
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Caméra & Vision par Ordinateur
    
    public func openLiveCamera() {
        HapticService.shared.buttonTap()
        let cameraVC = LiveCameraViewController()
        cameraVC.modalPresentationStyle = .fullScreen
        cameraVC.onPhotoAnalyzed = { [weak self] image, result in
            guard let self = self else { return }
            let photoMsg = Message(content: "📷 Photo analysée : \(result.objectLabel)", isFromUser: true)
            self.appendMessage(photoMsg)
            let aiMsg = Message(content: result.naturalSpokenResponse, isFromUser: false)
            self.appendMessage(aiMsg)
            self.speak(text: result.naturalSpokenResponse)
        }
        cameraVC.onScreenShareRequested = { [weak self] in
            self?.startScreenShareAnalysis()
        }
        present(cameraVC, animated: true, completion: nil)
    }
    
    // MARK: - Envoi & Traitement des Messages
    
    @objc private func textFieldDidChange() {
        let hasText = !(inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.backgroundColor = hasText ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0) : UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0)
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendButtonTapped()
        return true
    }
    
    @objc private func sendButtonTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return
        }
        
        inputTextField.text = ""
        textFieldDidChange()
        
        let isFirstUserMessage = messages.filter({ $0.isFromUser }).isEmpty
        if isFirstUserMessage {
            let dynamicTitle = AIService.shared.generateSmartTitle(from: text)
            if let idx = conversations.firstIndex(where: { $0.id == currentConversationId }) {
                conversations[idx].title = dynamicTitle
            }
        }
        
        let userMsg = Message(content: text, isFromUser: true)
        appendMessage(userMsg)
        
        statusLabel.text = "● Réflexion..."
        statusLabel.textColor = .yellow
        
        let norm = text.lowercased()
        
        // 0. Commande d'activation Caméra en direct
        if norm.contains("camera") || norm.contains("appareil photo") || norm.contains("ouvre la camera") || norm.contains("active la camera") || norm.contains("lance la camera") || norm.contains("prends une photo") {
            statusLabel.text = "● En ligne"
            statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
            let aiMsg = Message(content: "📷 J'active la caméra immédiatement ! Pointez l'objectif vers ce que vous souhaitez que j'analyse.", isFromUser: false)
            appendMessage(aiMsg)
            speak(text: "J'active la caméra !")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openLiveCamera()
            }
            return
        }
        
        // 1. Vérification si recherche Web explicite
        if AIService.shared.isWebSearchIntent(norm) {
            statusLabel.text = "● Recherche sur le Web..."
            WebSearchService.shared.searchWeb(query: text) { [weak self] webSummary, _ in
                guard let self = self else { return }
                self.statusLabel.text = "● En ligne"
                self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
                
                SemanticMemoryIndex.shared.indexExchange(userText: text, assistantText: webSummary, topicType: "web_search")
                let aiMsg = Message(content: webSummary, isFromUser: false)
                self.appendMessage(aiMsg)
                self.speak(text: webSummary)
            }
            return
        }
        
        // 2. Traitement standard synchrone / local
        DispatchQueue.global(qos: .userInitiated).async {
            let response = AIService.shared.generateSyncResponse(for: text)
            SemanticMemoryIndex.shared.indexExchange(userText: text, assistantText: response)
            DispatchQueue.main.async {
                self.statusLabel.text = "● En ligne"
                self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
                
                // Mettre à jour le titre dynamique avec le contexte de la réponse si premier tour
                if isFirstUserMessage {
                    if let idx = self.conversations.firstIndex(where: { $0.id == self.currentConversationId }) {
                        self.conversations[idx].title = AIService.shared.generateSmartTitle(from: text, responseText: response)
                        self.drawerTableView.reloadData()
                    }
                }
                
                let aiMsg = Message(content: response, isFromUser: false)
                self.appendMessage(aiMsg)
                self.speak(text: response)
            }
        }
    }
    
    // MARK: - Microphone Ultra-Réactif au TAC au TAC avec Vague Siri
    
    @objc private func toggleMicTapped() {
        if isRecording {
            stopAudioRecording()
        } else {
            startAudioRecording()
        }
    }
    
    private func startAudioRecording() {
        accumulatedSpokenText = ""
        
        // 1. Déclenchement instantané de l'animation de la Vague Siri
        startWaveAnimation()
        isRecording = true
        statusLabel.text = "● Écoute en direct..."
        statusLabel.textColor = .red
        
        // 2. Vérification des permissions avec démarrage immédiat
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    guard authStatus == .authorized, micGranted else {
                        self?.stopAudioRecording()
                        self?.statusLabel.text = "● Micro refusé"
                        self?.statusLabel.textColor = .orange
                        return
                    }
                    self?.beginLiveRecognitionSession()
                }
            }
        }
    }
    
    private func beginLiveRecognitionSession() {
        guard isRecording else { return }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Session audio: \(error)")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        audioEngine.reset()
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        // Configuration audio 100% sécurisée pour iPhone 5S (iOS 12)
        var recordingFormat = inputNode.inputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            recordingFormat = inputNode.outputFormat(forBus: 0)
        }
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? recordingFormat
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                self?.accumulatedSpokenText = result.bestTranscription.formattedString
            }
            
            if error != nil {
                // Terminer proprement et envoyer ce qui a été capté
                if self?.isRecording == true {
                    self?.stopAudioRecording()
                }
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine: \(error)")
            stopAudioRecording()
        }
    }
    
    private func stopAudioRecording() {
        guard isRecording else { return }
        isRecording = false
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        stopWaveAnimation()
        
        statusLabel.text = "● En ligne"
        statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        
        let finalText = accumulatedSpokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            inputTextField.text = finalText
            sendButtonTapped()
        }
    }
    
    private func appendMessage(_ msg: Message) {
        messages.append(msg)
        saveState()
        tableView.reloadData()
        scrollToBottom(animated: true)
    }
    
    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    // MARK: - Synthèse Vocale avec Voix Siri Féminine Réaliste
    
    private func speak(text: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Nettoyage et formatage naturel avec virgules pour une diction expressive
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "!", with: " ! ")
            .replacingOccurrences(of: "?", with: " ? ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        let utterance = AVSpeechUtterance(string: cleaned)
        
        // Sélection de la meilleure voix féminine française Siri
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "fr") }
        let femaleVoice = allVoices.first(where: {
            let name = $0.name.lowercased()
            return name.contains("siri") || name.contains("audrey") || name.contains("aurélie") || name.contains("julie") || !name.contains("thomas")
        }) ?? AVSpeechSynthesisVoice(language: "fr-FR")
        
        utterance.voice = femaleVoice
        utterance.rate = 0.48 // Vitesse d'élocution naturelle
        utterance.pitchMultiplier = 1.06 // Ton chaleureux et féminin
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Persistance État
    
    private func loadPersistedState() {
        let state = StorageService.shared.loadState()
        self.conversations = state.conversations
        if let currentId = state.currentConversationId,
           let activeConv = conversations.first(where: { $0.id == currentId }) {
            self.currentConversationId = activeConv.id
            self.messages = activeConv.messages
        } else if let first = conversations.first {
            self.currentConversationId = first.id
            self.messages = first.messages
        } else {
            newChatTapped()
            return
        }
        
        AIService.shared.syncHistoryFromMessages(self.messages)
        tableView.reloadData()
    }
    
    private func saveState() {
        if let idx = conversations.firstIndex(where: { $0.id == currentConversationId }) {
            conversations[idx].messages = messages
            conversations[idx].updatedAt = Date()
        }
        
        if let idx = conversations.firstIndex(where: { $0.id == currentConversationId }) {
            conversations[idx].messages = messages
        }
        
        var state = StorageService.shared.loadState()
        state.conversations = conversations
        state.currentConversationId = currentConversationId
        state.messages = messages
        StorageService.shared.saveState(state)
        
        // Calcul du total des questions (messages utilisateur) sur l'ensemble des discussions
        var totalQuestions = 0
        for conv in conversations {
            totalQuestions += conv.messages.filter { $0.isFromUser }.count
        }
        let currentConvQuestions = messages.filter { $0.isFromUser }.count
        let totalMsgs = max(totalQuestions, currentConvQuestions)
        let totalConvs = max(1, conversations.count)
        let memoriesCount = state.learnedMemories.count
        
        // Synchronisation directe immédiate avec l'App Group partagé
        if let sharedDefaults = UserDefaults(suiteName: "group.com.sarahia.app") {
            sharedDefaults.set(totalConvs, forKey: "totalConversations")
            sharedDefaults.set(totalMsgs, forKey: "totalMessages")
            sharedDefaults.set(memoriesCount, forKey: "learnedMemoriesCount")
            sharedDefaults.synchronize()
        }
        
        let lastMemoryTuple: (trigger: String, response: String)? = state.learnedMemories.first.map { ($0.key, $0.value) }
        SarahWidgetBridge.shared.syncStats(
            conversationsCount: totalConvs,
            messagesCount: totalMsgs,
            memoriesCount: memoriesCount,
            lastMemory: lastMemoryTuple,
            lastMessage: messages.last?.content
        )
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == drawerTableView {
            return conversations.count
        }
        return messages.count
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == drawerTableView {
            return 64
        }
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == drawerTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DrawerCell", for: indexPath) as! LegacyDrawerCell
            let conv = conversations[indexPath.row]
            let isSelected = conv.id == currentConversationId
            cell.configure(with: conv, isSelected: isSelected)
            return cell
        }
        
        let msg = messages[indexPath.row]
        if msg.isFromUser {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! LegacyUserCell
            cell.configure(with: msg)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AICell", for: indexPath) as! LegacyAICell
            cell.configure(with: msg) { [weak self] in
                self?.speak(text: msg.content)
            }
            return cell
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if tableView == drawerTableView {
            let selectedConv = conversations[indexPath.row]
            currentConversationId = selectedConv.id
            messages = selectedConv.messages
            AIService.shared.syncHistoryFromMessages(messages)
            tableView.reloadData()
            self.tableView.reloadData()
            toggleDrawer()
            scrollToBottom(animated: false)
        }
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if tableView == drawerTableView && editingStyle == .delete {
            deleteConversation(at: indexPath.row)
        }
    }
}

// MARK: - Cellule Moderne du Menu Latéral (Drawer Card Cell)

final class LegacyDrawerCell: UITableViewCell {
    private let cardView = UIView()
    private let activeIndicator = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0)
        cardView.layer.cornerRadius = 12
        cardView.layer.borderWidth = 0.5
        cardView.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        
        activeIndicator.translatesAutoresizingMaskIntoConstraints = false
        activeIndicator.backgroundColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        activeIndicator.layer.cornerRadius = 2
        cardView.addSubview(activeIndicator)
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = "💬"
        iconLabel.font = UIFont.systemFont(ofSize: 15)
        cardView.addSubview(iconLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        cardView.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        subtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        cardView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            activeIndicator.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 4),
            activeIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            activeIndicator.widthAnchor.constraint(equalToConstant: 4),
            activeIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            iconLabel.leadingAnchor.constraint(equalTo: activeIndicator.trailingAnchor, constant: 8),
            iconLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(with conversation: Conversation, isSelected: Bool) {
        titleLabel.text = conversation.title
        titleLabel.textColor = isSelected ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0) : .white
        activeIndicator.isHidden = !isSelected
        cardView.backgroundColor = isSelected ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.15) : UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0)
        cardView.layer.borderColor = isSelected ? UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.5).cgColor : UIColor(white: 1.0, alpha: 0.08).cgColor
        
        if let last = conversation.messages.last {
            subtitleLabel.text = last.content.replacingOccurrences(of: "\n", with: " ")
        } else {
            subtitleLabel.text = "Discussion vide"
        }
    }
}

// MARK: - Cellules Messages (Pixel-Perfect Dark Mode)

final class LegacyUserCell: UITableViewCell {
    private let bubbleView = UIView()
    private let stackView = UIStackView()
    private let photoImageView = UIImageView()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private var imageHeightConstraint: NSLayoutConstraint!
    private var imageWidthConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.backgroundColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        bubbleView.layer.cornerRadius = 18
        bubbleView.clipsToBounds = true
        contentView.addSubview(bubbleView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.alignment = .fill
        bubbleView.addSubview(stackView)
        
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.layer.cornerRadius = 14
        photoImageView.clipsToBounds = true
        photoImageView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        stackView.addArrangedSubview(photoImageView)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        stackView.addArrangedSubview(messageLabel)
        
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        timeLabel.font = UIFont.systemFont(ofSize: 10)
        contentView.addSubview(timeLabel)
        
        imageHeightConstraint = photoImageView.heightAnchor.constraint(equalToConstant: 160)
        imageWidthConstraint = photoImageView.widthAnchor.constraint(equalToConstant: 210)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 50),
            
            stackView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            stackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            
            imageHeightConstraint,
            imageWidthConstraint,
            
            timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 2),
            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -4),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(with message: Message) {
        timeLabel.text = message.formattedTime
        
        if let data = message.imageData, let img = UIImage(data: data) {
            photoImageView.isHidden = false
            imageHeightConstraint.isActive = true
            imageWidthConstraint.isActive = true
            photoImageView.image = img
            
            if message.content == "📷 [Photo analysée]" || message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messageLabel.isHidden = true
            } else {
                messageLabel.isHidden = false
                messageLabel.text = message.content
            }
        } else {
            photoImageView.isHidden = true
            imageHeightConstraint.isActive = false
            imageWidthConstraint.isActive = false
            photoImageView.image = nil
            messageLabel.isHidden = false
            messageLabel.text = message.content
        }
    }
}

final class LegacyAICell: UITableViewCell {
    private let assistantBadge = UILabel()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let listenButton = UIButton(type: .system)
    private let timeLabel = UILabel()
    private var onListen: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        assistantBadge.translatesAutoresizingMaskIntoConstraints = false
        assistantBadge.text = "👩🏻‍💼"
        assistantBadge.font = UIFont.systemFont(ofSize: 20)
        contentView.addSubview(assistantBadge)
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.borderWidth = 0.5
        bubbleView.layer.borderColor = UIColor(white: 1.0, alpha: 0.1).cgColor
        bubbleView.clipsToBounds = true
        contentView.addSubview(bubbleView)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        bubbleView.addSubview(messageLabel)
        
        listenButton.translatesAutoresizingMaskIntoConstraints = false
        listenButton.setTitle("🔊 Écouter", for: .normal)
        listenButton.setTitleColor(UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0), for: .normal)
        listenButton.tintColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        listenButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        listenButton.addTarget(self, action: #selector(listenTapped), for: .touchUpInside)
        contentView.addSubview(listenButton)
        
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        timeLabel.font = UIFont.systemFont(ofSize: 10)
        contentView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            assistantBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            assistantBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            assistantBadge.widthAnchor.constraint(equalToConstant: 26),
            assistantBadge.heightAnchor.constraint(equalToConstant: 26),
            
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.leadingAnchor.constraint(equalTo: assistantBadge.trailingAnchor, constant: 8),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            
            listenButton.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 2),
            listenButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 4),
            listenButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            timeLabel.centerYAnchor.constraint(equalTo: listenButton.centerYAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: listenButton.trailingAnchor, constant: 8)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @objc private func listenTapped() {
        onListen?()
    }
    
    func configure(with message: Message, onListen: @escaping () -> Void) {
        messageLabel.text = message.content
        timeLabel.text = message.formattedTime
        self.onListen = onListen
    }
}
