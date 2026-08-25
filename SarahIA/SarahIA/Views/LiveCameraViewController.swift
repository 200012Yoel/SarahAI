import Foundation
import UIKit
import AVFoundation

/// Contrôleur d'Interface Caméra Temps Réel Ultra-Rapide (0ms) & Responsive :
/// - Démarrage caméra instantané sans délai
/// - Interface épurée et immersive (badge central superflu retiré)
/// - Carré Bleu Futuriste Central aux Vagues Animées en Temps Réel (SarahVoiceWaveSquareView)
/// - Contrôles supérieurs discrets : Fermeture ✕, Flash/Torche ⚡, Bascule caméra 🔄, Veille caméra 📷
/// - Barre d'actions inférieure : Bouton Capture IA 📷, Carré Bleu aux Vagues 🌊, Partage d'Écran 📲, Micro 🎙️
/// - Conversation vocale directe avec Sarah/Tom sans latence
public final class LiveCameraViewController: UIViewController {
    
    // MARK: - Callbacks
    public var onPhotoAnalyzed: ((UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void)?
    public var onScreenShareRequested: (() -> Void)?
    
    // MARK: - Vues Principales
    private let previewContainer = UIView()
    private let cameraHiddenOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let cameraHiddenIcon = UIImageView()
    private let cameraHiddenLabel = UILabel()
    private let focusIndicator = UIView()
    
    // MARK: - Barre Flottante Inférieure Futuriste (Bottom Dock)
    private let bottomDockContainer = UIView()
    private let dockBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let dockStack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let captureActionButton = UIButton(type: .custom)
    private let voiceWaveSquare = SarahVoiceWaveSquareView(frame: .zero)
    private let screenShareButton = UIButton(type: .system)
    
    // MARK: - Statut & Carte Résultat
    private let statusBanner = UILabel()
    private let recognizedObjectCard = UIView()
    private let recognizedObjectLabel = UILabel()
    
    // MARK: - États
    private var isCameraHidden: Bool = false
    private var isMicMuted: Bool = false
    private var isAnalyzing: Bool = false
    private var isVoiceActive: Bool = true
    private var micLevelTimer: Timer?
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupGestures()
        
        // Attachement immédiat sans aucun délai d'attente
        LiveCameraManager.shared.attachPreview(to: previewContainer)
        checkCameraPermissionAndSetup()
        setupVoiceVisualizer()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissAllNotification),
            name: NSNotification.Name("SarahDismissAllModals"),
            object: nil
        )
    }
    
    @objc private func handleDismissAllNotification() {
        LiveCameraManager.shared.stopSession()
        dismiss(animated: true, completion: nil)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if !isCameraHidden {
            LiveCameraManager.shared.startSession()
        }
        voiceWaveSquare.startAnimating()
        startMicLevelMonitoring()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bringControlsToFront()
        
        // Accueil vocal instantané léger et direct
        TTSManager.shared.handOffToTom(
            sarahTransitionPhrase: "Je regarde ce que tu me montres.",
            tomGreeting: ""
        )
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        LiveCameraManager.shared.updatePreviewLayout(bounds: previewContainer.bounds)
        bringControlsToFront()
    }
    
    private func bringControlsToFront() {
        view.bringSubviewToFront(previewContainer)
        view.bringSubviewToFront(recognizedObjectCard)
        view.bringSubviewToFront(statusBanner)
        view.bringSubviewToFront(bottomDockContainer)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        LiveCameraManager.shared.stopSession()
        voiceWaveSquare.stopAnimating()
        stopMicLevelMonitoring()
        AppleSpeechRecognizer.shared.stopListening()
    }
    
    deinit {
        LiveCameraManager.shared.stopSession()
        stopMicLevelMonitoring()
    }
    
    // MARK: - Configuration UI Épurée & Fluide (100% Immersive)
    
    private func setupUI() {
        let isSmallScreen = UIScreen.main.bounds.width <= 360 // iPhone 5S, SE
        let btnSize: CGFloat = isSmallScreen ? 42 : 48
        let squareSize: CGFloat = isSmallScreen ? 56 : 64
        let captureBtnSize: CGFloat = isSmallScreen ? 48 : 54
        let stackSpacing: CGFloat = isSmallScreen ? 12 : 18
        
        // 1. Conteneur Vidéo Plein Écran
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .black
        view.addSubview(previewContainer)
        
        // 1.1 Voile en cas de mise en veille
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
        
        cameraHiddenLabel.translatesAutoresizingMaskIntoConstraints = false
        cameraHiddenLabel.text = "Caméra en veille"
        cameraHiddenLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        cameraHiddenLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        cameraHiddenLabel.textAlignment = .center
        cameraHiddenOverlay.contentView.addSubview(cameraHiddenLabel)
        
        // 1.2 Réticule de Focus Animé
        focusIndicator.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        focusIndicator.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.95).cgColor
        focusIndicator.layer.borderWidth = 1.8
        focusIndicator.layer.cornerRadius = 32
        focusIndicator.layer.shadowColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.8).cgColor
        focusIndicator.layer.shadowRadius = 8
        focusIndicator.layer.shadowOpacity = 0.8
        focusIndicator.layer.shadowOffset = .zero
        focusIndicator.alpha = 0.0
        focusIndicator.isUserInteractionEnabled = false
        previewContainer.addSubview(focusIndicator)
        
        // 2. Carte Objet Reconnu Flottante en Haut
        recognizedObjectCard.translatesAutoresizingMaskIntoConstraints = false
        recognizedObjectCard.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.88)
        recognizedObjectCard.layer.cornerRadius = 16
        recognizedObjectCard.layer.borderWidth = 1.2
        recognizedObjectCard.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.75).cgColor
        recognizedObjectCard.clipsToBounds = true
        recognizedObjectCard.alpha = 0.0
        view.addSubview(recognizedObjectCard)
        
        recognizedObjectLabel.translatesAutoresizingMaskIntoConstraints = false
        recognizedObjectLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        recognizedObjectLabel.textColor = .white
        recognizedObjectLabel.textAlignment = .center
        recognizedObjectLabel.numberOfLines = 2
        recognizedObjectCard.addSubview(recognizedObjectLabel)
        
        // Bannière de Statut Flottante
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        statusBanner.textColor = .white
        statusBanner.textAlignment = .center
        statusBanner.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        statusBanner.layer.cornerRadius = 15
        statusBanner.layer.borderWidth = 0.5
        statusBanner.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        statusBanner.clipsToBounds = true
        statusBanner.alpha = 0.0
        view.addSubview(statusBanner)
        
        // 3. Barre Flottante Inférieure Futuriste (Bottom Dock)
        bottomDockContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomDockContainer.backgroundColor = UIColor(white: 0.10, alpha: 0.85)
        bottomDockContainer.layer.cornerRadius = (squareSize + 18) / 2
        bottomDockContainer.layer.borderWidth = 1.0
        bottomDockContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        bottomDockContainer.layer.shadowColor = UIColor.black.cgColor
        bottomDockContainer.layer.shadowOpacity = 0.5
        bottomDockContainer.layer.shadowRadius = 12
        bottomDockContainer.layer.shadowOffset = CGSize(width: 0, height: 6)
        bottomDockContainer.clipsToBounds = true
        view.addSubview(bottomDockContainer)
        
        dockBlurView.translatesAutoresizingMaskIntoConstraints = false
        bottomDockContainer.addSubview(dockBlurView)
        
        dockStack.translatesAutoresizingMaskIntoConstraints = false
        dockStack.axis = .horizontal
        dockStack.spacing = stackSpacing
        dockStack.alignment = .center
        dockStack.distribution = .equalCentering
        bottomDockContainer.addSubview(dockStack)
        
        // 3.1 Bouton Fermer ✕ (Gauche)
        configureCircularGlassButton(closeButton, iconName: "xmark", fallbackText: "✕", size: btnSize)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(closeButton)
        
        // 3.2 Bouton Capture & Analyse IA (Centre-Gauche)
        captureActionButton.translatesAutoresizingMaskIntoConstraints = false
        captureActionButton.backgroundColor = UIColor(red: 0.10, green: 0.45, blue: 0.98, alpha: 1.0)
        captureActionButton.layer.cornerRadius = captureBtnSize / 2
        captureActionButton.layer.borderWidth = 1.5
        captureActionButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        captureActionButton.clipsToBounds = true
        let captureIcon = UIImageView()
        if #available(iOS 13.0, *) {
            captureIcon.image = UIImage(systemName: "sparkles") ?? UIImage(systemName: "camera.fill")
        }
        captureIcon.translatesAutoresizingMaskIntoConstraints = false
        captureIcon.tintColor = .white
        captureIcon.contentMode = .scaleAspectFit
        captureActionButton.addSubview(captureIcon)
        NSLayoutConstraint.activate([
            captureIcon.centerXAnchor.constraint(equalTo: captureActionButton.centerXAnchor),
            captureIcon.centerYAnchor.constraint(equalTo: captureActionButton.centerYAnchor),
            captureIcon.widthAnchor.constraint(equalToConstant: captureBtnSize * 0.48),
            captureIcon.heightAnchor.constraint(equalToConstant: captureBtnSize * 0.48),
            captureActionButton.widthAnchor.constraint(equalToConstant: captureBtnSize),
            captureActionButton.heightAnchor.constraint(equalToConstant: captureBtnSize)
        ])
        captureActionButton.addTarget(self, action: #selector(captureAndAnalyzeTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(captureActionButton)
        
        // 3.3 LE CARRÉ BLEU AUX VAGUES ANIMÉES (Centre du Dock)
        voiceWaveSquare.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            voiceWaveSquare.widthAnchor.constraint(equalToConstant: squareSize),
            voiceWaveSquare.heightAnchor.constraint(equalToConstant: squareSize)
        ])
        voiceWaveSquare.onTap = { [weak self] in
            self?.toggleVoiceInteraction()
        }
        dockStack.addArrangedSubview(voiceWaveSquare)
        
        // 3.4 Bouton Partage d'Écran (Droite)
        configureCircularGlassButton(screenShareButton, iconName: "arrow.up.to.line", fallbackText: "📲", size: btnSize)
        screenShareButton.addTarget(self, action: #selector(screenShareButtonTapped), for: .touchUpInside)
        dockStack.addArrangedSubview(screenShareButton)
        
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
            cameraHiddenIcon.centerYAnchor.constraint(equalTo: cameraHiddenOverlay.centerYAnchor, constant: -16),
            cameraHiddenIcon.widthAnchor.constraint(equalToConstant: 56),
            cameraHiddenIcon.heightAnchor.constraint(equalToConstant: 56),
            
            cameraHiddenLabel.topAnchor.constraint(equalTo: cameraHiddenIcon.bottomAnchor, constant: 10),
            cameraHiddenLabel.centerXAnchor.constraint(equalTo: cameraHiddenOverlay.centerXAnchor),
            
            recognizedObjectCard.topAnchor.constraint(equalTo: topSafeArea, constant: 16),
            recognizedObjectCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recognizedObjectCard.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            recognizedObjectCard.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            
            recognizedObjectLabel.topAnchor.constraint(equalTo: recognizedObjectCard.topAnchor, constant: 10),
            recognizedObjectLabel.bottomAnchor.constraint(equalTo: recognizedObjectCard.bottomAnchor, constant: -10),
            recognizedObjectLabel.leadingAnchor.constraint(equalTo: recognizedObjectCard.leadingAnchor, constant: 16),
            recognizedObjectLabel.trailingAnchor.constraint(equalTo: recognizedObjectCard.trailingAnchor, constant: -16),
            
            statusBanner.bottomAnchor.constraint(equalTo: bottomDockContainer.topAnchor, constant: -16),
            statusBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusBanner.heightAnchor.constraint(equalToConstant: 32),
            
            bottomDockContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomDockContainer.bottomAnchor.constraint(equalTo: bottomSafeArea, constant: -14),
            bottomDockContainer.heightAnchor.constraint(equalToConstant: squareSize + 18),
            
            dockBlurView.topAnchor.constraint(equalTo: bottomDockContainer.topAnchor),
            dockBlurView.leadingAnchor.constraint(equalTo: bottomDockContainer.leadingAnchor),
            dockBlurView.trailingAnchor.constraint(equalTo: bottomDockContainer.trailingAnchor),
            dockBlurView.bottomAnchor.constraint(equalTo: bottomDockContainer.bottomAnchor),
            
            dockStack.topAnchor.constraint(equalTo: bottomDockContainer.topAnchor, constant: 8),
            dockStack.bottomAnchor.constraint(equalTo: bottomDockContainer.bottomAnchor, constant: -8),
            dockStack.leadingAnchor.constraint(equalTo: bottomDockContainer.leadingAnchor, constant: 14),
            dockStack.trailingAnchor.constraint(equalTo: bottomDockContainer.trailingAnchor, constant: -14)
        ])
    }
    
    private func configureCircularGlassButton(_ button: UIButton, iconName: String, fallbackText: String = "", size: CGFloat) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(white: 0.15, alpha: 0.82)
        button.layer.cornerRadius = size / 2
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        button.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            let pointSize: CGFloat = size <= 40 ? 15 : 17
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            let icon = UIImage(systemName: iconName, withConfiguration: config) ?? UIImage(systemName: iconName)
            button.setImage(icon, for: .normal)
            button.tintColor = .white
        } else {
            button.setTitle(fallbackText.isEmpty ? iconName : fallbackText, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        }
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
        ])
    }
    
    // MARK: - Visualiseur & Monitoring Micro Temps Réel
    
    private func setupVoiceVisualizer() {
        voiceWaveSquare.audioLevel = 0.40
    }
    
    private func startMicLevelMonitoring() {
        micLevelTimer?.invalidate()
        micLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isVoiceActive, !self.isMicMuted else { return }
            
            if TTSManager.shared.isSpeaking {
                let randomLevel = Float.random(in: 0.65...0.95)
                self.voiceWaveSquare.audioLevel = randomLevel
            } else if AppleSpeechRecognizer.shared.isListening {
                let micLevel = max(0.25, AppleSpeechRecognizer.shared.micEnergyLevel)
                self.voiceWaveSquare.audioLevel = micLevel
            } else {
                self.voiceWaveSquare.audioLevel = 0.25
            }
        }
    }
    
    private func stopMicLevelMonitoring() {
        micLevelTimer?.invalidate()
        micLevelTimer = nil
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
        
        focusIndicator.center = touchPoint
        focusIndicator.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        focusIndicator.alpha = 1.0
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.focusIndicator.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0.4, options: .curveEaseIn, animations: {
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
    
    @objc private func toggleVoiceInteraction() {
        isVoiceActive.toggle()
        voiceWaveSquare.setActive(isVoiceActive)
        
        if isVoiceActive {
            showStatus("🎙️ Sarah vous écoute en direct...")
            speak("Je regarde ce que tu me montres. Pose-moi une question !")
        } else {
            showStatus("Mode vocal en pause")
            TTSManager.shared.stop()
        }
    }
    
    @objc private func captureAndAnalyzeTapped() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        HapticService.shared.buttonTap()
        
        showStatus("🔍 Analyse de l'image...")
        captureActionButton.alpha = 0.6
        
        LiveCameraManager.shared.captureSnapshot { [weak self] capturedImage in
            guard let self = self, let image = capturedImage else {
                self?.isAnalyzing = false
                self?.captureActionButton.alpha = 1.0
                self?.showStatus("Erreur capture image", isError: true)
                return
            }
            
            LocalVisionEngine.shared.recognizeObject(in: image) { [weak self] result in
                guard let self = self else { return }
                self.isAnalyzing = false
                self.captureActionButton.alpha = 1.0
                
                self.recognizedObjectLabel.text = "👁️ \(result.objectLabel)\n\(result.detectedText.prefix(60))"
                UIView.animate(withDuration: 0.25) {
                    self.recognizedObjectCard.alpha = 1.0
                }
                
                if result.detectedText.contains("sarahsync://") || result.detectedText.contains("sarahpayload://") || result.detectedText.contains("sarah://sync") {
                    self.showStatus("⚡ Synchronisation Sarah...")
                    self.speak("QR Code Sarah détecté ! Synchronisation en cours...")
                    LocalSyncServerService.shared.performSync(with: result.detectedText) { [weak self] success, message in
                        guard let self = self else { return }
                        if success {
                            HapticService.shared.notificationSuccess()
                            self.speak("Synchronisation réussie !")
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
    
    @objc private func screenShareButtonTapped() {
        HapticService.shared.buttonTap()
        let rootVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.keyWindow?.rootViewController
            ?? self.presentingViewController
        
        self.dismiss(animated: true) { [weak self] in
            self?.onScreenShareRequested?()
            ScreenShareService.shared.startLiveScreenSharing(from: rootVC) { success, message in
                print("📺 Screen share: \(message)")
            }
        }
    }
    
    @objc private func closeButtonTapped() {
        HapticService.shared.buttonTap()
        LiveCameraManager.shared.stopSession()
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helpers & Synthèse Vocale
    
    private func showStatus(_ text: String, isError: Bool = false) {
        statusBanner.text = "  \(text)  "
        statusBanner.textColor = isError ? .systemRed : .white
        UIView.animate(withDuration: 0.2) {
            self.statusBanner.alpha = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.statusBanner.alpha = 0.0
            }
        }
    }
    
    private func speak(_ text: String) {
        TTSManager.shared.speakAsSarah(text)
    }
}
