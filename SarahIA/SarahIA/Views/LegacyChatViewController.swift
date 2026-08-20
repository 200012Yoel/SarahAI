import UIKit
import AVFoundation

/// Contrôleur de discussion 100% natif UIKit assurant une compatibilité totale avec iOS 12.0+ (iPhone 5S, 6, 6 Plus).
public final class LegacyChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    // MARK: - Propriétés UI
    private let tableView = UITableView()
    private let composerContainer = UIView()
    private let inputTextField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let emptyStateView = UIView()
    
    private var composerBottomConstraint: NSLayoutConstraint?
    
    // MARK: - Données & Services
    private var messages: [Message] = []
    private var isRecording: Bool = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardNotifications()
        setupGestures()
        loadInitialMessages()
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Configuration UI Native UIKit
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 1. Barre de navigation supérieure
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.0)
        view.addSubview(topBar)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Sarah IA"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        topBar.addSubview(titleLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "● Prête (Mode iOS 12)"
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        topBar.addSubview(statusLabel)
        
        // 2. TableView des messages
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
        
        // 3. Barre de saisie (Composer)
        composerContainer.translatesAutoresizingMaskIntoConstraints = false
        composerContainer.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        composerContainer.layer.cornerRadius = 22
        composerContainer.layer.masksToBounds = true
        composerContainer.layer.borderWidth = 0.5
        composerContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.addSubview(composerContainer)
        
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.placeholder = "Demander à Sarah..."
        inputTextField.textColor = .white
        inputTextField.tintColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        inputTextField.font = UIFont.systemFont(ofSize: 16)
        inputTextField.returnKeyType = .send
        inputTextField.delegate = self
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: "Demander à Sarah...",
            attributes: [.foregroundColor: UIColor.gray]
        )
        inputTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        composerContainer.addSubview(inputTextField)
        
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setTitle("🎙️", for: .normal)
        micButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        micButton.addTarget(self, action: #selector(toggleMicTapped), for: .touchUpInside)
        composerContainer.addSubview(micButton)
        
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("⬆️", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        sendButton.backgroundColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        sendButton.layer.cornerRadius = 16
        sendButton.tintColor = .white
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        composerContainer.addSubview(sendButton)
        
        // Setup Constraints
        let topSafeArea = topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        let composerBottom = composerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        self.composerBottomConstraint = composerBottom
        
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topSafeArea,
            topBar.heightAnchor.constraint(equalToConstant: 54),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 8),
            
            statusLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -8),
            
            composerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            composerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            composerContainer.heightAnchor.constraint(equalToConstant: 44),
            composerBottom,
            
            micButton.leadingAnchor.constraint(equalTo: composerContainer.leadingAnchor, constant: 8),
            micButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 32),
            micButton.heightAnchor.constraint(equalToConstant: 32),
            
            inputTextField.leadingAnchor.constraint(equalTo: micButton.trailingAnchor, constant: 8),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputTextField.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            
            sendButton.trailingAnchor.constraint(equalTo: composerContainer.trailingAnchor, constant: -6),
            sendButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Synchronisation Clavier iOS 12+
    
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
        
        let bottomPadding: CGFloat = -frame.height - 4
        composerBottomConstraint?.constant = bottomPadding
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.scrollToBottom(animated: true)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        composerBottomConstraint?.constant = -10
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Envoi & Traitement des Messages
    
    @objc private func textFieldDidChange() {
        let hasText = !(inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.backgroundColor = hasText ? UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0) : UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)
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
        
        let userMsg = Message(content: text, isFromUser: true)
        appendMessage(userMsg)
        
        statusLabel.text = "● Réflexion..."
        statusLabel.textColor = .yellow
        
        DispatchQueue.global(qos: .userInitiated).async {
            if #available(iOS 13.0, *) {
                Task {
                    let response = await AIService.shared.generateResponse(for: text)
                    DispatchQueue.main.async {
                        self.statusLabel.text = "● Prête"
                        self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
                        
                        let aiMsg = Message(content: response, isFromUser: false)
                        self.appendMessage(aiMsg)
                        self.speak(text: response)
                    }
                }
            } else {
                let response = "Bonjour ! J'ai bien reçu votre message : « \(text) »."
                DispatchQueue.main.async {
                    self.statusLabel.text = "● Prête"
                    self.statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
                    
                    let aiMsg = Message(content: response, isFromUser: false)
                    self.appendMessage(aiMsg)
                    self.speak(text: response)
                }
            }
        }
    }
    
    @objc private func toggleMicTapped() {
        isRecording.toggle()
        if isRecording {
            micButton.setTitle("🔴", for: .normal)
            statusLabel.text = "● Écoute en direct..."
            statusLabel.textColor = .red
            AppleSpeechRecognizer.shared.startListening()
            AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] transcript in
                DispatchQueue.main.async {
                    self?.inputTextField.text = transcript
                    self?.sendButtonTapped()
                    self?.toggleMicTapped()
                }
            }
        } else {
            micButton.setTitle("🎙️", for: .normal)
            statusLabel.text = "● Prête"
            statusLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
            AppleSpeechRecognizer.shared.stopListening()
        }
    }
    
    private func appendMessage(_ message: Message) {
        messages.append(message)
        tableView.reloadData()
        scrollToBottom(animated: true)
    }
    
    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    private func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = 0.52
        speechSynthesizer.speak(utterance)
    }
    
    private func loadInitialMessages() {
        let welcome = Message(
            content: "Bonjour ! 👋 Je suis Sarah, votre assistante IA 100% native adaptée pour votre iPhone. Comment puis-je vous aider ?",
            isFromUser: false
        )
        messages = [welcome]
        tableView.reloadData()
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        if message.isFromUser {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! LegacyUserCell
            cell.configure(with: message)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AICell", for: indexPath) as! LegacyAICell
            cell.configure(with: message) { [weak self] in
                self?.speak(text: message.content)
            }
            return cell
        }
    }
}

// MARK: - Cellules UIKit de Message

public final class LegacyUserCell: UITableViewCell {
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.backgroundColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        bubbleView.layer.cornerRadius = 16
        contentView.addSubview(bubbleView)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        bubbleView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func configure(with message: Message) {
        messageLabel.text = message.content
    }
}

public final class LegacyAICell: UITableViewCell {
    private let avatarLabel = UILabel()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let listenButton = UIButton(type: .system)
    private var onListen: (() -> Void)?
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.text = "👩🏻‍💼"
        avatarLabel.font = UIFont.systemFont(ofSize: 22)
        contentView.addSubview(avatarLabel)
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
        bubbleView.layer.cornerRadius = 16
        contentView.addSubview(bubbleView)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        bubbleView.addSubview(messageLabel)
        
        listenButton.translatesAutoresizingMaskIntoConstraints = false
        listenButton.setTitle("🔊 Écouter", for: .normal)
        listenButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        listenButton.tintColor = .cyan
        listenButton.addTarget(self, action: #selector(listenTapped), for: .touchUpInside)
        contentView.addSubview(listenButton)
        
        NSLayoutConstraint.activate([
            avatarLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            avatarLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            avatarLabel.widthAnchor.constraint(equalToConstant: 28),
            avatarLabel.heightAnchor.constraint(equalToConstant: 28),
            
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.leadingAnchor.constraint(equalTo: avatarLabel.trailingAnchor, constant: 6),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            listenButton.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 2),
            listenButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 4),
            listenButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func listenTapped() {
        onListen?()
    }
    
    public func configure(with message: Message, onListen: @escaping () -> Void) {
        messageLabel.text = message.content
        self.onListen = onListen
    }
}
