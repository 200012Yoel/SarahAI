package com.sarahia.app

import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale

private fun String.capitalized(): String =
    this.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }

data class WebSearchResultItem(
    val title: String,
    val snippet: String,
    val url: String,
    val sourceName: String
)

/**
 * Service de Recherche Web Intégré pour Android :
 * Collaboration :
 * - Sarah (Patronne) : Réceptionne et délègue la mission
 * - Tom (Agent de Recherche Web) : Interroge le Web en direct et produit le rapport
 */
class WebSearchService {

    companion object {
        val instance = WebSearchService()
    }

    fun searchWebAsync(query: String, callback: (summary: String, items: List<WebSearchResultItem>) -> Unit) {
        val cleanQuery = query.trim()
        if (cleanQuery.isEmpty()) {
            callback("Veuillez préciser votre recherche.", emptyList())
            return
        }

        Thread {
            val norm = cleanQuery.lowercase()

            // 0. Météo spécifique pour une ville
            val weatherTriggers = listOf("meteo a ", "meteo pour ", "meteo de ", "temps a ", "temperature a ")
            for (t in weatherTriggers) {
                if (norm.contains(t)) {
                    val city = norm.substringAfter(t).trim().trim(':', '?', '.', '!')
                    val weatherRes = fetchCityWeather(city)
                    if (weatherRes != null) {
                        val formatted = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de vérifier la météo pour vous en direct.*\n\n" +
                                "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n${weatherRes.snippet}"
                        callback(formatted, listOf(weatherRes))
                        return@Thread
                    }
                }
            }
            
            // 0.8. Billets de Train / SNCF / Trainline
            val trainTriggers = listOf("billet de train", "billets de train", "billet train", "train pour", "train de ", "sncf", "trainline", "trajet en train")
            if (trainTriggers.any { norm.contains(it) } || (norm.contains("train") && (norm.contains("paris") || norm.contains("billet") || norm.contains("deauville")))) {
                var origin = "Paris"
                var destination = "Deauville"
                if (norm.contains(" de ") && (norm.contains(" a ") || norm.contains(" vers "))) {
                    val afterDe = norm.substringAfter(" de ")
                    val sep = if (afterDe.contains(" a ")) " a " else " vers "
                    val parts = afterDe.split(sep, limit = 2)
                    if (parts.isNotEmpty()) {
                        val rawOrig = parts[0].replace(Regex("\\b(et|un billet|des billets|billet de train|billet|train|pour)\\b"), "").trim()
                        if (rawOrig.isNotEmpty()) origin = rawOrig.capitalized()
                    }
                    if (parts.size > 1) {
                        val rawDest = parts[1].replace(Regex("\\b(et|vers|pour)\\b"), "").trim().trim(':', '?', '.', '!')
                        if (rawDest.isNotEmpty()) destination = rawDest.capitalized()
                    }
                } else if (norm.contains(" a ") || norm.contains(" pour ")) {
                    val sep = if (norm.contains(" a ")) " a " else " pour "
                    val rawDest = norm.substringAfter(sep).replace(Regex("\\b(et|vers|pour)\\b"), "").trim().trim(':', '?', '.', '!')
                    if (rawDest.isNotEmpty()) destination = rawDest.capitalized()
                }

                val encOrig = URLEncoder.encode(origin, "UTF-8")
                val encDest = URLEncoder.encode(destination, "UTF-8")
                val sncfUrl = "https://www.sncf-connect.com/app/home/search?origin=$encOrig&destination=$encDest"
                val trainlineUrl = "https://www.thetrainline.com/fr/billets-de-train/${origin.lowercase()}-a-${destination.lowercase()}"
                val mapsUrl = "https://www.google.com/maps/dir/$encOrig/$encDest"

                val trainFormatted = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande tout de suite à **Tom**, mon agent de recherche Web, de trouver les meilleurs billets de train pour vous.*\n\n" +
                        "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n" +
                        "🚆 **Recherche de Billets de Train en direct** pour le trajet **$origin ➔ $destination** :\n\n" +
                        "• 🚄 **SNCF Connect** : Horaires TGV Inoui, TER & Nomad, disponibilités et réservation en direct\n" +
                        "  🔗 $sncfUrl\n" +
                        "• 🎫 **Trainline** : Comparateur de tarifs SNCF / Ouigo avec sélection de places et cartes Avantage\n" +
                        "  🔗 $trainlineUrl\n" +
                        "• 🗺️ **Itinéraire & Temps de Trajet** : Visualiser les gares de départ et le plan ferroviaire\n" +
                        "  🔗 $mapsUrl\n\n" +
                        "💡 *Astuce de Tom : Sur la ligne $origin ➔ $destination, les trains partent généralement de Paris-Saint-Lazare pour un temps de trajet moyen de 2h05.*"

                val resItem = WebSearchResultItem("SNCF & Trainline : $origin - $destination", trainFormatted, sncfUrl, "SNCF Connect")
                callback(trainFormatted, listOf(resItem))
                return@Thread
            }

            // 1. Billets d'avion / Vols / Voyage
            val flightTriggers = listOf("billet d avion", "billets d avion", "vol pour", "vols pour", "trouve un vol", "chercher un vol", "billet avion")
            if (flightTriggers.any { norm.contains(it) }) {
                val encoded = URLEncoder.encode(cleanQuery, "UTF-8")
                val flightFormatted = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande tout de suite à **Tom**, mon agent de recherche Web, de trouver les meilleurs billets d'avion pour vous.*\n\n" +
                        "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n" +
                        "✈️ **Recherche de Billets d'Avion & Comparateurs en direct** :\n\n" +
                        "• 🌐 **Google Flights** : Calendrier des prix et compagnies en direct (https://www.google.com/travel/flights?q=$encoded)\n" +
                        "• 🛫 **Skyscanner** : Tarifs low-cost & compagnies régulières (https://www.skyscanner.fr/transport/vols/?q=$encoded)\n" +
                        "• 🧭 **Kayak** : Prédictions de prix et comparateur (https://www.kayak.fr/flights)\n\n" +
                        "💡 *Astuce de Tom : Réservez en milieu de semaine pour obtenir les tarifs les plus compétitifs.*"
                val resItem = WebSearchResultItem("Comparateurs de Vols", flightFormatted, "https://www.google.com/travel/flights?q=$encoded", "Google Flights")
                callback(flightFormatted, listOf(resItem))
                return@Thread
            }

            val topic = extractCoreSearchTopic(cleanQuery)
            val displayTopic = if (topic.isNotEmpty()) topic.capitalized() else cleanQuery

            // 2. Essai Wikipedia REST API
            val wikiResult = fetchWikipediaSummary(topic)
            if (wikiResult != null) {
                val formatted = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de s'en occuper pour vous en direct.*\n\n" +
                        "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n" +
                        "🌐 **Résultat Web pour « ${wikiResult.title} »** :\n\n${wikiResult.snippet}\n\n📖 *Source vérifiée par Tom : Wikipédia (${wikiResult.url})*"
                callback(formatted, listOf(wikiResult))
                return@Thread
            }

            // 3. Essai DuckDuckGo Instant Answer API
            val ddgResult = fetchDuckDuckGo(topic)
            if (ddgResult != null) {
                val formatted = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de s'en occuper pour vous en direct.*\n\n" +
                        "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n" +
                        "🌐 **Résultat Web pour « ${ddgResult.title} »** :\n\n${ddgResult.snippet}\n\n🔗 *Source vérifiée par Tom : ${ddgResult.sourceName} (${ddgResult.url})*"
                callback(formatted, listOf(ddgResult))
                return@Thread
            }

            // 4. Réponse de secours
            val fallback = "👩🏻‍💼 **Sarah (Patronne)** : *D'accord ! Je demande à **Tom**, mon agent de recherche Web, de regarder ça pour vous.*\n\n" +
                    "🕵️‍♂️ **Rapport de Tom (Agent Web)** :\n" +
                    "J'ai exploré le Web pour « $displayTopic ». N'hésitez pas à préciser votre demande ou vos mots-clés !"
            callback(fallback, emptyList())
        }.start()
    }

