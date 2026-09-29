package com.example.poshaneye

import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Hosts the `poshaneye/landmarks` MethodChannel for the production hybrid
 * inference pipeline. The Dart side is lib/services/hybrid_landmark_bridge.dart;
 * the extraction logic is LandmarkExtractor.kt. No feature math here.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "poshaneye/landmarks"
    private var extractor: LandmarkExtractor? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extract" -> handleExtract(call.argument<ByteArray>("imageBytes"), result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "poshaneye/location")
            .setMethodCallHandler { call, result ->
                if (call.method == "getRegion") handleRegionLookup(result)
                else result.notImplemented()
            }
    }

    @Suppress("MissingPermission") // Dart requests foreground location permission first.
    private fun handleRegionLookup(result: MethodChannel.Result) {
        try {
            val manager = getSystemService(LOCATION_SERVICE) as LocationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                manager.getCurrentLocation(
                    LocationManager.NETWORK_PROVIDER,
                    CancellationSignal(),
                    mainExecutor
                ) { location ->
                    if (location == null) {
                        result.error("location_unavailable", "Could not obtain a current location.", null)
                    } else {
                        reverseGeocode(location, result)
                    }
                }
            } else {
                val location = manager.getProviders(true)
                    .asSequence()
                    .mapNotNull { provider -> manager.getLastKnownLocation(provider) }
                    .maxByOrNull { it.time }
                if (location == null) {
                    result.error("location_unavailable", "Could not obtain a location.", null)
                } else {
                    reverseGeocode(location, result)
                }
            }
        } catch (error: Exception) {
            result.error("location_unavailable", "Location lookup is unavailable.", null)
        }
    }

    private fun reverseGeocode(location: Location, result: MethodChannel.Result) {
        executor.execute {
            try {
                val address = Geocoder(applicationContext, Locale.getDefault())
                    .getFromLocation(location.latitude, location.longitude, 1)
                    ?.firstOrNull()
                val region = address?.let {
                    mapOf(
                        "country" to (it.countryName ?: ""),
                        "state" to (it.adminArea ?: ""),
                        "district" to (it.subAdminArea ?: it.locality ?: "")
                    ).filterValues(String::isNotBlank)
                } ?: emptyMap()
                mainHandler.post { result.success(region) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("geocoding_failed", "Could not determine a general region.", null)
                }
            }
        }
    }

    private fun handleExtract(imageBytes: ByteArray?, result: MethodChannel.Result) {
        if (imageBytes == null || imageBytes.isEmpty()) {
            result.error("missing_bytes", "No image bytes were provided.", null)
            return
        }
        executor.execute {
            try {
                val ex = obtainExtractor()
                val payload = ex.extract(imageBytes)
                mainHandler.post { result.success(payload) }
            } catch (e: InvalidImageException) {
                postError(result, "invalid_image", e.message ?: "Could not decode the image.")
            } catch (e: IllegalArgumentException) {
                // MediaPipe throws IllegalArgumentException for bad model assets/options.
                postError(result, "model_init", "Landmark model failed to initialize: ${e.message}")
            } catch (e: IllegalStateException) {
                postError(result, "model_init", "Landmark model failed to initialize: ${e.message}")
            } catch (e: Exception) {
                postError(result, "extraction_failed", "MediaPipe extraction failed: ${e.message}")
            }
        }
    }

    @Synchronized
    private fun obtainExtractor(): LandmarkExtractor {
        return extractor ?: LandmarkExtractor.create(applicationContext).also { extractor = it }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    override fun onDestroy() {
        executor.shutdown()
        extractor?.close()
        extractor = null
        super.onDestroy()
    }
}
