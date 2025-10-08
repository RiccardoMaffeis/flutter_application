package com.example.flutter_application

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.ar.core.ArCoreApk
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "arcore/check"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAvailability" -> {
                        val availability = ArCoreApk.getInstance().checkAvailability(this)
                        // Esempi: SUPPORTED_INSTALLED, SUPPORTED_APK_TOO_OLD, SUPPORTED_NOT_INSTALLED, UNKNOWN_CHECKING, UNKNOWN_TIMED_OUT, UNSUPPORTED_DEVICE_NOT_CAPABLE
                        result.success(availability.toString())
                    }

                    "requestInstall" -> {
                        val userRequestedInstall = call.argument<Boolean>("userRequestedInstall") ?: true
                        try {
                            val status = ArCoreApk.getInstance().requestInstall(this, userRequestedInstall)
                            // Ritorna INSTALLED o INSTALL_REQUESTED
                            result.success(status.toString())
                        } catch (e: Exception) {
                            result.error("REQUEST_INSTALL_ERROR", e.message, null)
                        }
                    }

                    "openPlayStore" -> {
                        val market = Uri.parse("market://details?id=com.google.ar.core")
                        val web = Uri.parse("https://play.google.com/store/apps/details?id=com.google.ar.core")
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, market).apply {
                                setPackage("com.android.vending")
                            })
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            startActivity(Intent(Intent.ACTION_VIEW, web))
                            result.success(true)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
