package com.sarahia.app

import android.content.Context
import java.util.Locale

/**
 * Moteur d'Indexation Sémantique & RAG Local (100% Hors-Ligne) :
 * - Mémorise et indexe les thèmes et sujets clés de la conversation
 * - Permet à Sarah de faire référence naturellement aux échanges passés
 * - Calcul de pertinence local à 0 latence sans serveur
 */
class SemanticMemoryIndex(private val context: Context) {

    data class MemoryItem(
        val timestamp: Long,
        val text: String,
        val keywords: Set<String>,
        val topicType: String // "translation", "question", "fact", "general"
    )

    private val indexedMemories = mutableListOf<MemoryItem>()
    private val MAX_MEMORIES = 60

    private val stopwords = setOf(
        "le", "la", "les", "un", "une", "des", "du", "de", "d", "l", "et", "ou", "mais", "donc",
        "car", "ni", "que", "qui", "quoi", "dont", "où", "ce", "cet", "cette", "ces", "dans",
        "sur", "sous", "par", "pour", "avec", "sans", "est", "sont", "a", "ont", "je", "tu",
        "il", "elle", "nous", "vous", "ils", "elles", "mon", "ton", "son", "mes", "tes", "ses"
    )

    /**
     * Indexe un nouvel échange dans la mémoire locale
     */
    fun indexExchange(userText: String, assistantText: String, topicType: String = "general") {
        val keywords = extractKeywords("$userText $assistantText")
        val item = MemoryItem(
            timestamp = System.currentTimeMillis(),
            text = "Utilisateur: $userText | Sarah: $assistantText",
            keywords = keywords,
            topicType = topicType
        )

        synchronized(indexedMemories) {
            indexedMemories.add(item)
            if (indexedMemories.size > MAX_MEMORIES) {
                indexedMemories.removeAt(0)
            }
        }
    }

    /**
     * Recherche le contexte pertinent le plus proche pour une question donnée (Local RAG)
     */
    fun findRelevantContext(query: String): String? {
        val queryKeywords = extractKeywords(query)
        if (queryKeywords.isEmpty()) return null

        var bestScore = 0
        var bestMatch: MemoryItem? = null

        synchronized(indexedMemories) {
            for (item in indexedMemories.reversed()) {
                val intersection = item.keywords.intersect(queryKeywords)
                val score = intersection.size
                if (score > bestScore && score >= 2) {
                    bestScore = score
                    bestMatch = item
                }
            }
        }

        return bestMatch?.text
    }

    private fun extractKeywords(text: String): Set<String> {
        val clean = text.lowercase(Locale.FRENCH)
            .replace(Regex("[^a-z0-9àâäéèêëîïôöùûüç\\u0590-\\u05FF]+"), " ")
            .split(" ")
            .filter { it.length > 2 && !stopwords.contains(it) }
        return clean.toSet()
    }
}
