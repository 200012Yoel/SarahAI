from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Missing expected UI block: {label}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


chat = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
replace_once(
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
    "menu button identifier",
)
replace_once(
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
    "agent menu identifier",
)
replace_once(
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
    "settings button identifier",
)

bar = Path("SarahIA/SarahIA/Views/MessageBar.swift")
replace_once(
    bar,
    '''            .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")

            HStack(spacing: 8) {
''',
    '''            .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")
            .accessibilityIdentifier("sarah.attachment.menu")

            HStack(spacing: 8) {
''',
    "attachment menu identifier",
)
replace_once(
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
    "composer identifier",
)
replace_once(
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
    "composer action identifier",
)

sidebar = Path("SarahIA/SarahIA/Views/SidebarView.swift")
replace_once(
    sidebar,
    '''        .preferredColorScheme(.dark)
        .confirmationDialog(
''',
    '''        .preferredColorScheme(.dark)
        .accessibilityIdentifier("sarah.sidebar")
        .confirmationDialog(
''',
    "sidebar identifier",
)

print("Simulator-only UI accessibility identifiers injected")
