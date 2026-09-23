from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAT = ROOT / "SarahIA/SarahIA/Views/ChatScreenView.swift"

text = CHAT.read_text(encoding="utf-8")
old = "camera.eulerAngles.x = -.35"
new = "camera.eulerAngles.x = -0.35"

if new in text:
    print("3D camera literal already fixed.")
elif old in text:
    text = text.replace(old, new, 1)
    CHAT.write_text(text, encoding="utf-8")
    print("Fixed 3D camera literal for Swift 5 parser.")
else:
    raise SystemExit("Expected 3D camera literal not found")
