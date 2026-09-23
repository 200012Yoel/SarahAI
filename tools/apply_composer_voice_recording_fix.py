from pathlib import Path

path = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
text = path.read_text(encoding="utf-8")
old = ".padding(.bottom, keyboard.isVisible ? 6 : 24)"
new = ".padding(.bottom, keyboard.isVisible ? 8 : 38)"
if new in text:
    print("Composer already raised.")
elif old in text:
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("Raised composer by 14pt at rest and 2pt above keyboard.")
else:
    raise SystemExit("Expected composer bottom padding not found")
