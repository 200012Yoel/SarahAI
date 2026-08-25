import Foundation
import UIKit
import AVFoundation

/// Contrôleur d'Interface Caméra & Vision IA Redesigné pour Sarah IA :
/// - Agent Spécialiste Vision : 💙 TOM
/// - Disposition épurée, immersive et futuriste adaptée de l'iPhone 5S aux iPhone 16 Pro
/// - Barre supérieure avec statut Tom, indicateur de confidentialité, bascule caméra et flash
/// - Viseur vidéo fluide plein écran sans bordures noires
/// - Carte de résultat IA flottante moderne avec lecture vocale (Tom)
/// - Contrôles inférieurs simples et élégants : Shutter central lumineux, Flash, Flip et Partage d'Écran
public final class LiveCameraViewController: UIViewController {
    
    // MARK: - Callbacks
    public var onPhotoAnalyzed: ((UIImage, LocalVisionEngine.VisionAnalysisResult) -> Void)?
    public var onScreenShareRequested: (() -> Void)?
    
    // MARK: - Vues Principales
    private let previewContainer = UIView()
    private let focusIndicator = UIView()
    
    // MARK: - Barre Supérieure Tom Vision
    private let topBarView = UIView()
    private let topBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let backButton = UIButton(type: .system)
    private let tomTitleLabel = UILabel()
    private let tomStatusDot = UIView()
    private let tomStatusLabel = UILabel()
    private let flashButton = UIButton(type: .system)
    private let flipCameraButton = UIButton(type: .system)
    
    // MARK: - Indicateur Central Discret
    private let tomWatchingPill = UIView()
    private let tomWatchingIcon = UILabel()
    private let tomWatchingLabel = UILabel()
    
    // MARK: - Carte Flottante de Réponse IA Tom
    private let responseCard = UIView()
    private let responseBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let responseHeaderLabel = UILabel()
    private let responseCloseButton = UIButton(type: .system)
    private let responseTextView = UITextView()
    private let responseListenButton = UIButton(type: .system)
    private var lastAnalyzedResult: LocalVisionEngine.VisionAnalysisResult?
    
    // MARK: - Barre de Contrôles Inférieure (Bottom Dock)
    private let bottomControlsContainer = UIView()
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let captureButton = UIButton(type: .custom)
    private let captureRingView = UIView()
    private let screenShareButton = UIButton(type: .system)
    private let voiceWaveSquare = SarahVoiceWaveSquareView(frame: .zero)
    
    // MARK: - États
    private var isAnalyzing: Bool = false
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    
    // MARK: - Cycle de Vie
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupGestures()
        
