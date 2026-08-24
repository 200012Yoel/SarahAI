import UIKit
import AVFoundation

/// Contrôleur de Réglages Natif iOS 12+ pour Sarah AI
/// - Remplace définitivement les alertes texte par une vraie interface de réglages moderne
/// - Réglage de la voix, vitesse, tonalité, widgets, mémoire et synchronisation QR
public final class LegacySettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    public var onNewChatRequested: (() -> Void)?
    public var onWidgetsRequested: (() -> Void)?
    public var onSyncQRRequested: (() -> Void)?
    public var onMemoryVaultRequested: (() -> Void)?
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var speechRate: Float = 0.50
    private var speechPitch: Float = 1.02
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadVoiceSettings()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        title = "⚙️ Réglages"
        
        let closeBtn = UIBarButtonItem(
            title: "Fermer",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )
        closeBtn.tintColor = UIColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 1.0)
        navigationItem.rightBarButtonItem = closeBtn
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor(white: 1.0, alpha: 0.12)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadVoiceSettings() {
        let s = StorageService.shared.loadState().voiceSettings
        self.speechRate = s.speechRate
        self.speechPitch = s.speechPitch
    }
    
    @objc private func closeTapped() {
        HapticService.shared.buttonTap()
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // Voix Sarah, Voix Tom, Vitesse
        case 1: return 3 // Widgets, Synchronisation QR, Coffre de mémoire
        case 2: return 1 // Réinitialiser conversation
        default: return 0
        }
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "SYNTHÈSE VOCALE & ASSISTANTS"
        case 1: return "FONCTIONNALITÉS & OUTILS"
        case 2: return "HISTORIQUE & GESTION"
        default: return nil
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = UIColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1.0)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor(white: 0.7, alpha: 1.0)
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.textLabel?.text = "🔊 Voix de Sarah (Féminine)"
            cell.detailTextLabel?.text = "Tester"
            cell.accessoryType = .disclosureIndicator
        case (0, 1):
            cell.textLabel?.text = "👁️ Voix de Tom (Vision / Caméra)"
            cell.detailTextLabel?.text = "Tester"
            cell.accessoryType = .disclosureIndicator
        case (0, 2):
            cell.textLabel?.text = "⚡ Vitesse d'élocution"
            cell.detailTextLabel?.text = String(format: "%.1fx", speechRate * 2.0)
            cell.accessoryType = .none
        case (1, 0):
            cell.textLabel?.text = "📊 8 Widgets Sarah IA"
            cell.accessoryType = .disclosureIndicator
        case (1, 1):
            cell.textLabel?.text = "📱 Synchronisation QR (P2P Local)"
            cell.accessoryType = .disclosureIndicator
        case (1, 2):
            cell.textLabel?.text = "🧠 Coffre de Mémorisation"
            cell.accessoryType = .disclosureIndicator
        case (2, 0):
            cell.textLabel?.text = "🗑️ Réinitialiser la discussion"
            cell.textLabel?.textColor = .systemRed
            cell.accessoryType = .none
        default:
            break
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticService.shared.buttonTap()
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            TTSManager.shared.speakAsSarah("Bonjour ! Je suis Sarah, votre assistante vocale.")
        case (0, 1):
            TTSManager.shared.speakAsTom("Salut ! C'est Tom. Je suis prêt pour l'analyse visuelle et la caméra.")
        case (0, 2):
            speechRate = (speechRate >= 0.60) ? 0.40 : (speechRate + 0.10)
            StorageService.shared.updateVoiceSettings(rate: speechRate, pitch: speechPitch)
            tableView.reloadRows(at: [indexPath], with: .fade)
        case (1, 0):
            dismiss(animated: true) { [weak self] in
                self?.onWidgetsRequested?()
            }
        case (1, 1):
            dismiss(animated: true) { [weak self] in
                self?.onSyncQRRequested?()
            }
        case (1, 2):
            dismiss(animated: true) { [weak self] in
                self?.onMemoryVaultRequested?()
            }
        case (2, 0):
            dismiss(animated: true) { [weak self] in
                self?.onNewChatRequested?()
            }
        default:
            break
        }
    }
}
