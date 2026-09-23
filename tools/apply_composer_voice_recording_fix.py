from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CHAT = ROOT / "SarahIA/SarahIA/Views/ChatScreenView.swift"
VM = ROOT / "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# 1) Raphaël: keep the local handoff/guided flow ahead of the heavy AI service.
vm = VM.read_text(encoding="utf-8")
old_send = '''    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        aiService.syncHistoryFromMessages(messages)
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""

        if handleDeveloperSkillAnswer(text) {
            isTyping = false
            voiceStatus = isContinuousConversationActive ? voiceStatus : .idle
            return
        }

        if looksLikeDeveloperHandoff(text) {
            beginDeveloperSkill()
            isTyping = false
            return
        }

        // Une demande de suivi peut arriver après un changement d'agent,
'''
new_send = '''    public func sendMessage(_ explicitText: String? = nil) {
        let text = (explicitText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Le handoff Raphaël et son questionnaire sont entièrement locaux.
        // Ils doivent répondre immédiatement, sans réveiller AIService avant même
        // que le premier message ait pu être affiché (ce qui gelait le smoke test
        // et pouvait donner l'impression que le changement d'agent ne marchait pas).
        if developerSkillSession != nil || looksLikeDeveloperHandoff(text) {
            let userMessage = Message(content: text, isFromUser: true)
            appendMessage(userMessage)
            inputText = ""

            if handleDeveloperSkillAnswer(text) {
                isTyping = false
                voiceStatus = isContinuousConversationActive ? voiceStatus : .idle
                return
            }

            if looksLikeDeveloperHandoff(text) {
                beginDeveloperSkill()
                isTyping = false
                return
            }
        }

        aiService.syncHistoryFromMessages(messages)
        let userMessage = Message(content: text, isFromUser: true)
        appendMessage(userMessage)
        inputText = ""

        // Une demande de suivi peut arriver après un changement d'agent,
'''
vm = replace_once(vm, old_send, new_send, "Raphael local routing")
VM.write_text(vm, encoding="utf-8")


# 2) Chat UI smoke tests + real 3D prompt routing.
chat = CHAT.read_text(encoding="utf-8")
old_voice_smoke = '''            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    viewModel.isShowingVoiceOrbModal = true
                }
            }
'''
new_voice_smoke = '''            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    // Le smoke visuel ne doit jamais rester bloqué derrière une alerte
                    // système de permission. Le vrai mode vocal garde son démarrage
                    // normal partout ailleurs.
                    viewModel.isContinuousConversationActive = true
                    viewModel.isVoiceMicrophoneMuted = true
                    viewModel.isMicRunning = false
                    viewModel.voiceStatus = .idle
                    viewModel.isShowingVoiceOrbModal = true
                }
            }
'''
chat = replace_once(chat, old_voice_smoke, new_voice_smoke, "Voice smoke preview")

old_dev_timing = '''                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(index) * 0.45) {
                        viewModel.sendMessage(answer)
                    }
'''
new_dev_timing = '''                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(index) * 0.62) {
                        viewModel.sendMessage(answer)
                    }
'''
chat = replace_once(chat, old_dev_timing, new_dev_timing, "Developer smoke pacing")

old_states = '''    @State private var extraBoxes = 0
    @State private var extraSpheres = 0
    @State private var sceneSeed = 0

    var body: some View {
'''
new_states = '''    @State private var extraBoxes = 0
    @State private var extraSpheres = 0
    @State private var sceneSeed = 0

    /// Interprétation locale légère du prompt. Pas de réseau et pas d'attente :
    /// les mots clés choisissent l'environnement puis SceneKit le régénère.
    private func generateFromPrompt() {
        HapticService.shared.buttonTap()

        let normalized = prompt
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()

        let spaceWords = ["espace", "spatial", "planete", "galaxie", "etoile", "lune", "mars", "orbite"]
        let natureWords = ["nature", "foret", "arbre", "parc", "montagne", "jardin", "vegetation"]
        let showroomWords = ["showroom", "galerie", "exposition", "produit", "boutique", "studio", "musee"]
        let cityWords = ["ville", "city", "urbain", "immeuble", "rue", "avenue", "gratte ciel", "metropole"]

        if spaceWords.contains(where: normalized.contains) {
            preset = .space
        } else if natureWords.contains(where: normalized.contains) {
            preset = .nature
        } else if showroomWords.contains(where: normalized.contains) {
            preset = .showroom
        } else if cityWords.contains(where: normalized.contains) {
            preset = .city
        }

        if normalized.contains("cube") {
            extraBoxes = max(extraBoxes, 4)
        }
        if normalized.contains("sphere") || normalized.contains("boule") {
            extraSpheres = max(extraSpheres, 4)
        }

        sceneSeed += 1
    }

    var body: some View {
'''
chat = replace_once(chat, old_states, new_states, "3D prompt interpreter")

# Restrict button rewrites to the 3D studio section only.
marker = "// MARK: - Sarah 3D Environment Studio"
prefix, studio = chat.split(marker, 1)
old_generate_action = '''                    Button {
                        HapticService.shared.buttonTap()
                        sceneSeed += 1
                    } label: {
                        Label("Générer", systemImage: "sparkles")
'''
new_generate_action = '''                    Button {
                        generateFromPrompt()
                    } label: {
                        Label("Générer", systemImage: "sparkles")
'''
studio = replace_once(studio, old_generate_action, new_generate_action, "3D top generate button")

old_prompt_action = '''                        Button {
                            HapticService.shared.buttonTap()
                            sceneSeed += 1
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
'''
new_prompt_action = '''                        Button {
                            generateFromPrompt()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
'''
studio = replace_once(studio, old_prompt_action, new_prompt_action, "3D prompt send button")
chat = prefix + marker + studio
CHAT.write_text(chat, encoding="utf-8")


# The existing Apply Composer Voice Recording Fix workflow invokes this helper.
# Commit both audited production files here so the workflow's legacy git-add line
# cannot accidentally leave ChatViewModel.swift behind.
if os.environ.get("GITHUB_ACTIONS") == "true":
    subprocess.run(["git", "config", "user.name", "SarahIA Build Bot"], cwd=ROOT, check=True)
    subprocess.run(["git", "config", "user.email", "actions@github.com"], cwd=ROOT, check=True)
    subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
    subprocess.run(["git", "add", str(CHAT.relative_to(ROOT)), str(VM.relative_to(ROOT))], cwd=ROOT, check=True)
    quiet = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT)
    if quiet.returncode != 0:
        subprocess.run([
            "git", "commit", "-m",
            "Fix Raphael handoff and audit voice 3D UI"
        ], cwd=ROOT, check=True)
        subprocess.run([
            "git", "push", "origin",
            "HEAD:feature/chatgpt-ui-media-shortcuts-20260922"
        ], cwd=ROOT, check=True)

print("Applied SarahIA final UI audit fixes")
