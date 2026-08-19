import Foundation

/// Générateur de Raccourcis Apple & Automatisations (100% Hors-Ligne) :
/// - Crée et exporte des définitions de raccourcis compatibles iOS
public final class ShortcutGenerator {
    
    public static let shared = ShortcutGenerator()
    
    public struct ShortcutSchema: Codable {
        public let id: String
        public let title: String
        public let action: String
        public let parameters: [String: String]
        public let createdAt: Date
    }
    
    private var shortcutsDirectory: URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = (urls.first ?? fm.temporaryDirectory).appendingPathComponent("Shortcuts", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {}
    
    public func createShortcut(title: String, action: String, parameters: [String: String]) -> ShortcutSchema {
        let id = "shortcut_\(Int(Date().timeIntervalSince1970))"
        let schema = ShortcutSchema(id: id, title: title, action: action, parameters: parameters, createdAt: Date())
        
        let file = shortcutsDirectory.appendingPathComponent("\(id).json")
        if let data = try? JSONEncoder().encode(schema) {
            try? data.write(to: file)
        }
        return schema
    }
}
