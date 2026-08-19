package com.sarahia.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log

/**
 * Moniteur Réseau Haute Précision :
 * - Détecte en millisecondes le passage Hors-Ligne ⇄ En-Ligne
 * - Permet la transition fluide entre OpenAI (Cloud) et le modèle local hors-ligne
 */
class NetworkMonitor(context: Context) {

    private val TAG = "SarahNetworkMonitor"
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    @Volatile
    var isConnected: Boolean = false
        private set

    var onNetworkStatusChanged: ((Boolean) -> Unit)? = null

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            isConnected = true
            Log.d(TAG, "🟢 Connexion Internet rétablie.")
            onNetworkStatusChanged?.invoke(true)
        }

        override fun onLost(network: Network) {
            isConnected = false
            Log.d(TAG, "🔴 Connexion Internet perdue. Bascule immédiate sur le modèle hors-ligne.")
            onNetworkStatusChanged?.invoke(false)
        }

        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            val hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                              networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            if (isConnected != hasInternet) {
                isConnected = hasInternet
                onNetworkStatusChanged?.invoke(hasInternet)
            }
        }
    }

    init {
        checkInitialState()
        registerCallback()
    }

    private fun checkInitialState() {
        try {
            val activeNetwork = connectivityManager.activeNetwork
            val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
            isConnected = caps != null && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } catch (e: Exception) {
            isConnected = false
        }
    }

    private fun registerCallback() {
        try {
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            connectivityManager.registerNetworkCallback(request, networkCallback)
        } catch (e: Exception) {
            Log.w(TAG, "Erreur enregistrement network callback: ${e.message}")
        }
    }

    fun unregister() {
        try {
            connectivityManager.unregisterNetworkCallback(networkCallback)
        } catch (e: Exception) {}
    }
}
