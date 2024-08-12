package com.example.project_drone

import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter.native/helper"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "map#addKML" -> {
                    val kmlResource = getKMLResource()
                    val kmlData = loadKMLFromResource(kmlResource)
                    result.success(kmlData)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun loadKMLFromResource(resourceId: Int): String {
        val inputStream = resources.openRawResource(resourceId)
        return inputStream.bufferedReader().use { it.readText() }
    }

    private fun getKMLResource(): Int {
        return R.raw.rawalpindi // Assuming the file is named rawalpindi.kml in res/raw folder
    }
}
