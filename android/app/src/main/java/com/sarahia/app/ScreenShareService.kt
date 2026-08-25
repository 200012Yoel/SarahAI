package com.sarahia.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import java.io.ByteArrayOutputStream

/**
 * Service de Partage d'Écran Numérique et Live Stream pour Android (MediaProjection) :
 * - Capture numérique directe de l'affichage via VirtualDisplay et ImageReader en mémoire
 * - N'utilise PAS la caméra physique et n'enregistre AUCUN fichier dans la galerie
 * - Diffuse les trames capturées en temps réel (15 FPS) vers l'interface UI (PiP / Web)
 */
class ScreenShareService private constructor() {

    companion object {
        private const val TAG = "ScreenShareService"
        val shared = ScreenShareService()
        const val SCREEN_CAPTURE_REQUEST_CODE = 3001
    }

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var isStreaming = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var frameListener: ((Bitmap) -> Unit)? = null
    private var latestBitmap: Bitmap? = null

    fun init(context: Context) {
        mediaProjectionManager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
    }

    fun createScreenCaptureIntent(): Intent? {
        return mediaProjectionManager?.createScreenCaptureIntent()
    }

    fun startScreenCapture(
        activity: Activity,
        resultCode: Int,
        data: Intent,
        onFrame: (Bitmap) -> Unit
    ) {
        if (isStreaming) {
            Log.d(TAG, "Le partage d'écran est déjà actif.")
            return
        }

        this.frameListener = onFrame

        try {
            mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
            if (mediaProjection == null) {
                Log.e(TAG, "Impossible d'obtenir MediaProjection.")
                return
            }

            val windowManager = activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            windowManager.defaultDisplay.getRealMetrics(metrics)

            val width = metrics.widthPixels / 2
            val height = metrics.heightPixels / 2
            val density = metrics.densityDpi

            imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "SarahScreenShare",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface,
                null,
                mainHandler
            )

            isStreaming = true

            imageReader?.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                try {
                    val planes = image.planes
                    val buffer = planes[0].buffer
                    val pixelStride = planes[0].pixelStride
                    val rowStride = planes[0].rowStride
                    val rowPadding = rowStride - pixelStride * width

                    val bitmap = Bitmap.createBitmap(
                        width + rowPadding / pixelStride,
                        height,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.copyPixelsFromBuffer(buffer)

                    val croppedBitmap = if (rowPadding > 0) {
                        Bitmap.createBitmap(bitmap, 0, 0, width, height)
                    } else {
                        bitmap
                    }

                    latestBitmap = croppedBitmap
                    frameListener?.invoke(croppedBitmap)
                } catch (e: Exception) {
                    Log.e(TAG, "Erreur lecture image: ${e.message}")
                } finally {
                    image.close()
                }
            }, mainHandler)

            Log.d(TAG, "✅ Partage d'écran numérique démarré avec succès !")

        } catch (e: Exception) {
            Log.e(TAG, "Erreur lors du démarrage du partage d'écran: ${e.message}")
            stopScreenCapture()
        }
    }

    fun stopScreenCapture() {
        isStreaming = false
        try {
            virtualDisplay?.release()
            virtualDisplay = null
            imageReader?.close()
            imageReader = null
            mediaProjection?.stop()
            mediaProjection = null
            frameListener = null
            Log.d(TAG, "⏹ Partage d'écran arrêté.")
        } catch (e: Exception) {
            Log.e(TAG, "Erreur arrêt partage d'écran: ${e.message}")
        }
    }

    fun isScreenSharingActive(): Boolean = isStreaming

    fun getLatestBitmap(): Bitmap? = latestBitmap
}
