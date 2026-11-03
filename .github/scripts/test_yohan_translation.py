#!/usr/bin/env python3
"""Regression checks for the command and translation fixes visible in Yohan chat."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
services = ROOT / "SarahIA" / "SarahIA" / "Services"
coordinator = (services / "SarahActionCoordinator.swift").read_text()
start = coordinator.index("public enum LiveTranslationCommand {")
end = coordinator.index("// ============================================================================", start)
swift_enum = coordinator[start:end]

assert shutil.which("swift"), "Swift is required to execute the production command parser"
test_cases = {
    "Translate. Live.": True,
    "TRANSLATE LIVE": True,
    "Live Translate!": True,
    "Active la traduction en direct.": True,
    "Traduction en temps réel": True,
    "Traduis la télé": True,
    "トンスライトルライト": True,
    "トランスレートライブ": True,
    "Traduis bonjour en hébreu": False,
    "Bonjour": False,
    "Comment dit-on merci en hébreu ?": False,
    "": False,
    "これは日本語です": False,
}
assert len(test_cases) == 13
with tempfile.TemporaryDirectory() as tmp:
    swift_file = Path(tmp) / "live_regression.swift"
    body = "import Foundation\n" + swift_enum + "\n"
    # Build safe Swift strings through JSON escaping.
    import json
    for phrase, expected in test_cases.items():
        body += f"precondition(LiveTranslationCommand.isActivationRequest({json.dumps(phrase, ensure_ascii=False)}) == {str(expected).lower()})\n"
    body += 'print("13/13 cas de commande validés")\n'
    swift_file.write_text(body)
    subprocess.run(["swift", str(swift_file)], check=True)

vm = (ROOT / "SarahIA" / "SarahIA" / "ViewModels" / "ChatViewModel.swift").read_text()
assert vm.index("LiveTranslationCommand.isActivationRequest(text)") < vm.index("multiAgentCoordinator.routeAndProcess(query: text")
assert 'LiveLanguagePair(sourceLanguage: "he", targetLanguage: "fr", isVoiceEnabled: true)' in vm

lexicon = (services / "YohanLexiconEngine.swift").read_text()
assert "translateExact(text:" in lexicon
assert "indexation locale" not in lexicon
assert "norm.contains(key)" not in lexicon

translation = (services / "TranslationEngine.swift").read_text()
assert 'let dictKey = "\\(source)|\\(target)|\\(lower)"' in translation
assert '"fr|he|bonjour": "שלום"' in translation
assert '"he|fr|שלום": "Bonjour"' in translation
assert '"fr|en|bonjour": "Hello"' in translation

yohan = (services / "MultiAgentCoordinator.swift").read_text()
assert "translation.translateDetailed(" in yohan
assert "translation.prepareOfflinePacks(for:" in yohan
assert "YohanLexiconEngine.shared.translateExact(" in yohan
print("Routage, traduction et dictionnaire : contrôles OK")
