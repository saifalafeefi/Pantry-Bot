package com.example.pantrybot

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.pantrybot/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        val success = installApk(apkPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun installApk(apkPath: String): Boolean {
        return try {
            val apkFile = File(apkPath)
            if (!apkFile.exists()) {
                return false
            }

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Use FileProvider for Android 7.0+
                val apkUri = FileProvider.getUriForFile(
                    this,
                    "com.example.pantrybot.fileprovider",
                    apkFile
                )
                intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                // Direct file URI for older Android versions
                intent.setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
            }

            // Try multiple approaches for OnePlus compatibility
            try {
                // Method 1: Direct startActivity
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // Method 2: Try with different flags
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                try {
                    startActivity(intent)
                    return true
                } catch (e2: Exception) {
                    // Method 3: Try INSTALL_PACKAGE action (requires permission)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (packageManager.canRequestPackageInstalls()) {
                            val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE)
                            installIntent.data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                FileProvider.getUriForFile(this, "com.example.pantrybot.fileprovider", apkFile)
                            } else {
                                Uri.fromFile(apkFile)
                            }
                            installIntent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                            try {
                                startActivity(installIntent)
                                return true
                            } catch (e3: Exception) {
                                return false
                            }
                        }
                    }
                    return false
                }
            }
        } catch (e: Exception) {
            false
        }
    }
} 