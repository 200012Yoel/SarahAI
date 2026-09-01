import Foundation
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

// ============================================================================
// SARAH DESIGN SYSTEM — TOKENS & COMPOSANTS UNIVERSELS (iOS 12.0+ à iOS 18.0+)
// ============================================================================
// Garantit une parité visuelle et fonctionnelle STRICTE à 100% sur tous les appareils,
// de l'iPhone 5s (4") à l'iPhone 17+ (6.9").
// ============================================================================

public struct SarahDesignSystem {
    
    // MARK: - 1. Palette Couleurs Dark Neon
    public struct Colors {
        public static let background = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)        // #0A0A0F
        public static let surface = UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1.0)           // #171721
        public static let surfaceElevated = UIColor(red: 0.13, green: 0.13, blue: 0.18, alpha: 1.0)   // #21212E
        public static let border = UIColor(red: 0.18, green: 0.18, blue: 0.24, alpha: 1.0)            // #2E2E3D
        
        // Accents Néon
        public static let accent = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)             // #26B8FF
        public static let neonCyan = UIColor(red: 0.00, green: 0.85, blue: 1.0, alpha: 1.0)           // #00D9FF
        public static let neonPink = UIColor(red: 1.00, green: 0.20, blue: 0.55, alpha: 1.0)           // #FF338C
        public static let neonGreen = UIColor(red: 0.10, green: 0.90, blue: 0.45, alpha: 1.0)          // #1AE673
        public static let destructive = UIColor(red: 1.00, green: 0.30, blue: 0.30, alpha: 1.0)        // #FF4D4D
        
        // Agents
        public static let agentSarah = UIColor(red: 0.15, green: 0.72, blue: 1.0, alpha: 1.0)
        public static let agentTom = UIColor(red: 0.20, green: 0.85, blue: 0.50, alpha: 1.0)
        public static let agentNathan = UIColor(red: 0.98, green: 0.65, blue: 0.15, alpha: 1.0)
        public static let agentYoann = UIColor(red: 0.70, green: 0.40, blue: 0.95, alpha: 1.0)
        
        // Textes
        public static let textPrimary = UIColor.white
        public static let textSecondary = UIColor(white: 0.70, alpha: 1.0)
        public static let textMuted = UIColor(white: 0.45, alpha: 1.0)
        
        #if canImport(SwiftUI)
        public struct SwiftColors {
            public static let background = Color(SarahDesignSystem.Colors.background)
            public static let surface = Color(SarahDesignSystem.Colors.surface)
            public static let surfaceElevated = Color(SarahDesignSystem.Colors.surfaceElevated)
            public static let border = Color(SarahDesignSystem.Colors.border)
            public static let accent = Color(SarahDesignSystem.Colors.accent)
            public static let destructive = Color(SarahDesignSystem.Colors.destructive)
        }
        #endif
    }
    
    // MARK: - 2. Métriques & Espacements
    public struct Metrics {
        public static let cornerRadiusSm: CGFloat = 8.0
        public static let cornerRadiusMd: CGFloat = 14.0
        public static let cornerRadiusLg: CGFloat = 20.0
        public static let cornerRadiusPill: CGFloat = 50.0
        
        public static let paddingSm: CGFloat = 6.0
        public static let paddingMd: CGFloat = 12.0
        public static let paddingLg: CGFloat = 16.0
        
        public static let topBarHeight: CGFloat = 52.0
        public static let composerHeight: CGFloat = 56.0
        public static let buttonTouchSize: CGFloat = 38.0
    }
    
    // MARK: - 3. Typographie Universelle
    public struct Typography {
        public static func headline(size: CGFloat = 16) -> UIFont {
            return UIFont.systemFont(ofSize: size, weight: .bold)
        }
        public static func body(size: CGFloat = 14) -> UIFont {
            return UIFont.systemFont(ofSize: size, weight: .regular)
        }
        public static func subheadline(size: CGFloat = 12) -> UIFont {
            return UIFont.systemFont(ofSize: size, weight: .medium)
        }
        public static func mono(size: CGFloat = 13) -> UIFont {
            if let font = UIFont(name: "Menlo-Regular", size: size) {
                return font
            }
            return UIFont.systemFont(ofSize: size, weight: .regular)
        }
    }
}

// MARK: - 4. Composants UIKit Universels (Zéro Dépendance de Version)

public final class SarahIconButton: UIButton {
    
    public enum IconType {
        case menu
        case settings
        case clearTrash
        case close
        case send
        case mic
        case waveform
        case plus
    }
    
    public init(type: IconType, tint: UIColor = .white, backgroundColor: UIColor = SarahDesignSystem.Colors.surfaceElevated, size: CGFloat = SarahDesignSystem.Metrics.buttonTouchSize) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = backgroundColor
        self.tintColor = tint
        self.setTitleColor(tint, for: .normal)
        self.layer.cornerRadius = size / 2.0
        self.clipsToBounds = true
        
        // Icônes universelles (SF Symbols sur iOS 13+ et symboles vectoriels/Unicode fidèles sur iOS 12)
        switch type {
        case .menu:
            if #available(iOS 13.0, *), let img = UIImage(systemName: "line.3.horizontal") {
                setImage(img, for: .normal)
            } else {
                setTitle("☰", for: .normal)
                titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            }
        case .settings:
            if #available(iOS 13.0, *), let img = UIImage(systemName: "gearshape.fill") {
                setImage(img, for: .normal)
            } else {
                setTitle("⚙️", for: .normal)
                titleLabel?.font = UIFont.systemFont(ofSize: 17)
            }
        case .clearTrash:
            if #available(iOS 13.0, *), let img = UIImage(systemName: "trash") {
                setImage(img, for: .normal)
            } else {
                setTitle("🗑️", for: .normal)
                titleLabel?.font = UIFont.systemFont(ofSize: 16)
            }
            self.tintColor = SarahDesignSystem.Colors.destructive
            self.setTitleColor(SarahDesignSystem.Colors.destructive, for: .normal)
        case .close:
            setTitle("✕", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        case .send:
            setTitle("⬆️", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            self.backgroundColor = SarahDesignSystem.Colors.accent
        case .mic:
            setTitle("🎤", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 17)
        case .waveform:
            setTitle("〰️", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 15)
        case .plus:
            setTitle("＋", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        }
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public final class SarahAgentCapsuleView: UIButton {
    
    public init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = SarahDesignSystem.Colors.surface
        layer.cornerRadius = 16
        layer.borderWidth = 1.0
        layer.borderColor = SarahDesignSystem.Colors.border.cgColor
        contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        setTitleColor(.white, for: .normal)
        titleLabel?.font = SarahDesignSystem.Typography.headline(size: 14)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(agentName: String, agentColor: UIColor = SarahDesignSystem.Colors.accent) {
        setTitle("● \(agentName) ▼", for: .normal)
        layer.borderColor = agentColor.withAlphaComponent(0.4).cgColor
    }
}
