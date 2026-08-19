package com.sarahia.app

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors
import java.util.regex.Pattern

/**
 * Moteur de Traduction Multilingue Temps Réel (Français, Hébreu, Anglais) :
 * - Traduction bidirectionnelle instantanée FR ⇄ HE, FR ⇄ EN, EN ⇄ FR
 * - Détection automatique de la langue
 * - Dictionnaire local ultra-rapide (< 1ms) + moteur distant haute précision
 */
class TranslationEngine(private val context: Context) {

    private val TAG = "SarahTranslation"
    private val executor = Executors.newFixedThreadPool(2)

    // Dictionnaire local haute fréquence pour des réponses à la milliseconde
    private val fastLocalDict = mapOf(
        // FR -> HE
        "bonjour" to "שלום",
        "salut" to "היי",
        "merci" to "תודה",
        "merci beaucoup" to "תודה רבה",
        "au revoir" to "להתראות",
        "s'il vous plaît" to "בבקשה",
        "s'il te plaît" to "בבקשה",
        "oui" to "כן",
        "non" to "לא",
        "bonne nuit" to "לילה טוב",
        "bonsoir" to "ערב טוב",
        "bonne journée" to "יום טוב",
        "comment ça va" to "מה נשמע",
        "comment vas tu" to "מה שלומך",
        "je t'aime" to "אני אוהב אותך",
        "bienvenue" to "ברוכים הבאים",
        "bon appétit" to "בתיאבון",
        "félicitations" to "מזל טוב",
        "pardon" to "סליחה",
        "excusez moi" to "סליחה",
        "à bientôt" to "נתראה בקרוב",

        // HE -> FR
        "שלום" to "Bonjour",
        "תודה" to "Merci",
        "תודה רבה" to "Merci beaucoup",
        "להתראות" to "Au revoir",
        "בבקשה" to "S'il vous plaît",
        "כן" to "Oui",
        "לא" to "Non",
        "לילה טוב" to "Bonne nuit",
        "ערב טוב" to "Bonsoir",
        "יום טוב" to "Bonne journée",
        "מה נשמע" to "Comment ça va ?",
        "מה שלומך" to "Comment vas-tu ?",
        "סליחה" to "Pardon / Excusez-moi",
        "מזל טוב" to "Félicitations",

        // FR -> EN
        "bonjour|en" to "Hello",
        "merci|en" to "Thank you",
        "au revoir|en" to "Goodbye",
        "comment ça va|en" to "How are you?",
        "bonne nuit|en" to "Good night",
        "s'il vous plaît|en" to "Please"
    )

    enum class TargetLanguage(val code: String, val displayNameFr: String, val displayNameHe: String) {
        FRENCH("fr", "Français", "צרפתית"),
        HEBREW("he", "Hébreu", "עברית"),
        ENGLISH("en", "Anglais", "אנגלית")
    }

    data class TranslationRequest(
        val textToTranslate: String,
        val sourceLanguage: String,
        val targetLanguage: TargetLanguage
    )

