package com.example.app_asistencia

import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val officeZone = TimeZone.getTimeZone("America/Mexico_City")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app_asistencia/clock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sample" -> {
                        val boot = Settings.Global.getInt(contentResolver, "boot_count", -1)
                        result.success(listOf(boot, SystemClock.elapsedRealtime()))
                    }
                    "officeOffset" -> {
                        val epochMs = (call.arguments as Number).toLong()
                        result.success(officeZone.getOffset(epochMs))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
