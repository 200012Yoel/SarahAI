import Foundation
import UIKit
import AVFoundation

/// Contrôleur d'Interface Caméra Plein Écran Dédié, Léger & Haute Précision :
/// - Flux vidéo temps réel fluide en basse résolution (.vga640x480) pour garantir 60 FPS sans surchauffe
/// - Tap-to-Focus interactif avec anneau visuel animé pour mise au point instantanée
/// - Barre de contrôle inférieure (Microphone Mute/Unmute, Partage d'Écran Live +, Déclencheur, Galerie)
/// - Gestion des permissions avec redirection directe vers Réglages si l'accès est refusé
/// - Reconnexion automatique lors du retour de l'application au premier plan
public final class LiveCameraViewController: UIViewController {
    
    // MARK: - Callbacks
    public var onPhotoAnalyzed: ((UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void)?
    public var onScreenShareRequested: (() -> Void)?
    
    // MARK: - Propriétés UI
    private let previewContainer = UIView()
    private let focusIndicator = UIView()
    
    private let topBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleBadge = UILabel()
    private let switchCameraButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    
    private let bottomControlBar = UIView()
    private let controlsStack = UIStackView()
    private let micToggleButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .custom)
    private let galleryButton = UIButton(type: .system)
    private let statusBanner = UILabel()
    
