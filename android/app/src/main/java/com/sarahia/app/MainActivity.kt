package com.sarahia.app

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private val TAG = "SarahMainActivity"
    private var webView: WebView? = null
    private var voiceManager: VoiceManager? = null
    private var chatDatabase: ChatDatabase? = null
    private var networkMonitor: NetworkMonitor? = null
    private val RECORD_AUDIO_REQUEST_CODE = 2001
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        chatDatabase = ChatDatabase(this)
        networkMonitor = NetworkMonitor(this)

        initWebView()
        initVoiceEngine()
        checkAndRequestPermissions()
        startVoiceService()
    }

    private fun startVoiceService() {
        try {
            val serviceIntent = Intent(this, SarahVoiceForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Démarrage foreground service: ${e.message}")
        }
    }

    private fun initWebView() {
        try {
            val wv = findViewById<WebView>(R.id.webView) ?: return
            this.webView = wv

            wv.setBackgroundColor(Color.parseColor("#030308"))
            wv.setLayerType(View.LAYER_TYPE_HARDWARE, null)

            val s = wv.settings
            s.javaScriptEnabled = true
            s.domStorageEnabled = true
            s.databaseEnabled = true
            s.allowFileAccess = true
            s.allowContentAccess = true
            s.mediaPlaybackRequiresUserGesture = false
            s.loadWithOverviewMode = true
            s.useWideViewPort = true
            s.cacheMode = WebSettings.LOAD_DEFAULT

            try {
                s.allowFileAccessFromFileURLs = true
                s.allowUniversalAccessFromFileURLs = true
            } catch (e: Exception) {
                Log.w(TAG, "Universal access flag: ${e.message}")
            }

            wv.addJavascriptInterface(SarahNativeBridge(), "SarahBridge")

            wv.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    return false
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "✅ Interface chargée.")
                    updateWebStatus("Sarah vous écoute en continu")
                }
            }

            wv.webChromeClient = object : WebChromeClient() {
                override fun onPermissionRequest(request: PermissionRequest?) {
                    try {
                        request?.grant(request.resources)
                    } catch (e: Exception) {
                        Log.e(TAG, "Erreur grant permission: ${e.message}")
                    }
                }
            }

            wv.loadUrl("file:///android_asset/sarah_ai_web.html")

        } catch (e: Exception) {
            Log.e(TAG, "Erreur WebView: ${e.message}")
        }
    }

    private fun initVoiceEngine() {
        try {
            voiceManager = VoiceManager(
                context = this,
                onStatusUpdate = { status ->
                    updateWebStatus(status)
                },
                onSpeakingStateChanged = { isSpeaking ->
                    setWebAvatarSpeaking(isSpeaking)
                },
                onLiveTranscription = { liveText ->
                    setWebLiveTranscription(liveText)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Erreur VoiceManager: ${e.message}")
        }
    }

    private fun checkAndRequestPermissions() {
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.RECORD_AUDIO),
                    RECORD_AUDIO_REQUEST_CODE
                )
            } else {
                mainHandler.postDelayed({
                    voiceManager?.startContinuousListening()
                }, 800)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Erreur permission: ${e.message}")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "✅ Permission micro accordée.")
                voiceManager?.startContinuousListening()
            }
        }
    }

    private fun updateWebStatus(text: String) {
        mainHandler.post {
            try {
                val safe = text.replace("'", "\\'")
                webView?.evaluateJavascript("if (window.updateStatus) { window.updateStatus('$safe'); }", null)
            } catch (e: Exception) {}
        }
    }

    private fun setWebAvatarSpeaking(isSpeaking: Boolean) {
        mainHandler.post {
            try {
                webView?.evaluateJavascript("if (window.setSpeaking) { window.setSpeaking($isSpeaking); }", null)
            } catch (e: Exception) {}
        }
    }

    private fun setWebLiveTranscription(text: String) {
        mainHandler.post {
            try {
                val safe = text.replace("'", "\\'")
                webView?.evaluateJavascript("if (window.updateStatus) { window.updateStatus('$safe'); }", null)
            } catch (e: Exception) {}
        }
    }

    inner class SarahNativeBridge {
        @JavascriptInterface
        fun onUserSpoke(text: String) {
            val userText = text.trim()
            if (userText.isEmpty()) return
            Log.d(TAG, "Message reçu depuis interface: $userText")
            chatDatabase?.insertMessage(role = "user", content = userText)
            
            voiceManager?.getBrain()?.getAnswerAsync(userText) { reply ->
                chatDatabase?.insertMessage(role = "assistant", content = reply)
                mainHandler.post {
                    voiceManager?.speak(reply)
                }
            }
        }

        @JavascriptInterface
        fun stopSpeaking() {
            voiceManager?.stopSpeaking()
        }

        @JavascriptInterface
        fun startListening() {
            voiceManager?.startContinuousListening()
        }

        @JavascriptInterface
        fun onAvatarTapped(zone: String) {
            Log.d(TAG, "Avatar touché: $zone")
            val quips = if (zone == "head") {
                listOf("Oui ? Je suis là !", "Coucou !", "Je t'écoute attentivement !", "Comment puis-je t'aider ?")
            } else {
                listOf("Bonjour !", "Je suis prête !", "Tout va bien !")
            }
            val randomQuip = quips.random()
            mainHandler.post {
                voiceManager?.speak(randomQuip)
            }
        }

        @JavascriptInterface
        fun getChatHistoryJson(): String {
            val list = chatDatabase?.getRecentMessages(100) ?: emptyList()
            val arr = org.json.JSONArray()
            for (m in list) {
                val o = org.json.JSONObject()
                o.put("id", m.id)
                o.put("timestamp", m.timestamp)
                o.put("role", m.role)
                o.put("content", m.content)
                o.put("language", m.language)
                arr.put(o)
            }
            return arr.toString()
        }

        @JavascriptInterface
        fun clearChatHistory() {
            chatDatabase?.clearHistory()
        }

        @JavascriptInterface
        fun setOpenAIKey(key: String) {
            getSharedPreferences("sarah_ai_openai", Context.MODE_PRIVATE)
                .edit().putString("openai_api_key", key.trim()).apply()
        }

        @JavascriptInterface
        fun getOpenAIKey(): String {
            return getSharedPreferences("sarah_ai_openai", Context.MODE_PRIVATE)
                .getString("openai_api_key", "") ?: ""
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            webView?.onResume()
            voiceManager?.startContinuousListening()
        } catch (e: Exception) {}
    }

    override fun onPause() {
        try {
            voiceManager?.stopSpeaking()
            voiceManager?.stopListening()
            webView?.onPause()
        } catch (e: Exception) {}
        super.onPause()
    }

    override fun onDestroy() {
        try {
            voiceManager?.destroy()
            voiceManager = null
            webView?.destroy()
        } catch (e: Exception) {}
        super.onDestroy()
    }
}