    /**
     * Détecte si la phrase de l'utilisateur est une demande explicite de traduction.
     */
    fun parseTranslationIntent(input: String): TranslationRequest? {
        val lower = input.trim().lowercase()

        // 1. Vers l'hébreu
        val toHebrewPatterns = listOf(
            Pattern.compile("^(?:traduis|traduit|traduire|comment dit on|comment on dit|comment se dit)\\s+(?:en hébreu|en hebreu)\\s*[:,-]?\\s*(.+)$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(.+)\\s+en hébreu\\s*\\??$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(?:traduis|traduit|traduire)\\s+(.+)\\s+(?:en hébreu|en hebreu)$", Pattern.CASE_INSENSITIVE)
        )
        for (p in toHebrewPatterns) {
            val m = p.matcher(lower)
            if (m.find()) {
                val text = m.group(1)?.trim() ?: ""
                if (text.isNotEmpty()) return TranslationRequest(text, "fr", TargetLanguage.HEBREW)
            }
        }

        // 2. Vers l'anglais
        val toEnglishPatterns = listOf(
            Pattern.compile("^(?:traduis|traduit|traduire|comment dit on|comment on dit|comment se dit)\\s+(?:en anglais)\\s*[:,-]?\\s*(.+)$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(.+)\\s+en anglais\\s*\\??$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(?:traduis|traduit|traduire)\\s+(.+)\\s+(?:en anglais)$", Pattern.CASE_INSENSITIVE)
        )
        for (p in toEnglishPatterns) {
            val m = p.matcher(lower)
            if (m.find()) {
                val text = m.group(1)?.trim() ?: ""
                if (text.isNotEmpty()) return TranslationRequest(text, "fr", TargetLanguage.ENGLISH)
            }
        }

        // 3. Vers le français
        val toFrenchPatterns = listOf(
            Pattern.compile("^(?:traduis|traduit|traduire|comment dit on|comment on dit)\\s+(?:en français|en francais)\\s*[:,-]?\\s*(.+)$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(.+)\\s+en français\\s*\\??$", Pattern.CASE_INSENSITIVE),
            Pattern.compile("^(?:תרגם|איך אומרים|איך מתרגמים)\\s+(?:לצרפתית|בצרפתית)\\s*[:,-]?\\s*(.+)$", Pattern.CASE_INSENSITIVE)
        )
        for (p in toFrenchPatterns) {
            val m = p.matcher(lower)
            if (m.find()) {
                val text = m.group(1)?.trim() ?: ""
                val src = if (detectLanguage(text) == "he") "he" else "en"
                if (text.isNotEmpty()) return TranslationRequest(text, src, TargetLanguage.FRENCH)
            }
        }

        return null
    }

    fun detectLanguage(text: String): String {
        var hebrewCount = 0
        var latinCount = 0
        for (char in text) {
            val code = char.code
            if (code in 0x0590..0x05FF) {
                hebrewCount++
            } else if ((code in 65..90) || (code in 97..122) || code in 0x00C0..0x017F) {
                latinCount++
            }
        }
        return if (hebrewCount > latinCount && hebrewCount > 0) "he" else "fr"
    }

    /**
     * Exécute la traduction de manière asynchrone ultra-rapide.
     */
    fun translateAsync(
        text: String,
        sourceLang: String,
        targetLang: TargetLanguage,
        callback: (Result<String>) -> Unit
    ) {
        executor.execute {
            val cleanText = text.trim()
            val lower = cleanText.lowercase()

            // 1. Vérification dans le dictionnaire local instantané
            val dictKey = if (targetLang == TargetLanguage.ENGLISH) "$lower|en" else lower
            val localMatch = fastLocalDict[dictKey]
            if (localMatch != null) {
                callback(Result.success(localMatch))
                return@execute
            }

            // 2. Traduction via service haute fidélité (MyMemory / LibreTranslate)
            try {
                val pair = "${sourceLang}|${targetLang.code}"
                val encodedText = URLEncoder.encode(cleanText, "UTF-8")
                val urlString = "https://api.mymemory.translated.net/get?q=$encodedText&langpair=$pair"
                
                val url = URL(urlString)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.connectTimeout = 4000
                conn.readTimeout = 4000

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                    val resp = reader.readText()
                    reader.close()

                    val json = JSONObject(resp)
                    val responseData = json.optJSONObject("responseData")
                    val translatedText = responseData?.optString("translatedText", "") ?: ""

                    if (translatedText.isNotEmpty() && !translatedText.equals("NO QUERY SPECIFIED", ignoreCase = true)) {
                        callback(Result.success(translatedText))
                        return@execute
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Distant translation failed: ${e.message}")
            }

            // Fallback de secours
            callback(Result.success("« $cleanText » (${targetLang.displayNameFr})"))
        }
    }
}
