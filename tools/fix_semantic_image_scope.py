from pathlib import Path

path = Path("SarahIA/SarahIA/Services/MultiAgentCoordinator.swift")
text = path.read_text(encoding="utf-8")

old = '''                let prompt = imageCheck.cleanedPrompt
                let profile = SarahGenerativeModelCatalog.imageProfile()

                OpenSourceImageGenerationService.shared.generateImage(prompt: semanticImage.enhancedPrompt) { result in'''
new = '''                let prompt = imageCheck.cleanedPrompt
                let semanticImage = SarahMediaPromptUnderstanding.image(prompt)
                let profile = SarahGenerativeModelCatalog.imageProfile()

                OpenSourceImageGenerationService.shared.generateImage(prompt: semanticImage.enhancedPrompt) { result in'''

if new not in text:
    if old not in text:
        raise SystemExit("Target semantic image scope not found")
    text = text.replace(old, new, 1)

path.write_text(text.rstrip() + "\n", encoding="utf-8")
print("Fixed Nathan image semantic scope")
