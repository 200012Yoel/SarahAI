from pathlib import Path
import re

ROOT = Path("SarahIA/SarahIA")


def remove_swift_function(text: str, function_name: str) -> str:
    token = f"func {function_name}("
    idx = text.find(token)
    if idx < 0:
        return text

    start = text.rfind("\n", 0, idx) + 1
    # Include immediately preceding Swift doc/comments for this function.
    scan = start
    while scan > 0:
        previous_end = scan - 1
        previous_start = text.rfind("\n", 0, previous_end) + 1
        line = text[previous_start:previous_end].strip()
        if line.startswith("///") or line.startswith("//") or not line:
            start = previous_start
            scan = previous_start
        else:
            break

    brace = text.find("{", idx)
    if brace < 0:
        raise SystemExit(f"Opening brace missing for {function_name}")
    depth = 0
    in_string = False
    escape = False
    end = None
    for i in range(brace, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit(f"Closing brace missing for {function_name}")
    while end < len(text) and text[end] in " \t\n":
        end += 1
    return text[:start] + text[end:]


def remove_else_if_block(text: str, needle: str) -> str:
    idx = text.find(needle)
    if idx < 0:
        return text
    # Include the nearby Shortcuts comment.
    start = text.rfind("\n", 0, idx) + 1
    comment_anchor = text.rfind("//", max(0, start - 180), idx)
    if comment_anchor >= 0 and "Raccour" in text[comment_anchor:idx]:
        start = text.rfind("\n", 0, comment_anchor) + 1

    brace = text.find("{", idx)
    if brace < 0:
        raise SystemExit("Shortcut conditional opening brace missing")
    depth = 0
    in_string = False
    escape = False
    end = None
    for i in range(brace, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            continue
        if ch == "{": depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit("Shortcut conditional closing brace missing")
    while end < len(text) and text[end] in " \t\n":
        end += 1
    return text[:start] + text[end:]


# 1. Remove implementation file.
shortcut_file = ROOT / "Services/ShortcutGenerator.swift"
if shortcut_file.exists():
    shortcut_file.unlink()

# 2. Remove all Xcode project references to the deleted source file.
pbx = Path("SarahIA/SarahIA.xcodeproj/project.pbxproj")
pbx_text = pbx.read_text()
pbx_lines = [line for line in pbx_text.splitlines(True) if "ShortcutGenerator.swift" not in line]
pbx.write_text("".join(pbx_lines))

# 3. Remove Shortcut-producing APIs from the code engine.
engine_path = ROOT / "Services/VAICodeEngine.swift"
engine = engine_path.read_text()
engine = engine.replace(
    "/// Capable de générer du code Web (HTML/CSS/JS monopage), Swift, Python,\n/// d'analyser les spécifications de designs (Figma / Google Stitch) et d'exporter des raccourcis Apple (.shortcut / .json).",
    "/// Capable de générer du code Web (HTML/CSS/JS monopage), Swift et Python."
)
engine = engine.replace(' // "html", "swift", "python", "shortcut"', ' // "html", "swift", "python"')
engine = engine.replace('// "html", "swift", "python", "shortcut"', '// "html", "swift", "python"')
engine = remove_swift_function(engine, "generateAppleShortcut")
engine = remove_swift_function(engine, "generateShortcutJSON")
engine_path.write_text(engine)

# 4. Remove routing and responses that expose Apple Shortcuts in Raphaël.
coord_path = ROOT / "Services/MultiAgentCoordinator.swift"
coord = coord_path.read_text()
coord = coord.replace('           normalized.contains("shortcut") || normalized.contains("raccourci") ||\n', '')
coord = coord.replace('normalized.contains("shortcut") || normalized.contains("raccourci") || ', '')
coord = remove_else_if_block(coord, 'else if lower.contains("shortcut") || lower.contains("raccourci")')
coord = coord.replace("Sites web, apps iOS, SwiftUI, scripts, raccourcis Apple et studio de code.", "Sites web, apps iOS, SwiftUI, scripts et studio de code.")
coord = coord.replace("Je peux préparer des maquettes web, des bases SwiftUI pour iPhone, des scripts Python, des raccourcis Apple et des prototypes", "Je peux préparer des sites web, des bases SwiftUI pour iPhone, des scripts Python et des prototypes")
coord_path.write_text(coord)

# 5. Remove user-facing Shortcuts wording elsewhere.
replacements = {
    ROOT / "ViewModels/ChatViewModel.swift": [
        ("Raphaël (Développeur & Raccourcis)", "Raphaël (Développeur & Code)"),
        ("Développeur & Raccourcis", "Développeur & Code"),
    ],
    ROOT / "Views/VAICodingStudioView.swift": [
        ("Aucun générateur de secours, aucun menu Cloud/Figma/Raccourcis n'est présent ici.", "Aucun générateur de secours ni menu annexe n'est présent ici."),
    ],
    ROOT / "Services/StorageService.swift": [
        ("code, exports de raccourcis et images", "code et images"),
    ],
    ROOT / "Views/LegacyChatViewController.swift": [
        ("Raccourcis", "Code"),
        ("raccourcis", "code"),
    ],
}
for path, pairs in replacements.items():
    if not path.exists():
        continue
    value = path.read_text()
    for old, new in pairs:
        value = value.replace(old, new)
    path.write_text(value)

# 6. Remove old generated Shortcuts directory names from persistent cleanup lists.
storage_path = ROOT / "Services/StorageService.swift"
if storage_path.exists():
    storage = storage_path.read_text()
    storage = re.sub(r'^.*(?:Shortcut|Shortcuts|Raccourci|Raccourcis).*\n', '', storage, flags=re.MULTILINE)
    storage_path.write_text(storage)

# 7. Hard fail if live app source still exposes Shortcut functionality.
remaining = []
for path in ROOT.rglob("*.swift"):
    value = path.read_text(errors="ignore")
    for token in ("ShortcutGenerator", "generateAppleShortcut", "generateShortcutJSON"):
        if token in value:
            remaining.append(f"{path}: {token}")
if "ShortcutGenerator.swift" in pbx.read_text():
    remaining.append("project.pbxproj: ShortcutGenerator.swift")

if remaining:
    raise SystemExit("Shortcuts removal incomplete:\n" + "\n".join(remaining))

print("All iOS Shortcuts generation code removed")
