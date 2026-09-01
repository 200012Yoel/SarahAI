import UIKit

/// Contrôleur UIKit Talkie-Walkie & Vocal WhatsApp pour iPhone 5s à iPhone 17+ (iOS 12+)
/// - Dispatching WhatsApp par Nathan & Voix/Traduction par Yoann
public final class LegacyWhatsAppVoiceCallViewController: UIViewController {
    
    private let walkieManager = OpenWAVoiceWalkieTalkieManager.shared
    
    // UI Elements
    private let closeButton = UIButton(type: .system)
    private let badgeLabel = UILabel()
    private let avatarContainer = UIView()
    private let avatarEmojiLabel = UILabel()
    private let contactNameLabel = UILabel()
    private let statusLabel = UILabel()
    
    private let languageBar = UIView()
    private let localLangButton = UIButton(type: .system)
    private let remoteLangButton = UIButton(type: .system)
    private let yoannVoiceBadge = UILabel()
    
    private let transcriptScrollView = UIScrollView()
    private let transcriptStackView = UIStackView()
    
    private let pttButton = UIButton(type: .system)
    private let pttHintLabel = UILabel()
    
    private var uiTimer: Timer?
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        setupTopBar()
        setupLanguageBar()
        setupTranscriptFeed()
        setupPTTButton()
        startUITimer()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        uiTimer?.invalidate()
        uiTimer = nil
    }
    
    // MARK: - En-tête
    private func setupTopBar() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        closeButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        closeButton.layer.cornerRadius = 16
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "🤖 Nathan (WA) • 🇮🇱 Yoann (Voix)"
        badgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        badgeLabel.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true
        view.addSubview(badgeLabel)
        
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.backgroundColor = UIColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 1.0)
        avatarContainer.layer.cornerRadius = 35
        avatarContainer.layer.borderColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 0.4).cgColor
        avatarContainer.layer.borderWidth = 2.0
        view.addSubview(avatarContainer)
        
        avatarEmojiLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarEmojiLabel.text = walkieManager.activeContact?.avatarEmoji ?? "💬"
        avatarEmojiLabel.font = UIFont.systemFont(ofSize: 30)
        avatarEmojiLabel.textAlignment = .center
        avatarContainer.addSubview(avatarEmojiLabel)
        
        contactNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contactNameLabel.text = walkieManager.activeContact?.name ?? "Contact WhatsApp"
        contactNameLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        contactNameLabel.textColor = .white
        contactNameLabel.textAlignment = .center
        view.addSubview(contactNameLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = walkieManager.lastStatusMessage
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = UIColor.gray
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            badgeLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            badgeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),
            badgeLabel.widthAnchor.constraint(equalToConstant: 210),
            
            avatarContainer.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: 10),
            avatarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: 70),
            avatarContainer.heightAnchor.constraint(equalToConstant: 70),
            
            avatarEmojiLabel.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarEmojiLabel.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            
            contactNameLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: 6),
            contactNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: contactNameLabel.bottomAnchor, constant: 2),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    // MARK: - Sélecteur de Langues
    private func setupLanguageBar() {
        languageBar.translatesAutoresizingMaskIntoConstraints = false
        languageBar.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.12, alpha: 1.0)
        languageBar.layer.cornerRadius = 10
        view.addSubview(languageBar)
        
        localLangButton.translatesAutoresizingMaskIntoConstraints = false
        localLangButton.setTitle("🇫🇷 FR", for: .normal)
        localLangButton.setTitleColor(.white, for: .normal)
        localLangButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        localLangButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        localLangButton.layer.cornerRadius = 6
        localLangButton.addTarget(self, action: #selector(cycleLocalLang), for: .touchUpInside)
        languageBar.addSubview(localLangButton)
        
        let arrow = UILabel()
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.text = "⇄"
        arrow.textColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 1.0)
        arrow.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        languageBar.addSubview(arrow)
        
        remoteLangButton.translatesAutoresizingMaskIntoConstraints = false
        remoteLangButton.setTitle("\(walkieManager.languagePair.remoteFlag) \(walkieManager.languagePair.remoteLanguage.uppercased())", for: .normal)
        remoteLangButton.setTitleColor(.white, for: .normal)
        remoteLangButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        remoteLangButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        remoteLangButton.layer.cornerRadius = 6
        remoteLangButton.addTarget(self, action: #selector(cycleRemoteLang), for: .touchUpInside)
        languageBar.addSubview(remoteLangButton)
        
        yoannVoiceBadge.translatesAutoresizingMaskIntoConstraints = false
        yoannVoiceBadge.text = "Voix de Yoann 🔊"
        yoannVoiceBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        yoannVoiceBadge.textColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        languageBar.addSubview(yoannVoiceBadge)
        
        NSLayoutConstraint.activate([
            languageBar.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            languageBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            languageBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            languageBar.heightAnchor.constraint(equalToConstant: 36),
            
            localLangButton.leadingAnchor.constraint(equalTo: languageBar.leadingAnchor, constant: 8),
            localLangButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            localLangButton.widthAnchor.constraint(equalToConstant: 60),
            localLangButton.heightAnchor.constraint(equalToConstant: 24),
            
            arrow.leadingAnchor.constraint(equalTo: localLangButton.trailingAnchor, constant: 6),
            arrow.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            
            remoteLangButton.leadingAnchor.constraint(equalTo: arrow.trailingAnchor, constant: 6),
            remoteLangButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            remoteLangButton.widthAnchor.constraint(equalToConstant: 60),
            remoteLangButton.heightAnchor.constraint(equalToConstant: 24),
            
            yoannVoiceBadge.trailingAnchor.constraint(equalTo: languageBar.trailingAnchor, constant: -8),
            yoannVoiceBadge.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor)
        ])
    }
    
    // MARK: - Sous-Titres
    private func setupTranscriptFeed() {
        transcriptScrollView.translatesAutoresizingMaskIntoConstraints = false
        transcriptScrollView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        transcriptScrollView.layer.cornerRadius = 14
        transcriptScrollView.layer.borderWidth = 1.0
        transcriptScrollView.layer.borderColor = UIColor(white: 1.0, alpha: 0.06).cgColor
        view.addSubview(transcriptScrollView)
        
        transcriptStackView.translatesAutoresizingMaskIntoConstraints = false
        transcriptStackView.axis = .vertical
        transcriptStackView.spacing = 10
        transcriptScrollView.addSubview(transcriptStackView)
        
        NSLayoutConstraint.activate([
            transcriptScrollView.topAnchor.constraint(equalTo: languageBar.bottomAnchor, constant: 10),
            transcriptScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            transcriptScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            transcriptScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110),
            
            transcriptStackView.topAnchor.constraint(equalTo: transcriptScrollView.topAnchor, constant: 8),
            transcriptStackView.leadingAnchor.constraint(equalTo: transcriptScrollView.leadingAnchor, constant: 8),
            transcriptStackView.trailingAnchor.constraint(equalTo: transcriptScrollView.trailingAnchor, constant: -8),
            transcriptStackView.bottomAnchor.constraint(equalTo: transcriptScrollView.bottomAnchor, constant: -8),
            transcriptStackView.widthAnchor.constraint(equalTo: transcriptScrollView.widthAnchor, constant: -16)
        ])
    }
    
    // MARK: - Bouton Talkie-Walkie PTT
    private func setupPTTButton() {
        pttButton.translatesAutoresizingMaskIntoConstraints = false
        pttButton.setTitle("🎙️", for: .normal)
        pttButton.titleLabel?.font = UIFont.systemFont(ofSize: 28)
        pttButton.backgroundColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 1.0)
        pttButton.layer.cornerRadius = 35
        pttButton.addTarget(self, action: #selector(pttTapped), for: .touchUpInside)
        view.addSubview(pttButton)
        
        pttHintLabel.translatesAutoresizingMaskIntoConstraints = false
        pttHintLabel.text = "Touchez pour parler (Vocal WhatsApp par Nathan)"
        pttHintLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        pttHintLabel.textColor = UIColor.gray
        pttHintLabel.textAlignment = .center
        view.addSubview(pttHintLabel)
        
        NSLayoutConstraint.activate([
            pttButton.bottomAnchor.constraint(equalTo: pttHintLabel.topAnchor, constant: -6),
            pttButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pttButton.widthAnchor.constraint(equalToConstant: 70),
            pttButton.heightAnchor.constraint(equalToConstant: 70),
            
            pttHintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            pttHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func pttTapped() {
        if walkieManager.isRecording {
            walkieManager.stopAndSendPushToTalk()
            pttButton.backgroundColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 1.0)
            pttButton.setTitle("🎙️", for: .normal)
            pttHintLabel.text = "Vocal transmis à Nathan pour WhatsApp !"
            pttHintLabel.textColor = UIColor.gray
        } else {
            walkieManager.startPushToTalk()
            pttButton.backgroundColor = UIColor.red
            pttButton.setTitle("⏹️", for: .normal)
            pttHintLabel.text = "Enregistrement... Touchez pour envoyer"
            pttHintLabel.textColor = UIColor.red
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func cycleLocalLang() {
        let current = walkieManager.languagePair.localLanguage
        let next = (current == "fr") ? "en" : (current == "en" ? "he" : "fr")
        walkieManager.languagePair.localLanguage = next
        localLangButton.setTitle("\(walkieManager.languagePair.localFlag) \(next.uppercased())", for: .normal)
    }
    
    @objc private func cycleRemoteLang() {
        let current = walkieManager.languagePair.remoteLanguage
        let next = (current == "he") ? "en" : (current == "en" ? "fr" : "he")
        walkieManager.languagePair.remoteLanguage = next
        remoteLangButton.setTitle("\(walkieManager.languagePair.remoteFlag) \(next.uppercased())", for: .normal)
    }
    
    // MARK: - Rafraîchissement UI
    private func startUITimer() {
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.statusLabel.text = self.walkieManager.lastStatusMessage
            self.updateTranscriptCards()
        }
    }
    
    private func updateTranscriptCards() {
        let items = walkieManager.transcriptFeed
        if transcriptStackView.arrangedSubviews.count != items.count {
            transcriptStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for item in items {
                let card = createTranscriptBubble(for: item)
                transcriptStackView.addArrangedSubview(card)
            }
            DispatchQueue.main.async {
                let bottomOffset = CGPoint(x: 0, y: max(0, self.transcriptScrollView.contentSize.height - self.transcriptScrollView.bounds.height))
                self.transcriptScrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
    
    private func createTranscriptBubble(for item: CallTranscriptItem) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 10
        card.backgroundColor = item.isLocalSpeaker ?
            UIColor(red: 0.10, green: 0.18, blue: 0.14, alpha: 1.0) :
            UIColor(red: 0.14, green: 0.12, blue: 0.20, alpha: 1.0)
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 3
        card.addSubview(stack)
        
        let headerLbl = UILabel()
        headerLbl.text = item.isLocalSpeaker ? "🇫🇷 Vous (Vocal PTT WhatsApp)" : "🌐 \(walkieManager.activeContact?.name ?? "Contact")"
        headerLbl.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        headerLbl.textColor = item.isLocalSpeaker ? UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 1.0) : UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        stack.addArrangedSubview(headerLbl)
        
        let origLbl = UILabel()
        origLbl.text = item.originalText
        origLbl.font = UIFont.systemFont(ofSize: 12)
        origLbl.textColor = UIColor(white: 0.85, alpha: 1.0)
        origLbl.numberOfLines = 0
        stack.addArrangedSubview(origLbl)
        
        let transLbl = UILabel()
        transLbl.text = "🗣️ \(item.translatedText)"
        transLbl.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        transLbl.textColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        transLbl.numberOfLines = 0
        stack.addArrangedSubview(transLbl)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6)
        ])
        
        return card
    }
}
