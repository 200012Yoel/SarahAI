from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAT = ROOT / "SarahIA/SarahIA/Views/ChatScreenView.swift"
WORKFLOW = ROOT / ".github/workflows/ios-build.yml"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing expected block: {label}")
    return text.replace(old, new, 1)


chat = CHAT.read_text(encoding="utf-8")

chat = replace_once(
    chat,
    '''                    onOpenVoiceOrb: {\n                        keyboard.dismiss()\n                        viewModel.isShowingVoiceOrbModal = true\n                    },''',
    '''                    onOpenVoiceOrb: {\n                        keyboard.dismiss()\n                        viewModel.startVoiceConversation()\n                        viewModel.isShowingVoiceOrbModal = true\n                    },''',
    "voice button starts session",
)

chat = replace_once(
    chat,
    '''                    .default(Text("🔮 Ouvrir l'Orbe Vocal Immersif")) {\n                        viewModel.isShowingVoiceOrbModal = true\n                    },''',
    '''                    .default(Text("🔮 Ouvrir l'Orbe Vocal Immersif")) {\n                        viewModel.startVoiceConversation()\n                        viewModel.isShowingVoiceOrbModal = true\n                    },''',
    "voice action starts session",
)

chat = replace_once(
    chat,
    '''                )\n            }\n            .background(\n                LinearGradient(''',
    '''                )\n            }\n            // Sur les iPhone avec Home Indicator, le composer était visuellement\n            // trop proche du bord inférieur. On le remonte légèrement au repos,\n            // tout en gardant un écart minimal quand le clavier est affiché pour\n            // éviter le double décalage clavier corrigé précédemment.\n            .padding(.bottom, keyboard.isVisible ? 4 : 12)\n            .background(\n                LinearGradient(''',
    "composer bottom lift",
)

CHAT.write_text(chat, encoding="utf-8")

workflow = WORKFLOW.read_text(encoding="utf-8")

workflow = replace_once(
    workflow,
    '''          mkdir -p "$GITHUB_WORKSPACE/ui-smoke"\n          xcrun simctl install "$SIM_UDID" "$SIM_APP"\n\n          check_alive() {''',
    '''          mkdir -p "$GITHUB_WORKSPACE/ui-smoke"\n          xcrun simctl install "$SIM_UDID" "$SIM_APP"\n\n          # Enregistre tout le parcours de validation afin que l'interface soit\n          # vérifiable visuellement après chaque build, pas seulement par captures.\n          RECORDING_PATH="$GITHUB_WORKSPACE/ui-smoke/simulator-session.mp4"\n          rm -f "$RECORDING_PATH"\n          xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 "$RECORDING_PATH" > /tmp/sarah-simulator-video.log 2>&1 &\n          RECORD_PID=$!\n\n          stop_recording() {\n            if [ -n "${RECORD_PID:-}" ] && kill -0 "$RECORD_PID" >/dev/null 2>&1; then\n              kill -INT "$RECORD_PID" >/dev/null 2>&1 || true\n              wait "$RECORD_PID" || true\n            fi\n          }\n          trap stop_recording EXIT\n\n          check_alive() {''',
    "start simulator recording",
)

workflow = replace_once(
    workflow,
    '''          terminate_app\n\n          xcrun simctl shutdown "$SIM_UDID" || true\n\n      - name: Upload simulator screenshots''',
    '''          terminate_app\n\n          stop_recording\n          trap - EXIT\n          test -s "$RECORDING_PATH"\n          xcrun simctl shutdown "$SIM_UDID" || true\n\n      - name: Upload simulator screenshots''',
    "stop simulator recording",
)

workflow = replace_once(
    workflow,
    '''          if-no-files-found: error\n\n      - name: Package IPA''',
    '''          if-no-files-found: error\n\n      - name: Upload simulator recording\n        uses: actions/upload-artifact@v4\n        with:\n          name: SarahIA-Simulator-Recording\n          path: ui-smoke/simulator-session.mp4\n          retention-days: 7\n          if-no-files-found: error\n\n      - name: Package IPA''',
    "upload simulator recording",
)

WORKFLOW.write_text(workflow, encoding="utf-8")
print("Applied composer lift, voice restore, and simulator video recording.")
