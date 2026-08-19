import Foundation

/// Bac à Sable de Scripts & Mini-Apps HTML/JS pour iOS :
/// - Permet à Sarah d'enregistrer et de générer des scripts et mini-outils locaux
public final class LocalScriptSandbox {
    
    public static let shared = LocalScriptSandbox()
    
    private var sandboxDirectory: URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = (urls.first ?? fm.temporaryDirectory).appendingPathComponent("SandboxScripts", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {}
    
    public func saveScript(fileName: String, content: String) -> URL? {
        let file = sandboxDirectory.appendingPathComponent(fileName)
        try? content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
    
    public func generateMiniApp(title: String, bodyContent: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0c0d14; color: #fff; padding: 20px; }
                h1 { color: #8e7dff; font-size: 20px; }
                .card { background: rgba(255,255,255,0.06); border-radius: 12px; padding: 16px; margin-top: 12px; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <div class="card">\(bodyContent)</div>
        </body>
        </html>
        """
    }
}
