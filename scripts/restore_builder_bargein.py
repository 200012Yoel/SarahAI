from pathlib import Path
import re

root = Path("SarahIA/SarahIA")

# MARK: Website builder
p = root / "Views/ChatScreenView.swift"
s = p.read_text()
start = s.index("private struct WebsiteBuilderFlowView: View")
end = s.index("/// Sélecteur UIKit minimal utilisé par le bouton appareil photo.", start)
b = s[start:end]

b = b.replace(
    "@State private var visualStyle: String\n    @State private var accent: String",
    "@State private var visualStyle: String\n    @State private var designMood: String\n    @State private var accent: String",
)

b = re.sub(
    r"    private let categories = \[.*?\n    \]\n\n    private let audiences = \[",
    '''    private let categories = [
        WebsiteChoice(title: "E-commerce", icon: "bag.fill", detail: "Vendre des produits"),
        WebsiteChoice(title: "Voyage", icon: "airplane", detail: "Inspirer et réserver"),
        WebsiteChoice(title: "Restaurant", icon: "fork.knife", detail: "Menu et réservation"),
        WebsiteChoice(title: "Portfolio", icon: "person.crop.rectangle", detail: "Présenter son travail"),
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Services et contact"),
        WebsiteChoice(title: "Événement", icon: "calendar", detail: "Informer et inscrire")
    ]

    private let audiences = [''',
    b,
    count=1,
    flags=re.S,
)

style_start = b.index("    private let styleChoices = [")
style_end = b.index("    private let accentOptions", style_start)
b = b[:style_start] + '''    private let moodChoices = [
        WebsiteChoice(title: "Minimaliste", icon: "rectangle.compress.vertical", detail: "Simple, calme et très lisible"),
        WebsiteChoice(title: "Élégant", icon: "sparkles", detail: "Raffiné, équilibré et premium"),
        WebsiteChoice(title: "Énergique", icon: "bolt.fill", detail: "Contrastes forts et rythme visuel"),
        WebsiteChoice(title: "Luxe", icon: "crown.fill", detail: "Sobre, éditorial et haut de gamme"),
        WebsiteChoice(title: "Naturel", icon: "leaf.fill", detail: "Doux, organique et chaleureux"),
        WebsiteChoice(title: "Tech", icon: "cpu", detail: "Précis, moderne et numérique")
    ]

    private let styleChoices = [
        WebsiteStyleChoice(title: "Apple Premium", icon: "apple.logo", detail: "Grands espaces, verre discret et typographie monumentale"),
        WebsiteStyleChoice(title: "Google Color", icon: "circle.grid.2x2.fill", detail: "Material lumineux, cartes douces et palette multicolore"),
        WebsiteStyleChoice(title: "Tesla Minimal", icon: "bolt.car.fill", detail: "Minimalisme extrême, grands visuels et noir et blanc"),
        WebsiteStyleChoice(title: "Microsoft Fluent", icon: "square.grid.2x2.fill", detail: "Surfaces Fluent, profondeur, transparence et bleu"),
        WebsiteStyleChoice(title: "Stripe Commerce", icon: "creditcard.fill", detail: "Dégradés premium et hiérarchie orientée conversion"),
        WebsiteStyleChoice(title: "Airbnb Travel", icon: "house.fill", detail: "Chaleureux, photographique et arrondis généreux"),
        WebsiteStyleChoice(title: "Shopify Store", icon: "bag.badge.plus", detail: "Boutique claire, fiches produit et accents verts"),
        WebsiteStyleChoice(title: "Notion Editorial", icon: "doc.text.fill", detail: "Noir et blanc, éditorial et blocs très sobres"),
        WebsiteStyleChoice(title: "Linear Tech", icon: "sparkle", detail: "Dark mode précis, halos subtils et finition SaaS"),
        WebsiteStyleChoice(title: "Sarah Signature", icon: "wand.and.stars", detail: "Verre sombre, cyan lumineux et détails futuristes")
    ]

''' + b[style_end:]

old_init = '''        _visualStyle = State(initialValue: draft?.visualStyle ?? "")
        _accent = State(initialValue: draft?.accent ?? "Bleu")'''
