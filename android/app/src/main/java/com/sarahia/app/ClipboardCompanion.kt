package com.sarahia.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context

/**
 * Compagnon Presse-Papier Intelligent (100% Local) :
 * - Lit le texte copié par l'utilisateur pour le résumer, traduire ou analyser
 */
class ClipboardCompanion(private val context: Context) {

    private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    fun getClipboardText(): String? {
        return try {
            val clip = clipboardManager.primaryClip
            if (clip != null && clip.itemCount > 0) {
                clip.getItemAt(0).text?.toString()
            } else null
        } catch (e: Exception) {
            null
        }
    }

    fun setClipboardText(label: String, text: String) {
        try {
            val clip = ClipData.newPlainText(label, text)
            clipboardManager.setPrimaryClip(clip)
        } catch (e: Exception) {}
    }
}
