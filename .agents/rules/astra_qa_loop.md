# SarahIA — Astra autonomous QA loop

## Goal
Astra must iterate on SarahIA until the tested flows have no reproducible blocking UI bug. Do not merely report bugs: diagnose, patch, rebuild, rerun the affected test, then rerun the regression suite.

## Priority fixes
1. Voice mode: tapping the microphone/voice control must reliably enter the voice UI, request permissions when needed, start audio capture/transcription, visibly reflect listening state, and allow stopping without leaving the UI stuck.
2. Plus menu: drastically reduce information density. Show only the primary actions initially; secondary/advanced actions belong behind a compact secondary destination. Avoid long explanatory copy in the menu.
3. Dictation: the inline microphone must show real microphone variation, keep listening until the user stops it, put the transcript back into the composer when stopped, and send only when the send control is pressed.
4. Code editor: redesign for a clean professional editor experience: readable monospace editing area, restrained toolbar, clear run/preview actions, useful file/language context, keyboard-safe layout, and no visually noisy panels.

## Simulator protocol
- Boot one iOS Simulator and launch SarahIA once at the beginning of a test pass. Do not repeatedly relaunch the app between every interaction.
- Keep the same application process alive while traversing the test flows unless a crash or a fix genuinely requires relaunching.
- Start screen recording before the interaction pass when supported by the runner.
- Before each important interaction, record the current state and target control.
- Tap the control once.
- Capture an immediate screenshot after the tap.
- Wait up to 30 seconds for the expected visible state change, checking periodically rather than blindly sleeping when possible.
- Capture another screenshot at the 30-second deadline, or earlier when the expected state is reached.
- If the expected state never appears, treat it as a reproducible bug. Save screenshots/logs, diagnose the responsible code, patch it, rebuild, and rerun that exact interaction.
- A visual change alone is not sufficient when the feature has functional behavior. For voice and dictation, verify the recording/transcription state. For editor actions, verify editor/preview state.
- Collect crash logs, console errors, permission errors, hangs, layout clipping, keyboard obstruction, dead taps, navigation failures, and obvious state inconsistencies.
- Never claim a bug is fixed solely because compilation succeeds.

## Regression pass
Test at minimum: cold launch, main chat, keyboard/input, inline dictation start/stop/send, plus menu, voice start/stop, navigation/sidebar, settings/about if present, code editor entry/edit/run-or-preview flow, responsive web preview, back navigation, and return to chat. After every patch, rerun the affected flow. After the final patch, rerun the whole suite.

## Evidence
Store screenshots, recording, simulator logs, and a concise machine-readable/text QA report as CI artifacts. Each finding should include: flow, action, expected result, observed result, evidence filename, fix/commit, and retest result.

## Guardrails
Preserve already-working features. Prefer targeted fixes over broad rewrites. Do not remove functionality just to make a test pass. Do not generate/release an IPA until the regression pass is complete and remaining known issues are explicitly documented.
