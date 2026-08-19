package com.sarahia.app

import android.content.Context
import java.io.File

/**
 * Bac à Sable & Copilote de Scripts / Mini-Applications Locales :
 * - Stocke, écrit et génère des scripts légers (.py, .js, .html, .bat, .sh)
 * - Générateur de mini-applications HTML/JS interactives à la volée
 */
class LocalScriptSandbox(private val context: Context) {

    private val sandboxDir: File
        get() {
            val dir = File(context.filesDir, "sandbox_scripts")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    fun saveScript(fileName: String, content: String): File {
        val file = File(sandboxDir, fileName)
        file.writeText(content, Charsets.UTF_8)
        return file
    }

    fun readScript(fileName: String): String? {
        val file = File(sandboxDir, fileName)
        return if (file.exists()) file.readText(Charsets.UTF_8) else null
    }

    fun listScripts(): List<String> {
        return sandboxDir.listFiles()?.map { it.name } ?: emptyList()
    }

    /**
     * Génère un modèle de mini-application HTML/JS autonome prêt à l'affichage
     */
    fun generateMiniAppHtml(title: String, bodyContent: String): String {
        return """
            <!DOCTYPE html>
            <html lang="fr">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>$title</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0c0d14; color: #fff; padding: 20px; margin: 0; }
                    h1 { color: #8e7dff; font-size: 20px; margin-bottom: 12px; }
                    .card { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 16px; margin-bottom: 16px; }
                    button { background: #8e7dff; color: #fff; border: none; padding: 10px 18px; border-radius: 8px; font-weight: 600; cursor: pointer; }
                </style>
            </head>
            <body>
                <h1>$title</h1>
                <div class="card">
                    $bodyContent
                </div>
            </body>
            </html>
        """.trimIndent()
    }
}