    private fun extractCoreSearchTopic(input: String): String {
        var cleaned = input.lowercase()
        val prefixes = listOf(
            "cherche sur internet ", "recherche sur internet ", "cherche sur le web ",
            "recherche sur le web ", "trouve sur internet ", "trouve sur le web ",
            "cherche moi ", "trouve moi ", "moteur de recherche ", "qui est ", "qui etait ",
            "c'est quoi ", "qu'est ce que ", "qu'est-ce que ", "recherche ", "cherche ", "trouve "
        )
        for (p in prefixes) {
            if (cleaned.startsWith(p)) {
                cleaned = cleaned.substring(p.length)
                break
            }
        }
        return cleaned.trim().trim(':', '?', '.')
    }

    private fun fetchCityWeather(city: String): WebSearchResultItem? {
        return try {
            val encodedCity = URLEncoder.encode(city, "UTF-8")
            val geoUrl = URL("https://geocoding-api.open-meteo.com/v1/search?name=$encodedCity&count=1&language=fr&format=json")
            val geoConn = geoUrl.openConnection() as HttpURLConnection
            geoConn.connectTimeout = 3000
            geoConn.readTimeout = 3000
            geoConn.setRequestProperty("User-Agent", "SarahIA-Android/2.0")

            if (geoConn.responseCode != 200) return null
            val geoJson = JSONObject(readStream(geoConn))
            val results = geoJson.optJSONArray("results") ?: return null
            if (results.length() == 0) return null
            val first = results.getJSONObject(0)
            val lat = first.getDouble("latitude")
            val lon = first.getDouble("longitude")
            val name = first.optString("name", city.capitalized())
            val country = first.optString("country", "")

            val forecastUrl = URL("https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto")
            val fConn = forecastUrl.openConnection() as HttpURLConnection
            fConn.connectTimeout = 3000
            fConn.readTimeout = 3000
            fConn.setRequestProperty("User-Agent", "SarahIA-Android/2.0")

            if (fConn.responseCode != 200) return null
            val fJson = JSONObject(readStream(fConn))
            val current = fJson.optJSONObject("current") ?: return null
            val temp = current.optDouble("temperature_2m", 0.0).toInt()
            val wind = current.optDouble("wind_speed_10m", 0.0).toInt()
            val code = current.optInt("weather_code", 0)

            val condition = when (code) {
                0 -> "Ciel dégagé ☀️"
                1, 2 -> "Partiellement nuageux ⛅"
                3 -> "Ciel couvert ☁️"
                45, 48 -> "Brouillard 🌫️"
                51, 53, 55 -> "Bruine 🌦️"
                61, 63, 65 -> "Pluie 🌧️"
                71, 73, 75 -> "Neige ❄️"
                80, 81, 82 -> "Averses 🌧️"
                95, 96, 99 -> "Orages ⚡"
                else -> "Conditions variables 🌤️"
            }

            val loc = if (country.isNotEmpty()) "$name, $country" else name
            val summary = "☀️ **Météo en direct pour $loc** :\n\n• Température : **${temp}°C**\n• Ciel : **$condition**\n• Vent : **${wind} km/h**\n\nBelle journée avec Sarah IA ! ✨"
            WebSearchResultItem("Météo $loc", summary, "https://open-meteo.com", "Open-Meteo")
        } catch (e: Exception) {
            null
        }
    }

