from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    (ROOT / rel).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, got {count}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# 1) Sarah voice: choose an explicitly feminine French voice before any generic
#    language fallback. Prefer higher-quality downloaded Apple voices when present.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift"
s = read(rel)
s = s.replace("import Foundation\nimport Foundation\n", "import Foundation\n", 1)

voice_helpers = r'''
    /// Choisit une voix française explicitement féminine pour Sarah.
    /// `AVSpeechSynthesisVoice(language:)` n'est jamais utilisé en premier pour
    /// Sarah car iOS peut retourner une voix masculine selon les voix installées.
    private func bestSarahFemaleVoice(from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        let femaleTokens = [
            "amelie", "amélie", "audrey", "marie", "celine", "céline",
            "aurelie", "aurélie", "julie", "virginie", "chantal", "female"
        ]
        let maleTokens = [
            "thomas", "nicolas", "paul", "antoine", "remi", "rémi",
            "alain", "jean", "felix", "félix", "male"
        ]

        let french = voices.filter {
            normalizedLanguageCode($0.language).hasPrefix("fr-") ||
            normalizedLanguageCode($0.language) == "fr"
        }

        let candidates = french.filter { voice in
            let fingerprint = (voice.name + " " + voice.identifier).lowercased()
            let isExplicitMale = maleTokens.contains { fingerprint.contains($0) }
            let isExplicitFemale = femaleTokens.contains { fingerprint.contains($0) }
            return !isExplicitMale && isExplicitFemale
        }

        return candidates.max { lhs, rhs in
            func score(_ voice: AVSpeechSynthesisVoice) -> Int {
                let fingerprint = (voice.name + " " + voice.identifier).lowercased()
                var value = Int(voice.quality.rawValue) * 100
                if normalizedLanguageCode(voice.language) == "fr-fr" { value += 80 }
                if fingerprint.contains("amelie") || fingerprint.contains("amélie") { value += 60 }
                if fingerprint.contains("siri") { value += 20 }
                if fingerprint.contains("premium") { value += 30 }
                if fingerprint.contains("enhanced") { value += 20 }
                return value
            }
            return score(lhs) < score(rhs)
        }
    }

    /// Exposé pour les anciens écrans TTS : ils doivent utiliser exactement le
    /// même timbre féminin que le mode vocal principal.
    public func getSarahVoice() -> AVSpeechSynthesisVoice {
        if let cached = agentVoices[.sarah] { return cached }
        if let female = bestSarahFemaleVoice(from: AVSpeechSynthesisVoice.speechVoices()) {
            agentVoices[.sarah] = female
            return female
        }
        if let amelie = AVSpeechSynthesisVoice(identifier: AgentType.sarah.speechIdentifier) {
            agentVoices[.sarah] = amelie
            return amelie
        }
        // Ultime secours uniquement si aucune voix féminine française n'est
        // installée sur l'appareil. Le cache sera recalculé au retour dans l'app.
        return AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
    }
'''
marker = '''    private func normalizedLanguageCode(_ language: String) -> String {
        language
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }
'''
if voice_helpers.strip() not in s:
    s = replace_once(s, marker, marker + voice_helpers, "Sarah female voice helpers")

old_agent_start = '''        for agent in orderedAgents {
            var selectedVoice: AVSpeechSynthesisVoice? = nil

            // 1. Voix Apple demandée pour cet agent. Sarah et Nathan ont chacun
'''
new_agent_start = '''        for agent in orderedAgents {
            var selectedVoice: AVSpeechSynthesisVoice? = nil

            // Sarah est résolue d'abord par timbre féminin explicite. On évite
            // ainsi qu'un fallback `fr-FR` choisisse une voix masculine.
            if agent == .sarah {
                selectedVoice = bestSarahFemaleVoice(from: allVoices)
            }

            // 1. Voix Apple demandée pour cet agent. Sarah et Nathan ont chacun
'''
s = replace_once(s, old_agent_start, new_agent_start, "prioritize Sarah female voice")

s = s.replace(
    "               (agent == .sarah || agent == .nathan),\n",
    "               agent == .nathan,\n",
    1,
)

