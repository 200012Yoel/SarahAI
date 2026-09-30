#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "SarahIA" / "SarahIA"

errors: list[str] = []
warnings: list[str] = []
passes: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.exists():
        errors.append(f"Fichier manquant: {rel}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(condition: bool, message: str) -> None:
    (passes if condition else errors).append(message)


def warn_if(condition: bool, message: str) -> None:
    if condition:
        warnings.append(message)


bar = read("SarahIA/SarahIA/Views/MessageBar.swift")
chat = read("SarahIA/SarahIA/Views/ChatScreenView.swift")
message_list = read("SarahIA/SarahIA/Views/MessageList.swift")
content = read("SarahIA/SarahIA/ContentView.swift")
styles = read("SarahIA/SarahIA/Views/CommonStyles.swift")
storage = read("SarahIA/SarahIA/Services/StorageService.swift")
view_model = read("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")

# Composer: first-tap regression guard.
require("@FocusState" not in bar, "Composer sans FocusState intermédiaire")
require('.accessibilityIdentifier("sarah.composer.field")' in bar, "Identifiant du champ présent")
require("minHeight: 48" in bar and "contentShape(Rectangle())" in bar, "Zone tactile du champ agrandie")
require("TextField(" in bar, "TextField natif présent")
require("dismissKeyboard()" in bar, "Fermeture clavier centralisée")

# Global hit-testing / gesture traps that previously made the whole UI feel dead.
require('.onTapGesture { keyboard.dismiss() }' not in chat, "Pas de tap plein écran qui vole le premier toucher")
require(".simultaneousGesture(" not in message_list, "Pas de geste concurrent dans MessageList")
require("@FocusState" not in message_list, "MessageList sans gestion de focus parasite")
require(".allowsHitTesting(false)" in styles, "Couches Liquid Glass décoratives non interactives")
require("SarahStartupAnimationView" in content and ".allowsHitTesting(false)" in content, "Animation Sarah non bloquante")

# Storage/main-thread freeze guards.
save_match = re.search(r"public func saveState\(_ state: AppPersistedState\) \{(.*?)\n    \}", storage, re.S)
if save_match:
    save_body = save_match.group(1)
    require("ioQueue.async" in save_body, "Sauvegarde JSON hors du thread appelant")
    require("ioQueue.sync" not in save_body, "Aucune sauvegarde JSON synchrone")
else:
    errors.append("Impossible d'analyser StorageService.saveState")

all_swift = []
for path in APP.rglob("*.swift"):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        errors.append(f"Lecture impossible {path.relative_to(ROOT)}: {exc}")
        continue
    all_swift.append((path, text))
    rel = path.relative_to(ROOT)

    if "DispatchQueue.main.sync" in text:
        errors.append(f"{rel}: DispatchQueue.main.sync peut provoquer un deadlock")

    if re.search(r"\.allowsHitTesting\(false\).*?(TextField|Button|Menu)\(", text, re.S):
        warnings.append(f"{rel}: vérifier une zone allowsHitTesting(false) proche d'un contrôle interactif")

    todo_count = len(re.findall(r"\b(?:TODO|FIXME)\b", text))
    if todo_count:
        warnings.append(f"{rel}: {todo_count} TODO/FIXME")

    if "fatalError(" in text:
        warnings.append(f"{rel}: fatalError présent")

# Specific production leftovers.
warn_if("[DEBUG]" in view_model, "ChatViewModel contient encore un texte [DEBUG] utilisateur")
warn_if("SFSpeechRecognizer" in read("SarahIA/SarahIA/Services/AppleSpeechRecognizer.swift"), "AppleSpeechRecognizer référence encore SFSpeechRecognizer")

# Detect suspicious giant transparent gesture catchers. A narrow edge catcher is allowed.
for path, text in all_swift:
    rel = path.relative_to(ROOT)
    for match in re.finditer(r"Color\.clear(?P<body>.{0,450}?)\.gesture\(", text, re.S):
        body = match.group("body")
        if ".frame(width: 18)" not in body and ".frame(width: 20)" not in body:
            warnings.append(f"{rel}: Color.clear + gesture à vérifier, potentielle couche tactile invisible")

parser = argparse.ArgumentParser()
parser.add_argument("--xcode-log", type=Path)
args = parser.parse_args()

if args.xcode_log and args.xcode_log.exists():
    log = args.xcode_log.read_text(encoding="utf-8", errors="replace")
    compiler_errors = [line for line in log.splitlines() if re.search(r"\berror:\s", line)]
    compiler_warnings = [line for line in log.splitlines() if re.search(r"\bwarning:\s", line)]
    if compiler_errors:
        errors.append(f"Xcode: {len(compiler_errors)} ligne(s) error: détectée(s)")
    if compiler_warnings:
        warnings.append(f"Xcode: {len(compiler_warnings)} avertissement(s) compilateur détecté(s)")
    else:
        passes.append("Xcode: aucun warning: détecté dans le log")

print("\n=== SARAH DEEP AUDIT ===")
for item in passes:
    print(f"PASS  {item}")
for item in warnings:
    print(f"WARN  {item}")
for item in errors:
    print(f"ERROR {item}")
print(f"\nRésumé: {len(passes)} pass, {len(warnings)} warning(s), {len(errors)} erreur(s)")

sys.exit(1 if errors else 0)
