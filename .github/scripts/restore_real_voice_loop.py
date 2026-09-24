from pathlib import Path
import re
import subprocess

OLD = '55e03d44856e351c0803e8d6ff840711ce5ad596'
ROOT = Path('.')


def old_file(path: str) -> str:
    return subprocess.check_output(['git', 'show', f'{OLD}:{path}'], text=True)

# 1) Restore the proven voice UI and Apple multi-agent TTS implementation verbatim.
for path in [
    'SarahIA/SarahIA/Views/VoiceOrbModalView.swift',
    'SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift',
]:
    Path(path).write_text(old_file(path), encoding='utf-8')

# 2) Restore the proven voice conversation loop inside the current ChatViewModel,
# while preserving all current non-voice features.
vm_path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
vm = vm_path.read_text(encoding='utf-8')
old_vm = old_file('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')

block_re = re.compile(
    r'    // MARK: - Pipeline Vocale Apple Speech & Multi-Agents\n.*?(?=    // MARK: - Envoi de Message & Orchestration Multi-Agents)',
    re.S,
)
old_match = block_re.search(old_vm)
if not old_match:
    raise SystemExit('Old voice block not found')
voice_block = old_match.group(0)

# Current app prepares Speech lazily to avoid touching AVAudioEngine at cold launch.
# Keep that safety, but guarantee the old loop is wired before the first mic start.
voice_block = voice_block.replace(
    '    public func toggleMicrophone() {\n        haptics.buttonTap()',
    '    public func toggleMicrophone() {\n        ensureVoicePipelinePrepared()\n        haptics.buttonTap()',
)
voice_block = voice_block.replace(
    '    public func startVoiceConversation() {\n        voiceManager.stop()',
    '    public func startVoiceConversation() {\n        ensureVoicePipelinePrepared()\n        voiceManager.stop()',
)
voice_block = voice_block.replace(
    '    public func speakMessage(_ text: String) {\n        haptics.buttonTap()',
    '    public func speakMessage(_ text: String) {\n        ensureVoicePipelinePrepared()\n        haptics.buttonTap()',
)
voice_block = voice_block.replace(
    '    public func toggleSpeechForMessage(_ text: String) {\n        haptics.buttonTap()',
    '    public func toggleSpeechForMessage(_ text: String) {\n        ensureVoicePipelinePrepared()\n        haptics.buttonTap()',
)

vm, count = block_re.subn(voice_block, vm, count=1)
if count != 1:
    raise SystemExit(f'Current voice block replacement failed: {count}')

# The modern composer still has a square Stop button. The old voice snapshot did
# not have this helper, so preserve a lightweight cancellation action explicitly.
if 'public func cancelCurrentGeneration()' not in vm:
    marker = '    // MARK: - Envoi de Message & Orchestration Multi-Agents\n'
    cancel_method = '''    public func cancelCurrentGeneration() {\n        haptics.buttonTap()\n        isTyping = false\n        voiceStatus = .idle\n        AIProgressiveScheduler.shared.cancelAllTasks()\n    }\n\n'''
    if marker not in vm:
        raise SystemExit('Message orchestration marker missing')
    vm = vm.replace(marker, cancel_method + marker, 1)

vm_path.write_text(vm, encoding='utf-8')

# 3) Keep the modern + menu / attachments, but make the voice presentation behave
# exactly like the older working version: opening the sheet starts listening,
# closing it stops cleanly, and the compact detent is available.
chat_path = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
chat = chat_path.read_text(encoding='utf-8')

# No persistent mini voice session outside the sheet.
chat = re.sub(
    r'\n\s*if viewModel\.isContinuousConversationActive && !viewModel\.isShowingVoiceOrbModal \{.*?\n\s*\}\n\n\s*MessageBar\(',
    '\n                MessageBar(',
    chat,
    count=1,
    flags=re.S,
)

# The older sheet owns start/stop itself.
chat = chat.replace(
    '                    onOpenVoiceOrb: {\n                        keyboard.dismiss()\n                        viewModel.startVoiceConversation()\n                        viewModel.isShowingVoiceOrbModal = true\n                    },',
    '                    onOpenVoiceOrb: {\n                        keyboard.dismiss()\n                        viewModel.isShowingVoiceOrbModal = true\n                    },',
)

# Restore old VoiceOrb initializer signature while keeping attachments in MessageBar.
chat = re.sub(
    r'                onOpenSettings: \{\n                    isShowingSettings = true\n                \},\n                onOpenPhotoLibrary: \{.*?\n                onOpenFile: \{\n                    isShowingFileImporter = true\n                \}\n',
    '                onOpenSettings: {\n                    isShowingSettings = true\n                }\n',
    chat,
    flags=re.S,
)
chat = chat.replace('.presentationDetents([.large])', '.presentationDetents([.height(255), .large])')

# Remove the no-longer-used persistent-session mini bar type.
chat = re.sub(
    r'\n@available\(iOS 15\.0, \*\)\nprivate struct CollapsedVoiceSessionBar: View \{.*?\n\}\n\n(?=/// Brief conservé)',
    '\n',
    chat,
    flags=re.S,
)

# Hard guard: this restoration must not bring 3D back.
for token in ['SceneKit', 'RealityKit', 'Model3D', 'Sarah3DEnvironmentStudioView', 'cube.transparent']:
    if token in chat:
        raise SystemExit(f'Forbidden 3D token in ChatScreen: {token}')

chat_path.write_text(chat, encoding='utf-8')

print('Restored proven Sept 18 voice loop, voice UI and TTS while preserving current chat/media features.')
