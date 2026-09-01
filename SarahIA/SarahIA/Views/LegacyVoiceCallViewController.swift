import UIKit

/// Contrôleur UIKit Natif pour l'Appel Vocal WebRTC avec Traduction en Direct (iOS 12+ / iPhone 5s à iPhone 17+)
public final class LegacyVoiceCallViewController: UIViewController {
    
    private let callManager = WebRTCVoiceCallManager.shared
    
    // UI Elements
    private let topBadgeView = UIView()
    private let avatarContainer = UIView()
    private let avatarEmojiLabel = UILabel()
    private let contactNameLabel = UILabel()
    private let statusLabel = UILabel()
    private let durationLabel = UILabel()
    
    private let languageBar = UIView()
    private let localLangButton = UIButton(type: .system)
    private let arrowIconLabel = UILabel()
    private let remoteLangButton = UIButton(type: .system)
    private let voiceTranslationToggle = UIButton(type: .system)
    
    private let transcriptScrollView = UIScrollView()
    private let transcriptStackView = UIStackView()
    
    private let controlsBar = UIView()
    private let muteButton = UIButton(type: .system)
    private let speakerButton = UIButton(type: .system)
    private let hangupButton = UIButton(type: .system)
    
    private var updateTimer: Timer?
    
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
        setupHeader()
        setupLanguageBar()
        setupTranscriptFeed()
        setupControls()
        startUIRefreshTimer()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Configuration de l'En-tête
    private func setupHeader() {
        // Badge Chiffrement WebRTC
        topBadgeView.translatesAutoresizingMaskIntoConstraints = false
        topBadgeView.backgroundColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 0.15)
        topBadgeView.layer.cornerRadius = 10
        view.addSubview(topBadgeView)
        
        let badgeLabel = UILabel()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "🔒 WebRTC P2P Chiffré de bout en bout"
        badgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = UIColor(red: 0.15, green: 0.85, blue: 0.40, alpha: 1.0)
        topBadgeView.addSubview(badgeLabel)
        