new_init = '''        let savedStyle = draft?.visualStyle ?? ""
        let savedParts = savedStyle.components(separatedBy: " · ")
        _designMood = State(initialValue: savedParts.count > 1 ? savedParts[0] : "")
        _visualStyle = State(initialValue: savedParts.count > 1 ? savedParts.dropFirst().joined(separator: " · ") : savedStyle)
        _accent = State(initialValue: draft?.accent ?? "Violet")'''
if old_init not in b:
    raise SystemExit("builder init pattern not found")
b = b.replace(old_init, new_init, 1)

b = b.replace(
    'Text(step == 3 ? "Derniers réglages" : "Construisons ton site")',
    'Text(step == 4 ? "Derniers réglages" : "Construisons ton site")',
    1,
)

b = re.sub(
    r"    private var headerSubtitle: String \{.*?\n    \}\n\n    private var progress:",
    '''    private var headerSubtitle: String {
        switch step {
        case 0: return "Choisis le type de site avec les mêmes cartes que la build 502."
        case 1: return "Donne le nom, l’objectif et le public du site."
        case 2: return "Choisis l’ambiance graphique du parcours original."
        case 3: return "Choisis ensuite une grande direction visuelle pour guider Raphaël."
        default: return "Sélectionne les sections à afficher avant la première maquette locale."
        }
    }

    private var progress:''',
    b,
    count=1,
    flags=re.S,
)

b = b.replace('Text("Question \\(step + 1) sur 4")', 'Text("Question \\(step + 1) sur 5")', 1)
b = b.replace('Text("\\((step + 1) * 25) %")', 'Text("\\((step + 1) * 20) %")', 1)
b = b.replace('ProgressView(value: Double(step + 1), total: 4)', 'ProgressView(value: Double(step + 1), total: 5)', 1)

q_root = b.index("private var questionContent")
q_start = b.index("        case 2:", q_root)
q_default = b.index("        default:", q_start)
b = b[:q_start] + '''        case 2:
            questionTitle(
                "Quelle ambiance veux-tu ?",
                subtitle: "Le menu original : Minimaliste, Élégant, Énergique, Luxe, Naturel ou Tech."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(moodChoices.enumerated()), id: \\.element.id) { index, choice in
                    choiceCard(
                        number: index + 1,
                        title: choice.title,
                        detail: choice.detail,
                        icon: choice.icon,
                        selected: designMood == choice.title
                    ) {
                        HapticService.shared.buttonTap()
                        designMood = choice.title
                    }
                }
            }

            chipSection(title: "Couleur d’accent", options: accentOptions, selection: $accent)

        case 3:
            questionTitle(
                "Quelle direction graphique veux-tu ?",
                subtitle: "Chaque style change réellement les couleurs, la typographie, les formes, les surfaces et le rythme du site."
            )

            VStack(spacing: 12) {
                ForEach(Array(styleChoices.enumerated()), id: \\.element.id) { index, choice in
                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title) {
                        HapticService.shared.buttonTap()
                        visualStyle = choice.title
                    }
                }
            }

''' + b[q_default:]

b = b.replace('Button(step == 3 ? "Créer avec Raphaël" : "Continuer")', 'Button(step == 4 ? "Créer avec Raphaël" : "Continuer")', 1)
b = b.replace('if step == 3 {', 'if step == 4 {', 1)
b = re.sub(
    r"        case 2:\n            return !visualStyle\.isEmpty && !accent\.isEmpty\n        default:",
    '''        case 2:
            return !designMood.isEmpty && !accent.isEmpty
        case 3:
            return !visualStyle.isEmpty
        default:''',
    b,
    count=1,
)
b = b.replace('visualStyle: visualStyle,', 'visualStyle: "\\(designMood) · \\(visualStyle)",', 1)

# Builder only: return to the purple visual family that was validated in build #502.
b = b.replace(".sarahCyan", ".purple")

