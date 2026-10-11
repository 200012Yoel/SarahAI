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
        let d = TranslateLiveLanguages.pairFromCommand("active le minuteur")
        expect(d == nil, "ordinary chat is not intercepted")

        expect(TranslateLiveTranslationBackend.exactLocalTranslation(
            "Merci", from: "fr", to: "he") == "תודה", "exact commercial-safe local translation")
        expect(TranslateLiveTranslationBackend.exactLocalTranslation(
            "Hello", from: "en", to: "fr") == "Bonjour", "English to French short phrase")
        expect(TranslateLiveTranslationBackend.exactLocalTranslation(
            "Une émission complète sur la météo", from: "fr", to: "en") == nil,
               "no fake translation of long sentences")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "https://monserveur.example") != nil, "user-chosen HTTPS server")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "http://192.168.1.2:5000") != nil, "private LAN server")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "http://public.example") == nil, "reject insecure remote translation HTTP")
        expect(TranslateLiveTranslationBackend.validatedURL(
            "https://user:pass@somewhere.example") == nil, "reject embedded credentials")
        print("OK: 99+ language catalog, voice command routing, 31 TTS languages, local MT safety")
    }
}
