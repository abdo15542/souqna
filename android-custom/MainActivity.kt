package com.souqna.app

import android.content.Intent
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // === Installer channel ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souqna/installer")
            .setMethodCallHandler { call, result ->
                if (call.method == "install") {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("no_url", "missing url", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val conn = URL(url).openConnection() as HttpURLConnection
                            conn.connectTimeout = 15000
                            conn.readTimeout = 60000
                            conn.instanceFollowRedirects = true
                            val file = File(cacheDir, "souqna-update.apk")
                            conn.inputStream.use { input ->
                                file.outputStream().use { out -> input.copyTo(out) }
                            }
                            val uri = FileProvider.getUriForFile(this@MainActivity, "$packageName.fileprovider", file)
                            startActivity(Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            })
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("install_failed", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
        
        // === Share channel ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souqna/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "share") {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name") ?: "backup.db"
                    if (path.isNullOrEmpty()) {
                        result.error("no_path", "missing", null)
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(this@MainActivity, "$packageName.fileprovider", File(path))
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, "مشاركة النسخة"))
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
        
        // === Biometric channel ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souqna/biometric")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val manager = BiometricManager.from(this@MainActivity)
                        val canAuth = manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                        result.success(canAuth == BiometricManager.BIOMETRIC_SUCCESS)
                    }
                    "authenticate" -> {
                        val message = call.argument<String>("message") ?: "أدخل البصمة لفتح التطبيق"
                        
                        // استخدام activity property المتاح في FlutterActivity بدلاً من this
                        val fragmentActivity = this@MainActivity.activity as? androidx.fragment.app.FragmentActivity
                        if (fragmentActivity == null) {
                            result.error("no_activity", "Cannot get FragmentActivity", null)
                            return@setMethodCallHandler
                        }
                        
                        val executor = ContextCompat.getMainExecutor(fragmentActivity)
                        val biometricPrompt = BiometricPrompt(fragmentActivity, executor,
                            object : BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(authenticationResult: BiometricPrompt.AuthenticationResult) {
                                    super.onAuthenticationSucceeded(authenticationResult)
                                    result.success(true)
                                }
                                
                                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                    super.onAuthenticationError(errorCode, errString)
                                    result.error("auth_error", errString.toString(), null)
                                }
                                
                                override fun onAuthenticationFailed() {
                                    super.onAuthenticationFailed()
                                    result.success(false)
                                }
                            })
                        
                        val promptInfo = BiometricPrompt.PromptInfo.Builder()
                            .setTitle("التحقق من الهوية")
                            .setSubtitle(message)
                            .setNegativeButtonText("استخدام الرقم السري")
                            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                            .build()
                        
                        biometricPrompt.authenticate(promptInfo)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