dp_start = b.index("    private func designProfile(style: String, primary: String, secondary: String)")
dp_end = b.index("    private func accentColors", dp_start)
design_profile = r'''    private func designProfile(style: String, primary: String, secondary: String) -> (themeColor: String, css: String) {
        let n = style.lowercased()
        var theme = "#000000"
        var ink = "#f5f5f7"
        var muted = "#a1a1a6"
        var surface = "rgba(28,28,30,.78)"
        var soft = "#000000"
        var line = "rgba(255,255,255,.12)"
        var a1 = primary
        var a2 = secondary
        var font = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif"
        var radius = "30px"
        var cardRadius = "20px"
        var buttonRadius = "999px"
        var bodyBackground = "radial-gradient(circle at 50% -10%, rgba(10,132,255,.18), transparent 34%), #000"
        var heroBackground = "linear-gradient(145deg, rgba(255,255,255,.105), rgba(255,255,255,.025))"
        var shadow = "0 34px 90px rgba(0,0,0,.42)"

        if n.contains("google") {
            theme = "#F8FAFD"; ink = "#202124"; muted = "#5f6368"; surface = "#ffffff"; soft = "#f8fafd"; line = "#e1e3e7"
            a1 = "#4285F4"; a2 = "#34A853"; font = "Roboto, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
            radius = "34px"; cardRadius = "22px"; bodyBackground = "radial-gradient(circle at 12% 0%, rgba(66,133,244,.15), transparent 22%), radial-gradient(circle at 82% 4%, rgba(234,67,53,.12), transparent 20%), radial-gradient(circle at 64% 28%, rgba(251,188,5,.11), transparent 18%), #f8fafd"; heroBackground = "linear-gradient(135deg, rgba(66,133,244,.10), rgba(52,168,83,.08) 45%, rgba(251,188,5,.10))"; shadow = "0 2px 10px rgba(60,64,67,.10)"
        } else if n.contains("tesla") {
            theme = "#F4F4F4"; ink = "#111111"; muted = "#666666"; surface = "#ffffff"; soft = "#f4f4f4"; line = "#dedede"
            a1 = "#111111"; a2 = "#666666"; font = "Arial, 'Helvetica Neue', sans-serif"; radius = "4px"; cardRadius = "3px"; buttonRadius = "3px"; bodyBackground = "#f4f4f4"; heroBackground = "linear-gradient(180deg, #202020 0%, #060606 100%)"; shadow = "none"
        } else if n.contains("microsoft") {
            theme = "#0F1115"; ink = "#f5f5f5"; muted = "#b6bbc4"; surface = "rgba(35,38,44,.82)"; soft = "#111318"; line = "rgba(255,255,255,.10)"
            a1 = "#0078D4"; a2 = "#4CC2FF"; font = "'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif"; radius = "16px"; cardRadius = "10px"; buttonRadius = "8px"; bodyBackground = "radial-gradient(circle at 85% -10%, rgba(0,120,212,.30), transparent 36%), #0f1115"; heroBackground = "linear-gradient(145deg, rgba(255,255,255,.09), rgba(255,255,255,.035))"; shadow = "0 22px 70px rgba(0,0,0,.35)"
        } else if n.contains("stripe") {
            theme = "#F6F9FC"; ink = "#0A2540"; muted = "#425466"; surface = "rgba(255,255,255,.90)"; soft = "#f6f9fc"; line = "rgba(10,37,64,.10)"
            a1 = "#635BFF"; a2 = "#00D4FF"; cardRadius = "18px"; bodyBackground = "linear-gradient(140deg, #f6f9fc 0%, #eef4ff 55%, #f9f2ff 100%)"; heroBackground = "linear-gradient(120deg, rgba(99,91,255,.18), rgba(0,212,255,.15), rgba(255,82,191,.12))"; shadow = "0 30px 80px rgba(50,50,93,.13)"
        } else if n.contains("airbnb") {
            theme = "#FFFDFC"; ink = "#222222"; muted = "#717171"; surface = "#ffffff"; soft = "#fffdfc"; line = "#e7e7e7"
            a1 = "#FF385C"; a2 = "#E31C5F"; radius = "34px"; buttonRadius = "12px"; bodyBackground = "#fffdfc"; heroBackground = "linear-gradient(145deg, #4b2730, #b82647 58%, #ff6b81)"; shadow = "0 22px 60px rgba(0,0,0,.14)"
        } else if n.contains("shopify") {
            theme = "#F4F7F2"; ink = "#202223"; muted = "#6D7175"; surface = "#ffffff"; soft = "#f4f7f2"; line = "#dfe3df"
            a1 = "#008060"; a2 = "#95BF47"; radius = "22px"; cardRadius = "14px"; buttonRadius = "8px"; bodyBackground = "#f4f7f2"; heroBackground = "linear-gradient(135deg, #004c3f, #008060 62%, #95BF47)"; shadow = "0 18px 50px rgba(0,76,63,.14)"
        } else if n.contains("notion") {
            theme = "#FFFFFF"; ink = "#111111"; muted = "#6b6b6b"; surface = "#ffffff"; soft = "#ffffff"; line = "#e5e5e5"
            a1 = "#111111"; a2 = "#555555"; font = "Georgia, 'Times New Roman', serif"; radius = "8px"; cardRadius = "5px"; buttonRadius = "5px"; bodyBackground = "#fff"; heroBackground = "#fff"; shadow = "0 8px 26px rgba(0,0,0,.04)"
        } else if n.contains("linear") {
            theme = "#08090B"; ink = "#f4f4f5"; muted = "#9b9ba4"; surface = "rgba(18,18,24,.86)"; soft = "#08090b"; line = "rgba(255,255,255,.09)"
            a1 = "#5E6AD2"; a2 = "#8B7CFF"; radius = "24px"; cardRadius = "14px"; buttonRadius = "9px"; bodyBackground = "radial-gradient(circle at 50% -12%, rgba(94,106,210,.32), transparent 36%), #08090b"; heroBackground = "linear-gradient(145deg, rgba(94,106,210,.13), rgba(255,255,255,.025))"; shadow = "0 30px 90px rgba(0,0,0,.46)"
        } else if n.contains("sarah") {
            theme = "#05070A"; ink = "#f7fbff"; muted = "#aeb8c6"; surface = "rgba(16,22,30,.76)"; soft = "#05070a"; line = "rgba(148,220,255,.14)"
            a1 = "#64D2FF"; a2 = "#7D6CFF"; radius = "34px"; cardRadius = "18px"; bodyBackground = "radial-gradient(circle at 12% 0%, rgba(100,210,255,.18), transparent 30%), radial-gradient(circle at 90% 10%, rgba(125,108,255,.17), transparent 30%), #05070a"; heroBackground = "linear-gradient(145deg, rgba(100,210,255,.10), rgba(125,108,255,.07), rgba(255,255,255,.02))"; shadow = "0 32px 90px rgba(0,0,0,.48)"
        }

        let darkHero = n.contains("tesla") || n.contains("microsoft") || n.contains("airbnb") || n.contains("shopify") || n.contains("linear") || n.contains("sarah") || n.contains("apple")
        let heroInk = darkHero ? "#ffffff" : ink
        let heroMuted = darkHero ? "rgba(255,255,255,.82)" : muted

        return (theme, """
        :root { --primary: \(a1); --secondary: \(a2); --ink: \(ink); --muted: \(muted); --surface: \(surface); --soft: \(soft); --line: \(line); }
        body { color: var(--ink); background: \(bodyBackground); font-family: \(font); }
        .links a { color: var(--ink); padding: 8px 12px; border-radius: \(buttonRadius); background: color-mix(in srgb, var(--surface) 75%, transparent); }
        .hero { border-radius: \(radius); color: \(heroInk); background: \(heroBackground); border: 1px solid var(--line); box-shadow: \(shadow); backdrop-filter: blur(22px); }
        .eyebrow { color: var(--primary); }
        .hero p { color: \(heroMuted); }
        .intro, .card p { color: var(--muted); }
        .cta { color: #fff; background: linear-gradient(135deg, var(--primary), var(--secondary)); border-radius: \(buttonRadius); box-shadow: 0 8px 26px color-mix(in srgb, var(--primary) 22%, transparent); }
        section { border-radius: \(radius); background: var(--surface); border: 1px solid var(--line); backdrop-filter: blur(16px); }
        .card { border-radius: \(cardRadius); background: color-mix(in srgb, var(--surface) 82%, var(--soft)); border: 1px solid var(--line); }
        """)
    }

'''
b = b[:dp_start] + design_profile + b[dp_end:]
s = s[:start] + b + s[end:]
p.write_text(s)

