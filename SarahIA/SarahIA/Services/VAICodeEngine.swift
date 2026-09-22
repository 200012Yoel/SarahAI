import Foundation

/// Moteur de Code Autonome Raphaël (Agent Développeur & VAI Coding).
/// Capable de générer du code Web (HTML/CSS/JS monopage), Swift, Python,
/// d'analyser les spécifications de designs (Figma / Google Stitch) et d'exporter des raccourcis Apple (.shortcut / .json).
public final class VAICodeEngine {
    
    public static let shared = VAICodeEngine()
    
    public struct CodeProject: Identifiable, Codable {
        public let id: String
        public var title: String
        public var language: String // "html", "swift", "python", "shortcut"
        public var code: String
        public var createdAt: Date
        public var updatedAt: Date
    }
    
    private var workspaceDirectory: URL {
        let fm = FileManager.default
        let docURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let wsURL = docURL.appendingPathComponent("VAI_Workspace", isDirectory: true)
        if !fm.fileExists(atPath: wsURL.path) {
            try? fm.createDirectory(at: wsURL, withIntermediateDirectories: true, attributes: nil)
        }
        return wsURL
    }
    
    private init() {}
    
    /// Sauvegarde ou met à jour un fichier dans Documents/VAI_Workspace/
    public func saveFile(filename: String, content: String) -> URL? {
        let fileURL = workspaceDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ [VAICodeEngine] Erreur d'écriture de fichier: \(error)")
            return nil
        }
    }
    
    /// Générateur de composant Web monopage interactif (HTML5 / CSS moderne / Vanilla JS)
    public func generateWebUI(prompt: String) -> String {
        let lower = prompt.lowercased()
        
        let title: String
        let accentColor: String
        let cardContent: String
        
        if lower.contains("calculatrice") {
            title = "Calculatrice VAI Neumorphique"
            accentColor = "#00D2FF"
            cardContent = """
            <div class="calc-grid">
                <input type="text" id="display" readonly value="0" />
                <div class="btn-row"><button onclick="press('7')">7</button><button onclick="press('8')">8</button><button onclick="press('9')">9</button><button class="op" onclick="op('/')">÷</button></div>
                <div class="btn-row"><button onclick="press('4')">4</button><button onclick="press('5')">5</button><button onclick="press('6')">6</button><button class="op" onclick="op('*')">×</button></div>
                <div class="btn-row"><button onclick="press('1')">1</button><button onclick="press('2')">2</button><button onclick="press('3')">3</button><button class="op" onclick="op('-')">-</button></div>
                <div class="btn-row"><button class="clear" onclick="clr()">C</button><button onclick="press('0')">0</button><button class="eval" onclick="calc()">=</button><button class="op" onclick="op('+')">+</button></div>
            </div>
            """
        } else if lower.contains("meteo") || lower.contains("weather") {
            title = "Météo Card VAI Glassmorphism"
            accentColor = "#3A88E9"
            cardContent = """
            <div class="weather-box">
                <div class="city">Paris, FR</div>
                <div class="temp">22°C</div>
                <div class="desc">☀️ Ensoleillé & Agréable</div>
                <div class="stats">
                    <div class="stat-item"><span>Humidité</span><b>45%</b></div>
                    <div class="stat-item"><span>Vent</span><b>12 km/h</b></div>
                    <div class="stat-item"><span>Indice UV</span><b>Faible</b></div>
                </div>
            </div>
            """
        } else {
            title = "VAI Interactive Dashboard"
            accentColor = "#00F0FF"
            cardContent = """
            <div class="dashboard-box">
                <h2>⚡ Studio Raphaël Actif</h2>
                <p>Composant interactif généré en direct à partir de vos tokens de conception.</p>
                <div class="metrics">
                    <div class="metric-chip">🚀 60 FPS</div>
                    <div class="metric-chip">🔒 100% Hors-ligne</div>
                    <div class="metric-chip">⚡ 0 Latence</div>
                </div>
                <button class="action-btn" onclick="triggerEffect()">Interagir avec Raphaël</button>
                <div id="status-tag" style="margin-top: 15px; font-weight: bold; color: #00F0FF;"></div>
            </div>
            """
        }
        
        let html = """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>\(title)</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
                body { background: #0b0b0e; color: #ffffff; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
                .app-container { width: 100%; max-width: 380px; background: rgba(255, 255, 255, 0.05); backdrop-filter: blur(25px); border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 28px; padding: 24px; box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6); text-align: center; }
                h2 { font-size: 20px; font-weight: 700; margin-bottom: 12px; color: \(accentColor); }
                p { font-size: 14px; color: #8E8E93; margin-bottom: 20px; line-height: 1.4; }
                .metrics { display: flex; gap: 8px; justify-content: center; margin-bottom: 20px; }
                .metric-chip { background: rgba(255, 255, 255, 0.08); padding: 6px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
                .action-btn { width: 100%; background: linear-gradient(135deg, \(accentColor), #007AFF); color: white; border: none; border-radius: 16px; padding: 14px; font-size: 15px; font-weight: 600; cursor: pointer; transition: transform 0.15s; }
                .action-btn:active { transform: scale(0.96); }
                
                /* Styles Calculatrice */
                .calc-grid { display: flex; flex-direction: column; gap: 10px; }
                #display { width: 100%; background: rgba(0,0,0,0.5); border: 1px solid rgba(255,255,255,0.1); border-radius: 14px; color: white; font-size: 28px; text-align: right; padding: 12px; font-family: monospace; outline: none; margin-bottom: 10px; }
                .btn-row { display: flex; gap: 8px; }
                .btn-row button { flex: 1; height: 50px; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.06); border-radius: 14px; color: white; font-size: 18px; font-weight: 600; cursor: pointer; }
                .btn-row button.op { background: #007AFF; }
                .btn-row button.eval { background: \(accentColor); color: black; }
                .btn-row button.clear { background: #FF3B30; }
                
                /* Styles Météo */
                .weather-box .city { font-size: 18px; color: #8E8E93; margin-bottom: 6px; }
                .weather-box .temp { font-size: 48px; font-weight: 800; color: white; margin-bottom: 6px; }
                .weather-box .desc { font-size: 15px; color: \(accentColor); margin-bottom: 20px; }
                .stats { display: flex; justify-content: space-around; background: rgba(0,0,0,0.3); padding: 12px; border-radius: 16px; }
                .stat-item span { display: block; font-size: 11px; color: #8E8E93; margin-bottom: 4px; }
                .stat-item b { font-size: 14px; color: white; }
            </style>
        </head>
        <body>
            <div class="app-container">
                \(cardContent)
            </div>
            
            <script>
                function triggerEffect() {
                    const tag = document.getElementById('status-tag');
                    tag.innerText = "✨ Commande exécutée avec succès par Raphaël !";
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.vaiBridge) {
                        window.webkit.messageHandlers.vaiBridge.postMessage({ status: 'completed' });
                    }
                }
                
                let curVal = "";
                function press(num) {
                    curVal += num;
                    document.getElementById('display').value = curVal;
                }
                function op(operator) {
                    curVal += " " + operator + " ";
                    document.getElementById('display').value = curVal;
                }
                function clr() {
                    curVal = "";
                    document.getElementById('display').value = "0";
                }
                function calc() {
                    try {
                        let res = eval(curVal);
                        document.getElementById('display').value = res;
                        curVal = String(res);
                    } catch(e) {
                        document.getElementById('display').value = "Erreur";
                        curVal = "";
                    }
                }
            </script>
        </body>
        </html>
        """
        return html
    }

    /// Génère une base SwiftUI locale lorsque Raphaël reçoit une demande iOS.
    /// Ce n'est pas présenté comme une application compilée : c'est un point de départ
    /// clair, que la personne peut ensuite faire préciser et améliorer dans le chat.
    public func generateSwiftUIStarter(prompt: String) -> String {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")

        return """
        import SwiftUI

        /// Première base générée par Raphaël pour : \(escapedPrompt)
        struct RaphaelGeneratedView: View {
            @State private var input = ""
            @State private var items: [String] = []

            var body: some View {
                NavigationView {
                    List {
                        Section("Votre idée") {
                            TextField("Ajouter un élément", text: $input)
                            Button("Ajouter") {
                                let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !value.isEmpty else { return }
                                items.append(value)
                                input = ""
                            }
                        }

                        Section("Contenu") {
                            if items.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.title2)
                                        .foregroundColor(.accentColor)
                                    Text("Prêt à personnaliser")
                                        .font(.headline)
                                    Text("Décris à Raphaël les écrans, données et actions à ajouter.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ForEach(items, id: \\.self) { item in
                                    Text(item)
                                }
                                .onDelete { items.remove(atOffsets: $0) }
                            }
                        }
                    }
                    .navigationTitle("Prototype")
                }
            }
        }

        struct RaphaelGeneratedView_Previews: PreviewProvider {
            static var previews: some View {
                RaphaelGeneratedView()
            }
        }
        """
    }

    /// Petite base de script pour les demandes Python ; elle reste éditable et ne prétend
    /// pas avoir été exécutée sur l'iPhone.
    public func generatePythonStarter(prompt: String) -> String {
        let escapedPrompt = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        \"\"\"Base préparée par Raphaël pour : \(escapedPrompt)\"\"\"

        def main() -> None:
            # TODO: préciser les entrées, le traitement et le résultat attendu.
            print("Prototype prêt à être développé.")


        if __name__ == "__main__":
            main()
        """
    }

    /// Génère une première maquette de site à partir du questionnaire de Raphaël.
    /// Le résultat reste un fichier HTML local : aucune publication ou URL publique n'est simulée ici.
    public func generateWebsite(brief: WebsiteBrief) -> String {
        let siteName = htmlEscaped(brief.name.isEmpty ? "Mon nouveau site" : brief.name)
        let goal = htmlEscaped(brief.purpose.isEmpty ? "Une expérience claire, élégante et pensée pour vos visiteurs." : brief.purpose)
        let category = htmlEscaped(brief.category)
        let audience = htmlEscaped(brief.audience.isEmpty ? "vos visiteurs" : brief.audience)
        let style = htmlEscaped(brief.visualStyle.isEmpty ? "Moderne" : brief.visualStyle)
        let colors = websiteColors(for: brief.accent)
        let sections = brief.sections.isEmpty ? ["Accueil", "À propos", "Produits / services", "Contact"] : brief.sections

        let navigation = sections.map { "<a href=\"#\(htmlEscaped($0).replacingOccurrences(of: " ", with: "-"))\">\(htmlEscaped($0))</a>" }.joined(separator: "")
        let bodySections = sections.map { section in
            websiteSection(
                section,
                siteName: siteName,
                goal: goal,
                audience: audience,
                accent: colors.primary
            )
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="fr">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(siteName)</title>
          <style>
            :root { --accent: \(colors.primary); --accent-2: \(colors.secondary); --ink: #181a25; --muted: #687086; --surface: #ffffff; --soft: #f5f6fb; }
            * { box-sizing: border-box; }
            html { scroll-behavior: smooth; }
            body { margin: 0; background: var(--soft); color: var(--ink); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; line-height: 1.5; }
            .shell { max-width: 1120px; margin: auto; padding: 0 22px; }
            nav { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 22px 0; }
            .brand { font-weight: 800; font-size: 20px; letter-spacing: -.4px; }
            .brand span { color: var(--accent); }
            .links { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 15px; }
            .links a { color: var(--muted); text-decoration: none; font-size: 14px; font-weight: 650; }
            .hero { overflow: hidden; position: relative; padding: 68px 34px; border-radius: 30px; color: white; background: linear-gradient(130deg, var(--accent), var(--accent-2)); box-shadow: 0 22px 55px rgba(38, 25, 95, .20); }
            .hero:after { content: ""; position: absolute; width: 330px; height: 330px; right: -110px; top: -145px; border: 36px solid rgba(255,255,255,.17); border-radius: 50%; }
            .eyebrow { position: relative; z-index: 1; margin: 0 0 12px; font-size: 13px; letter-spacing: .09em; text-transform: uppercase; font-weight: 800; opacity: .82; }
            h1 { position: relative; z-index: 1; max-width: 700px; margin: 0; font-size: clamp(36px, 7vw, 64px); letter-spacing: -2px; line-height: 1.02; }
            .hero p { position: relative; z-index: 1; max-width: 570px; margin: 21px 0 0; font-size: 18px; opacity: .93; }
            .cta { position: relative; z-index: 1; display: inline-block; margin-top: 30px; padding: 14px 19px; border: 0; border-radius: 14px; color: var(--accent); background: #fff; font-size: 15px; font-weight: 800; cursor: pointer; }
            section { margin: 30px 0; padding: 31px; border: 1px solid #e8e9f0; border-radius: 25px; background: var(--surface); }
            h2 { margin: 0 0 10px; font-size: 25px; letter-spacing: -.5px; }
            .intro { max-width: 700px; color: var(--muted); }
            .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 13px; margin-top: 22px; }
            .card { padding: 19px; background: var(--soft); border-radius: 17px; }
            .card b { display: block; margin-bottom: 6px; }
            .card p { margin: 0; font-size: 14px; color: var(--muted); }
            .quote { padding: 18px; border-left: 4px solid var(--accent); background: var(--soft); border-radius: 0 15px 15px 0; color: var(--muted); }
            .contact { display: flex; align-items: center; justify-content: space-between; gap: 20px; background: #1d2030; color: #fff; }
            .contact h2 { color: #fff; }
            .contact p { margin: 0; color: #c6cad8; }
            .status { margin-top: 16px; color: #fff; font-weight: 650; }
            footer { padding: 12px 0 38px; text-align: center; color: #8890a6; font-size: 13px; }
            @media (max-width: 640px) { nav { align-items: flex-start; flex-direction: column; } .links { justify-content: flex-start; } .hero { padding: 48px 24px; } section { padding: 24px; } .cards { grid-template-columns: 1fr; } .contact { align-items: flex-start; flex-direction: column; } }
          </style>
        </head>
        <body>
          <main class="shell">
            <nav><div class="brand">\(siteName)<span>•</span></div><div class="links">\(navigation)</div></nav>
            <header class="hero">
              <p class="eyebrow">\(category) · \(style)</p>
              <h1>\(siteName)</h1>
              <p>\(goal)</p>
              <button class="cta" onclick="showContact()">Nous contacter</button>
              <div id="contact-status" class="status" aria-live="polite"></div>
            </header>
            \(bodySections)
            <footer>Première maquette locale créée avec Raphaël · À améliorer dans Sarah IA</footer>
          </main>
          <script>
            function showContact() {
              document.getElementById('contact-status').textContent = 'Merci ! La section contact est prête à être personnalisée.';
            }
          </script>
        </body>
        </html>
        """
    }

    /// Compétence de création de site premium inspirée des principes d'Apple :
    /// hiérarchie typographique nette, grands espaces, surfaces vitrées,
    /// animations discrètes et forte adaptation mobile. Aucun logo ni contenu
    /// propriétaire d'Apple n'est copié.
    public func generateAppleInspiredWebsite(prompt: String) -> String {
        let safePrompt = htmlEscaped(
            prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        return """
        <!doctype html>
        <html lang="fr">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <meta name="color-scheme" content="dark light">
          <title>Projet premium</title>
          <style>
            :root {
              --blue: #0a84ff;
              --ink: #f5f5f7;
              --muted: #a1a1a6;
              --panel: rgba(255,255,255,.075);
              --line: rgba(255,255,255,.14);
              --bg: #000;
            }
            * { box-sizing: border-box; }
            html { scroll-behavior: smooth; }
            body {
              margin: 0;
              background:
                radial-gradient(circle at 80% -10%, rgba(10,132,255,.22), transparent 34%),
                radial-gradient(circle at -10% 28%, rgba(94,92,230,.18), transparent 30%),
                var(--bg);
              color: var(--ink);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
              -webkit-font-smoothing: antialiased;
            }
            .wrap { width: min(1180px, calc(100% - 32px)); margin: auto; }
            nav {
              position: sticky; top: 12px; z-index: 20;
              display: flex; align-items: center; justify-content: space-between;
              margin-top: 12px; padding: 11px 15px;
              border: 1px solid var(--line);
              border-radius: 22px;
              background: rgba(20,20,22,.62);
              backdrop-filter: blur(28px) saturate(180%);
              -webkit-backdrop-filter: blur(28px) saturate(180%);
              box-shadow: inset 0 1px rgba(255,255,255,.15), 0 16px 50px rgba(0,0,0,.26);
            }
            .brand { font-weight: 700; letter-spacing: -.02em; }
            .links { display: flex; gap: 18px; }
            .links a { color: var(--muted); text-decoration: none; font-size: 13px; }
            .hero {
              min-height: 76vh; display: grid; place-items: center; text-align: center;
              padding: 88px 0 54px;
            }
            .hero-inner { max-width: 920px; }
            .kicker { color: var(--blue); font-weight: 700; margin-bottom: 12px; }
            h1 {
              margin: 0;
              font-size: clamp(48px, 9vw, 108px);
              line-height: .92;
              letter-spacing: -.065em;
              background: linear-gradient(180deg,#fff,#9b9ba1);
              -webkit-background-clip: text; color: transparent;
            }
            .lead {
              max-width: 720px; margin: 28px auto 0;
              color: var(--muted); font-size: clamp(18px,2.6vw,28px); line-height: 1.18;
            }
            .actions { display: flex; justify-content: center; gap: 10px; margin-top: 30px; flex-wrap: wrap; }
            .button {
              appearance: none; border: 0; cursor: pointer; text-decoration: none;
              padding: 12px 18px; border-radius: 999px; font-weight: 700; font-size: 14px;
            }
            .primary { background: var(--blue); color: white; }
            .secondary {
              color: white; border: 1px solid var(--line); background: var(--panel);
              backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
            }
            .showcase {
              position: relative; overflow: hidden; min-height: 470px;
              border-radius: 42px; border: 1px solid var(--line);
              background: linear-gradient(145deg, rgba(255,255,255,.12), rgba(255,255,255,.035));
              box-shadow: inset 0 1px rgba(255,255,255,.16), 0 35px 90px rgba(0,0,0,.42);
            }
            .glow {
              position:absolute; width:540px; height:540px; border-radius:50%;
              background:radial-gradient(circle,rgba(10,132,255,.55),transparent 64%);
              filter: blur(15px); right:-150px; top:-180px;
            }
            .product {
              position:absolute; inset:70px 8% 0; border-radius:34px 34px 0 0;
              border:1px solid rgba(255,255,255,.18);
              background:linear-gradient(160deg,#2a2a2f,#101014 48%,#070708);
              box-shadow:0 35px 90px rgba(0,0,0,.58), inset 0 1px rgba(255,255,255,.14);
              display:grid; place-items:center; text-align:center; padding:30px;
            }
            .product strong { font-size: clamp(30px,6vw,72px); letter-spacing:-.05em; }
            .grid {
              display:grid; grid-template-columns:repeat(3,minmax(0,1fr));
              gap:16px; padding:72px 0;
            }
            .card {
              min-height:270px; padding:26px; border-radius:30px;
              border:1px solid var(--line); background:var(--panel);
              backdrop-filter: blur(28px) saturate(150%);
              -webkit-backdrop-filter: blur(28px) saturate(150%);
              box-shadow: inset 0 1px rgba(255,255,255,.14);
              transform: translateY(18px); opacity: 0;
              transition: transform .65s cubic-bezier(.2,.8,.2,1), opacity .65s ease;
            }
            .card.visible { transform: translateY(0); opacity: 1; }
            .card h2 { margin:0 0 10px; font-size:28px; letter-spacing:-.035em; }
            .card p { color:var(--muted); margin:0; }
            .wide { grid-column:span 2; }
            .statement {
              padding:100px 0; text-align:center;
              font-size:clamp(34px,6vw,76px); line-height:1; letter-spacing:-.055em; font-weight:750;
            }
            .statement span { color:var(--muted); }
            footer { padding:34px 0 54px; color:#74747a; font-size:12px; border-top:1px solid rgba(255,255,255,.08); }
            @media(max-width:760px) {
              .links { display:none; }
              .hero { min-height:68vh; padding-top:70px; }
              .showcase { min-height:390px; border-radius:30px; }
              .product { inset:58px 6% 0; }
              .grid { grid-template-columns:1fr; padding:50px 0; }
              .wide { grid-column:auto; }
              .statement { padding:70px 0; }
            }
          </style>
        </head>
        <body>
          <div class="wrap">
            <nav>
              <div class="brand">Projet</div>
              <div class="links">
                <a href="#experience">Expérience</a>
                <a href="#details">Détails</a>
                <a href="#contact">Contact</a>
              </div>
            </nav>

            <section class="hero">
              <div class="hero-inner">
                <div class="kicker">Conçu pour être évident.</div>
                <h1>Plus simple.<br>Plus vivant.</h1>
                <p class="lead">(safePrompt.isEmpty ? "Une expérience premium, rapide et pensée pour chaque écran." : safePrompt)</p>
                <div class="actions">
                  <a class="button primary" href="#experience">Découvrir</a>
                  <a class="button secondary" href="#contact">En savoir plus</a>
                </div>
              </div>
            </section>

            <section class="showcase" id="experience">
              <div class="glow"></div>
              <div class="product">
                <div>
                  <strong>Votre produit.<br>Mis en lumière.</strong>
                  <p class="lead">Remplace ce bloc par la présentation centrale de ton projet.</p>
                </div>
              </div>
            </section>

            <section class="grid" id="details">
              <article class="card wide">
                <h2>Une interface qui respire.</h2>
                <p>Grands espaces, hiérarchie claire, animations discrètes et détails visuels précis.</p>
              </article>
              <article class="card">
                <h2>Rapide.</h2>
                <p>Structure légère, responsive et sans dépendances lourdes.</p>
              </article>
              <article class="card">
                <h2>Liquid Glass.</h2>
                <p>Surfaces translucides, profondeur et contraste adaptés au contenu.</p>
              </article>
              <article class="card wide">
                <h2>Mobile d’abord.</h2>
                <p>La mise en page se replie proprement sur iPhone sans perdre son caractère premium.</p>
              </article>
            </section>

            <section class="statement">
              Pensé pour disparaître.<br><span>Et laisser le contenu parler.</span>
            </section>

            <footer id="contact">Prototype local créé par Raphaël dans Sarah IA.</footer>
          </div>
          <script>
            const observer = new IntersectionObserver(entries => {
              entries.forEach(entry => {
                if (entry.isIntersecting) entry.target.classList.add('visible');
              });
            }, { threshold: .18 });
            document.querySelectorAll('.card').forEach(card => observer.observe(card));
          </script>
        </body>
        </html>
        """
    }

    /// Améliore le site actuellement ouvert sans repartir de zéro.
    /// Le HTML existant reste la source de vérité, puis Raphaël injecte une
    /// couche d'amélioration correspondant à la demande.
    public func refineWebsite(
        currentHTML: String,
        brief: WebsiteBrief?,
        instruction: String
    ) -> String {
        guard !currentHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let brief = brief {
                return generateWebsite(brief: brief)
            }
            return generateAppleInspiredWebsite(prompt: instruction)
        }

        let normalized = instruction
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
            .lowercased()

        let appleStyle =
            normalized.contains("apple")
            || normalized.contains("premium")
            || normalized.contains("liquid glass")
            || normalized.contains("liquidglass")

        let strongerMotion =
            normalized.contains("animation")
            || normalized.contains("anime")
            || normalized.contains("dynamique")
            || normalized.contains("fluide")

        var extraCSS = ""

        if appleStyle {
            extraCSS += """
            body { letter-spacing:-.012em; }
            nav, section, .card {
              border-color:rgba(255,255,255,.12)!important;
              backdrop-filter:blur(24px) saturate(170%);
              -webkit-backdrop-filter:blur(24px) saturate(170%);
            }
            .hero {
              border-radius:38px!important;
              box-shadow:0 35px 90px rgba(0,0,0,.22)!important;
            }
            h1, h2 { letter-spacing:-.045em!important; }
            """
        }

        if strongerMotion {
            extraCSS += """
            [data-sarah-reveal] {
              opacity:0;
              transform:translateY(18px);
              transition:opacity .7s ease, transform .7s cubic-bezier(.2,.8,.2,1);
            }
            [data-sarah-reveal].visible {
              opacity:1;
              transform:none;
            }
            """
        }

        let css = """
        <style id="sarah-raphael-refinement">
          html { scroll-behavior:smooth; }
          body {
            -webkit-font-smoothing:antialiased;
            text-rendering:optimizeLegibility;
          }
          nav {
            position:sticky;
            top:10px;
            z-index:50;
            backdrop-filter:blur(24px) saturate(170%);
            -webkit-backdrop-filter:blur(24px) saturate(170%);
          }
          section, .card, .hero {
            transition:transform .35s ease, box-shadow .35s ease, border-color .35s ease;
          }
          .card:hover {
            transform:translateY(-4px);
            box-shadow:0 18px 45px rgba(0,0,0,.14);
          }
          @media(max-width:640px) {
            h1 { font-size:clamp(38px,13vw,58px)!important; }
            .shell { padding-left:16px!important; padding-right:16px!important; }
          }
          \(extraCSS)
        </style>
        """

        let js: String
        if strongerMotion {
            js = """
            <script id="sarah-raphael-refinement-js">
              document.querySelectorAll('section,.card').forEach(el => {
                el.setAttribute('data-sarah-reveal','');
              });
              const sarahObserver = new IntersectionObserver(entries => {
                entries.forEach(entry => {
                  if (entry.isIntersecting) entry.target.classList.add('visible');
                });
              }, { threshold: .12 });
              document.querySelectorAll('[data-sarah-reveal]').forEach(el => {
                sarahObserver.observe(el);
              });
            </script>
            """
        } else {
            js = ""
        }

        var result = currentHTML

        if let oldStyle = result.range(
            of: #"(?s)<style id="sarah-raphael-refinement">.*?</style>"#,
            options: .regularExpression
        ) {
            result.replaceSubrange(oldStyle, with: css)
        } else if let headClose = result.range(
            of: "</head>",
            options: .caseInsensitive
        ) {
            result.insert(contentsOf: css + "\n", at: headClose.lowerBound)
        } else {
            result = css + result
        }

        if !js.isEmpty {
            if let oldScript = result.range(
                of: #"(?s)<script id="sarah-raphael-refinement-js">.*?</script>"#,
                options: .regularExpression
            ) {
                result.replaceSubrange(oldScript, with: js)
            } else if let bodyClose = result.range(
                of: "</body>",
                options: .caseInsensitive
            ) {
                result.insert(contentsOf: js + "\n", at: bodyClose.lowerBound)
            } else {
                result += js
            }
        }

        return result
    }

    private func websiteColors(for accent: String) -> (primary: String, secondary: String) {
        switch accent.lowercased() {
        case "bleu": return ("#176BFF", "#00B9E8")
        case "rose": return ("#D42A8F", "#FF7A75")
        case "orange": return ("#EA6A24", "#FFB347")
        case "vert": return ("#13865B", "#51B95B")
        case "noir & blanc": return ("#24252B", "#5B5E6A")
        default: return ("#6A35D9", "#A452E9")
        }
    }

    private func websiteSection(_ section: String, siteName: String, goal: String, audience: String, accent: String) -> String {
        let anchor = htmlEscaped(section).replacingOccurrences(of: " ", with: "-")
        let safeSection = htmlEscaped(section)
        switch section {
        case "Accueil":
            return "<section id=\"\(anchor)\"><h2>Bienvenue</h2><p class=\"intro\">\(goal)</p><div class=\"cards\"><div class=\"card\"><b>Simple</b><p>Une présentation immédiatement compréhensible.</p></div><div class=\"card\"><b>Soigné</b><p>Une expérience pensée pour \(audience).</p></div><div class=\"card\"><b>Évolutif</b><p>Chaque texte, couleur et section peut être amélioré.</p></div></div></section>"
        case "À propos":
            return "<section id=\"\(anchor)\"><h2>À propos de \(siteName)</h2><p class=\"intro\">Voici l’espace pour raconter votre histoire, vos valeurs et ce qui rend votre proposition unique.</p></section>"
        case "Produits / services":
            return "<section id=\"\(anchor)\"><h2>Nos produits et services</h2><div class=\"cards\"><div class=\"card\"><b>Découvrir</b><p>Présentez votre première offre de façon claire.</p></div><div class=\"card\"><b>Choisir</b><p>Ajoutez les détails, prix ou options utiles.</p></div><div class=\"card\"><b>Contacter</b><p>Guidez les visiteurs vers l’étape suivante.</p></div></div></section>"
        case "Galerie":
            return "<section id=\"\(anchor)\"><h2>Galerie</h2><div class=\"cards\"><div class=\"card\"><b>Projet 01</b><p>Ajoutez ici vos meilleures images.</p></div><div class=\"card\"><b>Projet 02</b><p>Montrez votre univers visuel.</p></div><div class=\"card\"><b>Projet 03</b><p>Une galerie prête à être personnalisée.</p></div></div></section>"
        case "Avis clients":
            return "<section id=\"\(anchor)\"><h2>Ils nous font confiance</h2><p class=\"quote\">« Ajoutez ici un avis client authentique qui explique votre valeur. »</p></section>"
        case "FAQ":
            return "<section id=\"\(anchor)\"><h2>Questions fréquentes</h2><div class=\"cards\"><div class=\"card\"><b>Comment ça marche ?</b><p>Ajoutez votre réponse ici.</p></div><div class=\"card\"><b>Quels sont les délais ?</b><p>Donnez une réponse claire à vos visiteurs.</p></div><div class=\"card\"><b>Comment vous joindre ?</b><p>Indiquez votre moyen de contact préféré.</p></div></div></section>"
        case "Contact":
            return "<section id=\"\(anchor)\" class=\"contact\"><div><h2>Parlons de votre projet</h2><p>Une question ? Écrivez-nous, nous vous répondrons rapidement.</p></div><button class=\"cta\" onclick=\"showContact()\">Envoyer un message</button></section>"
        default:
            return "<section id=\"\(anchor)\"><h2>\(safeSection)</h2><p class=\"intro\">Cette section est prête à être personnalisée avec votre contenu.</p></section>"
        }
    }

    private func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    /// Générateur d'Automatisation & Raccourcis Apple (.shortcut / JSON)
    public func generateAppleShortcut(title: String, prompt: String) -> (jsonString: String, shortcutURL: URL?) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortcutData: [String: Any] = [
            "WFWorkflowName": cleanTitle.isEmpty ? "Action Rapide Sarah" : cleanTitle,
            "WFWorkflowClientVersion": "2203.0.4",
            "WFWorkflowIcon": [
                "WFWorkflowIconGlyphNumber": 59511,
                "WFWorkflowIconStartColor": 4282601983
            ],
            "WFWorkflowActions": [
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.comment",
                    "WFWorkflowActionParameters": [
                        "WFCommentActionText": "Généré automatiquement par Raphaël (Sarah AI Code Engine)"
                    ]
                ],
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.showresult",
                    "WFWorkflowActionParameters": [
                        "Text": "Exécution réussie : \(prompt)"
                    ]
                ],
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.vibrate",
                    "WFWorkflowActionParameters": [:]
                ]
            ]
        ]
        
        let jsonData = (try? JSONSerialization.data(withJSONObject: shortcutData, options: [.prettyPrinted])) ?? Data()
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        let filename = "\(cleanTitle.replacingOccurrences(of: " ", with: "_")).shortcut"
        let savedURL = saveFile(filename: filename, content: jsonStr)
        return (jsonStr, savedURL)
    }
    
    // MARK: - Intégrations Développeur & Cloud (GitHub, Gmail, Google Play Console, Déploiement Web)
    
    /// Génère le flux d'authentification ou lance le portail de connexion GitHub
    public func getGitHubAuthURL() -> URL {
        return URL(string: "https://github.com/login")!
    }
    
    /// Prépare un fichier local pour publication.
    /// Une URL publique ne peut être fournie qu'après une vraie connexion à un hébergeur ou à GitHub.
    public func deployProjectOnline(projectName: String, htmlCode: String) -> (liveURL: String, status: String) {
        let cleanName = projectName.lowercased().replacingOccurrences(of: " ", with: "-")
        let filename = "\(cleanName)_ready_to_publish.html"
        _ = saveFile(filename: filename, content: htmlCode)
        let statusMsg = "📦 **Projet préparé localement**\n\nLe fichier HTML est prêt dans `Documents/VAI_Workspace/\(filename)`.\n\nAucune URL publique n’a été créée : pour le mettre réellement en ligne, il faut connecter un dépôt GitHub ou un hébergeur autorisé, puis lancer une publication."
        return ("", statusMsg)
    }
    
    /// Génère l'URL et le flux de connexion Google / Gmail
    public func getGoogleMailURL() -> URL {
        return URL(string: "https://mail.google.com")!
    }
    
    /// Génère l'accès direct et l'analyseur pour Google Play Developer Console
    public func getGooglePlayConsoleURL() -> URL {
        return URL(string: "https://play.google.com/console")!
    }
    
    /// Générateur de paquet Android App Bundle (AAB / Manifest) pour Google Play Console
    public func generateGooglePlayManifest(appName: String, packageName: String) -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <manifest xmlns:android="http://schemas.android.com/apk/res/android"
            package="\(packageName)">
            <application
                android:allowBackup="true"
                android:icon="@mipmap/ic_launcher"
                android:label="\(appName)"
                android:roundIcon="@mipmap/ic_launcher_round"
                android:supportsRtl="true"
                android:theme="@style/Theme.SarahAI">
                <activity
                    android:name=".MainActivity"
                    android:exported="true">
                    <intent-filter>
                        <action android:name="android.intent.action.MAIN" />
                        <category android:name="android.intent.category.LAUNCHER" />
                    </intent-filter>
                </activity>
            </application>
        </manifest>
        """
    }
    
    /// Ingestion et extraction de maquettes Figma / Google Stitch Tokens
    public func ingestDesignTokens(jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "⚠️ Format de tokens invalide. Fournissez un JSON valide avec les clés de style ou calques Figma."
        }
        
        var parsedSummary = "🎨 **Raphaël [Ingestion Design Tokens Figma/Stitch]**\n\n"
        parsedSummary += "• **Propriétés détectées :** \(json.keys.count) variables\n"
        if let colors = json["colors"] as? [String: String] {
            parsedSummary += "• **Palette :** \(colors.keys.joined(separator: ", "))\n"
        }
        if let typography = json["typography"] as? [String: Any] {
            parsedSummary += "• **Typographie :** \(typography.keys.joined(separator: ", "))\n"
        }
        parsedSummary += "\n✨ Composant Web prêt à être généré dans `Documents/VAI_Workspace/`."
        return parsedSummary
    }
    
    /// Générateur de fichier Shortcut JSON pour Apple Shortcuts
    public func generateShortcutJSON(name: String, prompt: String) -> String {
        return """
        {
          "WFWorkflowClientVersion": "2607.1",
          "WFWorkflowMinimumClientVersion": 900,
          "WFWorkflowIcon": {
            "WFWorkflowIconGlyphNumber": 59511,
            "WFWorkflowIconStartColor": 431817727
          },
          "WFWorkflowImportQuestions": [],
          "WFWorkflowTypes": ["NCWidget", "WatchKit", "MenuBar"],
          "WFWorkflowActions": [
            {
              "WFWorkflowActionIdentifier": "is.workflow.actions.gettext",
              "WFWorkflowActionParameters": {
                "WFTextActionText": "\(prompt)"
              }
            },
            {
              "WFWorkflowActionIdentifier": "is.workflow.actions.shownotification",
              "WFWorkflowActionParameters": {
                "WFNotificationActionTitle": "\(name)",
                "WFNotificationActionBody": "Exécuté avec Sarah IA"
              }
            }
          ]
        }
        """
    }
}
