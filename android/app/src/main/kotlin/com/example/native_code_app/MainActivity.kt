package com.example.native_code_app

import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.util.Log

class MainActivity : FlutterActivity() {
    private val channelName = "notificationChannel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppName" -> {
                    val packageName = call.arguments as String
                    val appName = getAppNameFromPkgName(applicationContext, packageName)
                    if (appName.isNotEmpty()) {
                        result.success(appName)
                    } else {
                        result.error("NOT_FOUND", "Application name not found", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getAppNameFromPkgName(context: Context, packageName: String): String {
        return try {
            val packageManager: PackageManager = context.packageManager
            val applicationInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            ""
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val filter = IntentFilter().apply {
            addAction("android.intent.action.PACKAGE_ADDED")
            addAction("android.intent.action.PACKAGE_REMOVED")
            addAction("android.intent.action.PACKAGE_REPLACED")
            addDataScheme("package")
        }
        registerReceiver(AppInstalledListener(), filter)
    }

    inner class AppInstalledListener : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            when (action) {
                "android.intent.action.PACKAGE_ADDED", "android.intent.action.PACKAGE_REMOVED", "android.intent.action.PACKAGE_REPLACED" -> {
                    Log.d("AppInstalledListener", "DATA: " + intent.data.toString())
                }
            }
        }
    }
}
