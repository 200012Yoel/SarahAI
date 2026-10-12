import Foundation

@main
struct TranslateLiveCatalogTests {
    static func main() {
        func expect(_ ok: @autoclosure () -> Bool, _ name: String) {
            guard ok() else {
                fputs("FAIL: \(name)\n", stderr)
                exit(1)
            }
        }

        expect(TranslateLiveLanguages.available.count >= 95,
               "many real OpenAI Whisper language codes")
        expect(Set(TranslateLiveLanguages.available.map(\.id)).count ==
               TranslateLiveLanguages.available.count, "unique catalog")
        expect(TranslateLiveLanguages.spokenOutputCodes.count == 31,
               "31 verified spoken languages")
        expect(TranslateLiveLanguages.spokenOutputCodes.contains("fr"),
               "French TTS")
        expect(TranslateLiveLanguages.spokenOutputCodes.contains("ja"),
               "Japanese TTS")
        expect(!TranslateLiveLanguages.spokenOutputCodes.contains("he"),
               "Do not claim Hebrew TTS")
        expect(TranslateLiveLanguages.isRecognized("he"), "Hebrew ASR")
        expect(TranslateLiveLanguages.isRecognized("yue"), "Cantonese ASR")
        expect(TranslateLiveLanguages.isRecognized("auto"), "automatic detection")
        expect(!TranslateLiveLanguages.isSelectableTarget("auto"), "auto not a target")

        let a = TranslateLiveLanguages.pairFromCommand("Active Translate Live hébreu-français")
        expect(a?.from == "he" && a?.to == "fr", "Hebrew to French voice command")
        let b = TranslateLiveLanguages.pairFromCommand("Lance Translate Live espagnol anglais")
        expect(b?.from == "es" && b?.to == "en", "Spanish to English command")
        let c = TranslateLiveLanguages.pairFromCommand("Démarre Translate Live automatique japonais")
        expect(c?.from == "auto" && c?.to == "ja", "auto to Japanese command")
        let spokenA = TranslateLiveLanguages.pairFromCommand(
            "Il y a quelqu'un qui parle anglais, je veux la traduction en hébreu")
        expect(spokenA?.from == "en" && spokenA?.to == "he",
               "natural English to Hebrew")
        let spokenB = TranslateLiveLanguages.pairFromCommand(
            "La personne parle français, je veux la traduction en hébreu")
        expect(spokenB?.from == "fr" && spokenB?.to == "he",
               "natural French to Hebrew")
        let spokenC = TranslateLiveLanguages.pairFromCommand(
            "Lance Live Translate de l'anglais des États-Unis vers le français")
        expect(spokenC?.from == "en-US" && spokenC?.to == "fr",
               "live translate US to French")
        let spokenD = TranslateLiveLanguages.pairFromCommand(
            "Traduction en direct de l'hébreu vers l'anglais britannique")
        expect(spokenD?.from == "he" && spokenD?.to == "en-GB",
               "Hebrew to UK English")
        let spokenE = TranslateLiveLanguages.pairFromCommand(
            "Je veux la traduction en français, la personne parle hébreu")
        expect(spokenE?.from == "he" && spokenE?.to == "fr",
               "target language mentioned first")
        let spokenF = TranslateLiveLanguages.pairFromCommand("Ouvre Yoann")
        expect(spokenF == nil, "normal Yoann is separate from Translate Live")
        let spokenG = TranslateLiveLanguages.pairFromCommand("Translate Live")
        expect(spokenG?.from == "he" && spokenG?.to == "fr",
               "bare Translate Live still launches dedicated screen")
        let d = TranslateLiveLanguages.pairFromCommand("active le minuteur")
        expect(d == nil, "ordinary chat is not intercepted")

        // The production interpreter must never emit a canned translation
        // from a 10-item demo dictionary. A model-backed path is required.
        // "Bonjour" must not be returned just because the word was listed
        // in source, and non-model inputs are rejected cleanly.
        // This regression previously passed because production served a
        // canned list of 10 greetings. With no installed neural translator,
        // even familiar phrases must be reported unavailable, never faked.
        for sample in ["שלום", "תודה רבה", "ערב טוב", "מה נשמע"] {
            var returned = false
            TranslateLiveTranslationBackend.translate(
                text: sample, from: "he", to: "fr", serverURL: ""
            ) { outcome in
                switch outcome {
                case .translated:
                    fatalError("A prerecorded translation was returned for " + sample)
                case .unavailable:
                    returned = true
                }
            }
            expect(returned, "No prerecorded Hebrew phrase for " + sample)
        }

        expect(TranslateLiveTranslationBackend.validatedURL(
            "https://monserveur.example") != nil, "user-chosen HTTPS server")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "http://192.168.1.2:5000") != nil, "private LAN server")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "http://public.example") == nil, "reject insecure remote translation HTTP")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "https://user:pass@somewhere.example") == nil, "reject embedded credentials")
        print("OK: language catalog, voice routing, model-only live translation safety")
    }
}