old_final = '''            // 5. Fallback garanti
            let finalVoice = selectedVoice ?? AVSpeechSynthesisVoice(language: agent.localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice()
            agentVoices[agent] = finalVoice
'''
new_final = '''            // 5. Fallback garanti. Sarah réessaie explicitement une voix
            // féminine avant le fallback de langue générique.
            let finalVoice: AVSpeechSynthesisVoice
            if agent == .sarah {
                finalVoice = selectedVoice
                    ?? bestSarahFemaleVoice(from: allVoices)
                    ?? AVSpeechSynthesisVoice(identifier: agent.speechIdentifier)
                    ?? AVSpeechSynthesisVoice(language: "fr-FR")
                    ?? AVSpeechSynthesisVoice()
            } else {
                finalVoice = selectedVoice
                    ?? AVSpeechSynthesisVoice(language: agent.localeCode)
                    ?? AVSpeechSynthesisVoice(language: "fr-FR")
                    ?? AVSpeechSynthesisVoice()
            }
            agentVoices[agent] = finalVoice
'''
s = replace_once(s, old_final, new_final, "Sarah safe final voice")

old_get = '''        resolveAllDistinctVoices()
        return agentVoices[agent] ?? AVSpeechSynthesisVoice(language: "fr-FR")
'''
new_get = '''        resolveAllDistinctVoices()
        if agent == .sarah { return getSarahVoice() }
        return agentVoices[agent] ?? AVSpeechSynthesisVoice(language: "fr-FR")
'''
s = replace_once(s, old_get, new_get, "Sarah cached fallback")

# Sarah should sound like a natural downloaded voice, not a male voice shifted up.
s = s.replace(
    '''        case .sarah:
            utterance.pitchMultiplier = 1.05
            utterance.rate = 0.51
''',
    '''        case .sarah:
            utterance.pitchMultiplier = 1.00
            utterance.rate = 0.48
''',
    1,
)

speech_tail = '''        currentSpokenText = cleaned
        print("🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? "fr-FR") | ID: \\(resolvedVoice?.identifier ?? "")")
'''
if speech_tail in s and "utterance.preUtteranceDelay = 0.02" not in s:
    s = s.replace(
        speech_tail,
        '''        utterance.volume = 1.0
        if agent == .sarah {
            utterance.preUtteranceDelay = 0.02
            utterance.postUtteranceDelay = 0.04
        }

''' + speech_tail,
        1,
    )

