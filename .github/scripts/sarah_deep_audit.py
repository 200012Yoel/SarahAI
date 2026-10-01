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
sidebar = read("SarahIA/SarahIA/Views/SidebarView.swift")
content = read("SarahIA/SarahIA/ContentView.swift")
styles = read("SarahIA/SarahIA/Views/CommonStyles.swift")
storage = read("SarahIA/SarahIA/Services/StorageService.swift")
view_model = read("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
whisper = read("SarahIA/SarahIA/Services/WhisperService.swift")
voice_orb = read("SarahIA/SarahIA/Views/VoiceOrbModalView.swift")

# Composer: first-tap regression guard. The chat composer intentionally uses a
# real UIKit UITextField so the complete visible capsule is an actual native
# responder instead of padding around a smaller SwiftUI control.
require("@FocusState" not in bar, "Composer sans FocusState intermédiaire")
require("UIViewRepresentable" in bar and "UITextFieldDelegate" in bar, "Composer basé sur UITextField UIKit natif")
require("ReliableComposerTextField" in bar, "Champ natif fiable utilisé dans le composer")
require('accessibilityIdentifier: "sarah.composer.field"' in bar, "Identifiant du champ composer présent")
require("minHeight: 52" in bar and "contentShape" in bar, "Zone tactile du composer agrandie")
require("isUserInteractionEnabled = true" in bar, "Interaction UIKit explicitement active")
require("isEnabled: true" in bar, "Composer reste éditable pendant une génération")
require("dismissKeyboard()" in bar, "Fermeture clavier du composer centralisée")
require('.accessibilityIdentifier("sarah.composer.action")' in bar, "Bouton vocal/envoi identifiable")
require(".frame(width: 50, height: 50)" in bar, "Boutons principaux avec cible tactile 50 pt")
require("Color.black.opacity(0.001)" in bar, "Le dock empêche les touches de traverser vers la liste")

# Sidebar search: same first-tap protection as the composer.
require('TextField("Rechercher"' in sidebar, "TextField natif de recherche présent")
require('.accessibilityIdentifier("sarah.sidebar.search.field")' in sidebar, "Identifiant du champ de recherche présent")
require("maxWidth: .infinity, minHeight: 48" in sidebar, "Zone tactile de recherche agrandie à 48 pt")
require(".contentShape(Rectangle())" in sidebar, "Surface tactile de recherche explicite")
search_background = re.search(
    r'private func searchField\(horizontal: CGFloat\).*?// MARK: - Active conversations',
    sidebar,
    re.S,
)
if search_background:
    require(
        ".allowsHitTesting(false)" in search_background.group(0),
        "Fond décoratif de la recherche non interactif",
    )
else:
    errors.append("Impossible d'analyser SidebarView.searchField")

# Voice mode: the UI must appear before the heavy Whisper model loads.
require("isModelLoading" in whisper, "État de chargement Whisper asynchrone présent")
require("inferenceQueue.async" in whisper, "Chargement/inférence Whisper hors main thread")
require("prepareModelInBackgroundIfNeeded" in whisper, "Préparation Whisper non bloquante utilisée")
require("wantsRecordingAfterModelLoad" in whisper, "Demande micro conservée pendant le chargement du modèle")
require("viewModel.startVoiceConversation()" in voice_orb, "Écran vocal démarre réellement la conversation")
require("onOpenVoiceOrb()" in bar, "Bouton waveform relié à l'ouverture du mode vocal")

start_recording = re.search(
    r"public func startRecording\(autoFinalizeOnSilence: Bool = true\) \{(.*?)\n    \}",
    whisper,
    re.S,
)
if start_recording:
    body = start_recording.group(1)
    require("ensureModelLoaded()" not in body, "startRecording ne charge jamais Whisper synchronement")
    require("prepareModelInBackgroundIfNeeded()" in body, "startRecording délègue le modèle en arrière-plan")
else:
    errors.append("Impossible d'analyser WhisperService.startRecording")

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

require("loadStateAsync" in storage, "Chargement d'historique asynchrone disponible")
require("saveChatState" in storage, "Fusion/sauvegarde du chat exécutée sur la file stockage")
require("restorePersistedStateInBackground()" in view_model, "ChatViewModel restaure l'historique hors du démarrage UI")
require("storageService.saveChatState(" in view_model, "ChatViewModel ne relit pas le JSON à chaque message")

persist_match = re.search(r"public func persistCurrentState\(\) \{(.*?)\n    \}", view_model, re.S)
if persist_match:
    persist_body = persist_match.group(1)
    require("storageService.loadState()" not in persist_body, "persistCurrentState ne fait aucune lecture disque synchrone")
else:
    errors.append("Impossible d'analyser ChatViewModel.persistCurrentState")

init_match = re.search(r"public init\(\) \{(.*?)\n    \}", view_model, re.S)
if init_match:
    init_body = init_match.group(1)
    require("restorePersistedState()" not in init_body, "Initialisation du ViewModel sans décodage JSON synchrone")
    require("restorePersistedStateInBackground()" in init_body, "Initialisation du ViewModel lance une restauration asynchrone")
else:
    errors.append("Impossible d'analyser ChatViewModel.init")

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

    # The preceding xcodebuild workflow step is already authoritative because it
    # runs with pipefail. This second audit therefore validates the actual Xcode
    # result marker instead of treating unrelated text containing `error:` as a
    # failed compilation.
    build_succeeded = "** BUILD SUCCEEDED **" in log
    build_failed = "** BUILD FAILED **" in log
    require(build_succeeded and not build_failed, "Xcode: build terminé avec succès")

    source_error = re.compile(
        r"\.(?:swift|m|mm|c|cc|cpp|cxx|h|hpp):\d+:\d+:\s+(?:fatal\s+)?error:\s",
        re.IGNORECASE,
    )
    tool_error = re.compile(
        r"^(?:clang|swiftc|swift-frontend|ld|libtool):\s+(?:fatal\s+)?error:\s",
        re.IGNORECASE,
    )
    suspicious_errors = [
        line
        for line in log.splitlines()
        if source_error.search(line)
        or tool_error.search(line.strip())
        or "error: linker command failed" in line.lower()
    ]
    if suspicious_errors and build_succeeded and not build_failed:
        warnings.append(
            f"Xcode: {len(suspicious_errors)} ligne(s) ressemblant à une erreur dans un build déclaré réussi"
        )

    compiler_warnings = [
        line
        for line in log.splitlines()
        if re.search(
            r"\.(?:swift|m|mm|c|cc|cpp|cxx|h|hpp):\d+:\d+:\s+warning:\s",
            line,
            re.IGNORECASE,
        )
    ]
    if compiler_warnings:
        warnings.append(f"Xcode: {len(compiler_warnings)} avertissement(s) compilateur détecté(s)")
    else:
        passes.append("Xcode: aucun warning compilateur détecté dans le log")

print("\n=== SARAH DEEP AUDIT ===")
for item in passes:
    print(f"PASS  {item}")
for item in warnings:
    print(f"WARN  {item}")
for item in errors:
    print(f"ERROR {item}")
print(f"\nRésumé: {len(passes)} pass, {len(warnings)} warning(s), {len(errors)} erreur(s)")

sys.exit(1 if errors else 0)