        LiveCameraManager.shared.attachPreview(to: previewContainer)
        LiveCameraManager.shared.requestCameraAccess { [weak self] granted in
            if granted {
                DispatchQueue.main.async {
                    LiveCameraManager.shared.startSession()
                }
            } else {
                DispatchQueue.main.async {
                    self?.showPermissionAlert()
                }
            }
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        LiveCameraManager.shared.startSession()
        voiceWaveSquare.startAnimating()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bringControlsToFront()
        
        // Accueil vocal de Tom
        TTSManager.shared.handOffToTom(
            sarahTransitionPhrase: "Tom observe ce que tu me montres.",
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
        view.bringSubviewToFront(topBarView)
        view.bringSubviewToFront(tomWatchingPill)
        view.bringSubviewToFront(responseCard)
        view.bringSubviewToFront(bottomControlsContainer)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        LiveCameraManager.shared.stopSession()
        voiceWaveSquare.stopAnimating()
    }
    
    deinit {
        LiveCameraManager.shared.stopSession()
    }
    
    // MARK: - Construction de l'Interface Utilisateur (UI Redesign)
    
    private func setupUI() {
        let isSmallScreen = UIScreen.main.bounds.width <= 360 // iPhone 5S, SE
        
        // 1. Conteneur Aperçu Caméra Plein Écran
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .black
        view.addSubview(previewContainer)
        
        // Réticule de mise au point
        focusIndicator.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        focusIndicator.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.9).cgColor
        focusIndicator.layer.borderWidth = 1.5
        focusIndicator.layer.cornerRadius = 30
        focusIndicator.alpha = 0.0
        focusIndicator.isUserInteractionEnabled = false
        previewContainer.addSubview(focusIndicator)
        
        // 2. Barre Supérieure Tom Vision
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        topBarView.layer.cornerRadius = 20
        topBarView.layer.borderWidth = 0.5
        topBarView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        topBarView.clipsToBounds = true
        view.addSubview(topBarView)
        
        topBlurView.translatesAutoresizingMaskIntoConstraints = false
        topBarView.addSubview(topBlurView)
        
        // Bouton Retour ✕ / ←
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setTitle("✕", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        backButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        topBarView.addSubview(backButton)
        
        // Titre TOM • VISION
        tomTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        tomTitleLabel.text = "💙 TOM • VISION"
        tomTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        tomTitleLabel.textColor = .white
        topBarView.addSubview(tomTitleLabel)
        
        // Indicateur d'état (Point vert / bleu)
        tomStatusDot.translatesAutoresizingMaskIntoConstraints = false
        tomStatusDot.backgroundColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 1.0)
        tomStatusDot.layer.cornerRadius = 3.5
        topBarView.addSubview(tomStatusDot)
        
        tomStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        tomStatusLabel.text = "Prêt"
        tomStatusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        tomStatusLabel.textColor = UIColor(white: 0.85, alpha: 1.0)
        topBarView.addSubview(tomStatusLabel)
        
        // Bouton Flash ⚡
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setTitle("⚡ Auto", for: .normal)
        flashButton.setTitleColor(UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), for: .normal)
        flashButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        flashButton.addTarget(self, action: #selector(toggleFlashTapped), for: .touchUpInside)
        topBarView.addSubview(flashButton)
        
        // Bouton Flip Caméra 🔄
        flipCameraButton.translatesAutoresizingMaskIntoConstraints = false
        flipCameraButton.setTitle("🔄", for: .normal)
        flipCameraButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        flipCameraButton.addTarget(self, action: #selector(flipCameraTapped), for: .touchUpInside)
        topBarView.addSubview(flipCameraButton)
        
        // 3. Pastille Centrale Discrète « Tom observe la caméra »
        tomWatchingPill.translatesAutoresizingMaskIntoConstraints = false
        tomWatchingPill.backgroundColor = UIColor(white: 0.12, alpha: 0.75)
        tomWatchingPill.layer.cornerRadius = 14
        tomWatchingPill.layer.borderWidth = 0.5
        tomWatchingPill.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.4).cgColor
        tomWatchingPill.clipsToBounds = true
        view.addSubview(tomWatchingPill)
        
        tomWatchingIcon.translatesAutoresizingMaskIntoConstraints = false
        tomWatchingIcon.text = "👁"
        tomWatchingIcon.font = UIFont.systemFont(ofSize: 13)
        tomWatchingPill.addSubview(tomWatchingIcon)
        
        tomWatchingLabel.translatesAutoresizingMaskIntoConstraints = false
        tomWatchingLabel.text = "Tom observe la caméra"
        tomWatchingLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        tomWatchingLabel.textColor = .white
        tomWatchingPill.addSubview(tomWatchingLabel)
        
        // 4. Carte Flottante de Réponse IA Tom (Affichée après capture)
        responseCard.translatesAutoresizingMaskIntoConstraints = false
        responseCard.layer.cornerRadius = 18
        responseCard.layer.borderWidth = 1.2
        responseCard.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.75).cgColor
        responseCard.clipsToBounds = true
        responseCard.alpha = 0.0
        view.addSubview(responseCard)
        
        responseBlurView.translatesAutoresizingMaskIntoConstraints = false
        responseCard.addSubview(responseBlurView)
        
        responseHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        responseHeaderLabel.text = "💙 TOM (Vision IA)"
        responseHeaderLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        responseHeaderLabel.textColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 1.0)
        responseCard.addSubview(responseHeaderLabel)
        
        responseCloseButton.translatesAutoresizingMaskIntoConstraints = false
        responseCloseButton.setTitle("✕", for: .normal)
        responseCloseButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        responseCloseButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        responseCloseButton.addTarget(self, action: #selector(dismissResponseCard), for: .touchUpInside)
        responseCard.addSubview(responseCloseButton)
        
        responseTextView.translatesAutoresizingMaskIntoConstraints = false
        responseTextView.backgroundColor = .clear
        responseTextView.textColor = .white
        responseTextView.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        responseTextView.isEditable = false
        responseTextView.isSelectable = false
        responseCard.addSubview(responseTextView)
        
        responseListenButton.translatesAutoresizingMaskIntoConstraints = false
        responseListenButton.setTitle("🔊 Écouter l'analyse", for: .normal)
        responseListenButton.setTitleColor(.white, for: .normal)
        responseListenButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        responseListenButton.backgroundColor = UIColor(red: 0.0, green: 0.60, blue: 0.95, alpha: 0.85)
        responseListenButton.layer.cornerRadius = 12
        responseListenButton.clipsToBounds = true
        responseListenButton.addTarget(self, action: #selector(listenResponseTapped), for: .touchUpInside)
        responseCard.addSubview(responseListenButton)
        
        // 5. Barre de Contrôles Inférieure
        bottomControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsContainer.backgroundColor = UIColor(white: 0.10, alpha: 0.82)
        bottomControlsContainer.layer.cornerRadius = 32
        bottomControlsContainer.layer.borderWidth = 0.8
        bottomControlsContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        bottomControlsContainer.clipsToBounds = true
        view.addSubview(bottomControlsContainer)
        
        bottomBlurView.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsContainer.addSubview(bottomBlurView)
        
        // Anneau lumineux extérieur du Shutter
        captureRingView.translatesAutoresizingMaskIntoConstraints = false
        captureRingView.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.85).cgColor
        captureRingView.layer.borderWidth = 3.0
        captureRingView.layer.cornerRadius = 32
        captureRingView.clipsToBounds = true
        bottomControlsContainer.addSubview(captureRingView)
        
        // Bouton Shutter Central
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 25
        captureButton.clipsToBounds = true
        captureButton.addTarget(self, action: #selector(captureAndAnalyzeTapped), for: .touchUpInside)
        bottomControlsContainer.addSubview(captureButton)
        
        // Bouton Carré Vocal Tom (Gauche)
        voiceWaveSquare.translatesAutoresizingMaskIntoConstraints = false
        voiceWaveSquare.onTap = { [weak self] in
            self?.toggleVoiceInteraction()
        }
        bottomControlsContainer.addSubview(voiceWaveSquare)
        
        // Bouton Partage d'Écran (Droite)
        screenShareButton.translatesAutoresizingMaskIntoConstraints = false
        screenShareButton.setTitle("📲", for: .normal)
        screenShareButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        screenShareButton.backgroundColor = UIColor(white: 0.22, alpha: 0.7)
        screenShareButton.layer.cornerRadius = 20
        screenShareButton.clipsToBounds = true
        screenShareButton.addTarget(self, action: #selector(screenShareButtonTapped), for: .touchUpInside)
        bottomControlsContainer.addSubview(screenShareButton)
        
        // MARK: - Contraintes de Mise en Page (AutoLayout)
        let topSafeArea = view.safeAreaLayoutGuide.topAnchor
        let bottomSafeArea = view.safeAreaLayoutGuide.bottomAnchor
        let barHorizontalPadding: CGFloat = isSmallScreen ? 12 : 20
        
        NSLayoutConstraint.activate([
            // Preview
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // TopBar
            topBarView.topAnchor.constraint(equalTo: topSafeArea, constant: 8),
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: barHorizontalPadding),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -barHorizontalPadding),
            topBarView.heightAnchor.constraint(equalToConstant: 44),
            
            topBlurView.topAnchor.constraint(equalTo: topBarView.topAnchor),
            topBlurView.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor),
            topBlurView.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor),
            topBlurView.bottomAnchor.constraint(equalTo: topBarView.bottomAnchor),
            
            backButton.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: 10),
            backButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            
            tomTitleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            tomTitleLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor, constant: -6),
            
            tomStatusDot.leadingAnchor.constraint(equalTo: tomTitleLabel.leadingAnchor),
            tomStatusDot.topAnchor.constraint(equalTo: tomTitleLabel.bottomAnchor, constant: 3),
            tomStatusDot.widthAnchor.constraint(equalToConstant: 7),
            tomStatusDot.heightAnchor.constraint(equalToConstant: 7),
            
            tomStatusLabel.leadingAnchor.constraint(equalTo: tomStatusDot.trailingAnchor, constant: 4),
            tomStatusLabel.centerYAnchor.constraint(equalTo: tomStatusDot.centerYAnchor),
            
            flipCameraButton.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor, constant: -8),
            flipCameraButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            flipCameraButton.widthAnchor.constraint(equalToConstant: 32),
            
            flashButton.trailingAnchor.constraint(equalTo: flipCameraButton.leadingAnchor, constant: -6),
            flashButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            
            // Pastille Centrale « Tom observe »
            tomWatchingPill.topAnchor.constraint(equalTo: topBarView.bottomAnchor, constant: 12),
            tomWatchingPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tomWatchingPill.heightAnchor.constraint(equalToConstant: 28),
            
            tomWatchingIcon.leadingAnchor.constraint(equalTo: tomWatchingPill.leadingAnchor, constant: 10),
            tomWatchingIcon.centerYAnchor.constraint(equalTo: tomWatchingPill.centerYAnchor),
            
            tomWatchingLabel.leadingAnchor.constraint(equalTo: tomWatchingIcon.trailingAnchor, constant: 6),
            tomWatchingLabel.trailingAnchor.constraint(equalTo: tomWatchingPill.trailingAnchor, constant: -10),
            tomWatchingLabel.centerYAnchor.constraint(equalTo: tomWatchingPill.centerYAnchor),
            
            // Carte de Réponse IA Tom
            responseCard.topAnchor.constraint(equalTo: tomWatchingPill.bottomAnchor, constant: 12),
            responseCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            responseCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            responseCard.heightAnchor.constraint(lessThanOrEqualToConstant: 160),
            
            responseBlurView.topAnchor.constraint(equalTo: responseCard.topAnchor),
            responseBlurView.leadingAnchor.constraint(equalTo: responseCard.leadingAnchor),
            responseBlurView.trailingAnchor.constraint(equalTo: responseCard.trailingAnchor),
            responseBlurView.bottomAnchor.constraint(equalTo: responseCard.bottomAnchor),
            
            responseHeaderLabel.topAnchor.constraint(equalTo: responseCard.topAnchor, constant: 10),
            responseHeaderLabel.leadingAnchor.constraint(equalTo: responseCard.leadingAnchor, constant: 14),
            
            responseCloseButton.trailingAnchor.constraint(equalTo: responseCard.trailingAnchor, constant: -10),
            responseCloseButton.centerYAnchor.constraint(equalTo: responseHeaderLabel.centerYAnchor),
            responseCloseButton.widthAnchor.constraint(equalToConstant: 24),
            
            responseTextView.topAnchor.constraint(equalTo: responseHeaderLabel.bottomAnchor, constant: 4),
            responseTextView.leadingAnchor.constraint(equalTo: responseCard.leadingAnchor, constant: 10),
            responseTextView.trailingAnchor.constraint(equalTo: responseCard.trailingAnchor, constant: -10),
            responseTextView.heightAnchor.constraint(equalToConstant: 60),
            
            responseListenButton.topAnchor.constraint(equalTo: responseTextView.bottomAnchor, constant: 4),
            responseListenButton.leadingAnchor.constraint(equalTo: responseCard.leadingAnchor, constant: 14),
            responseListenButton.trailingAnchor.constraint(equalTo: responseCard.trailingAnchor, constant: -14),
            responseListenButton.bottomAnchor.constraint(equalTo: responseCard.bottomAnchor, constant: -10),
            responseListenButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Barre Inférieure
            bottomControlsContainer.bottomAnchor.constraint(equalTo: bottomSafeArea, constant: -12),
            bottomControlsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomControlsContainer.widthAnchor.constraint(equalToConstant: isSmallScreen ? 260 : 290),
            bottomControlsContainer.heightAnchor.constraint(equalToConstant: 72),
            
            bottomBlurView.topAnchor.constraint(equalTo: bottomControlsContainer.topAnchor),
            bottomBlurView.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: bottomControlsContainer.bottomAnchor),
            
            captureRingView.centerXAnchor.constraint(equalTo: bottomControlsContainer.centerXAnchor),
            captureRingView.centerYAnchor.constraint(equalTo: bottomControlsContainer.centerYAnchor),
            captureRingView.widthAnchor.constraint(equalToConstant: 64),
            captureRingView.heightAnchor.constraint(equalToConstant: 64),
            
            captureButton.centerXAnchor.constraint(equalTo: captureRingView.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: captureRingView.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 50),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            
            voiceWaveSquare.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor, constant: 16),
            voiceWaveSquare.centerYAnchor.constraint(equalTo: bottomControlsContainer.centerYAnchor),
            voiceWaveSquare.widthAnchor.constraint(equalToConstant: 40),
            voiceWaveSquare.heightAnchor.constraint(equalToConstant: 40),
            
            screenShareButton.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            screenShareButton.centerYAnchor.constraint(equalTo: bottomControlsContainer.centerYAnchor),
            screenShareButton.widthAnchor.constraint(equalToConstant: 40),
            screenShareButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Gestes & Actions
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        previewContainer.addGestureRecognizer(tap)
    }
    
    @objc private func handlePreviewTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: previewContainer)
        focusIndicator.center = location
        focusIndicator.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        focusIndicator.alpha = 1.0
        
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
            self.focusIndicator.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0.5, options: .curveEaseIn, animations: {
                self.focusIndicator.alpha = 0.0
            })
        }
        
        LiveCameraManager.shared.focus(at: location, in: previewContainer.bounds)
    }
    
    // MARK: - Capture & Analyse IA Tom
    
    @objc private func captureAndAnalyzeTapped() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        HapticService.shared.buttonTap()
        
        // Animation du bouton Shutter
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }
        
        tomStatusLabel.text = "Analyse..."
        tomWatchingLabel.text = "Tom analyse l'image..."
        
        LiveCameraManager.shared.capturePhoto { [weak self] image in
            guard let self = self else { return }
            guard let image = image else {
                self.isAnalyzing = false
                self.tomStatusLabel.text = "Prêt"
                self.tomWatchingLabel.text = "Tom observe la caméra"
                return
            }
            
            LocalVisionEngine.shared.recognizeObject(in: image) { [weak self] result in
                guard let self = self else { return }
                self.isAnalyzing = false
                self.lastAnalyzedResult = result
                self.tomStatusLabel.text = "Analysé"
                self.tomWatchingLabel.text = "Tom a analysé l'image"
                
                DispatchQueue.main.async {
                    self.showResponseCard(result: result, image: image)
                    self.onPhotoAnalyzed?(image, result)
                    
                    // Réponse vocale immédiate de Tom
                    TTSManager.shared.speakAsTom(result.naturalSpokenResponse)
                }
            }
        }
    }
    
    private func showResponseCard(result: LocalVisionEngine.VisionAnalysisResult, image: UIImage) {
        responseTextView.text = result.naturalSpokenResponse
        UIView.animate(withDuration: 0.3) {
            self.responseCard.alpha = 1.0
        }
    }
    
    @objc private func dismissResponseCard() {
        UIView.animate(withDuration: 0.25) {
            self.responseCard.alpha = 0.0
        }
    }
    
    @objc private func listenResponseTapped() {
        if let result = lastAnalyzedResult {
            TTSManager.shared.speakAsTom(result.naturalSpokenResponse)
        }
    }
    
    // MARK: - Bascule Partage d'Écran vers Tom
    
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
    
    // MARK: - Flash & Flip
    
    @objc private func toggleFlashTapped() {
        HapticService.shared.buttonTap()
        switch flashMode {
        case .auto:
            flashMode = .on
            flashButton.setTitle("⚡ On", for: .normal)
        case .on:
            flashMode = .off
            flashButton.setTitle("⚡ Off", for: .normal)
            flashButton.setTitleColor(UIColor(white: 0.6, alpha: 1.0), for: .normal)
        case .off:
            flashMode = .auto
            flashButton.setTitle("⚡ Auto", for: .normal)
            flashButton.setTitleColor(UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), for: .normal)
        @unknown default:
            flashMode = .auto
        }
        LiveCameraManager.shared.setFlashMode(flashMode)
    }
    
    @objc private func flipCameraTapped() {
        HapticService.shared.buttonTap()
        LiveCameraManager.shared.switchCamera()
    }
    
    @objc private func toggleVoiceInteraction() {
        HapticService.shared.buttonTap()
        if voiceWaveSquare.isAnimating {
            voiceWaveSquare.stopAnimating()
        } else {
            voiceWaveSquare.startAnimating()
        }
    }
    
    @objc private func closeButtonTapped() {
        HapticService.shared.buttonTap()
        LiveCameraManager.shared.stopSession()
        dismiss(animated: true, completion: nil)
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Accès Caméra Requis",
            message: "Pour que Tom puisse voir et analyser votre environnement, autorisez l'accès à la caméra dans les Réglages.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Ouvrir les Réglages", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        })
        present(alert, animated: true, completion: nil)
    }
}
