from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAT = ROOT / "SarahIA/SarahIA/Views/ChatScreenView.swift"

chat = CHAT.read_text(encoding="utf-8")
old = ".padding(.bottom, keyboard.isVisible ? 4 : 12)"
new = ".padding(.bottom, keyboard.isVisible ? 6 : 24)"

if new in chat:
    print("Composer spacing already upgraded.")
elif old in chat:
    chat = chat.replace(old, new, 1)
    CHAT.write_text(chat, encoding="utf-8")
    print("Raised composer to 24 pt at rest / 6 pt with keyboard.")
else:
    raise SystemExit("Expected composer spacing not found")