# MARK: Developer agent routing
p = root / "Services/MultiAgentCoordinator.swift"
s = p.read_text()
s = s.replace(
    'let estherTokens = ["esther", "ester", "esther code", "raphael", "raphaël", "raph", "rafael"]',
    'let estherTokens = ["l agent developpeur", "le developpeur", "agent developpeur", "developpeur", "agent de codage", "agent code", "esther", "ester", "esther code", "raphael", "raphaël", "raph", "rafael"]',
    1,
)
s = s.replace(
    'if normalized.contains("esther") || normalized.contains("raphael") ||\n           normalized.contains("code") || normalized.contains("programme") ||',
    'if normalized.contains("esther") || normalized.contains("raphael") ||\n           normalized.contains("agent developpeur") || normalized.contains("developpeur") ||\n           normalized.contains("agent de codage") || normalized.contains("agent code") ||\n           normalized.contains("code") || normalized.contains("programme") ||',
    1,
)
p.write_text(s)

# MARK: Voice barge-in
p = root / "Services/MultiAgentVoiceManager.swift"
s = p.read_text()
s = s.replace(
    "        AppleSpeechRecognizer.shared.stopListening()\n        stop()\n        pendingSpeechBlock = nil",
    "        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {\n            AppleSpeechRecognizer.shared.stopListening()\n        }\n        stop()\n        pendingSpeechBlock = nil",
    1,
)
s = s.replace(
    "        AppleSpeechRecognizer.shared.stopListening()\n        stop()\n\n        let cleanTransition",
    "        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {\n            AppleSpeechRecognizer.shared.stopListening()\n        }\n        stop()\n\n        let cleanTransition",
    1,
)
p.write_text(s)

