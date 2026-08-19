package com.sarahia.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.UUID

/**
 * Base de données SQLite locale et sécurisée pour l'historique des conversations :
 * - Stockage persistant privé sur l'appareil
 * - Récupération paginée et recherche rapide
 * - Suppression et reprise de sessions de discussion
 */
class ChatDatabase(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "sarah_chat_history.db"
        private const val DATABASE_VERSION = 1

        const val TABLE_MESSAGES = "messages"
        const val COLUMN_ID = "id"
        const val COLUMN_TIMESTAMP = "timestamp"
        const val COLUMN_ROLE = "role" // "user", "assistant", "system"
        const val COLUMN_CONTENT = "content"
        const val COLUMN_LANGUAGE = "language"
        const val COLUMN_SESSION_ID = "session_id"
    }

    data class MessageRecord(
        val id: String,
        val timestamp: Long,
        val role: String,
        val content: String,
        val language: String,
        val sessionId: String
    )

    override fun onCreate(db: SQLiteDatabase) {
        val createTableQuery = """
            CREATE TABLE $TABLE_MESSAGES (
                $COLUMN_ID TEXT PRIMARY KEY,
                $COLUMN_TIMESTAMP INTEGER NOT NULL,
                $COLUMN_ROLE TEXT NOT NULL,
                $COLUMN_CONTENT TEXT NOT NULL,
                $COLUMN_LANGUAGE TEXT DEFAULT 'fr',
                $COLUMN_SESSION_ID TEXT NOT NULL
            )
        """.trimIndent()
        db.execSQL(createTableQuery)
        db.execSQL("CREATE INDEX idx_timestamp ON $TABLE_MESSAGES ($COLUMN_TIMESTAMP DESC)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_MESSAGES")
        onCreate(db)
    }

    /**
     * Sauvegarde un message dans la base locale
     */
    fun insertMessage(role: String, content: String, language: String = "fr", sessionId: String = "default"): String {
        val id = UUID.randomUUID().toString()
        val values = ContentValues().apply {
            put(COLUMN_ID, id)
            put(COLUMN_TIMESTAMP, System.currentTimeMillis())
            put(COLUMN_ROLE, role)
            put(COLUMN_CONTENT, content)
            put(COLUMN_LANGUAGE, language)
            put(COLUMN_SESSION_ID, sessionId)
        }
        writableDatabase.insert(TABLE_MESSAGES, null, values)
        return id
    }

    /**
     * Récupère les derniers messages (paginés)
     */
    fun getRecentMessages(limit: Int = 50, offset: Int = 0): List<MessageRecord> {
        val list = mutableListOf<MessageRecord>()
        val cursor = readableDatabase.query(
            TABLE_MESSAGES,
            null,
            null,
            null,
            null,
            null,
            "$COLUMN_TIMESTAMP ASC",
            "$offset, $limit"
        )
        cursor.use { c ->
            val idIdx = c.getColumnIndexOrThrow(COLUMN_ID)
            val timeIdx = c.getColumnIndexOrThrow(COLUMN_TIMESTAMP)
            val roleIdx = c.getColumnIndexOrThrow(COLUMN_ROLE)
            val contentIdx = c.getColumnIndexOrThrow(COLUMN_CONTENT)
            val langIdx = c.getColumnIndexOrThrow(COLUMN_LANGUAGE)
            val sessionIdx = c.getColumnIndexOrThrow(COLUMN_SESSION_ID)

            while (c.moveToNext()) {
                list.add(
                    MessageRecord(
                        id = c.getString(idIdx),
                        timestamp = c.getLong(timeIdx),
                        role = c.getString(roleIdx),
                        content = c.getString(contentIdx),
                        language = c.getString(langIdx),
                        sessionId = c.getString(sessionIdx)
                    )
                )
            }
        }
        return list
    }

    /**
     * Efface tout l'historique de discussion
     */
    fun clearHistory() {
        writableDatabase.delete(TABLE_MESSAGES, null, null)
    }

    /**
     * Compte le nombre total de messages enregistrés
     */
    fun getMessageCount(): Int {
        val cursor = readableDatabase.rawQuery("SELECT COUNT(*) FROM $TABLE_MESSAGES", null)
        return cursor.use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }
    }
}
