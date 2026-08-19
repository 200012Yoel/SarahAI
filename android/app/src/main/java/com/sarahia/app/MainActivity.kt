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
    private val RECORD_AUDIO_REQUEST_CODE = 2001
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initWebView()
        initVoiceEngine()
        checkAndRequestPermissions()
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

                override fun shouldInterceptRequest(
                    view: WebView?,
                    request: WebResourceRequest?
                ): android.webkit.WebResourceResponse? {
                    val url = request?.url?.toString() ?: return null
                    if (url.endsWith("Sarah.vrm", ignoreCase = true) || url.endsWith("AA.vrm", ignoreCase = true)) {
                        try {
                            val isStream = assets.open("Sarah.vrm")
                            val response = android.webkit.WebResourceResponse("model/gltf-binary", "UTF-8", isStream)
                            val headers = HashMap<String, String>()
                            headers["Access-Control-Allow-Origin"] = "*"
                            headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
                            headers["Access-Control-Allow-Headers"] = "*"
                            response.responseHeaders = headers
                            return response
                        } catch (e: Exception) {
                            Log.w(TAG, "Interception VRM asset: ${e.message}")
                        }
                    }
                    return super.shouldInterceptRequest(view, request)
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "✅ Page 3D VRM chargée.")
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
            Log.d(TAG, "Message reçu: $text")
        }

        @JavascriptInterface
        fun stopSpeaking() {
            voiceManager?.stopSpeaking()
        }

        @JavascriptInterface
        fun startListening() {
            voiceManager?.startContinuousListening()
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
