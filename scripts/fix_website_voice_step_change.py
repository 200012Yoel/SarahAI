from pathlib import Path

path = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
text = path.read_text()
old = '''        .onChange(of: viewModel.websiteVoiceCommandSequence) { _ in
            handleWebsiteVoiceCommand(viewModel.websiteVoiceCommand)
        }
        .onChange(of: step) { _ in
            // Une navigation manuelle ou vocale invalide les lectures programmées
            // de l'étape précédente. Raphaël reste ainsi synchronisé avec l'écran.
            voiceGuideGeneration = UUID()
            voiceFocusedOption = nil
        }
    }
'''
new = '''        .onChange(of: viewModel.websiteVoiceCommandSequence) { _ in
            handleWebsiteVoiceCommand(viewModel.websiteVoiceCommand)
        }
    }
'''
if old not in text:
    raise SystemExit("step onChange patch target missing")
path.write_text(text.replace(old, new, 1))
print("Removed global step observer so automatic voice reads keep their generation token")
