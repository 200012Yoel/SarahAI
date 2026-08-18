package com.sarahia.app

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.WindowManager
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
        
        try {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            )
        } catch (e: Exception) {
            Log.w(TAG, "FLAG_LAYOUT_NO_LIMITS: ${e.message}")
        }

        setContentView(R.layout.activity_main)

        initWebView()
        initVoiceEngine()
        checkAndRequestPermissions()
    }

    private fun initWebView() {
        try {
            val wv = findViewById<WebView>(R.id.webView)
            this.webView = wv

            wv.setBackgroundColor(Color.BLACK)
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
                    Log.d(TAG, "✅ Page 3D VRM chargée.")
                    updateWebStatus("Sarah est prête • Parlez-lui directement")
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
            val safe = text.replace("'", "\\'")
            webView?.evaluateJavascript("if (window.updateStatus) { window.updateStatus('$safe'); }", null)
        }
    }

    private fun setWebAvatarSpeaking(isSpeaking: Boolean) {
        mainHandler.post {
            webView?.evaluateJavascript("if (window.setSpeaking) { window.setSpeaking($isSpeaking); }", null)
        }
    }

    private fun setWebLiveTranscription(text: String) {
        mainHandler.post {
            val safe = text.replace("'", "\\'")
            webView?.evaluateJavascript("if (window.updateStatus) { window.updateStatus('$safe'); }", null)
        }
    }

    inner class SarahNativeBridge {
        @JavascriptInterface
        fun onUserSpoke(text: String) {
            Log.d(TAG, "Message reçu depuis le Web: $text")
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
        webView?.onResume()
        voiceManager?.startContinuousListening()
    }

    override fun onPause() {
        voiceManager?.stopSpeaking()
        voiceManager?.stopListening()
        webView?.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        voiceManager?.destroy()
        voiceManager = null
        try {
            webView?.destroy()
        } catch (e: Exception) {}
        super.onDestroy()
    }
}
