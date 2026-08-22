import Foundation
import UIKit
import AVFoundation

/// Contrôleur d'Interface Caméra Plein Écran Dédié & Léger (iOS 12 -> iOS 18 / iPhone 5S -> iPhone 14) :
/// - Flux vidéo temps réel stabilisé en basse résolution (.vga640x480) pour garantir 60 FPS sans crash OOM
/// - Barre de contrôle inférieure avec bouton Microphone (Mute/Unmute), bouton Plus (+) et Déclencheur Shutter
/// - Action Partage d'Écran intégrée via le bouton (+)
/// - Libération mémoire immédiate à la fermeture
public final class LiveCameraViewController: UIViewController {
    
    // MARK: - Callbacks
    public var onPhotoAnalyzed: ((UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void)?
    public var onScreenShareRequested: (() -> Void)?
    
    // MARK: - Propriétés UI
    private let previewContainer = UIView()
    private let topBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleBadge = UILabel()
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
        setupCamera()
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
        
        // 2. Barre Supérieure
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.addSubview(topBar)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        closeButton.layer.cornerRadius = 20
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        titleBadge.translatesAutoresizingMaskIntoConstraints = false
        titleBadge.text = "👁️ Vision Sarah IA"
        titleBadge.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleBadge.textColor = .white
        titleBadge.textAlignment = .center
        titleBadge.backgroundColor = UIColor(red: 0.0, green: 0.52, blue: 1.0, alpha: 0.3)
        titleBadge.layer.cornerRadius = 14
        titleBadge.layer.borderWidth = 0.8
        titleBadge.layer.borderColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.5).cgColor
        titleBadge.clipsToBounds = true
        topBar.addSubview(titleBadge)
        
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setTitle("🔦", for: .normal)
        flashButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        flashButton.backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        flashButton.layer.cornerRadius = 20
        flashButton.clipsToBounds = true
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        topBar.addSubview(flashButton)
        
        // 3. Bannière de Statut Dynamique
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.text = "Visez un objet ou document à analyser"
        statusBanner.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusBanner.textColor = UIColor(white: 0.9, alpha: 1.0)
        statusBanner.textAlignment = .center
        statusBanner.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusBanner.layer.cornerRadius = 12
        statusBanner.clipsToBounds = true
        view.addSubview(statusBanner)
        
        // 4. Barre de Contrôle Inférieure
        bottomControlBar.translatesAutoresizingMaskIntoConstraints = false
        bottomControlBar.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.85)
        bottomControlBar.layer.cornerRadius = 28
        bottomControlBar.layer.borderWidth = 0.5
        bottomControlBar.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        bottomControlBar.clipsToBounds = true
        view.addSubview(bottomControlBar)
        
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .horizontal
        controlsStack.alignment = .center
        controlsStack.distribution = .equalCentering
        controlsStack.spacing = 14
        bottomControlBar.addSubview(controlsStack)
        
        // 4.1 Bouton Microphone Toggle (Mute / Unmute)
        micToggleButton.translatesAutoresizingMaskIntoConstraints = false
        micToggleButton.setTitle("🎙️", for: .normal)
        micToggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        micToggleButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        micToggleButton.layer.cornerRadius = 24
        micToggleButton.clipsToBounds = true
        micToggleButton.addTarget(self, action: #selector(micToggleTapped), for: .touchUpInside)
        micToggleButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        micToggleButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        controlsStack.addArrangedSubview(micToggleButton)
        
        // 4.2 Bouton Plus (+) pour Partage d'Écran & Options
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.setTitle("＋", for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        plusButton.layer.cornerRadius = 24
        plusButton.clipsToBounds = true
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        plusButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        plusButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        controlsStack.addArrangedSubview(plusButton)
        
        // 4.3 Bouton Shutter Déclencheur Principal (Grand Cercle Lumineux)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.8).cgColor
        shutterButton.clipsToBounds = true
        shutterButton.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)
        shutterButton.widthAnchor.constraint(equalToConstant: 70).isActive = true
        shutterButton.heightAnchor.constraint(equalToConstant: 70).isActive = true
        controlsStack.addArrangedSubview(shutterButton)
        
        // 4.4 Bouton Galerie
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.setTitle("🖼️", for: .normal)
        galleryButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        galleryButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        galleryButton.layer.cornerRadius = 24
        galleryButton.clipsToBounds = true
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        galleryButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        galleryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
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
            topBar.heightAnchor.constraint(equalToConstant: 54),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleBadge.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleBadge.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleBadge.heightAnchor.constraint(equalToConstant: 30),
            titleBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            
            flashButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -14),
            flashButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),
            
            statusBanner.bottomAnchor.constraint(equalTo: bottomControlBar.topAnchor, constant: -14),
            statusBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusBanner.heightAnchor.constraint(equalToConstant: 28),
            statusBanner.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            
            bottomControlBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomControlBar.heightAnchor.constraint(equalToConstant: 88),
            
            controlsStack.leadingAnchor.constraint(equalTo: bottomControlBar.leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: bottomControlBar.trailingAnchor, constant: -16),
            controlsStack.centerYAnchor.constraint(equalTo: bottomControlBar.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration Caméra Basse Résolution
    
    private func setupCamera() {
        LiveCameraManager.shared.setupSession(previewView: previewContainer) { [weak self] success in
            guard let self = self else { return }
            if !success {
                self.statusBanner.text = "⚠️ Caméra non disponible"
                self.statusBanner.textColor = .systemRed
            } else {
                LiveCameraManager.shared.startSession()
            }
        }
    }
    
    // MARK: - Actions Utilisateur
    
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
        let sheet = UIAlertController(title: "Options Visuelles & Partage", message: nil, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "🖥️ Partager l'écran avec Sarah", style: .default, handler: { [weak self] _ in
            self?.handleScreenShareFromCamera()
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
    
    @objc private func shutterButtonTapped() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        HapticService.shared.buttonTap()
        
        statusBanner.text = "● Analyse en cours..."
        statusBanner.textColor = .yellow
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
                self.dismiss(animated: true) {
                    self.onPhotoAnalyzed?(image, result)
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

// MARK: - UIImagePickerControllerDelegate

extension LiveCameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self,
                  let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
            
            self.statusBanner.text = "● Analyse de la photo..."
            LocalVisionEngine.shared.recognizeObject(in: image) { [weak self] result in
                guard let self = self else { return }
                self.dismiss(animated: true) {
                    self.onPhotoAnalyzed?(image, result)
                }
            }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
