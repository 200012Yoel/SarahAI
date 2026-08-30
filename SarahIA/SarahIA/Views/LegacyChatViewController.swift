import UIKit
import AVFoundation
import Speech
import WebKit

/// Contrôleur UIKit 100% Natif de Secours (iOS 12 à iOS 14 / iPhone 5s, 6, 6 Plus)
/// avec support des 4 agents (Sarah, Tom, Raphaël, Yohan), reconnaissance Apple Speech et synthèse vocale.
public final class LegacyChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    private let topBar = UIView()
    private let agentSwitchButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let newChatButton = UIButton(type: .system)
    
    private let tableView = UITableView()
    private let composerContainer = UIView()
    private let inputTextField = UITextField()
    private let micButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    
    private var messages: [Message] = []
    private var activeAgent: AgentType = .sarah
    private var isRecording: Bool = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupSpeechPipeline()
        loadInitialMessages()
    }
    
    private func setupUI() {
        // Topbar
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        view.addSubview(topBar)
        
        agentSwitchButton.translatesAutoresizingMaskIntoConstraints = false
        agentSwitchButton.setTitle("👑 Sarah", for: .normal)
        agentSwitchButton.setTitleColor(.white, for: .normal)
        agentSwitchButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        agentSwitchButton.addTarget(self, action: #selector(toggleAgentTapped), for: .touchUpInside)
        topBar.addSubview(agentSwitchButton)
        
        newChatButton.translatesAutoresizingMaskIntoConstraints = false
        newChatButton.setTitle("＋ Nouvelle discussion", for: .normal)
        newChatButton.setTitleColor(UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0), for: .normal)
        newChatButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 13)
        newChatButton.backgroundColor = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 0.15)
        newChatButton.layer.cornerRadius = 12
        newChatButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        newChatButton.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        topBar.addSubview(newChatButton)
        
        // TableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        // Composer
        composerContainer.translatesAutoresizingMaskIntoConstraints = false
        composerContainer.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        composerContainer.layer.cornerRadius = 22
        view.addSubview(composerContainer)
        
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.placeholder = "Demander à Sarah..."
        inputTextField.textColor = .white
        inputTextField.font = UIFont.systemFont(ofSize: 15)
        inputTextField.delegate = self
        composerContainer.addSubview(inputTextField)
        
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setTitle("🎤", for: .normal)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        composerContainer.addSubview(micButton)
        
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("⬆️", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        composerContainer.addSubview(sendButton)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            agentSwitchButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            agentSwitchButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            newChatButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            newChatButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -8),
            
            composerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            composerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            composerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            composerContainer.heightAnchor.constraint(equalToConstant: 44),
            
            inputTextField.leadingAnchor.constraint(equalTo: composerContainer.leadingAnchor, constant: 14),
            inputTextField.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -6),
            inputTextField.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            
            micButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -4),
            micButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 34),
            
            sendButton.trailingAnchor.constraint(equalTo: composerContainer.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: composerContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34)
        ])
    }
    
    private func setupSpeechPipeline() {
        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] text in
            self?.sendMessage(text)
        }
    }
    
    private func loadInitialMessages() {
        let welcome = Message(
            content: "Bonjour ! 👋 Je suis Sarah, votre assistante IA. Dites-moi simplement « Passe-moi Tom », « Passe-moi Raphaël » ou « Passe-moi Yohan » pour basculer d'un agent à l'autre à tout moment.",
            isFromUser: false
        )
        messages.append(welcome)
        tableView.reloadData()
    }
    
    @objc private func toggleAgentTapped() {
        HapticService.shared.buttonTap()
        let next: AgentType
        switch activeAgent {
        case .sarah:   next = .tom
        case .tom:     next = .raphael
        case .raphael: next = .yohan
        case .yohan:   next = .nathan
        case .nathan:  next = .ethel
        case .ethel:   next = .sarah
        }
        activeAgent = next
        agentSwitchButton.setTitle("\(next.rawValue)", for: .normal)
        inputTextField.placeholder = "Demander à \(next.rawValue)..."
    }
    
    @objc private func newChatTapped() {
        HapticService.shared.buttonTap()
        messages.removeAll()
        loadInitialMessages()
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
            self.agentSwitchButton.setTitle("\(response.agent.rawValue)", for: .normal)
            
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
        cell.textLabel?.textColor = msg.isFromUser ? .white : UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.text = (msg.isFromUser ? "👤 " : "🤖 ") + msg.content
        return cell
    }
}
