import Foundation
import UIKit
import AVFoundation

/// Contrôleur d'Interface Caméra Temps Réel 100% Conforme à la Maquette (iOS 12 -> 18) :
/// - Aperçu vidéo plein écran haute fluidité avec mise au point et exposition automatiques continues
/// - Boutons supérieurs droits (Bascule Caméra Avant/Arrière, Masquage/Démasquage Temps Réel, Badge Roulette/Drapeaux)
/// - Barre d'actions inférieure flottante (Bouton Bleu Vidéo, Partage d'Écran, Capsule Vocale Électrique Glowing, Microphone, Fermeture ✕)
/// - Reconnexion instantanée sans crash lors du masquage/démasquage physique ou logiciel de l'objectif
public final class LiveCameraViewController: UIViewController {
    
    // MARK: - Callbacks
    public var onPhotoAnalyzed: ((UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void)?
    public var onScreenShareRequested: (() -> Void)?
    
    // MARK: - Vues Principales
    private let previewContainer = UIView()
    private let cameraHiddenOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let cameraHiddenIcon = UIImageView()
    private let focusIndicator = UIView()
    
    // MARK: - Boutons Supérieurs Droits (Top Right)
    private let topButtonsStack = UIStackView()
    private let flipCameraButton = UIButton(type: .system)
    private let hideCameraButton = UIButton(type: .system)
    private let badgeButton = UIButton(type: .custom)
    
    // MARK: - Barre Flottante Inférieure (Bottom Floating Dock)
    private let bottomDock = UIView()
    private let dockStack = UIStackView()
    private let videoActionButton = UIButton(type: .custom)
    private let screenShareButton = UIButton(type: .system)
    private let voiceWaveformPill = UIButton(type: .custom)
    private let micToggleButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
    // MARK: - Indicateur d'Analyse / Statut
    private let statusBanner = UILabel()
    private let voicePulseLayer = CAGradientLayer()
    
    // MARK: - États
    private var isCameraHidden: Bool = false
    private var isMicMuted: Bool = false
    private var isAnalyzing: Bool = false
    private var isListeningVoice: Bool = false
    
    // Synthèse Vocale Dédiée Universelle
    private var speechSynthesizer: AVSpeechSynthesizer?
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupGestures()
        checkCameraPermissionAndSetup()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if !isCameraHidden {
            LiveCameraManager.shared.startSession()
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        LiveCameraManager.shared.updatePreviewLayout(bounds: previewContainer.bounds)
        voicePulseLayer.frame = voiceWaveformPill.bounds
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        LiveCameraManager.shared.stopSession()
    }
    
    deinit {
        LiveCameraManager.shared.stopSession()
    }
    
    // MARK: - Configuration UI (100% Fidèle aux Captures)
    
    private func setupUI() {
        // 1. Conteneur Vidéo Plein Écran
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .black
        view.addSubview(previewContainer)
        
        // 1.1 Voile en cas de masquage de caméra
        cameraHiddenOverlay.translatesAutoresizingMaskIntoConstraints = false
        cameraHiddenOverlay.alpha = 0.0
        previewContainer.addSubview(cameraHiddenOverlay)
        
        cameraHiddenIcon.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            cameraHiddenIcon.image = UIImage(systemName: "camera.fill")
        }
        cameraHiddenIcon.tintColor = UIColor.white.withAlphaComponent(0.6)
        cameraHiddenIcon.contentMode = .scaleAspectFit
        cameraHiddenOverlay.contentView.addSubview(cameraHiddenIcon)
        
        // 1.2 Anneau de focus animé
        focusIndicator.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        focusIndicator.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.9).cgColor
        focusIndicator.layer.borderWidth = 1.8
        focusIndicator.layer.cornerRadius = 32
        focusIndicator.alpha = 0.0
        focusIndicator.isUserInteractionEnabled = false
        previewContainer.addSubview(focusIndicator)
        
