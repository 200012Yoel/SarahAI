package com.sarahia.app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Service OpenAI pour SarahAI :
 * - Gestion de conversations approfondies et complexes multi-tours
 * - Mémoire contextuelle dynamique (maintient le fil de la discussion)
 * - Persona Sarah : intelligente, vive, chaleureuse, bilingue et concise à l'oral
 * - Fallback transparent vers le moteur local en cas d'absence de réseau
 */
class OpenAIService(private val context: Context) {

    private val TAG = "SarahOpenAI"
    private val prefs: SharedPreferences = context.getSharedPreferences("sarah_ai_openai", Context.MODE_PRIVATE)
    private val executor = Executors.newSingleThreadExecutor()

    // Historique des messages pour le contexte multi-tours
    private val conversationHistory = mutableListOf<ChatMessage>()
    private val MAX_HISTORY_TURNS = 12

    data class ChatMessage(val role: String, val content: String)

    private val SYSTEM_PROMPT = """
        Tu es Sarah, une intelligence artificielle conversationnelle brillante, chaleureuse, naturelle et vive d'esprit.
        Tu discutes à l'oral avec l'utilisateur via un avatar 3D en temps réel.
        Tes réponses doivent être fluides, intelligentes, empathiques et bien rythmées pour la voix.
        Tu es capable de raisonnements complexes et d'analyses détaillées tout en restant claire.
        Tu maîtrises parfaitement le français, l'hébreu et l'anglais.
        N'utilise pas de puces Markdown complexes ni d'émojis excessifs dans tes réponses orales afin que la synthèse vocale soit parfaitement naturelle.
    """.trimIndent()

    init {
        resetContext()
    }

    fun getApiKey(): String {
        return prefs.getString("openai_api_key", "") ?: ""
    }

    fun setApiKey(key: String) {
        prefs.edit().putString("openai_api_key", key.trim()).apply()
    }

    fun isConfigured(): Boolean {
        return getApiKey().isNotEmpty()
    }

    fun resetContext() {
        conversationHistory.clear()
        conversationHistory.add(ChatMessage("system", SYSTEM_PROMPT))
    }

    fun askAsync(userPrompt: String, callback: (Result<String>) -> Unit) {
        executor.execute {
            try {
                val apiKey = getApiKey()
                if (apiKey.isEmpty()) {
                    callback(Result.failure(Exception("NO_API_KEY")))
                    return@execute
                }

                // Ajouter le message utilisateur à l'historique
                synchronized(conversationHistory) {
                    conversationHistory.add(ChatMessage("user", userPrompt))
                    // Élaguer si l'historique dépasse la taille max (garder le system prompt)
                    if (conversationHistory.size > MAX_HISTORY_TURNS * 2 + 1) {
                        val system = conversationHistory[0]
                        val subList = conversationHistory.takeLast(MAX_HISTORY_TURNS * 2)
                        conversationHistory.clear()
                        conversationHistory.add(system)
                        conversationHistory.addAll(subList)
                    }
                }

                val endpoint = URL("https://api.openai.com/v1/chat/completions")
                val conn = endpoint.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 8000
                conn.readTimeout = 12000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                conn.setRequestProperty("Authorization", "Bearer $apiKey")

                val rootJson = JSONObject()
                rootJson.put("model", "gpt-4o-mini") // Modèle rapide, intelligent et ultra-économique
                rootJson.put("temperature", 0.7)
                rootJson.put("max_tokens", 350)

                val messagesArray = JSONArray()
                synchronized(conversationHistory) {
                    for (msg in conversationHistory) {
                        val m = JSONObject()
                        m.put("role", msg.role)
                        m.put("content", msg.content)
                        messagesArray.put(m)
                    }
                }
                rootJson.put("messages", messagesArray)

                val writer = OutputStreamWriter(conn.outputStream, "UTF-8")
                writer.write(rootJson.toString())
                writer.flush()
                writer.close()

                val responseCode = conn.responseCode
                if (responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                    val responseStr = reader.readText()
                    reader.close()

                    val resJson = JSONObject(responseStr)
                    val choices = resJson.getJSONArray("choices")
                    if (choices.length() > 0) {
                        val assistantMsg = choices.getJSONObject(0).getJSONObject("message").getString("content")
                        val cleanText = assistantMsg.trim()

                        // Mémoriser la réponse de l'assistant
                        synchronized(conversationHistory) {
                            conversationHistory.add(ChatMessage("assistant", cleanText))
                        }

                        callback(Result.success(cleanText))
                        return@execute
                    }
                }

                val errorStream = conn.errorStream
                val errStr = if (errorStream != null) BufferedReader(InputStreamReader(errorStream)).readText() else "Code $responseCode"
                Log.w(TAG, "OpenAI API Error: $errStr")
                callback(Result.failure(Exception("HTTP $responseCode: $errStr")))

            } catch (e: Exception) {
                Log.e(TAG, "OpenAI request failed: ${e.message}")
                callback(Result.failure(e))
            }
        }
    }
}
