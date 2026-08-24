import Foundation
import UIKit

/// Modal Plein Écran de Confirmation du Partage d'Écran (100% Conforme à la Capture d'Écran iOS) :
/// - Avertissement officiel d'enregistrement de l'écran et des notifications
/// - Carte centrale en verre dépoli avec icône d'enregistrement, nom de l'application Sarah IA et coche
/// - Bouton interactif « Démarrer le partage »
public final class ScreenShareModalViewController: UIViewController {
    
    public var onStartBroadcast: (() -> Void)?
    
    private let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let containerView = UIView()
    private let warningLabel = UILabel()
    private let cardView = UIView()
    
    private let broadcastIconView = UIImageView()
    private let titleLabel = UILabel()
    private let separator1 = UIView()
    
    private let appRow = UIView()
    private let appIconView = UIImageView()
    private let appNameLabel = UILabel()
    private let checkmarkIcon = UIImageView()
    
    private let separator2 = UIView()
    private let startButton = UIButton(type: .system)
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        // 1. Fond Flou
        blurBackgroundView.frame = view.bounds
        blurBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurBackgroundView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissModal))
        view.addGestureRecognizer(tapGesture)
        
        // 2. Conteneur
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // 3. Texte d'avertissement en haut
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.text = "Tout le contenu de l’écran, y compris les notifications, sera enregistré. Activez « Ne pas déranger » pour éviter d’en recevoir."
        warningLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        warningLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        warningLabel.textAlignment = .center
        warningLabel.numberOfLines = 0
        containerView.addSubview(warningLabel)
        
        // 4. Carte centrale dépolie
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor(white: 0.28, alpha: 0.85)
        cardView.layer.cornerRadius = 24
        cardView.layer.borderWidth = 0.5
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        cardView.clipsToBounds = true
        containerView.addSubview(cardView)
        
        // 4.1 Icône Broadcast
        broadcastIconView.translatesAutoresizingMaskIntoConstraints = false
        broadcastIconView.image = UIImage(systemName: "record.circle") ?? UIImage(systemName: "circle.inset.filled")
        broadcastIconView.tintColor = .white
        broadcastIconView.contentMode = .scaleAspectFit
        cardView.addSubview(broadcastIconView)
        
        // 4.2 Titre Partage d'écran
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Partage d’écran"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        cardView.addSubview(titleLabel)
        
        // 4.3 Séparateur 1
        separator1.translatesAutoresizingMaskIntoConstraints = false
        separator1.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        cardView.addSubview(separator1)
        
        // 4.4 Ligne Application Sarah IA
        appRow.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(appRow)
        
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        appIconView.image = UIImage(systemName: "sparkles") ?? UIImage(systemName: "star.fill")
        appIconView.tintColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        appIconView.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        appIconView.layer.cornerRadius = 8
        appIconView.clipsToBounds = true
        appIconView.contentMode = .center
        appRow.addSubview(appIconView)
        
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.text = "Sarah IA"
        appNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        appNameLabel.textColor = .white
        appRow.addSubview(appNameLabel)
        
        checkmarkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkmarkIcon.image = UIImage(systemName: "checkmark")
        checkmarkIcon.tintColor = .white
        checkmarkIcon.contentMode = .scaleAspectFit
        appRow.addSubview(checkmarkIcon)
        
        // 4.5 Séparateur 2
        separator2.translatesAutoresizingMaskIntoConstraints = false
        separator2.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        cardView.addSubview(separator2)
        
        // 4.6 Bouton « Démarrer le partage »
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("Démarrer le partage", for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        startButton.setTitleColor(UIColor.white, for: .normal)
        startButton.addTarget(self, action: #selector(startSharingTapped), for: .touchUpInside)
        cardView.addSubview(startButton)
        
        // MARK: - Layout Constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            warningLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            warningLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            warningLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            cardView.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 36),
            cardView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 290),
            cardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            broadcastIconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            broadcastIconView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            broadcastIconView.widthAnchor.constraint(equalToConstant: 32),
            broadcastIconView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: broadcastIconView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            separator1.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            separator1.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            separator1.heightAnchor.constraint(equalToConstant: 0.5),
            
            appRow.topAnchor.constraint(equalTo: separator1.bottomAnchor),
            appRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            appRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            appRow.heightAnchor.constraint(equalToConstant: 54),
            
            appIconView.leadingAnchor.constraint(equalTo: appRow.leadingAnchor),
            appIconView.centerYAnchor.constraint(equalTo: appRow.centerYAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 32),
            appIconView.heightAnchor.constraint(equalToConstant: 32),
            
            appNameLabel.leadingAnchor.constraint(equalTo: appIconView.trailingAnchor, constant: 12),
            appNameLabel.centerYAnchor.constraint(equalTo: appRow.centerYAnchor),
            
            checkmarkIcon.trailingAnchor.constraint(equalTo: appRow.trailingAnchor),
            checkmarkIcon.centerYAnchor.constraint(equalTo: appRow.centerYAnchor),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 18),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 18),
            
            separator2.topAnchor.constraint(equalTo: appRow.bottomAnchor),
            separator2.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            separator2.heightAnchor.constraint(equalToConstant: 0.5),
            
            startButton.topAnchor.constraint(equalTo: separator2.bottomAnchor),
            startButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            startButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            startButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
    }
    
    @objc private func startSharingTapped() {
        HapticService.shared.buttonTap()
        dismiss(animated: true) { [weak self] in
            self?.onStartBroadcast?()
        }
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true, completion: nil)
    }
}