    private fun fetchWikipediaSummary(topic: String): WebSearchResultItem? {
        return try {
            val encoded = URLEncoder.encode(topic, "UTF-8")
            val url = URL("https://fr.wikipedia.org/api/rest_v1/page/summary/$encoded")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("User-Agent", "SarahIA-Android/2.0")

            if (conn.responseCode == 200) {
                val json = JSONObject(readStream(conn))
                val extract = json.optString("extract", "")
                val title = json.optString("title", topic)
                val pageUrl = json.optJSONObject("content_urls")?.optJSONObject("desktop")?.optString("page")
                    ?: "https://fr.wikipedia.org/wiki/$encoded"

                if (extract.isNotEmpty()) {
                    WebSearchResultItem(title, extract, pageUrl, "Wikipédia")
                } else null
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun fetchDuckDuckGo(topic: String): WebSearchResultItem? {
        return try {
            val encoded = URLEncoder.encode(topic, "UTF-8")
            val url = URL("https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1&skip_disambig=1")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("User-Agent", "SarahIA-Android/2.0")

            if (conn.responseCode == 200) {
                val json = JSONObject(readStream(conn))
                val abstract = json.optString("AbstractText", "")
                val heading = json.optString("Heading", topic)
                val sourceUrl = json.optString("AbstractURL", "https://duckduckgo.com/?q=$encoded")

                if (abstract.isNotEmpty()) {
                    WebSearchResultItem(heading, abstract, sourceUrl, "DuckDuckGo")
                } else null
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun readStream(conn: HttpURLConnection): String {
        val reader = BufferedReader(InputStreamReader(conn.inputStream))
        val sb = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            sb.append(line)
        }
        reader.close()
        return sb.toString()
    }
}