        // Avatar
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
        avatarContainer.layer.cornerRadius = 35
        avatarContainer.layer.borderColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.4).cgColor
        avatarContainer.layer.borderWidth = 2.0
        view.addSubview(avatarContainer)
        
        avatarEmojiLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarEmojiLabel.text = callManager.currentContact?.avatarEmoji ?? "👤"
        avatarEmojiLabel.font = UIFont.systemFont(ofSize: 32)
        avatarEmojiLabel.textAlignment = .center
        avatarContainer.addSubview(avatarEmojiLabel)
        
        // Nom du Contact
        contactNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contactNameLabel.text = callManager.currentContact?.name ?? "Correspondant"
        contactNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        contactNameLabel.textColor = .white
        contactNameLabel.textAlignment = .center
        view.addSubview(contactNameLabel)
        
        // Statut & Chronomètre
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "En communication"
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = UIColor.gray
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
        
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.text = "00:00"
        durationLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        durationLabel.textColor = .white
        durationLabel.textAlignment = .center
        view.addSubview(durationLabel)
        
        NSLayoutConstraint.activate([
            topBadgeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topBadgeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topBadgeView.heightAnchor.constraint(equalToConstant: 22),
            
            badgeLabel.leadingAnchor.constraint(equalTo: topBadgeView.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: topBadgeView.trailingAnchor, constant: -10),
            badgeLabel.centerYAnchor.constraint(equalTo: topBadgeView.centerYAnchor),
            
            avatarContainer.topAnchor.constraint(equalTo: topBadgeView.bottomAnchor, constant: 12),
            avatarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: 70),
            avatarContainer.heightAnchor.constraint(equalToConstant: 70),
            
            avatarEmojiLabel.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarEmojiLabel.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            
            contactNameLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: 8),
            contactNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contactNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: contactNameLabel.bottomAnchor, constant: 4),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -26),
            
            durationLabel.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 6)
        ])
    }
    
    // MARK: - Barre de Sélection des Langues
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
        localLangButton.addTarget(self, action: #selector(toggleLocalLanguage), for: .touchUpInside)
        languageBar.addSubview(localLangButton)
        
        arrowIconLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowIconLabel.text = "⇄"
        arrowIconLabel.textColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        arrowIconLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        languageBar.addSubview(arrowIconLabel)
        
        remoteLangButton.translatesAutoresizingMaskIntoConstraints = false
        remoteLangButton.setTitle("\(callManager.languagePair.remoteFlag) \(callManager.languagePair.remoteLanguage.uppercased())", for: .normal)
        remoteLangButton.setTitleColor(.white, for: .normal)
        remoteLangButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        remoteLangButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        remoteLangButton.layer.cornerRadius = 6
        remoteLangButton.addTarget(self, action: #selector(toggleRemoteLanguage), for: .touchUpInside)
        languageBar.addSubview(remoteLangButton)
        
        voiceTranslationToggle.translatesAutoresizingMaskIntoConstraints = false
        voiceTranslationToggle.setTitle("Voix IA Active", for: .normal)
        voiceTranslationToggle.setTitleColor(UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0), for: .normal)
        voiceTranslationToggle.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        voiceTranslationToggle.backgroundColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.20)
        voiceTranslationToggle.layer.cornerRadius = 6
        voiceTranslationToggle.addTarget(self, action: #selector(toggleVoiceTranslation), for: .touchUpInside)
        languageBar.addSubview(voiceTranslationToggle)
        
        NSLayoutConstraint.activate([
            languageBar.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            languageBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            languageBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            languageBar.heightAnchor.constraint(equalToConstant: 38),
            
            localLangButton.leadingAnchor.constraint(equalTo: languageBar.leadingAnchor, constant: 8),
            localLangButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            localLangButton.widthAnchor.constraint(equalToConstant: 64),
            localLangButton.heightAnchor.constraint(equalToConstant: 26),
            
            arrowIconLabel.leadingAnchor.constraint(equalTo: localLangButton.trailingAnchor, constant: 6),
            arrowIconLabel.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            
            remoteLangButton.leadingAnchor.constraint(equalTo: arrowIconLabel.trailingAnchor, constant: 6),
            remoteLangButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            remoteLangButton.widthAnchor.constraint(equalToConstant: 64),
            remoteLangButton.heightAnchor.constraint(equalToConstant: 26),
            
            voiceTranslationToggle.trailingAnchor.constraint(equalTo: languageBar.trailingAnchor, constant: -8),
            voiceTranslationToggle.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            voiceTranslationToggle.heightAnchor.constraint(equalToConstant: 26),
            voiceTranslationToggle.widthAnchor.constraint(equalToConstant: 110)
        ])
    }
    
    // MARK: - Zone Centrale : Sous-Titres Bilingues
    private func setupTranscriptFeed() {
        transcriptScrollView.translatesAutoresizingMaskIntoConstraints = false
        transcriptScrollView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        transcriptScrollView.layer.cornerRadius = 14
        transcriptScrollView.layer.borderColor = UIColor(white: 1.0, alpha: 0.06).cgColor
        transcriptScrollView.layer.borderWidth = 1.0
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
            
            transcriptStackView.topAnchor.constraint(equalTo: transcriptScrollView.topAnchor, constant: 10),
            transcriptStackView.leadingAnchor.constraint(equalTo: transcriptScrollView.leadingAnchor, constant: 10),
            transcriptStackView.trailingAnchor.constraint(equalTo: transcriptScrollView.trailingAnchor, constant: -10),
            transcriptStackView.bottomAnchor.constraint(equalTo: transcriptScrollView.bottomAnchor, constant: -10),
            transcriptStackView.widthAnchor.constraint(equalTo: transcriptScrollView.widthAnchor, constant: -20)
        ])
    }
    
    // MARK: - Barre de Contrôles
    private func setupControls() {
        controlsBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsBar)
        
        // Mute
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.setTitle("🎙️", for: .normal)
        muteButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        muteButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        muteButton.layer.cornerRadius = 28
        muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        controlsBar.addSubview(muteButton)
        
        // Speaker
        speakerButton.translatesAutoresizingMaskIntoConstraints = false
        speakerButton.setTitle("🔊", for: .normal)
        speakerButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        speakerButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        speakerButton.layer.cornerRadius = 28
        speakerButton.addTarget(self, action: #selector(speakerTapped), for: .touchUpInside)
        controlsBar.addSubview(speakerButton)
        
        // Hangup
        hangupButton.translatesAutoresizingMaskIntoConstraints = false
        hangupButton.setTitle("📞", for: .normal)
        hangupButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        hangupButton.backgroundColor = UIColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1.0)
        hangupButton.layer.cornerRadius = 32
        hangupButton.addTarget(self, action: #selector(hangupTapped), for: .touchUpInside)
        controlsBar.addSubview(hangupButton)
        
        NSLayoutConstraint.activate([
            controlsBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            controlsBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlsBar.heightAnchor.constraint(equalToConstant: 70),
            controlsBar.widthAnchor.constraint(equalToConstant: 260),
            
            muteButton.leadingAnchor.constraint(equalTo: controlsBar.leadingAnchor, constant: 10),
            muteButton.centerYAnchor.constraint(equalTo: controlsBar.centerYAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 56),
            muteButton.heightAnchor.constraint(equalToConstant: 56),
            
            speakerButton.centerXAnchor.constraint(equalTo: controlsBar.centerXAnchor),
            speakerButton.centerYAnchor.constraint(equalTo: controlsBar.centerYAnchor),
            speakerButton.widthAnchor.constraint(equalToConstant: 56),
            speakerButton.heightAnchor.constraint(equalToConstant: 56),
            
            hangupButton.trailingAnchor.constraint(equalTo: controlsBar.trailingAnchor, constant: -10),
            hangupButton.centerYAnchor.constraint(equalTo: controlsBar.centerYAnchor),
            hangupButton.widthAnchor.constraint(equalToConstant: 64),
            hangupButton.heightAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    // MARK: - Actions
    @objc private func muteTapped() {
        callManager.toggleMute()
        muteButton.backgroundColor = callManager.isMuted ? UIColor.red.withAlphaComponent(0.3) : UIColor(white: 0.15, alpha: 1.0)
    }
    
    @objc private func speakerTapped() {
        callManager.toggleSpeaker()
        speakerButton.backgroundColor = callManager.isSpeakerOn ? UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.3) : UIColor(white: 0.15, alpha: 1.0)
    }
    
    @objc private func hangupTapped() {
        callManager.endCall()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func toggleLocalLanguage() {
        let current = callManager.languagePair.localLanguage
        let next = (current == "fr") ? "en" : (current == "en" ? "he" : "fr")
        callManager.setLocalLanguage(next)
        localLangButton.setTitle("\(callManager.languagePair.localFlag) \(next.uppercased())", for: .normal)
    }
    
    @objc private func toggleRemoteLanguage() {
        let current = callManager.languagePair.remoteLanguage
        let next = (current == "en") ? "he" : (current == "he" ? "fr" : "en")
        callManager.setTargetLanguage(next)
        remoteLangButton.setTitle("\(callManager.languagePair.remoteFlag) \(next.uppercased())", for: .normal)
    }
    
    @objc private func toggleVoiceTranslation() {
        callManager.toggleVoiceTranslation()
        let active = callManager.languagePair.isVoiceTranslationEnabled
        voiceTranslationToggle.setTitle(active ? "Voix IA Active" : "Bypass Direct", for: .normal)
        voiceTranslationToggle.setTitleColor(active ? UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0) : .gray, for: .normal)
    }
    
    // MARK: - Rafraîchissement UI & Sous-Titres
    private func startUIRefreshTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.durationLabel.text = self.callManager.formattedDuration
            self.refreshTranscriptBubbles()
            
            if !self.callManager.callState.isCallActive && self.callManager.callDuration > 0 {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func refreshTranscriptBubbles() {
        let items = callManager.transcriptItems
        
        // Vider les anciennes vues si le nombre a changé
        if transcriptStackView.arrangedSubviews.count != items.count {
            transcriptStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            for item in items {
                let card = createTranscriptCard(for: item)
                transcriptStackView.addArrangedSubview(card)
            }
            
            // Auto-scroll vers le bas
            DispatchQueue.main.async {
                let bottomOffset = CGPoint(x: 0, y: max(0, self.transcriptScrollView.contentSize.height - self.transcriptScrollView.bounds.height))
                self.transcriptScrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
    
    private func createTranscriptCard(for item: CallTranscriptItem) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 10
        card.backgroundColor = item.isLocalSpeaker ?
            UIColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 1.0) :
            UIColor(red: 0.15, green: 0.12, blue: 0.22, alpha: 1.0)
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 3
        card.addSubview(stack)
        
        let speakerLbl = UILabel()
        speakerLbl.text = item.isLocalSpeaker ? "🇫🇷 Vous (Voix Synthétisée 🔊)" : "🌐 \(callManager.currentContact?.name ?? "Contact")"
        speakerLbl.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        speakerLbl.textColor = item.isLocalSpeaker ? UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0) : UIColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1.0)
        stack.addArrangedSubview(speakerLbl)
        
        let origLbl = UILabel()
        origLbl.text = item.originalText
        origLbl.font = UIFont.systemFont(ofSize: 12)
        origLbl.textColor = UIColor(white: 0.85, alpha: 1.0)
        origLbl.numberOfLines = 0
        stack.addArrangedSubview(origLbl)
        
        let transLbl = UILabel()
        transLbl.text = "💬 \(item.translatedText)"
        transLbl.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        transLbl.textColor = item.isLocalSpeaker ? UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0) : UIColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1.0)
        transLbl.numberOfLines = 0
        stack.addArrangedSubview(transLbl)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        
        return card
    }
}