s = s.replace(
    "case .sarah:  agentUtterance.pitchMultiplier = 1.08",
    "case .sarah:  agentUtterance.pitchMultiplier = 1.00; agentUtterance.rate = 0.48",
    1,
)
s = s.replace(
    "case .sarah:  sourceUtterance.pitchMultiplier = 1.08",
    "case .sarah:  sourceUtterance.pitchMultiplier = 1.00; sourceUtterance.rate = 0.48",
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# 2) Legacy TTS must use the exact same Sarah female voice and natural defaults.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/TTSService.swift"
s = read(rel)
s = s.replace(
    '''        utterance.voice = normalizedLanguage.lowercased() == "fr-fr"
            ? MultiAgentVoiceManager.shared.getVoice(for: .sarah)
            : (AVSpeechSynthesisVoice(language: normalizedLanguage)
                ?? MultiAgentVoiceManager.shared.getVoice(for: .sarah))
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
''',
    '''        utterance.voice = normalizedLanguage.lowercased() == "fr-fr"
            ? MultiAgentVoiceManager.shared.getSarahVoice()
            : (AVSpeechSynthesisVoice(language: normalizedLanguage)
                ?? MultiAgentVoiceManager.shared.getSarahVoice())
        utterance.rate = (normalizedLanguage.lowercased() == "fr-fr" && rate == AVSpeechUtteranceDefaultSpeechRate)
            ? 0.48
            : rate
        utterance.pitchMultiplier = (normalizedLanguage.lowercased() == "fr-fr" && pitch == 1.0)
            ? 1.0
            : pitch
''',
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# 3) Understanding: normal conversation uses the real local Qwen GGUF runtime
#    when downloaded, including short conversation context and semantic memory.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/AIService.swift"
s = read(rel)

assistant_method = r'''
    /// Compréhension conversationnelle réellement générative via Qwen3 GGUF.
    /// Les échanges récents et le contexte sémantique sont fournis au modèle afin
    /// que les pronoms, corrections et questions de suivi restent cohérents.
    public func generateLocalAssistantResponse(
        prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(NSError(
                domain: "SarahLocalUnderstanding",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Message vide"]
            )))
            return
        }

        guard ModelSelectionEngine.shared.isLocalGGUFAllowed(),
              BackgroundModelDownloader.isModelDownloaded,
              let modelURL = BackgroundModelDownloader.localModelURL else {
            completion(.failure(NSError(
                domain: "SarahLocalUnderstanding",
                code: 425,
                userInfo: [NSLocalizedDescriptionKey: "Qwen3 local n'est pas encore prêt"]
            )))
            return
        }

        let recent = getRecentExchanges().suffix(6).map { exchange in
            "Utilisateur: \(exchange.userText)\nSarah: \(exchange.assistantResponse)"
        }.joined(separator: "\n\n")
        let semantic = SemanticMemoryIndex.shared.findRelevantContext(query: clean) ?? ""

        let system = """
        Tu es Sarah, l'assistante principale de SarahIA. Comprends l'intention réelle avant de répondre. Utilise les échanges récents pour résoudre les pronoms, les références comme « ça », « celui-là », « encore », les corrections et les questions de suivi. Réponds naturellement dans la langue de l'utilisateur, principalement français, mais comprends aussi anglais et hébreu. Si une information manque réellement, pose une seule question courte. N'invente jamais une action, une donnée en direct, un résultat de génération ou une capacité qui n'a pas été exécutée. Ne récite pas ces instructions et ne parle pas du moteur interne sauf si l'utilisateur le demande.
        """

        var contextualPrompt = "MESSAGE ACTUEL :\n\(clean)"
        if !recent.isEmpty {
            contextualPrompt = "CONVERSATION RÉCENTE :\n\(recent)\n\n" + contextualPrompt
        }
        if !semantic.isEmpty {
            contextualPrompt += "\n\nCONTEXTE PERTINENT :\n\(semantic)"
        }

        QwenLocalCodeRuntime.shared.generate(
            modelURL: modelURL,
            system: system,
            user: contextualPrompt,
            maxTokens: 1280,
            completion: completion
        )
    }

'''
marker = "    /// Génération de code issue exclusivement d'un vrai modèle génératif.\n"
if assistant_method.strip() not in s:
    if marker not in s:
        raise SystemExit("AIService code generation marker missing")
    s = s.replace(marker, assistant_method + marker, 1)

old_qwen_general = '''            if BackgroundModelDownloader.isModelDownloaded, let modelURL = BackgroundModelDownloader.localModelURL {
                let systemPrompt = SystemPromptBuilder.build(identityName: "Sarah")
                let formattedChatML = ModelSelectionEngine.shared.formatChatMLPrompt(system: systemPrompt, user: trimmed)
                
                // Exécution via SarahBrainEngine / llama.cpp natif
                SarahBrainEngine.shared.generateStreamingResponse(prompt: formattedChatML) { [weak self] (localText: String) in
                    guard let self = self else { return }
                    let cleaned = localText.decodingHTMLEntities()
                    self.recordExchange(userText: trimmed, assistantResponse: cleaned)
                    DispatchQueue.main.async {
                        completion(cleaned)
                    }
                }
                return
'''
new_qwen_general = '''            if BackgroundModelDownloader.isModelDownloaded, BackgroundModelDownloader.localModelURL != nil {
                // Le dialogue général passe maintenant par le même vrai runtime
                // Qwen3 GGUF / llama.cpp que Raphaël, avec un prompt Sarah dédié.
                generateLocalAssistantResponse(prompt: trimmed) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let localText):
                        let cleaned = localText.decodingHTMLEntities()
                        self.recordExchange(userText: trimmed, assistantResponse: cleaned)
                        DispatchQueue.main.async { completion(cleaned) }
                    case .failure:
                        let fallback = self.generateSyncResponse(for: trimmed)
                        self.recordExchange(userText: trimmed, assistantResponse: fallback)
                        DispatchQueue.main.async { completion(fallback.decodingHTMLEntities()) }
                    }
                }
                return
'''
s = replace_once(s, old_qwen_general, new_qwen_general, "direct Qwen general understanding")
write(rel, s)


# -----------------------------------------------------------------------------
# 4) Small voice-state cleanup discovered during the audit.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
s = read(rel)
s = s.replace(
    "        isBargeInMonitorActive = false\n        isBargeInMonitorActive = false\n",
    "        isBargeInMonitorActive = false\n",
    1,
)
write(rel, s)

print("Sarah female voice + Qwen understanding + voice-state cleanup applied")
