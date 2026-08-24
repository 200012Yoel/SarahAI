import Foundation
import UIKit
import AVFoundation

/// Carré Bleu Interactif Futuriste aux Vagues Animées en Temps Réel :
/// - Design carré aux coins arrondis, fond bleu nuit/cyan avec lueur néon pulsante
/// - Vagues sinusoïdales multi-barres dynamiques ("les vagues qui bougent") réactives au son et à la voix
/// - Animation fluide 60 FPS via CADisplayLink avec interpolation d'amplitude naturelle
/// - Tappable pour activer/désactiver instantanément la conversation vocale en direct avec Sarah
public final class SarahVoiceWaveSquareView: UIView {
    
    // MARK: - Propriétés de Configuration
    public var onTap: (() -> Void)?
    
    public private(set) var isActive: Bool = true {
        didSet {
            updateVisualState()
        }
    }
    
    public var audioLevel: Float = 0.0 {
        didSet {
            targetAmplitude = CGFloat(max(0.15, min(1.0, audioLevel)))
        }
    }
    
    // MARK: - Éléments Graphiques
    private let containerView = UIView()
    private let backgroundGradient = CAGradientLayer()
    private var waveBars: [UIView] = []
    
    // MARK: - Animation
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0.0
    private var currentAmplitude: CGFloat = 0.35
    private var targetAmplitude: CGFloat = 0.35
    
    private let numberOfBars = 5
    
    // MARK: - Initialisation
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    deinit {
        stopAnimating()
    }
    
    // MARK: - Configuration UI
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        
        // 1. Conteneur principal (Carré bleu arrondi)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1.5
        containerView.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.9).cgColor
        containerView.clipsToBounds = true
        addSubview(containerView)
        
        // 2. Ombre / Lueur Néon Cyan
        layer.shadowColor = UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 0.85).cgColor
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.75
        layer.shadowOffset = .zero
        
        // 3. Dégradé de fond Bleu Électrique / Bleu Nuit
        backgroundGradient.colors = [
            UIColor(red: 0.04, green: 0.20, blue: 0.55, alpha: 0.95).cgColor,
            UIColor(red: 0.02, green: 0.10, blue: 0.30, alpha: 0.95).cgColor
        ]
        backgroundGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        backgroundGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        containerView.layer.insertSublayer(backgroundGradient, at: 0)
        
        // 4. Barres de vagues centrales dynamiques
        setupWaveBars()
        
        // 5. Contraintes
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        startAnimating()
    }
    
    private func setupWaveBars() {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.spacing = 3.5
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 28),
            stackView.widthAnchor.constraint(equalToConstant: 32)
        ])
        
        waveBars.removeAll()
        let barColors = [
            UIColor(red: 0.20, green: 0.85, blue: 1.0, alpha: 0.95),
            UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0),
            UIColor(red: 0.35, green: 0.90, blue: 1.0, alpha: 1.0),
            UIColor(red: 0.0, green: 0.70, blue: 1.0, alpha: 1.0),
            UIColor(red: 0.20, green: 0.85, blue: 1.0, alpha: 0.95)
        ]
        
        for i in 0..<numberOfBars {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = barColors[i % barColors.count]
            bar.layer.cornerRadius = 2.0
            bar.clipsToBounds = true
            
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 3.5),
                bar.heightAnchor.constraint(equalToConstant: 12)
            ])
            
            stackView.addArrangedSubview(bar)
            waveBars.append(bar)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundGradient.frame = containerView.bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }
    
    // MARK: - Animation en Temps Réel (CADisplayLink)
    
    public func startAnimating() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(renderAnimationFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    public func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func renderAnimationFrame() {
        guard isActive else { return }
        
        phase += 0.08
        // Lissage progressif de l'amplitude
        currentAmplitude += (targetAmplitude - currentAmplitude) * 0.15
        
        // Mettre à jour la hauteur de chaque barre en fonction d'une onde sinusoïdale fluide
        let baseHeight: CGFloat = 8.0
        let maxHeight: CGFloat = 26.0
        
        for (index, bar) in waveBars.enumerated() {
            let offset = CGFloat(index) * 0.65
            let sinValue = (sin(phase + offset) + 1.0) / 2.0 // 0.0 -> 1.0
            let calculatedHeight = baseHeight + (maxHeight - baseHeight) * sinValue * currentAmplitude
            
            if let heightConstraint = bar.constraints.first(where: { $0.firstAttribute == .height }) {
                heightConstraint.constant = calculatedHeight
            }
        }
        
        // Légère pulsation de lueur
        let glowPulse = 0.65 + 0.35 * sin(phase * 0.7)
        layer.shadowOpacity = Float(glowPulse)
    }
    
    // MARK: - Interactions
    
    @objc private func handleTap() {
        HapticService.shared.buttonTap()
        
        // Animation de rebond
        UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseInOut, animations: {
            self.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
        }) { _ in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.transform = .identity
            }, completion: nil)
        }
        
        onTap?()
    }
    
    public func setActive(_ active: Bool, animated: Bool = true) {
        self.isActive = active
        let duration = animated ? 0.25 : 0.0
        UIView.animate(withDuration: duration) {
            self.updateVisualState()
        }
    }
    
    private func updateVisualState() {
        if isActive {
            containerView.layer.borderColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 0.9).cgColor
            backgroundGradient.colors = [
                UIColor(red: 0.04, green: 0.20, blue: 0.55, alpha: 0.95).cgColor,
                UIColor(red: 0.02, green: 0.10, blue: 0.30, alpha: 0.95).cgColor
            ]
            layer.shadowOpacity = 0.75
            targetAmplitude = 0.40
        } else {
            containerView.layer.borderColor = UIColor(white: 0.4, alpha: 0.5).cgColor
            backgroundGradient.colors = [
                UIColor(white: 0.15, alpha: 0.90).cgColor,
                UIColor(white: 0.08, alpha: 0.90).cgColor
            ]
            layer.shadowOpacity = 0.15
            targetAmplitude = 0.10
        }
    }
}