p = root / "ViewModels/ChatViewModel.swift"
s = p.read_text()
old = '''        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            guard let self = self, self.isContinuousConversationActive else { return }
            self.liveTranscriptionText = partial
        }'''
new = '''        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            guard let self = self, self.isContinuousConversationActive else { return }
            let cleanedPartial = partial.trimmingCharacters(in: .whitespacesAndNewlines)
            self.liveTranscriptionText = partial

            if self.voiceManager.isSpeaking, !cleanedPartial.isEmpty {
                let normalized = cleanedPartial.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
                let words = normalized.split(separator: " ")
                let explicitInterrupt = normalized == "non" || normalized.hasPrefix("non ") ||
                    normalized.hasPrefix("attends") || normalized.hasPrefix("attend") ||
                    normalized.hasPrefix("stop") || normalized.hasPrefix("pardon") ||
                    normalized.hasPrefix("sarah") || normalized.contains("c est pas ca") ||
                    normalized.contains("ce n est pas ca") || words.count >= 3
                if explicitInterrupt {
                    self.interruptVoiceResponse()
                    self.liveTranscriptionText = partial
                }
            }
        }'''
if old not in s:
    raise SystemExit("partial block missing")
s = s.replace(old, new, 1)
s = s.replace(
    "            self.isSpeaking = true\n            self.isMicRunning = false\n            self.voiceStatus = .speaking",
    "            self.isSpeaking = true\n            self.isMicRunning = AppleSpeechRecognizer.shared.isListening\n            self.voiceStatus = .speaking",
    1,
)
old2 = '''                      !self.voiceManager.isSpeaking,
                      !AppleSpeechRecognizer.shared.isListening else { return }
                self.resumeVoiceMicrophone()'''
new2 = '''                      !self.voiceManager.isSpeaking else { return }
                if AppleSpeechRecognizer.shared.isListening {
                    self.isMicRunning = true
                    self.voiceStatus = .listening(level: self.micInputLevel)
                    return
                }
                self.resumeVoiceMicrophone()'''
if old2 not in s:
    raise SystemExit("resume block missing")
s = s.replace(old2, new2, 1)
p.write_text(s)

p = root / "Views/VoiceOrbModalView.swift"
s = p.read_text()
old3 = '''                if viewModel.isMicRunning {
                    viewModel.pauseVoiceMicrophone()
                } else {
                    viewModel.resumeVoiceMicrophone()
                }'''
new3 = '''                if viewModel.isSpeaking {
                    viewModel.interruptVoiceResponse()
                } else if viewModel.isMicRunning {
                    viewModel.pauseVoiceMicrophone()
                } else {
                    viewModel.resumeVoiceMicrophone()
                }'''
if old3 not in s:
    raise SystemExit("mic block missing")
s = s.replace(old3, new3, 1)
s = s.replace(
    '.accessibilityLabel(viewModel.isMicRunning ? "Couper le micro" : "Réactiver le micro")',
    '.accessibilityLabel(viewModel.isSpeaking ? "Interrompre Sarah" : (viewModel.isMicRunning ? "Couper le micro" : "Réactiver le micro"))',
    1,
)
p.write_text(s)

print("SarahIA patch applied")
