package com.sarahia.app

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * Générateur de Raccourcis & d'Automatisations Natives (100% Hors-Ligne) :
 * - Écrit, structure et enregistre des schémas d'automatisation exécutables (Intents Android / Scripts)
 * - Permet à l'utilisateur de demander à Sarah de créer des routines sur-mesure
 */
class ShortcutGenerator(private val context: Context) {

    data class ShortcutDefinition(
        val id: String,
        val title: String,
        val actionType: String,
        val payload: JSONObject,
        val createdAt: Long = System.currentTimeMillis()
    )

    private val shortcutsDir: File
        get() {
            val dir = File(context.filesDir, "shortcuts")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    /**
     * Crée et enregistre un nouveau raccourci d'automatisation
     */
    fun createShortcut(title: String, actionType: String, payload: JSONObject): ShortcutDefinition {
        val id = "sc_${System.currentTimeMillis()}"
        val def = ShortcutDefinition(id, title, actionType, payload)

        val file = File(shortcutsDir, "$id.json")
        val json = JSONObject().apply {
            put("id", def.id)
            put("title", def.title)
            put("actionType", def.actionType)
            put("payload", def.payload)
            put("createdAt", def.createdAt)
        }

        file.writeText(json.toString(2), Charsets.UTF_8)
        return def
    }

    /**
     * Liste tous les raccourcis enregistrés
     */
    fun listShortcuts(): List<ShortcutDefinition> {
        val list = mutableListOf<ShortcutDefinition>()
        val files = shortcutsDir.listFiles() ?: return list
        for (f in files) {
            if (f.name.endsWith(".json")) {
                try {
                    val json = JSONObject(f.readText(Charsets.UTF_8))
                    list.add(
                        ShortcutDefinition(
                            id = json.getString("id"),
                            title = json.getString("title"),
                            actionType = json.getString("actionType"),
                            payload = json.getJSONObject("payload"),
                            createdAt = json.getLong("createdAt")
                        )
                    )
                } catch (e: Exception) {}
            }
        }
        return list
    }
}
