import Foundation

@main
struct TranslateLiveContextTests {
    static func main() {
        func expect(_ value: @autoclosure () -> Bool, _ message: String) {
            guard value() else { fatalError("FAIL " + message) }
        }

        expect(TranslateLiveContextBuffer.isNonSpeechCaption("[Musique]"),
               "TV music cue must never be translated")
        expect(TranslateLiveContextBuffer.isNonSpeechCaption("[Music]"),
               "English music cue must never be translated")
        expect(!TranslateLiveContextBuffer.isNonSpeechCaption("Bonjour, je suis Yoann"),
               "normal French speech must survive the music filter")
        expect(!TranslateLiveContextBuffer.isNonSpeechCaption("שלום לכולם"),
               "Hebrew speech must survive the music filter")

        expect(TranslateLiveContextBuffer.isRepeatingHallucination(
            "תודה רבה. תודה רבה. תודה רבה. תודה רבה. תודה רבה."),
            "reject repeated Hebrew false recognition")
        expect(TranslateLiveContextBuffer.isUnreliableTranscript(
            "תודה רבה. תודה רבה. תודה רבה. תודה רבה."),
            "repeated Hebrew captions must not reach TTS")
        expect(TranslateLiveContextBuffer.isRepeatingHallucination(
            "האז כתב, האז כתב, האז כתב, כתב, כתב, כתב, כתב, כתב, כתב"),
            "reject single-word Hebrew hallucinations seen in user screenshot")
        expect(TranslateLiveContextBuffer.isRepeatingHallucination(
            "כתב כתב כתב כתב כתב כתב כתב כתב כתב כתב"),
            "reject repeated Hebrew tokens even without a prefix")
        expect(TranslateLiveContextBuffer.isRepeatingHallucination(
            "שלום, תבין, תבין, תבין, תבין, תבין, תבין."),
            "reject hallucination captured in the real Hebrew WAV test")

        expect(!TranslateLiveContextBuffer.isRepeatingHallucination(
            "שלום שלום חברים ברוכים הבאים למהדורת הערב"),
            "allow normal Hebrew greeting with a repeated word")
        expect(!TranslateLiveContextBuffer.isRepeatingHallucination(
            "תודה רבה לכל הצופים, נשוב אליכם אחרי החדשות."),
            "legitimate Hebrew broadcast sentence is retained")
        expect(!TranslateLiveContextBuffer.isRepeatingHallucination(
            "bonjour les amis, bienvenue au journal télévisé ce soir"),
            "legitimate French broadcast sentence is retained")
        expect(TranslateLiveContextBuffer.isMostlyHebrew("תמר זהורי"),
               "Hebrew news name should be accepted")
        expect(!TranslateLiveContextBuffer.isMostlyHebrew("I'm sorry. I'm sorry."),
               "English Whisper hallucination is not a Hebrew source")
        expect(!TranslateLiveContextBuffer.isMostlyHebrew("This is a French broadcast"),
               "reject Latin words from an explicitly Hebrew stream")
        expect(TranslateLiveContextBuffer.isSuspiciousEnglishPivot(
            "I'm sorry. I'm sorry.", hebrewSource: "תמר זהורי"),
            "reject screenshot's fabricated repeated English apology")
        expect(TranslateLiveContextBuffer.isSuspiciousEnglishPivot(
            "I am sorry. I am sorry.", hebrewSource: "שלום לכולם"),
            "reject repeated English sentences regardless of apostrophe")
        expect(!TranslateLiveContextBuffer.isSuspiciousEnglishPivot(
            "Good evening and welcome to the news.", hebrewSource: "ערב טוב וברוכים הבאים לחדשות"),
            "keep normal sentence translated from Hebrew")

        var buffer = TranslateLiveContextBuffer()
        let first = buffer.receive("שלום", paused: false)
        expect(first.provisional == "שלום", "speech starts provisional")
        expect(first.committed.isEmpty, "don't speak unconfirmed text")

        let second = buffer.receive("שלום", paused: true)
        expect(second.committed == ["שלום"], "short greeting commits on pause")
        expect(second.provisional.isEmpty, "no stale provisional")
        expect(second.recentContext.contains("שלום"), "Hebrew context preserved")

        let a = buffer.receive("I bought", paused: false)
        expect(a.provisional == "I bought", "first English hypothesis")
        let b = buffer.receive("I bought a book", paused: false)
        expect(b.provisional == "I bought a book", "replace growing hypothesis")
        expect(b.committed.isEmpty, "growing hypothesis isn't spoken prematurely")
        let c = buffer.receive("I bought a book", paused: true)
        expect(c.committed == ["I bought a book"], "commit only complete hypothesis")

        let firstRepeat = buffer.receive("yes", paused: true)
        let repeated = buffer.receive("yes", paused: true)
        expect(firstRepeat.committed == ["yes"] && repeated.committed == ["yes"],
               "legitimate one-word repetition isn't lost")

        buffer.reset()
        expect(buffer.committedHistory.isEmpty, "no previous conversation leakage")
        expect(buffer.provisional.isEmpty, "reset provisional")

        expect(TranslateLiveLanguages.engineCode(for: "en-GB") == "en",
               "UK English mapped to genuine Whisper en")
        expect(TranslateLiveLanguages.engineCode(for: "en-US") == "en",
               "US English mapped to genuine Whisper en")
        expect(TranslateLiveLanguages.isRecognized("en-GB"), "Whisper UK source")
        expect(TranslateLiveLanguages.isRecognized("en-US"), "Whisper US source")
        expect(TranslateLiveLanguages.isSelectableTarget("en-GB"), "UK target selectable")
        expect(TranslateLiveLanguages.isSelectableTarget("en-US"), "US target selectable")
        expect(TranslateLiveLanguages.available.contains(where: { $0.id == "en-GB" }),
               "UK locale visible")
        expect(TranslateLiveLanguages.available.contains(where: { $0.id == "en-US" }),
               "US locale visible")
        expect(TranslateLiveLanguages.spokenOutputCodes.contains("en"),
               "English TTS engine exists without claiming exact accent")

        let command = TranslateLiveLanguages.pairFromCommand(
            "Active Translate Live anglais britannique français"
        )
        expect(command?.from == "en-GB" && command?.to == "fr", "UK command")
        let us = TranslateLiveLanguages.pairFromCommand(
            "Lance Translate Live anglais américain français"
        )
        expect(us?.from == "en-US" && us?.to == "fr", "US command")

        print("PASS: context stabilization, Hebrew short greeting, UK/US locale mapping")
    }
}
