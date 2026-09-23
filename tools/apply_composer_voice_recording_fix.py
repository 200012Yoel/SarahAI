from pathlib import Path

path = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
text = path.read_text(encoding="utf-8")
old = "            let height = CGFloat(1.4 + ((index * 7 + seed) % 8)) * 0.46\n"
new = "            let heightStep = (index * 7 + seed) % 8\n            let height = CGFloat(heightStep) * CGFloat(0.46) + CGFloat(1.4)\n"
if new in text:
    print("3D height calculation already simplified.")
elif old in text:
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("Simplified 3D height calculation for Swift compiler.")
else:
    raise SystemExit("Expected 3D height calculation not found")