    private var isMicMuted: Bool = false
    private var isTorchOn: Bool = false
    private var isAnalyzing: Bool = false
    
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
        LiveCameraManager.shared.startSession()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        LiveCameraManager.shared.updatePreviewLayout(bounds: previewContainer.bounds)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        LiveCameraManager.shared.stopSession()
        if isTorchOn {
            toggleTorch(enable: false)
        }
    }
    
    deinit {
        LiveCameraManager.shared.stopSession()
    }
    
    // MARK: - Configuration UI
    
    private func setupUI() {
        // 1. Conteneur d'Aperçu Caméra
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .black
        view.addSubview(previewContainer)
        
        // 1.1 Anneau visuel de mise au point (Tap-to-Focus)
        focusIndicator.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        focusIndicator.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.9).cgColor
        focusIndicator.layer.borderWidth = 1.8
        focusIndicator.layer.cornerRadius = 32
        focusIndicator.alpha = 0.0
        focusIndicator.isUserInteractionEnabled = false
        previewContainer.addSubview(focusIndicator)
        
        // 2. Barre Supérieure
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.addSubview(topBar)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        closeButton.layer.cornerRadius = 18
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        titleBadge.translatesAutoresizingMaskIntoConstraints = false
        titleBadge.text = "👁️ Vision Sarah"
        titleBadge.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleBadge.textColor = .white
        titleBadge.textAlignment = .center
        titleBadge.backgroundColor = UIColor(red: 0.0, green: 0.52, blue: 1.0, alpha: 0.3)
        titleBadge.layer.cornerRadius = 13
        titleBadge.layer.borderWidth = 0.8
        titleBadge.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.5).cgColor
        titleBadge.clipsToBounds = true
        topBar.addSubview(titleBadge)
        
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.setTitle("🔄", for: .normal)
        switchCameraButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        switchCameraButton.backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        switchCameraButton.layer.cornerRadius = 18
        switchCameraButton.clipsToBounds = true
        switchCameraButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        topBar.addSubview(switchCameraButton)
        
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setTitle("🔦", for: .normal)
        flashButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        flashButton.backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        flashButton.layer.cornerRadius = 18
        flashButton.clipsToBounds = true
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        topBar.addSubview(flashButton)
        
        // 3. Bannière de Statut Dynamique
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.text = "Visez un objet ou document à analyser"
        statusBanner.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusBanner.textColor = UIColor(white: 0.9, alpha: 1.0)
        statusBanner.textAlignment = .center
        statusBanner.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusBanner.layer.cornerRadius = 12
        statusBanner.clipsToBounds = true
        view.addSubview(statusBanner)
        
        // 4. Barre de Contrôle Inférieure (Optimisée iPhone 5S 320pt)
        bottomControlBar.translatesAutoresizingMaskIntoConstraints = false
        bottomControlBar.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.88)
        bottomControlBar.layer.cornerRadius = 28
        bottomControlBar.layer.borderWidth = 0.5
        bottomControlBar.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        bottomControlBar.clipsToBounds = true
        view.addSubview(bottomControlBar)
        
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .horizontal
        controlsStack.alignment = .center
        controlsStack.distribution = .equalCentering
        controlsStack.spacing = 8
        bottomControlBar.addSubview(controlsStack)
        
        // 4.1 Bouton Microphone Toggle (Mute / Unmute)
        micToggleButton.translatesAutoresizingMaskIntoConstraints = false
        micToggleButton.setTitle("🎙️", for: .normal)
        micToggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        micToggleButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        micToggleButton.layer.cornerRadius = 22
        micToggleButton.clipsToBounds = true
        micToggleButton.addTarget(self, action: #selector(micToggleTapped), for: .touchUpInside)
        micToggleButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        micToggleButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        controlsStack.addArrangedSubview(micToggleButton)
        
        // 4.2 Bouton Plus (+) pour Partage d'Écran & Options
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.setTitle("＋", for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        plusButton.layer.cornerRadius = 22
        plusButton.clipsToBounds = true
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        plusButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        plusButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        controlsStack.addArrangedSubview(plusButton)
        
        // 4.3 Bouton Shutter Déclencheur Principal
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 32
        shutterButton.layer.borderWidth = 3.5
        shutterButton.layer.borderColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.8).cgColor
        shutterButton.clipsToBounds = true
        shutterButton.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)
        shutterButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
        shutterButton.heightAnchor.constraint(equalToConstant: 64).isActive = true
        controlsStack.addArrangedSubview(shutterButton)
        
        // 4.4 Bouton Galerie
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.setTitle("🖼️", for: .normal)
        galleryButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        galleryButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        galleryButton.layer.cornerRadius = 22
        galleryButton.clipsToBounds = true
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        galleryButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        galleryButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        controlsStack.addArrangedSubview(galleryButton)
        
        // Contraintes AutoLayout
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 10),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            titleBadge.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleBadge.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleBadge.heightAnchor.constraint(equalToConstant: 26),
            titleBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            switchCameraButton.trailingAnchor.constraint(equalTo: flashButton.leadingAnchor, constant: -8),
            switchCameraButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 36),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 36),
            
            flashButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -10),
            flashButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 36),
            flashButton.heightAnchor.constraint(equalToConstant: 36),
            
            statusBanner.bottomAnchor.constraint(equalTo: bottomControlBar.topAnchor, constant: -12),
            statusBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusBanner.heightAnchor.constraint(equalToConstant: 28),
            statusBanner.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            
            bottomControlBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            bottomControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            bottomControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            bottomControlBar.heightAnchor.constraint(equalToConstant: 80),
            
            controlsStack.leadingAnchor.constraint(equalTo: bottomControlBar.leadingAnchor, constant: 10),
            controlsStack.trailingAnchor.constraint(equalTo: bottomControlBar.trailingAnchor, constant: -10),
            controlsStack.centerYAnchor.constraint(equalTo: bottomControlBar.centerYAnchor)
        ])
    }
    
    // MARK: - Gestes & Tap-to-Focus
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        previewContainer.addGestureRecognizer(tap)
    }
    
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: previewContainer)
        showFocusIndicator(at: point)
        
        guard previewContainer.bounds.width > 0 && previewContainer.bounds.height > 0 else { return }
        guard let device = AVCaptureDevice.default(for: .video), device.isFocusPointOfInterestSupported else { return }
        let focusPoint = CGPoint(x: max(0.0, min(1.0, point.y / previewContainer.bounds.height)), y: max(0.0, min(1.0, 1.0 - (point.x / previewContainer.bounds.width))))
        
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [LiveCameraViewController] Erreur focus: \(error)")
        }
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        focusIndicator.center = point
        focusIndicator.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        focusIndicator.alpha = 1.0
        
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut], animations: {
            self.focusIndicator.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 0.6, options: [.curveEaseIn], animations: {
                self.focusIndicator.alpha = 0.0
            }, completion: nil)
        }
    }
    
    // MARK: - Vérification Permissions & Configuration Caméra
    
    private func checkCameraPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionAlert()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert()
        @unknown default:
            setupCamera()
        }
    }
    
    private func showPermissionAlert() {
        statusBanner.text = "⚠️ Accès caméra requis"
        statusBanner.textColor = .systemRed
        
        let alert = UIAlertController(
            title: "📷 Accès Caméra Nécessaire",
            message: "Pour permettre à Sarah d'analyser vos objets et documents, activez la caméra dans les Réglages de votre iPhone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Ouvrir Réglages", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func setupCamera() {
        LiveCameraManager.shared.setupSession(previewView: previewContainer) { [weak self] success in
            guard let self = self else { return }
            if !success {
                self.statusBanner.text = "⚠️ Caméra non disponible"
                self.statusBanner.textColor = .systemRed
            } else {
                LiveCameraManager.shared.startSession()
                self.statusBanner.text = "Visez un objet ou document à analyser"
                self.statusBanner.textColor = .white
            }
        }
    }
    
    // MARK: - Actions Utilisateur
    
    @objc private func switchCameraTapped() {
        HapticService.shared.buttonTap()
        LiveCameraManager.shared.switchCamera { [weak self] success in
            if success {
                self?.statusBanner.text = "Caméra basculée 🔄"
            }
        }
    }
    
    @objc private func closeButtonTapped() {
        HapticService.shared.buttonTap()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func micToggleTapped() {
        HapticService.shared.buttonTap()
        isMicMuted.toggle()
        micToggleButton.setTitle(isMicMuted ? "🔇" : "🎙️", for: .normal)
        micToggleButton.backgroundColor = isMicMuted ? UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.8) : UIColor(white: 0.2, alpha: 0.8)
        statusBanner.text = isMicMuted ? "Microphone désactivé" : "Microphone prêt"
    }
    
    @objc private func plusButtonTapped() {
        HapticService.shared.buttonTap()
        let sheet = UIAlertController(title: "Partage & Options Visuelles", message: "Partagez votre écran en direct ou ajustez la caméra :", preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "🖥️ Lancer le partage d'écran", style: .default, handler: { [weak self] _ in
            self?.handleScreenShareFromCamera()
        }))
        
        sheet.addAction(UIAlertAction(title: "🔄 Basculer caméra avant/arrière", style: .default, handler: { [weak self] _ in
            self?.switchCameraTapped()
        }))
        
        sheet.addAction(UIAlertAction(title: "🖼️ Choisir une photo de la galerie", style: .default, handler: { [weak self] _ in
            self?.galleryButtonTapped()
        }))
        
        sheet.addAction(UIAlertAction(title: "🔦 Lampe torche", style: .default, handler: { [weak self] _ in
            self?.flashButtonTapped()
        }))
        
        sheet.addAction(UIAlertAction(title: "Annuler", style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    @objc private func flashButtonTapped() {
        HapticService.shared.buttonTap()
        isTorchOn.toggle()
        toggleTorch(enable: isTorchOn)
        flashButton.backgroundColor = isTorchOn ? UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.8) : UIColor(white: 0.2, alpha: 0.6)
    }
    
    @objc private func galleryButtonTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true, completion: nil)
    }
    
    // MARK: - Synthèse Vocale Universelle (iOS 12 à 18)
    private var cameraSpeechSynthesizer: AVSpeechSynthesizer?
    
    private func speakCameraMessage(_ text: String) {
        if cameraSpeechSynthesizer == nil {
            cameraSpeechSynthesizer = AVSpeechSynthesizer()
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        cameraSpeechSynthesizer?.speak(utterance)
    }
    
    @objc private func shutterButtonTapped() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        HapticService.shared.triggerSelectionFeedback()
        
        statusBanner.text = "🔍 Analyse de la scène..."
        statusBanner.textColor = .systemYellow
        shutterButton.alpha = 0.5
        
        LiveCameraManager.shared.captureSnapshot { [weak self] capturedImage in
            guard let self = self, let image = capturedImage else {
                self?.isAnalyzing = false
                self?.shutterButton.alpha = 1.0
                self?.statusBanner.text = "Visez un objet à analyser"
                self?.statusBanner.textColor = .white
                return
            }
            
            LocalVisionEngine.shared.recognizeObject(in: image) { [weak self] result in
                guard let self = self else { return }
                
                // Détection d'un QR Code de synchronisation Sarah
                if result.detectedText.contains("sarahsync://") || result.detectedText.contains("sarahpayload://") || result.detectedText.contains("sarah://sync") {
                    self.statusBanner.text = "⚡ Synchronisation Sarah en cours..."
                    self.statusBanner.textColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
                    self.speakCameraMessage("QR Code Sarah détecté ! Synchronisation des discussions en cours...")
                    
                    LocalSyncServerService.shared.performSync(with: result.detectedText) { [weak self] success, message in
                        guard let self = self else { return }
                        if success {
                            HapticService.shared.notificationSuccess()
                            self.speakCameraMessage("Synchronisation terminée avec succès !")
                            self.dismiss(animated: true) {
                                self.onPhotoAnalyzed?(image, result)
                            }
                        } else {
                            self.isAnalyzing = false
                            self.shutterButton.alpha = 1.0
                            self.statusBanner.text = "⚠️ Échec de connexion"
                            self.statusBanner.textColor = .systemRed
                        }
                    }
                } else {
                    self.dismiss(animated: true) {
                        self.onPhotoAnalyzed?(image, result)
                    }
                }
            }
        }
    }
    
    private func handleScreenShareFromCamera() {
        dismiss(animated: true) { [weak self] in
            self?.onScreenShareRequested?()
        }
    }
    
    private func toggleTorch(enable: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = enable ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [LiveCameraViewController] Torche non disponible: \(error)")
        }
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate

extension LiveCameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self, let selectedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
            
            self.statusBanner.text = "● Analyse photo galerie..."
            self.statusBanner.textColor = .yellow
            
            LocalVisionEngine.shared.recognizeObject(in: selectedImage) { [weak self] result in
                guard let self = self else { return }
                self.dismiss(animated: true) {
                    self.onPhotoAnalyzed?(selectedImage, result)
                }
            }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