        // 2. Bannière de Statut Flottante en haut
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.text = ""
        statusBanner.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusBanner.textColor = .white
        statusBanner.textAlignment = .center
        statusBanner.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusBanner.layer.cornerRadius = 14
        statusBanner.clipsToBounds = true
        statusBanner.alpha = 0.0
        view.addSubview(statusBanner)
        
        // 3. Groupe Supérieur Droit (Top Right Controls)
        topButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        topButtonsStack.axis = .horizontal
        topButtonsStack.spacing = 10
        topButtonsStack.alignment = .center
        topButtonsStack.distribution = .equalSpacing
        view.addSubview(topButtonsStack)
        
        // 3.1 Bouton Bascule Caméra (🔄)
        configureCircularGlassButton(flipCameraButton, iconName: "arrow.triangle.2.circlepath", fallbackText: "🔄", size: 44)
        flipCameraButton.addTarget(self, action: #selector(flipCameraTapped), for: .touchUpInside)
        topButtonsStack.addArrangedSubview(flipCameraButton)
        
        // 3.2 Bouton Masquer / Démasquer Caméra (🚫📷)
        configureCircularGlassButton(hideCameraButton, iconName: "camera.fill", fallbackText: "📷", size: 44)
        hideCameraButton.addTarget(self, action: #selector(toggleHideCameraTapped), for: .touchUpInside)
        topButtonsStack.addArrangedSubview(hideCameraButton)
        
        // 3.3 Badge Roulette / Avatar
        badgeButton.translatesAutoresizingMaskIntoConstraints = false
        badgeButton.layer.cornerRadius = 22
        badgeButton.layer.borderWidth = 1.5
        badgeButton.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.8).cgColor
        badgeButton.backgroundColor = UIColor(white: 0.12, alpha: 0.85)
        badgeButton.clipsToBounds = true
        let badgeIcon = UIImageView()
        if #available(iOS 13.0, *) {
            badgeIcon.image = UIImage(systemName: "circle.grid.cross.fill") ?? UIImage(systemName: "sparkles")
        }
        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badgeIcon.tintColor = UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1.0)
        badgeButton.addSubview(badgeIcon)
        NSLayoutConstraint.activate([
            badgeIcon.centerXAnchor.constraint(equalTo: badgeButton.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badgeButton.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 22),
            badgeIcon.heightAnchor.constraint(equalToConstant: 22),
            badgeButton.widthAnchor.constraint(equalToConstant: 44),
            badgeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        badgeButton.addTarget(self, action: #selector(badgeTapped), for: .touchUpInside)
        topButtonsStack.addArrangedSubview(badgeButton)
        
        // 4. Barre Flottante Inférieure (Bottom Floating Dock)
        bottomDock.translatesAutoresizingMaskIntoConstraints = false
        bottomDock.backgroundColor = .clear
        view.addSubview(bottomDock)
        
        dockStack.translatesAutoresizingMaskIntoConstraints = false
        dockStack.axis = .horizontal
        dockStack.spacing = 10
        dockStack.alignment = .center
        dockStack.distribution = .equalSpacing
        bottomDock.addSubview(dockStack)
        
        // 4.1 Bouton Bleu Vidéo (Gauche)
        videoActionButton.translatesAutoresizingMaskIntoConstraints = false
        videoActionButton.backgroundColor = UIColor(red: 0.20, green: 0.38, blue: 0.88, alpha: 1.0)
        videoActionButton.layer.cornerRadius = 25
        videoActionButton.clipsToBounds = true
        let videoIcon = UIImageView()
        if #available(iOS 13.0, *) {
            videoIcon.image = UIImage(systemName: "video.fill") ?? UIImage(systemName: "camera.fill")
        }
        videoIcon.translatesAutoresizingMaskIntoConstraints = false
        videoIcon.tintColor = .white
        videoIcon.contentMode = .scaleAspectFit
        videoActionButton.addSubview(videoIcon)
        NSLayoutConstraint.activate([
            videoIcon.centerXAnchor.constraint(equalTo: videoActionButton.centerXAnchor),
            videoIcon.centerYAnchor.constraint(equalTo: videoActionButton.centerYAnchor),
            videoIcon.widthAnchor.constraint(equalToConstant: 22),
            videoIcon.heightAnchor.constraint(equalToConstant: 22),
            videoActionButton.widthAnchor.constraint(equalToConstant: 50),
            videoActionButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        videoActionButton.addTarget(self, action: #selector(captureAndAnalyzeTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(videoActionButton)
        
        // 4.2 Bouton Partage d'Écran (Flèche Haute)
        configureCircularGlassButton(screenShareButton, iconName: "arrow.up.to.line", fallbackText: "⬆️", size: 44)
        screenShareButton.addTarget(self, action: #selector(screenShareButtonTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(screenShareButton)
        
        // 4.3 Capsule Vocale Centrale Glowing (Noir avec lueur bleue en bas)
        setupGlowingVoicePill()
        dockStack.addArrangedSubview(voiceWaveformPill)
        
        // 4.4 Bouton Microphone
        configureCircularGlassButton(micToggleButton, iconName: "mic.fill", fallbackText: "🎙️", size: 44)
        micToggleButton.addTarget(self, action: #selector(micButtonTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(micToggleButton)
        
        // 4.5 Bouton Fermer ✕
        configureCircularGlassButton(closeButton, iconName: "xmark", fallbackText: "✕", size: 44)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(closeButton)
        
        // MARK: - Layout Constraints
        let topSafeArea = view.safeAreaLayoutGuide.topAnchor
        let bottomSafeArea = view.safeAreaLayoutGuide.bottomAnchor
        
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            cameraHiddenOverlay.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            cameraHiddenOverlay.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            cameraHiddenOverlay.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            cameraHiddenOverlay.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            
            cameraHiddenIcon.centerXAnchor.constraint(equalTo: cameraHiddenOverlay.centerXAnchor),
            cameraHiddenIcon.centerYAnchor.constraint(equalTo: cameraHiddenOverlay.centerYAnchor),
            cameraHiddenIcon.widthAnchor.constraint(equalToConstant: 64),
            cameraHiddenIcon.heightAnchor.constraint(equalToConstant: 64),
            
            topButtonsStack.topAnchor.constraint(equalTo: topSafeArea, constant: 12),
            topButtonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topButtonsStack.heightAnchor.constraint(equalToConstant: 44),
            
            statusBanner.topAnchor.constraint(equalTo: topSafeArea, constant: 14),
            statusBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusBanner.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusBanner.trailingAnchor.constraint(lessThanOrEqualTo: topButtonsStack.leadingAnchor, constant: -12),
            statusBanner.heightAnchor.constraint(equalToConstant: 32),
            
            bottomDock.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomDock.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomDock.bottomAnchor.constraint(equalTo: bottomSafeArea, constant: -16),
            bottomDock.heightAnchor.constraint(equalToConstant: 60),
            
            dockStack.centerXAnchor.constraint(equalTo: bottomDock.centerXAnchor),
            dockStack.centerYAnchor.constraint(equalTo: bottomDock.centerYAnchor),
            dockStack.leadingAnchor.constraint(greaterThanOrEqualTo: bottomDock.leadingAnchor),
            dockStack.trailingAnchor.constraint(lessThanOrEqualTo: bottomDock.trailingAnchor)
        ])
    }
    
    private func configureCircularGlassButton(_ button: UIButton, iconName: String, fallbackText: String = "", size: CGFloat) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(white: 0.15, alpha: 0.75)
        button.layer.cornerRadius = size / 2
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        button.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            let icon = UIImage(systemName: iconName, withConfiguration: config) ?? UIImage(systemName: iconName)
            button.setImage(icon, for: .normal)
            button.tintColor = .white
        } else {
            button.setTitle(fallbackText.isEmpty ? iconName : fallbackText, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        }
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
        ])
    }
    
    private func setupGlowingVoicePill() {
        voiceWaveformPill.translatesAutoresizingMaskIntoConstraints = false
        voiceWaveformPill.layer.cornerRadius = 23
        voiceWaveformPill.clipsToBounds = true
        voiceWaveformPill.backgroundColor = .black
        
        voicePulseLayer.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor(red: 0.05, green: 0.35, blue: 0.95, alpha: 0.85).cgColor,
            UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0).cgColor
        ]
        voicePulseLayer.locations = [0.0, 0.45, 0.80, 1.0]
        voicePulseLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        voicePulseLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        voiceWaveformPill.layer.insertSublayer(voicePulseLayer, at: 0)
        
        NSLayoutConstraint.activate([
            voiceWaveformPill.widthAnchor.constraint(equalToConstant: 96),
            voiceWaveformPill.heightAnchor.constraint(equalToConstant: 46)
        ])
        
        voiceWaveformPill.addTarget(self, action: #selector(voicePillTapped), for: .touchUpInside)
    }
    
    // MARK: - Gestes & Tap-to-Focus
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        previewContainer.addGestureRecognizer(tap)
    }
    
    @objc private func handlePreviewTap(_ gesture: UITapGestureRecognizer) {
        guard !isCameraHidden else { return }
        let touchPoint = gesture.location(in: previewContainer)
        let devicePoint = CGPoint(
            x: touchPoint.y / previewContainer.bounds.height,
            y: 1.0 - (touchPoint.x / previewContainer.bounds.width)
        )
        
        LiveCameraManager.shared.focusAndExpose(at: devicePoint)
        
        // Animation anneau de focus
        focusIndicator.center = touchPoint
        focusIndicator.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        focusIndicator.alpha = 1.0
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.focusIndicator.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0.5, options: .curveEaseIn, animations: {
                self.focusIndicator.alpha = 0.0
            }, completion: nil)
        }
    }
    
    // MARK: - Permissions & Initialisation Caméra
    
    private func checkCameraPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            LiveCameraManager.shared.setupSession(previewView: previewContainer) { [weak self] success in
                if success {
                    LiveCameraManager.shared.startSession()
                } else {
                    self?.showStatus("Impossible d'accéder à la caméra", isError: true)
                }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.checkCameraPermissionAndSetup()
                    } else {
                        self?.showStatus("Accès caméra refusé", isError: true)
                    }
                }
            }
        case .denied, .restricted:
            showStatus("Activez la caméra dans Réglages", isError: true)
        @unknown default:
            break
        }
    }
    
    // MARK: - Actions des Boutons
    
    @objc private func flipCameraTapped() {
        HapticService.shared.buttonTap()
        LiveCameraManager.shared.switchCamera { [weak self] success in
            if success {
                self?.showStatus("Caméra basculée")
            }
        }
    }
    
    @objc private func toggleHideCameraTapped() {
        HapticService.shared.buttonTap()
        isCameraHidden.toggle()
        
        UIView.animate(withDuration: 0.3) {
            self.cameraHiddenOverlay.alpha = self.isCameraHidden ? 1.0 : 0.0
        }
        
        if isCameraHidden {
            hideCameraButton.tintColor = .systemRed
            showStatus("Caméra en veille")
        } else {
            hideCameraButton.tintColor = .white
            LiveCameraManager.shared.startSession()
            LiveCameraManager.shared.resetContinuousAutoFocus()
            showStatus("Caméra active")
        }
    }
    
    @objc private func badgeTapped() {
        HapticService.shared.buttonTap()
        showStatus("Vision Sarah IA 2.0")
    }
    
    @objc private func captureAndAnalyzeTapped() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        HapticService.shared.buttonTap()
        
        showStatus("🔍 Analyse de la scène...")
        videoActionButton.alpha = 0.6
        
        LiveCameraManager.shared.captureSnapshot { [weak self] capturedImage in
            guard let self = self, let image = capturedImage else {
                self?.isAnalyzing = false
                self?.videoActionButton.alpha = 1.0
                self?.showStatus("Erreur capture image", isError: true)
                return
            }
            
            LocalVisionEngine.shared.recognizeObject(in: image) { [weak self] result in
                guard let self = self else { return }
                self.isAnalyzing = false
                self.videoActionButton.alpha = 1.0
                
                // Détection d'un QR Code de synchronisation Sarah
                if result.detectedText.contains("sarahsync://") || result.detectedText.contains("sarahpayload://") || result.detectedText.contains("sarah://sync") {
                    self.showStatus("⚡ Synchronisation Sarah...")
                    self.speak("QR Code Sarah détecté ! Synchronisation des discussions en cours...")
                    LocalSyncServerService.shared.performSync(with: result.detectedText) { [weak self] success, message in
                        guard let self = self else { return }
                        if success {
                            HapticService.shared.notificationSuccess()
                            self.speak("Synchronisation terminée avec succès !")
                            self.dismiss(animated: true) {
                                self.onPhotoAnalyzed?(image, result)
                            }
                        } else {
                            self.showStatus("⚠️ Échec de synchronisation", isError: true)
                        }
                    }
                } else {
                    self.showStatus("✅ \(result.objectLabel)")
                    self.speak(result.naturalSpokenResponse)
                    self.dismiss(animated: true) {
                        self.onPhotoAnalyzed?(image, result)
                    }
                }
            }
        }
    }
    
    @objc private func voicePillTapped() {
        HapticService.shared.buttonTap()
        isListeningVoice.toggle()
        
        if isListeningVoice {
            showStatus("🎙️ Sarah vous écoute et observe...")
            speak("Je regarde ce que vous me montrez. Posez-moi une question !")
            
            // Animation pulsation
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.duration = 0.8
            pulse.fromValue = 1.0
            pulse.toValue = 1.06
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            voiceWaveformPill.layer.add(pulse, forKey: "pulse")
        } else {
            showStatus("Microphone en pause")
            voiceWaveformPill.layer.removeAnimation(forKey: "pulse")
        }
    }
    
    @objc private func screenShareButtonTapped() {
        HapticService.shared.buttonTap()
        let modal = ScreenShareModalViewController()
        modal.modalPresentationStyle = .overFullScreen
        modal.modalTransitionStyle = .crossDissolve
        modal.onStartBroadcast = { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                self.onScreenShareRequested?()
                ScreenShareService.shared.startLiveScreenSharing(from: self) { success, message in
                    print("📺 Screen share result: \(message)")
                }
            }
        }
        present(modal, animated: true, completion: nil)
    }
    
    @objc private func micButtonTapped() {
        HapticService.shared.buttonTap()
        isMicMuted.toggle()
        let iconName = isMicMuted ? "mic.slash.fill" : "mic.fill"
        if #available(iOS 13.0, *) {
            micToggleButton.setImage(UIImage(systemName: iconName), for: .normal)
        } else {
            micToggleButton.setTitle(isMicMuted ? "🔇" : "🎙️", for: .normal)
        }
        micToggleButton.tintColor = isMicMuted ? .systemRed : .white
        showStatus(isMicMuted ? "Microphone coupé" : "Microphone activé")
    }
    
    @objc private func closeButtonTapped() {
        HapticService.shared.buttonTap()
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helpers & Synthèse Vocale
    
    private func showStatus(_ text: String, isError: Bool = false) {
        statusBanner.text = "  \(text)  "
        statusBanner.textColor = isError ? .systemRed : .white
        UIView.animate(withDuration: 0.25) {
            self.statusBanner.alpha = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.statusBanner.alpha = 0.0
            }
        }
    }
    
    private func speak(_ text: String) {
        if speechSynthesizer == nil {
            speechSynthesizer = AVSpeechSynthesizer()
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer?.speak(utterance)
    }
}
