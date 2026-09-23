from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VM = ROOT / "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


vm = VM.read_text(encoding="utf-8")

# The smoke voice flag used to present the sheet directly from ChatViewModel.init().
# That happened before ChatScreenView could prepare a muted visual-test session, so
# VoiceOrbModalView immediately started Apple Speech and the system permission alert
# covered the UI. Let ChatScreenView own the delayed smoke presentation instead.
old_voice_init = '''
        if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {
            isShowingVoiceOrbModal = true
        }
'''
vm = replace_once(vm, old_voice_init, "\n", "early voice smoke presentation")

# New conversations must be cheap to create. Calling the lazy AI service only to
# invent a title can stall the first visible message, including the local Raphaël
# handoff. Build a deterministic local title here; the actual assistant stays lazy.
old_title = '''        if currentConversationId == nil || !conversations.contains(where: { $0.id == currentConversationId }) {
            let title = aiService.generateSmartTitle(from: text)
            let newConv = Conversation(title: title)
            conversations.insert(newConv, at: 0)
            currentConversationId = newConv.id
        }
'''
new_title = '''        if currentConversationId == nil || !conversations.contains(where: { $0.id == currentConversationId }) {
            let compact = text
                .replacingOccurrences(of: "\\n", with: " ")
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = "Nouvelle discussion"
            let title = compact.isEmpty ? fallback : String(compact.prefix(44))
            let newConv = Conversation(title: title)
            conversations.insert(newConv, at: 0)
            currentConversationId = newConv.id
        }
'''
vm = replace_once(vm, old_title, new_title, "local conversation title")

VM.write_text(vm, encoding="utf-8")

if os.environ.get("GITHUB_ACTIONS") == "true":
    subprocess.run(["git", "config", "user.name", "SarahIA Build Bot"], cwd=ROOT, check=True)
    subprocess.run(["git", "config", "user.email", "actions@github.com"], cwd=ROOT, check=True)
    subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
    subprocess.run(["git", "add", str(VM.relative_to(ROOT))], cwd=ROOT, check=True)
    quiet = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT)
    if quiet.returncode != 0:
        subprocess.run([
            "git", "commit", "-m",
            "Remove first-message stall and fix voice smoke launch"
        ], cwd=ROOT, check=True)
        subprocess.run([
            "git", "push", "origin",
            "HEAD:feature/chatgpt-ui-media-shortcuts-20260922"
        ], cwd=ROOT, check=True)

print("Applied final visual-audit startup fixes")
