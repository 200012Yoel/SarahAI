from pathlib import Path

path = Path("SarahIA/SarahIA/Views/ChatScreenView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise SystemExit(f"Missing patch target: {label}")
    text = text.replace(old, new, 1)

replace_once(
'''        .onChange(of: viewModel.websiteVoiceCommandSequence) { _ in
            handleWebsiteVoiceCommand(viewModel.websiteVoiceCommand)
        }
    }
''',
'''        .onChange(of: viewModel.websiteVoiceCommandSequence) { _ in
            handleWebsiteVoiceCommand(viewModel.websiteVoiceCommand)
        }
        .onChange(of: step) { _ in
            // Une navigation manuelle ou vocale invalide les lectures programmées
            // de l'étape précédente. Raphaël reste ainsi synchronisé avec l'écran.
            voiceGuideGeneration = UUID()
            voiceFocusedOption = nil
        }
    }
''',
"step synchronization"
)

replace_once(
'''                    ) {
                        HapticService.shared.buttonTap()
                        category = choice.title
                    }
''',
'''                    ) {
                        HapticService.shared.buttonTap()
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        category = choice.title
                    }
''',
"manual category selection"
)

replace_once(
'''                    ) {
                        HapticService.shared.buttonTap()
                        designMood = choice.title
                    }
''',
'''                    ) {
                        HapticService.shared.buttonTap()
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        designMood = choice.title
                    }
''',
"manual mood selection"
)

replace_once(
'''                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title, focused: voiceFocusedOption == choice.title) {
                        HapticService.shared.buttonTap()
                        visualStyle = choice.title
                    }
''',
'''                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title, focused: voiceFocusedOption == choice.title) {
                        HapticService.shared.buttonTap()
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        visualStyle = choice.title
                    }
''',
"manual style selection"
)

replace_once(
'''                    Button {
                        HapticService.shared.buttonTap()
                        if sections.contains(section) {
''',
'''                    Button {
                        HapticService.shared.buttonTap()
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        if sections.contains(section) {
''',
"manual section selection"
)

replace_once(
'''            if step > 0 {
                Button("Retour") {
                    HapticService.shared.buttonTap()
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                }
''',
'''            if step > 0 {
                Button("Retour") {
                    HapticService.shared.buttonTap()
                    voiceGuideGeneration = UUID()
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                    announceCurrentStepAfterManualNavigation()
                }
''',
"manual back navigation"
)

replace_once(
'''            Button(step == 4 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                }
            }
''',
'''            Button(step == 4 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                voiceGuideGeneration = UUID()
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    announceCurrentStepAfterManualNavigation()
                }
            }
''',
"manual forward navigation"
)

replace_once(
'''                    Button(option) {
                        HapticService.shared.buttonTap()
                        selection.wrappedValue = option
                    }
''',
'''                    Button(option) {
                        HapticService.shared.buttonTap()
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        selection.wrappedValue = option
                    }
''',
"manual chip selection"
)

replace_once(
'''    private func estimatedSpeechDuration(_ text: String) -> Double {
        let words = max(1, text.split(whereSeparator: { $0.isWhitespace }).count)
        return max(2.3, Double(words) / 2.55 + 0.9)
    }
''',
'''    private func estimatedSpeechDuration(_ text: String) -> Double {
        let words = max(1, text.split(whereSeparator: { $0.isWhitespace }).count)
        // Marge volontairement confortable : AVSpeechSynthesizer peut ralentir
        // selon la voix française choisie. L'ancienne estimation lançait parfois
        // la carte suivante avant la fin de la phrase et coupait les derniers mots.
        return max(5.0, Double(words) / 1.9 + 2.2)
    }
''',
"speech timing"
)

replace_once(
'''        if step == 1 {
            voiceFocusedOption = nil
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Dis-moi le nom du site. Tu peux dire par exemple : le site s'appelle Horizon.")
            } else if audience.isEmpty {
                viewModel.speakWebsiteGuide("Quel est le public visé ? Tu peux dire grand public, professionnels, familles, jeunes adultes, clients locaux ou international.")
            }
            return
        }
''',
'''        if step == 1 {
            voiceFocusedOption = nil
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Tu es à la question du nom. Dis-moi librement le nom du site. Par exemple : le site s'appelle Horizon.")
            } else if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Le site s'appelle \(name). Dis-moi maintenant à qui il s'adresse. Tu peux choisir grand public, professionnels, familles, jeunes adultes, clients locaux ou international, mais tu peux aussi répondre avec ton propre public, avec tes mots.")
            } else {
                viewModel.speakWebsiteGuide("Le site s'appelle \(name) et le public choisi est \(audience). Tu peux dire suivant pour passer à l'ambiance graphique.")
            }
            return
        }
''',
"free-form name and audience prompt"
)

marker = '''    private func voiceChoiceIndex(from normalized: String, count: Int) -> Int? {
'''
helper = '''    private func currentStepStatusText() -> String {
        switch step {
        case 0:
            if category.isEmpty {
                return "Tu es à la question 1 sur 5. Choisis le type de site : e-commerce, voyage, restaurant, portfolio, entreprise ou événement."
            }
            return "Tu es à la question 1 sur 5. Le type \(category) est sélectionné. Tu peux continuer ou choisir une autre carte."
        case 1:
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Il me faut d'abord le nom du site. Tu peux me le dire librement."
            }
            if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Le nom est \(name). Maintenant, dis-moi le public visé. Tu peux utiliser tes propres mots, il n'est pas obligé de correspondre à une carte."
            }
            return "Tu es à la question 2 sur 5. Le site s'appelle \(name), pour \(audience). Tu peux continuer vers l'ambiance graphique."
        case 2:
            let modes = moodChoices.map(\\.title).joined(separator: ", ")
            if designMood.isEmpty {
                return "Tu es à la question 3 sur 5. Choisis l'ambiance graphique. Les modes sont : \(modes)."
            }
            return "Tu es à la question 3 sur 5. L'ambiance \(designMood) est sélectionnée. Les modes disponibles sont : \(modes)."
        case 3:
            let modes = styleChoices.map(\\.title).joined(separator: ", ")
            if visualStyle.isEmpty {
                return "Tu es à la question 4 sur 5. Il faut choisir le mode visuel du site. Pour \(category), les modes sont : \(modes)."
            }
            return "Tu es à la question 4 sur 5. Le mode \(visualStyle) est sélectionné. Pour \(category), les autres modes disponibles sont : \(modes)."
        default:
            let selected = sections.sorted().joined(separator: ", ")
            if selected.isEmpty {
                return "Tu es à la question 5 sur 5. Choisis les sections du site : \(sectionOptions.joined(separator: ", "))."
            }
            return "Tu es à la question 5 sur 5. Les sections sélectionnées sont : \(selected). Tu peux encore en ajouter ou dire suivant pour créer le site."
        }
    }

    private func speakCurrentStepStatus() {
        voiceGuideGeneration = UUID()
        voiceFocusedOption = nil
        viewModel.speakWebsiteGuide(currentStepStatusText())
    }

    private func announceCurrentStepAfterManualNavigation() {
        guard viewModel.isContinuousConversationActive else { return }
        let expectedStep = step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            guard step == expectedStep,
                  viewModel.isShowingWebsiteBuilder,
                  viewModel.isContinuousConversationActive else { return }
            speakCurrentStepStatus()
        }
    }

'''
replace_once(marker, helper + marker, "current step status helpers")

replace_once(
'''        if normalized.contains("repete") || normalized.contains("lis moi") || normalized.contains("lire les") ||
            normalized.contains("quelles options") || normalized.contains("quels choix") ||
            normalized.contains("quels styles") || normalized.contains("formes de site") ||
            normalized.contains("types de site") || normalized.contains("propose moi") {
            readCurrentVoiceOptions()
            return
        }
''',
'''        if normalized.contains("j en suis ou") || normalized.contains("on en est ou") ||
            normalized.contains("je suis ou") || normalized.contains("on est ou") ||
            normalized.contains("je fais quoi") || normalized.contains("je dois faire quoi") ||
            normalized.contains("qu est ce que je fais") || normalized.contains("qu est ce qu il faut") ||
            normalized.contains("c est quoi l etape") || normalized.contains("quelle etape") ||
            normalized.contains("quel mode je dois") || normalized.contains("quel mode maintenant") {
            speakCurrentStepStatus()
            return
        }

        if normalized.contains("repete") || normalized.contains("lis moi") || normalized.contains("lire les") ||
            normalized.contains("quelles options") || normalized.contains("quels choix") ||
            normalized.contains("quels styles") || normalized.contains("formes de site") ||
            normalized.contains("types de site") || normalized.contains("propose moi") {
            readCurrentVoiceOptions()
            return
        }
''',
"where am I voice intents"
)

replace_once(
'''        if let index = voiceChoiceIndex(from: normalized, count: choices.count) {
            applyVoiceChoice(choices[index])
            return
        }

        viewModel.speakWebsiteGuide("Je n'ai pas reconnu ce choix. Dis répète pour que je relise les cartes, ou dis directement le nom de l'option.")
''',
'''        if let index = voiceChoiceIndex(from: normalized, count: choices.count) {
            applyVoiceChoice(choices[index])
            return
        }

        // Le public n'est pas limité aux puces affichées. Une formulation libre
        // comme « tout public », « joueurs et familles » ou toute autre phrase
        // devient directement le public du brief au lieu d'être rejetée.
        if step == 1,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let freeAudience = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !freeAudience.isEmpty {
                audience = freeAudience
                viewModel.speakWebsiteGuide("D'accord. Je retiens comme public : \(freeAudience). On passe maintenant à l'ambiance graphique.")
                let captured = step
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    guard step == captured else { return }
                    withAnimation(.easeInOut(duration: 0.18)) { step = 2 }
                    readCurrentVoiceOptions()
                }
                return
            }
        }

        viewModel.speakWebsiteGuide("Je n'ai pas reconnu ce choix sur l'étape actuelle. Tu peux dire répète, demander j'en suis où, donner le numéro d'une carte, ou dire directement le nom de l'option.")
''',
"free-form audience fallback"
)

path.write_text(text)
print("Website voice guidance context patch applied")
