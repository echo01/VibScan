package com.example.viot_monitor

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.provider.MediaStore
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "viot_monitor/mobile_wifi"
    private val scanPermissionRequestCode = 4102
    private var pendingScanResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanWifiNetworks" -> scanWifiNetworks(result)
                "getCurrentWifi" -> result.success(currentWifiMap())
                "openWifiSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                    result.success(true)
                }
                "saveCsvToDownloads" -> saveCsvToDownloads(
                    fileName = call.argument<String>("fileName") ?: "viot_export.csv",
                    content = call.argument<String>("content") ?: "",
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun scanWifiNetworks(result: MethodChannel.Result) {
        if (!hasWifiScanPermissions()) {
            pendingScanResult = result
            requestWifiScanPermissions()
            return
        }

        returnScanResults(result)
    }

    private fun hasWifiScanPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        val hasLocation = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasNearbyWifi = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED

        return hasLocation && hasNearbyWifi
    }

    private fun requestWifiScanPermissions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            pendingScanResult?.let { returnScanResults(it) }
            pendingScanResult = null
            return
        }

        val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }

        requestPermissions(permissions.toTypedArray(), scanPermissionRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != scanPermissionRequestCode) {
            return
        }

        val result = pendingScanResult ?: return
        pendingScanResult = null

        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            returnScanResults(result)
        } else {
            result.error(
                "wifi_scan_permission_denied",
                "WiFi scanning requires Location/Nearby WiFi permission.",
                null,
            )
        }
    }

    private fun returnScanResults(result: MethodChannel.Result) {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

        try {
            wifiManager.startScan()
        } catch (_: SecurityException) {
            result.error(
                "wifi_scan_permission_denied",
                "Android blocked WiFi scan because required permissions are missing.",
                null,
            )
            return
        }

        val current = currentWifiMap()
        val currentSsid = current["ssid"] as? String
        val currentBssid = current["bssid"] as? String

        try {
            val networks = wifiManager.scanResults
                .filter { it.SSID.isNotBlank() }
                .groupBy { it.SSID }
                .map { (_, candidates) -> candidates.maxByOrNull { it.level }!! }
                .sortedByDescending { it.level }
                .map {
                    mapOf(
                        "ssid" to it.SSID,
                        "bssid" to it.BSSID,
                        "capabilities" to it.capabilities,
                        "level" to it.level,
                        "frequency" to it.frequency,
                        "isConnected" to (it.SSID == currentSsid || it.BSSID == currentBssid),
                    )
                }

            result.success(networks)
        } catch (error: SecurityException) {
            result.error(
                "wifi_scan_permission_denied",
                "Android blocked WiFi scan because Location service or permission is unavailable.",
                error.message,
            )
        }
    }

    private fun currentWifiMap(): Map<String, Any?> {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = wifiManager.connectionInfo
        val rawSsid = info?.ssid
        val ssid = rawSsid
            ?.removePrefix("\"")
            ?.removeSuffix("\"")
            ?.takeUnless { it == "<unknown ssid>" }

        return mapOf(
            "ssid" to ssid,
            "bssid" to info?.bssid,
            "level" to info?.rssi,
            "frequency" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) info?.frequency else null,
        )
    }

    private fun saveCsvToDownloads(fileName: String, content: String, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/csv")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Unable to create Downloads file")

                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(content.toByteArray(Charsets.UTF_8))
                } ?: throw IllegalStateException("Unable to open Downloads file")

                result.success("Downloads/$fileName")
                return
            }

            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloads.exists()) {
                downloads.mkdirs()
            }
            val file = File(downloads, fileName)
            file.writeText(content, Charsets.UTF_8)
            result.success(file.absolutePath)
        } catch (error: Exception) {
            result.error("downloads_save_failed", error.message, null)
        }
    }
}
