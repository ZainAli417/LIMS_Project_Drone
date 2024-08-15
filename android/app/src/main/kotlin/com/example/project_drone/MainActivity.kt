package com.example.project_drone

import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "flutter.native/helper"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "KML" -> {
                    result.success(getKMLResource())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getKMLResource(): Int {
        return R.raw.sample // Ensure this corresponds to a valid KML file in res/raw
    }
}
