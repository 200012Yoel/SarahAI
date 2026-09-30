from pathlib import Path


def ensure_replace(path: Path, old: str, new: str, marker: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if marker in text:
        print(f"Already present: {label}")
        return
    if old not in text:
        raise SystemExit(f"Missing expected UI block: {label}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


chat = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
ensure_replace(
    chat,
    '''            glassCircleButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }

            Spacer(minLength: 4)
''',
    '''            glassCircleButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }
            .accessibilityIdentifier("sarah.menu.button")

            Spacer(minLength: 4)
''',
    'accessibilityIdentifier("sarah.menu.button")',
    "menu button identifier",
)
ensure_replace(
    chat,
    '''            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 4)

            glassCircleButton(systemName: "gearshape.fill") {
''',
    '''            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("sarah.agent.menu")

            Spacer(minLength: 4)

            glassCircleButton(systemName: "gearshape.fill") {
''',
    'accessibilityIdentifier("sarah.agent.menu")',
    "agent menu identifier",
)
ensure_replace(
    chat,
    '''            glassCircleButton(systemName: "gearshape.fill") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                isShowingSettings = true
            }
''',
    '''            glassCircleButton(systemName: "gearshape.fill") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                isShowingSettings = true
            }
            .accessibilityIdentifier("sarah.settings.button")
''',
    'accessibilityIdentifier("sarah.settings.button")',
    "settings button identifier",
)

bar = Path("SarahIA/SarahIA/Views/MessageBar.swift")
ensure_replace(
    bar,
    '''            .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")

            HStack(spacing: 8) {
''',
    '''            .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")
            .accessibilityIdentifier("sarah.attachment.menu")

            HStack(spacing: 8) {
''',
    'accessibilityIdentifier("sarah.attachment.menu")',
    "attachment menu identifier",
)
ensure_replace(
    bar,
    '''                .accentColor(activeAgent.themeColor)
                .font(.system(size: 15))

                if activeAgent == .esther {
''',
    '''                .accentColor(activeAgent.themeColor)
                .font(.system(size: 15))
                .accessibilityIdentifier("sarah.composer.field")

                if activeAgent == .esther {
''',
    'accessibilityIdentifier("sarah.composer.field")',
    "composer identifier",
)
ensure_replace(
    bar,
    '''            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(isProcessing ? "Arrêter la génération" : (hasText ? "Envoyer" : "Mode vocal Sarah"))
        }
''',
    '''            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(isProcessing ? "Arrêter la génération" : (hasText ? "Envoyer" : "Mode vocal Sarah"))
            .accessibilityIdentifier("sarah.composer.action")
        }
''',
    'accessibilityIdentifier("sarah.composer.action")',
    "composer action identifier",
)

sidebar = Path("SarahIA/SarahIA/Views/SidebarView.swift")
ensure_replace(
    sidebar,
    '''        .preferredColorScheme(.dark)
        .confirmationDialog(
''',
    '''        .preferredColorScheme(.dark)
        .accessibilityIdentifier("sarah.sidebar")
        .confirmationDialog(
''',
    'accessibilityIdentifier("sarah.sidebar")',
    "sidebar identifier",
)

print("Simulator UI accessibility identifiers verified")
