import Foundation
import WebKit

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
    
    /// Générateur Web polyvalent de Raphaël.
    /// Toute demande qui arrive ici produit maintenant un vrai site monopage responsive,
    /// et non plus le même dashboard générique. Le prompt pilote le type de page,
    /// les libellés, les sections et l'interaction principale.
    public func generateWebUI(prompt: String) -> String {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()
        let safePrompt = htmlEscaped(normalized.isEmpty ? "Site créé avec Raphaël" : normalized)

        let title: String
        let eyebrow: String
        let hero: String
        let subtitle: String
        let primaryAction: String
        let accent: String
        let accent2: String
        let cards: [(String, String, String)]
        let interactiveBlock: String

        if lower.contains("calculatrice") || lower.contains("calculator") {
            title = "Calculatrice"
            eyebrow = "Outil interactif"
            hero = "Calcule vite, sans détour."
            subtitle = "Une calculatrice responsive pensée pour le téléphone."
            primaryAction = "Calculer"
            accent = "#7C5CFF"
            accent2 = "#22C1FF"
            cards = [("Rapide", "Résultats immédiats", "bolt.fill"), ("Lisible", "Interface mobile claire", "eye.fill"), ("Locale", "Aucun compte requis", "lock.fill")]
            interactiveBlock = """
            <section class="tool" id="experience">
              <input id="display" class="display" value="0" readonly aria-label="Résultat">
              <div class="calc-grid">
                <button onclick="press('7')">7</button><button onclick="press('8')">8</button><button onclick="press('9')">9</button><button class="accent" onclick="op('/')">÷</button>
                <button onclick="press('4')">4</button><button onclick="press('5')">5</button><button onclick="press('6')">6</button><button class="accent" onclick="op('*')">×</button>
                <button onclick="press('1')">1</button><button onclick="press('2')">2</button><button onclick="press('3')">3</button><button class="accent" onclick="op('-')">−</button>
                <button class="danger" onclick="clr()">C</button><button onclick="press('0')">0</button><button class="accent" onclick="calc()">=</button><button class="accent" onclick="op('+')">+</button>
              </div>
            </section>
            """
        } else if lower.contains("météo") || lower.contains("meteo") || lower.contains("weather") {
            title = "Météo"
            eyebrow = "Prévisions"
            hero = "La météo, en un regard."
            subtitle = "Une interface météo claire, mobile et immédiatement compréhensible."
            primaryAction = "Voir les prévisions"
            accent = "#2687FF"
            accent2 = "#60D6FF"
            cards = [("22°", "Température", "sun.max.fill"), ("45 %", "Humidité", "drop.fill"), ("12 km/h", "Vent", "wind")]
            interactiveBlock = """
            <section class="feature" id="experience">
              <div><span class="kicker">Paris</span><h2>22 °C</h2><p>Ensoleillé · Ressenti agréable</p></div>
              <button class="secondary" onclick="setStatus('Prévisions actualisées dans la maquette')">Actualiser</button>
            </section>
            """
        } else if lower.contains("restaurant") || lower.contains("café") || lower.contains("cafe") || lower.contains("pâtisserie") || lower.contains("patisserie") {
            title = "Maison"
            eyebrow = "Restaurant · Réservation"
            hero = "Une table qu’on a envie de réserver."
            subtitle = safePrompt
            primaryAction = "Réserver"
            accent = "#D56A3A"
            accent2 = "#F2B35B"
            cards = [("Menu", "Une carte courte et lisible", "fork.knife"), ("Savoir-faire", "Mettez vos produits en valeur", "sparkles"), ("Réserver", "Un parcours direct", "calendar")]
            interactiveBlock = """
            <section class="feature" id="experience"><div><span class="kicker">Aujourd’hui</span><h2>Votre sélection</h2><p>Présentez ici vos plats, créations et horaires.</p></div><button class="secondary" onclick="setStatus('Demande de réservation préparée')">Choisir une table</button></section>
            """
        } else if lower.contains("boutique") || lower.contains("ecommerce") || lower.contains("e-commerce") || lower.contains("shop") || lower.contains("magasin") || lower.contains("produit") {
            title = "Boutique"
            eyebrow = "E-commerce"
            hero = "Des produits qui respirent."
            subtitle = safePrompt
            primaryAction = "Découvrir"
            accent = "#5C47E8"
            accent2 = "#B35CFF"
            cards = [("Nouveau", "Collection principale", "bag.fill"), ("Favoris", "Sélection mise en avant", "heart.fill"), ("Simple", "Parcours d’achat lisible", "checkmark.circle.fill")]
            interactiveBlock = """
            <section class="product-grid" id="experience">
              <article class="product"><div class="product-art">01</div><h3>Produit phare</h3><p>49 €</p><button onclick="addToCart('Produit phare')">Ajouter</button></article>
              <article class="product"><div class="product-art">02</div><h3>Nouvelle collection</h3><p>69 €</p><button onclick="addToCart('Nouvelle collection')">Ajouter</button></article>
              <article class="product"><div class="product-art">03</div><h3>Édition spéciale</h3><p>89 €</p><button onclick="addToCart('Édition spéciale')">Ajouter</button></article>
            </section>
            """
        } else if lower.contains("portfolio") || lower.contains("photographe") || lower.contains("designer") || lower.contains("artiste") {
            title = "Portfolio"
            eyebrow = "Création"
            hero = "Votre travail mérite de l’espace."
            subtitle = safePrompt
            primaryAction = "Voir les projets"
            accent = "#FF4D8A"
            accent2 = "#8F5CFF"
            cards = [("Projet 01", "Direction artistique", "square.grid.2x2.fill"), ("Projet 02", "Identité visuelle", "paintbrush.fill"), ("Projet 03", "Expérience numérique", "cursorarrow.click")]
            interactiveBlock = """
            <section class="gallery" id="experience"><div class="tile tall"><span>01</span></div><div class="tile"><span>02</span></div><div class="tile"><span>03</span></div></section>
            """
        } else if lower.contains("voyage") || lower.contains("travel") || lower.contains("hotel") || lower.contains("hôtel") {
            title = "Horizon"
            eyebrow = "Voyage"
            hero = "Partez quelque part de mémorable."
            subtitle = safePrompt
            primaryAction = "Explorer"
            accent = "#007D73"
            accent2 = "#35C39A"
            cards = [("Explorer", "Destinations sélectionnées", "map.fill"), ("Préparer", "Informations essentielles", "suitcase.fill"), ("Profiter", "Une expérience fluide", "airplane")]
            interactiveBlock = """
            <section class="feature" id="experience"><div><span class="kicker">Destination</span><h2>Votre prochain départ</h2><p>Photos, itinéraire, prix et appel à l’action peuvent être personnalisés.</p></div><button class="secondary" onclick="setStatus('Destination ajoutée à votre sélection')">Ajouter au voyage</button></section>
            """
        } else if lower.contains("blog") || lower.contains("actualité") || lower.contains("actualite") || lower.contains("magazine") {
            title = "Journal"
            eyebrow = "Magazine"
            hero = "Des idées qui se lisent bien."
            subtitle = safePrompt
            primaryAction = "Lire"
            accent = "#E74B3C"
            accent2 = "#F49E45"
            cards = [("À la une", "Article principal", "newspaper.fill"), ("Dossiers", "Contenu organisé", "folder.fill"), ("Lecture", "Typographie confortable", "text.alignleft")]
            interactiveBlock = """
            <section class="article-list" id="experience"><article><span>01</span><div><h3>Article principal</h3><p>Une introduction claire pour donner envie de poursuivre la lecture.</p></div></article><article><span>02</span><div><h3>Deuxième sujet</h3><p>Une mise en page qui reste lisible sur petit écran.</p></div></article></section>
            """
        } else {
            title = "Projet Raphaël"
            eyebrow = lower.contains("dashboard") ? "Dashboard" : "Site sur mesure"
            hero = lower.contains("dashboard") ? "Tout ce qui compte, au même endroit." : "Une première version fidèle à votre idée."
            subtitle = safePrompt
            primaryAction = "Commencer"
            accent = "#336CFF"
            accent2 = "#8D55FF"
            cards = [("Responsive", "Téléphone, tablette et ordinateur", "rectangle.3.group.fill"), ("Interactif", "HTML, CSS et JavaScript", "cursorarrow.rays"), ("Évolutif", "Prêt à être amélioré avec Raphaël", "wand.and.stars")]
            interactiveBlock = """
            <section class="feature" id="experience"><div><span class="kicker">Votre demande</span><h2>Prototype fonctionnel</h2><p>\(safePrompt)</p></div><button class="secondary" onclick="setStatus('Interaction exécutée avec succès')">Tester l’interaction</button></section>
            """
        }

        let cardsHTML = cards.map { item in
            "<article class=\"card\"><div class=\"icon\">✦</div><h3>\(htmlEscaped(item.0))</h3><p>\(htmlEscaped(item.1))</p></article>"
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="fr">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <meta name="theme-color" content="#0A0A0D">
          <title>\(htmlEscaped(title))</title>
          <style>
            :root { --accent: \(accent); --accent2: \(accent2); --bg: #09090c; --panel: #131319; --line: rgba(255,255,255,.10); --muted: #a1a1ad; }
            * { box-sizing: border-box; }
            html { scroll-behavior: smooth; }
            body { margin: 0; color: #fff; background: radial-gradient(circle at 90% -10%, color-mix(in srgb, var(--accent) 26%, transparent), transparent 38%), var(--bg); font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif; }
            button, input { font: inherit; }
            button { cursor: pointer; }
            .shell { width: min(1120px, 100%); margin: auto; padding: max(18px, env(safe-area-inset-top)) 20px calc(42px + env(safe-area-inset-bottom)); }
            nav { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 10px 0 32px; }
            .brand { font-weight: 850; letter-spacing: -.6px; }
            .brand b { color: var(--accent2); }
            nav a { color: #fff; text-decoration: none; padding: 9px 13px; border: 1px solid var(--line); border-radius: 999px; font-size: 13px; }
            .hero { min-height: min(610px, 75vh); display: flex; flex-direction: column; justify-content: center; padding: clamp(34px, 7vw, 78px); border: 1px solid var(--line); border-radius: clamp(26px, 5vw, 44px); overflow: hidden; position: relative; background: linear-gradient(145deg, rgba(255,255,255,.08), rgba(255,255,255,.025)); box-shadow: 0 35px 90px rgba(0,0,0,.35); }
            .hero:after { content: ""; position: absolute; right: -12%; top: -32%; width: min(64vw, 610px); aspect-ratio: 1; border-radius: 50%; background: radial-gradient(circle at 35% 35%, var(--accent2), var(--accent) 45%, transparent 70%); filter: blur(10px); opacity: .48; }
            .kicker { color: #d8d8e1; text-transform: uppercase; letter-spacing: .14em; font-size: 12px; font-weight: 750; }
            h1 { position: relative; z-index: 1; max-width: 800px; margin: 14px 0; font-size: clamp(42px, 9vw, 86px); line-height: .98; letter-spacing: clamp(-4px, -.05em, -1px); }
            .hero p { position: relative; z-index: 1; max-width: 680px; color: #c4c4cf; font-size: clamp(16px, 2.5vw, 20px); line-height: 1.55; }
            .actions { position: relative; z-index: 1; display: flex; flex-wrap: wrap; gap: 10px; margin-top: 25px; }
            .primary, .secondary, .product button { border: 0; color: #fff; background: linear-gradient(135deg, var(--accent), var(--accent2)); padding: 13px 17px; border-radius: 14px; font-weight: 750; }
            .ghost { border: 1px solid var(--line); color: #fff; background: rgba(255,255,255,.05); padding: 13px 17px; border-radius: 14px; font-weight: 700; }
            .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; padding: 28px 0; }
            .card, .feature, .tool, .product, .article-list article { border: 1px solid var(--line); background: var(--panel); border-radius: 22px; }
            .card { padding: 22px; min-height: 150px; }
            .card .icon { color: var(--accent2); font-size: 22px; }
            h2, h3 { letter-spacing: -.5px; }
            .card h3 { margin: 24px 0 7px; }
            .card p, .feature p, .product p, .article-list p { color: var(--muted); line-height: 1.5; margin: 0; }
            .feature { margin-top: 4px; padding: clamp(24px, 5vw, 46px); display: flex; align-items: end; justify-content: space-between; gap: 28px; }
            .feature h2 { font-size: clamp(28px, 5vw, 48px); margin: 8px 0 12px; }
            .status { min-height: 24px; margin: 18px 3px 0; color: #c8f7db; font-size: 13px; }
            .tool { max-width: 520px; margin: 0 auto; padding: 18px; }
            .display { width: 100%; padding: 18px; margin-bottom: 12px; color: #fff; background: #08080b; border: 1px solid var(--line); border-radius: 15px; text-align: right; font-size: 32px; }
            .calc-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
            .calc-grid button { min-height: 58px; border: 0; border-radius: 15px; color: #fff; background: #24242b; font-size: 18px; }
            .calc-grid .accent { background: var(--accent); } .calc-grid .danger { background: #8e2934; }
            .product-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
            .product { padding: 14px; } .product-art { min-height: 190px; display: grid; place-items: center; border-radius: 15px; font-size: 40px; font-weight: 850; background: linear-gradient(145deg, var(--accent), var(--accent2)); }
            .product h3 { margin-bottom: 4px; } .product button { width: 100%; margin-top: 14px; }
            .gallery { display: grid; min-height: 520px; grid-template-columns: 1.5fr 1fr; grid-template-rows: 1fr 1fr; gap: 10px; }
            .tile { display: grid; place-items: end start; padding: 20px; border-radius: 24px; font-size: 42px; font-weight: 900; background: linear-gradient(145deg, var(--accent), var(--accent2)); } .tile.tall { grid-row: 1 / 3; }
            .article-list { display: grid; gap: 10px; } .article-list article { padding: 22px; display: flex; gap: 20px; align-items: center; } .article-list article > span { color: var(--accent2); font-size: 30px; font-weight: 850; }
            footer { padding: 36px 4px 8px; color: #72727f; font-size: 12px; text-align: center; }
            @media (max-width: 680px) { .shell { padding-left: 12px; padding-right: 12px; } nav { padding-bottom: 18px; } .hero { min-height: 560px; padding: 28px 22px; } .cards, .product-grid { grid-template-columns: 1fr; } .feature { align-items: stretch; flex-direction: column; } .gallery { min-height: 600px; grid-template-columns: 1fr; grid-template-rows: repeat(3, 1fr); } .tile.tall { grid-row: auto; } }
            @media (prefers-reduced-motion: no-preference) { .hero, .card, .feature, .tool, .product { animation: rise .45s ease both; } @keyframes rise { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } } }
          </style>
        </head>
        <body>
          <main class="shell">
            <nav><div class="brand">Raphaël<b>•</b> \(htmlEscaped(title))</div><a href="#experience">Aperçu</a></nav>
            <header class="hero">
              <span class="kicker">\(htmlEscaped(eyebrow))</span>
              <h1>\(htmlEscaped(hero))</h1>
              <p>\(subtitle)</p>
              <div class="actions"><button class="primary" onclick="document.getElementById('experience').scrollIntoView({behavior:'smooth'})">\(htmlEscaped(primaryAction))</button><button class="ghost" onclick="setStatus('Prototype prêt à être personnalisé avec Raphaël')">Personnaliser</button></div>
            </header>
            <section class="cards">\(cardsHTML)</section>
            \(interactiveBlock)
            <div id="status" class="status" aria-live="polite"></div>
            <footer>Prototype responsive généré localement par Raphaël · HTML + CSS + JavaScript</footer>
          </main>
          <script>
            const statusNode = document.getElementById('status');
            function setStatus(text) { if (statusNode) statusNode.textContent = text; }
            function addToCart(name) { setStatus(name + ' ajouté à la sélection'); }
            let curVal = '';
            function press(n) { curVal += n; const d = document.getElementById('display'); if (d) d.value = curVal; }
            function op(o) { if (!curVal.endsWith(' ')) curVal += ' ' + o + ' '; const d = document.getElementById('display'); if (d) d.value = curVal; }
            function clr() { curVal=''; const d=document.getElementById('display'); if(d) d.value='0'; }
            function calc() { const d=document.getElementById('display'); if(!d) return; try { const value = Function('return (' + curVal + ')')(); d.value=value; curVal=String(value); } catch(e) { d.value='Erreur'; curVal=''; } }
          </script>
        </body>
        </html>
        """
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
    
    public func getGitHubAuthURL() -> URL {
        return URL(string: "https://github.com/login")!
    }
    
    public func deployProjectOnline(projectName: String, htmlCode: String) -> (liveURL: String, status: String) {
        let cleanName = projectName.lowercased().replacingOccurrences(of: " ", with: "-")
        let filename = "\(cleanName)_ready_to_publish.html"
        _ = saveFile(filename: filename, content: htmlCode)
        let statusMsg = "📦 **Projet préparé localement**\n\nLe fichier HTML est prêt dans `Documents/VAI_Workspace/\(filename)`.\n\nAucune URL publique n’a été créée : pour le mettre réellement en ligne, il faut connecter un dépôt GitHub ou un hébergeur autorisé, puis lancer une publication."
        return ("", statusMsg)
    }
    
    public func getGoogleMailURL() -> URL {
        return URL(string: "https://mail.google.com")!
    }
    
    public func getGooglePlayConsoleURL() -> URL {
        return URL(string: "https://play.google.com/console")!
    }
    
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


// MARK: - Raphaël Agentic Web Pipeline

public struct SarahWebAuditReport: Codable, Equatable {
    public var errors: [String]
    public var warnings: [String]
    public var passedChecks: [String]
    public var isPassing: Bool { errors.isEmpty }
}

public struct SarahBrowserSmokeReport: Codable, Equatable {
    public var passed: Bool
    public var title: String
    public var buttonCount: Int
    public var linkCount: Int
    public var brokenImages: Int
    public var horizontalOverflow: Bool
    public var javascriptErrors: [String]
    public var details: String
}

public struct SarahAgenticWebBuildResult {
    public var html: String
    public var revision: Int
    public var wasRefinement: Bool
    public var architectModel: SarahCodingModelProfile
    public var implementerModel: SarahCodingModelProfile
    public var staticAudit: SarahWebAuditReport
    public var browserAudit: SarahBrowserSmokeReport?
    public var usedRemoteModels: Bool
}

private struct SarahPersistentWebProject: Codable {
    var rootRequest: String
    var latestInstruction: String
    var html: String
    var revision: Int
    var updatedAt: Date
}

/// Client générique pour un serveur OpenAI-compatible contrôlé par l'utilisateur.
/// Sarah n'envoie rien sur le réseau tant qu'aucun endpoint n'est configuré.
public final class SarahCodingRuntime {
    public static let shared = SarahCodingRuntime()
    private init() {}

    public var endpointString: String {
        UserDefaults.standard.string(forKey: "sarahCodingEndpoint")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public var isConfigured: Bool { resolvedEndpoint != nil }

    private var resolvedEndpoint: URL? {
        guard !endpointString.isEmpty else { return nil }
        var value = endpointString
        if value.hasSuffix("/v1") {
            value += "/chat/completions"
        } else if !value.contains("/chat/completions") {
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"
        }
        return URL(string: value)
    }

    public func generate(
        model: SarahCodingModelProfile,
        system: String,
        user: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let endpoint = resolvedEndpoint else {
            completion(.failure(NSError(domain: "SarahCodingRuntime", code: 1, userInfo: [NSLocalizedDescriptionKey: "Aucun endpoint de code configuré"])))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 150
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model.identifier,
            "temperature": model.role == .architect ? 0.30 : 0.15,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "SarahCodingRuntime", code: 2, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide du serveur de code"])))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    throw NSError(domain: "SarahCodingRuntime", code: 3, userInfo: [NSLocalizedDescriptionKey: "Format de réponse non reconnu"])
                }
                completion(.success(content))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

extension VAICodeEngine {
    private var agenticProjectURL: URL {
        workspaceDirectory.appendingPathComponent("current_web_project.json")
    }

    private func loadAgenticProject() -> SarahPersistentWebProject? {
        guard let data = try? Data(contentsOf: agenticProjectURL) else { return nil }
        return try? JSONDecoder().decode(SarahPersistentWebProject.self, from: data)
    }

    private func persistAgenticProject(_ project: SarahPersistentWebProject) {
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to: agenticProjectURL, options: .atomic)
        }
        _ = saveFile(filename: "index.html", content: project.html)
    }

    public func currentWebProjectHTML() -> String? { loadAgenticProject()?.html }

    public func resetCurrentWebProject() {
        try? FileManager.default.removeItem(at: agenticProjectURL)
    }

    public func auditWebHTML(_ html: String) -> SarahWebAuditReport {
        let lower = html.lowercased()
        var errors: [String] = []
        var warnings: [String] = []
        var passed: [String] = []

        if lower.contains("<!doctype html") { passed.append("DOCTYPE") } else { errors.append("DOCTYPE manquant") }
        if lower.contains("name=\"viewport\"") || lower.contains("name='viewport'") { passed.append("Viewport mobile") } else { errors.append("Viewport mobile manquant") }
        if lower.contains("<html") && lower.contains("</html>") { passed.append("Document HTML fermé") } else { errors.append("Balises HTML incomplètes") }
        if lower.contains("<body") && lower.contains("</body>") { passed.append("Body présent") } else { errors.append("Body incomplet") }
        if lower.contains("@media") || lower.contains("clamp(") || lower.contains("min(") { passed.append("Responsive CSS") } else { warnings.append("Peu de règles responsive détectées") }
        if lower.contains("document.write(") { warnings.append("document.write() détecté") }
        if html.count > 750_000 { warnings.append("Document très volumineux") }

        return SarahWebAuditReport(errors: errors, warnings: warnings, passedChecks: passed)
    }

    private func extractHTMLDocument(_ raw: String) -> String? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.range(of: "```html", options: .caseInsensitive),
           let end = cleaned.range(of: "```", options: [], range: start.upperBound..<cleaned.endIndex) {
            cleaned = String(cleaned[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleaned = cleaned.replacingOccurrences(of: "```html", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard cleaned.lowercased().contains("<html") || cleaned.lowercased().contains("<!doctype html") else { return nil }
        return cleaned
    }

    private func stabilizeHTML(_ html: String) -> String {
        var result = html
        if !result.lowercased().contains("<!doctype html") {
            result = "<!doctype html>\n" + result
        }
        if !result.lowercased().contains("name=\"viewport\"") && !result.lowercased().contains("name='viewport'") {
            let viewport = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">"
            if let range = result.range(of: "<head>", options: .caseInsensitive) {
                result.insert(contentsOf: "\n" + viewport, at: range.upperBound)
            }
        }
        let safetyCSS = """
        <style id="sarah-agentic-safety">
        html,body{max-width:100%;overflow-x:hidden}img,video,canvas,svg,iframe{max-width:100%;height:auto}*{box-sizing:border-box}
        </style>
        """
        if !result.contains("sarah-agentic-safety") {
            result = result.replacingOccurrences(of: "</head>", with: safetyCSS + "\n</head>", options: .caseInsensitive)
        }
        return result
    }

    private func appleStyleRefinement(_ html: String) -> String {
        guard !html.contains("sarah-apple-refinement") else { return html }
        let patch = """
        <style id="sarah-apple-refinement">
        :root{--sarah-glass:rgba(255,255,255,.075);--sarah-line:rgba(255,255,255,.12)}
        body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
        button,a,input,textarea,select{border-radius:14px}
        .card,.feature,.tool,.product,section{backdrop-filter:blur(22px);-webkit-backdrop-filter:blur(22px)}
        button,a{transition:transform .18s ease,opacity .18s ease}button:active,a:active{transform:scale(.98)}
        </style>
        """
        return html.replacingOccurrences(of: "</head>", with: patch + "\n</head>", options: .caseInsensitive)
    }

    private func applyLiteralEditIfPossible(_ instruction: String, html: String) -> String? {
        let patterns = [
            #"(?i)remplace\s+[«\"“](.+?)[»\"”]\s+par\s+[«\"“](.+?)[»\"”]"#,
            #"(?i)change\s+[«\"“](.+?)[»\"”]\s+(?:en|par)\s+[«\"“](.+?)[»\"”]"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(instruction.startIndex..., in: instruction)
            guard let match = regex.firstMatch(in: instruction, range: range), match.numberOfRanges >= 3,
                  let oldRange = Range(match.range(at: 1), in: instruction),
                  let newRange = Range(match.range(at: 2), in: instruction) else { continue }
            let old = String(instruction[oldRange])
            let new = String(instruction[newRange])
            if html.contains(old) { return html.replacingOccurrences(of: old, with: new) }
        }
        return nil
    }

    public func createOrRefineWebsite(prompt: String) -> SarahAgenticWebBuildResult {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let existing = loadAgenticProject()
        let explicitNew = lower.contains("nouveau site") || lower.contains("nouveau projet") || lower.contains("repars de zéro") || lower.contains("repars de zero")
        let refinementWords = ["corrige", "change", "remplace", "modifie", "améliore", "ameliore", "erreur", "bug", "plus beau", "style apple", "ajoute", "supprime", "déplace", "deplace"]
        let looksLikeRefinement = refinementWords.contains { lower.contains($0) }
        let shouldRefine = existing != nil && !explicitNew && looksLikeRefinement

        var rootRequest = clean
        var html: String
        var revision = 1

        if shouldRefine, let existing = existing {
            rootRequest = existing.rootRequest
            revision = existing.revision + 1
            if let edited = applyLiteralEditIfPossible(clean, html: existing.html) {
                html = edited
            } else if lower.contains("apple") || lower.contains("plus beau") || lower.contains("design") || lower.contains("interface") {
                html = appleStyleRefinement(existing.html)
            } else {
                html = generateWebUI(prompt: existing.rootRequest + "\nModification : " + clean)
            }
        } else {
            html = generateWebUI(prompt: clean)
        }

        html = stabilizeHTML(html)
        let audit = auditWebHTML(html)
        let project = SarahPersistentWebProject(rootRequest: rootRequest, latestInstruction: clean, html: html, revision: revision, updatedAt: Date())
        persistAgenticProject(project)

        return SarahAgenticWebBuildResult(
            html: html,
            revision: revision,
            wasRefinement: shouldRefine,
            architectModel: SarahCodingModelCatalog.architect,
            implementerModel: SarahCodingModelCatalog.implementer,
            staticAudit: audit,
            browserAudit: nil,
            usedRemoteModels: false
        )
    }

    private func architectSystemPrompt() -> String {
        """
        Tu es l'architecte web de Sarah IA. Comprends précisément la demande en langage naturel, conserve les contraintes du projet déjà créé, repère les erreurs et prépare un plan exécutable pour un second modèle. Réponds uniquement avec un plan concis et structuré, sans HTML complet.
        """
    }

    private func implementerSystemPrompt() -> String {
        """
        Tu es le Code Worker de Sarah IA. Retourne uniquement un document HTML autonome complet avec CSS et JavaScript intégrés. Respecte le plan, préserve les fonctions déjà valides du projet existant, corrige les bugs signalés, rends le site responsive et accessible, et n'ajoute aucune fonctionnalité factice présentée comme réelle.
        """
    }

    private func repairSystemPrompt() -> String {
        """
        Tu es le relecteur final du Code Worker. Retourne uniquement le HTML complet corrigé. Corrige les erreurs WebKit, le débordement horizontal, les erreurs JavaScript et les balises incomplètes sans supprimer les fonctions valides du site.
        """
    }

    private func remoteAgenticBuild(prompt: String, completion: @escaping (SarahAgenticWebBuildResult?) -> Void) {
        let existing = loadAgenticProject()
        let context = existing.map { "Projet existant, révision \($0.revision). Demande initiale : \($0.rootRequest)\nHTML actuel :\n\($0.html)" } ?? "Aucun projet existant."

        SarahCodingRuntime.shared.generate(
            model: SarahCodingModelCatalog.architect,
            system: architectSystemPrompt(),
            user: context + "\n\nNouvelle demande : " + prompt
        ) { architectResult in
            guard case .success(let plan) = architectResult else { completion(nil); return }

            let implementerUser = "Plan de l'architecte :\n\(plan)\n\nDemande utilisateur :\n\(prompt)\n\nHTML précédent si présent :\n\(existing?.html ?? "Aucun")"
            SarahCodingRuntime.shared.generate(
                model: SarahCodingModelCatalog.implementer,
                system: self.implementerSystemPrompt(),
                user: implementerUser
            ) { codeResult in
                guard case .success(let rawCode) = codeResult,
                      var html = self.extractHTMLDocument(rawCode) else { completion(nil); return }

                html = self.stabilizeHTML(html)
                let revision = (existing?.revision ?? 0) + 1
                let root = existing?.rootRequest ?? prompt
                let project = SarahPersistentWebProject(rootRequest: root, latestInstruction: prompt, html: html, revision: revision, updatedAt: Date())
                self.persistAgenticProject(project)
                completion(SarahAgenticWebBuildResult(
                    html: html,
                    revision: revision,
                    wasRefinement: existing != nil,
                    architectModel: SarahCodingModelCatalog.architect,
                    implementerModel: SarahCodingModelCatalog.implementer,
                    staticAudit: self.auditWebHTML(html),
                    browserAudit: nil,
                    usedRemoteModels: true
                ))
            }
        }
    }

    public func runBrowserSmokeTest(html: String, completion: @escaping (SarahBrowserSmokeReport) -> Void) {
        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            let probe = """
            window.__sarahErrors = [];
            window.addEventListener('error', function(e) {
              window.__sarahErrors.push(String(e.message || 'JavaScript error'));
            });
            window.addEventListener('unhandledrejection', function(e) {
              window.__sarahErrors.push(String(e.reason || 'Unhandled promise rejection'));
            });
            """
            config.userContentController.addUserScript(WKUserScript(source: probe, injectionTime: .atDocumentStart, forMainFrameOnly: false))
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
            webView.loadHTMLString(html, baseURL: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                let script = """
                (() => JSON.stringify({
                  title: document.title || '',
                  buttons: document.querySelectorAll('button').length,
                  links: document.querySelectorAll('a').length,
                  body: !!document.body,
                  ready: document.readyState,
                  overflow: document.documentElement.scrollWidth > (window.innerWidth + 2),
                  brokenImages: Array.from(document.images).filter(i => i.complete && i.naturalWidth === 0).length,
                  errors: window.__sarahErrors || []
                }))()
                """
                webView.evaluateJavaScript(script) { value, error in
                    if let error = error {
                        completion(SarahBrowserSmokeReport(passed: false, title: "", buttonCount: 0, linkCount: 0, brokenImages: 0, horizontalOverflow: false, javascriptErrors: [error.localizedDescription], details: error.localizedDescription))
                        return
                    }
                    guard let jsonString = value as? String,
                          let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(SarahBrowserSmokeReport(passed: false, title: "", buttonCount: 0, linkCount: 0, brokenImages: 0, horizontalOverflow: false, javascriptErrors: [], details: "Le DOM n'a pas répondu au test."))
                        return
                    }

                    let title = json["title"] as? String ?? ""
                    let buttons = json["buttons"] as? Int ?? 0
                    let links = json["links"] as? Int ?? 0
                    let body = json["body"] as? Bool ?? false
                    let ready = json["ready"] as? String ?? ""
                    let overflow = json["overflow"] as? Bool ?? false
                    let brokenImages = json["brokenImages"] as? Int ?? 0
                    let jsErrors = json["errors"] as? [String] ?? []
                    let passed = body && (ready == "complete" || ready == "interactive") && !overflow && jsErrors.isEmpty

                    var details: [String] = []
                    details.append("DOM: \(ready.isEmpty ? "inconnu" : ready)")
                    if overflow { details.append("débordement horizontal") }
                    if brokenImages > 0 { details.append("\(brokenImages) image(s) cassée(s)") }
                    if !jsErrors.isEmpty { details.append("\(jsErrors.count) erreur(s) JavaScript") }
                    if passed { details.append("rendu mobile valide") }

                    completion(SarahBrowserSmokeReport(
                        passed: passed,
                        title: title,
                        buttonCount: buttons,
                        linkCount: links,
                        brokenImages: brokenImages,
                        horizontalOverflow: overflow,
                        javascriptErrors: jsErrors,
                        details: details.joined(separator: " · ")
                    ))
                }
            }
        }
    }

    private func repairRemoteBuild(_ build: SarahAgenticWebBuildResult, report: SarahBrowserSmokeReport, completion: @escaping (SarahAgenticWebBuildResult) -> Void) {
        guard SarahCodingRuntime.shared.isConfigured else { completion(build); return }
        let auditText = "WebKit: \(report.details)\nErreurs JavaScript: \(report.javascriptErrors.joined(separator: " | "))\nAudit statique: \(build.staticAudit.errors.joined(separator: " | "))"
        SarahCodingRuntime.shared.generate(
            model: SarahCodingModelCatalog.implementer,
            system: repairSystemPrompt(),
            user: "Voici le HTML à corriger :\n\(build.html)\n\nRapport de test :\n\(auditText)"
        ) { result in
            guard case .success(let raw) = result,
                  var repaired = self.extractHTMLDocument(raw) else { completion(build); return }
            repaired = self.stabilizeHTML(repaired)
            var updated = build
            updated.html = repaired
            updated.staticAudit = self.auditWebHTML(repaired)
            if var project = self.loadAgenticProject() {
                project.html = repaired
                project.updatedAt = Date()
                self.persistAgenticProject(project)
            }
            completion(updated)
        }
    }

    public func buildAndTestWebsite(prompt: String, completion: @escaping (SarahAgenticWebBuildResult) -> Void) {
        let finish: (SarahAgenticWebBuildResult) -> Void = { build in
            self.runBrowserSmokeTest(html: build.html) { firstReport in
                if firstReport.passed {
                    var final = build
                    final.browserAudit = firstReport
                    completion(final)
                    return
                }

                self.repairRemoteBuild(build, report: firstReport) { repairedBuild in
                    let locallyStabilized = self.stabilizeHTML(repairedBuild.html)
                    self.runBrowserSmokeTest(html: locallyStabilized) { secondReport in
                        var final = repairedBuild
                        final.html = locallyStabilized
                        final.staticAudit = self.auditWebHTML(locallyStabilized)
                        final.browserAudit = secondReport
                        if var project = self.loadAgenticProject() {
                            project.html = locallyStabilized
                            project.updatedAt = Date()
                            self.persistAgenticProject(project)
                        }
                        completion(final)
                    }
                }
            }
        }

        if SarahCodingRuntime.shared.isConfigured {
            remoteAgenticBuild(prompt: prompt) { remote in
                if let remote = remote { finish(remote) }
                else { finish(self.createOrRefineWebsite(prompt: prompt)) }
            }
        } else {
            finish(createOrRefineWebsite(prompt: prompt))
        }
    }
}
