package com.example.native_code_app

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import android.telephony.SmsMessage
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import java.net.NetworkInterface
import java.util.Collections

class MainActivity : FlutterActivity() {
    private val channelName = "notificationChannel"
    private lateinit var channel: MethodChannel
    private var smsReceiver: BroadcastReceiver? = null
    private val receivedMessages: MutableList<Map<String, String>> = mutableListOf()
    private var isListening = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "toggleListeners" -> {
                    toggleListeners()
                    result.success(isListening)
                }
                "getReceivedMessages" -> {
                    result.success(receivedMessages)
                }
                "getAppName" -> {
                    val packageName = call.arguments as String
                    val appName = getAppNameFromPkgName(applicationContext, packageName)
                    if (appName.isNotEmpty()) {
                        result.success(appName)
                    } else {
                        result.error("NOT_FOUND", "Application name not found", null)
                    }
                }
                "getDeviceInfo" -> {
                    val deviceInfo = getDeviceInfo()
                    result.success(deviceInfo)
                }
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun getDeviceInfo(): Map<String, Any> {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val batteryPercentage: Int = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1

        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val simCardPresent = telephonyManager?.simState == TelephonyManager.SIM_STATE_READY
        val airplaneMode = Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
        val model = Build.MODEL ?: "Unknown"
        val operatingSystem = "Android ${Build.VERSION.RELEASE}"

        // Получение имени мобильного оператора (network_name)
        val networkName = if (simCardPresent && telephonyManager != null) {
            telephonyManager.networkOperatorName ?: "Unknown"
        } else {
            "No SIM Card"
        }

        // Проверка разрешений и получение данных, если версия API >= 23
        val networkPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(android.Manifest.permission.ACCESS_NETWORK_STATE) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Если версия ниже 23, разрешение считается предоставленным
        }

        val smsPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(android.Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Если версия ниже 23, разрешение считается предоставленным
        }

        // Получение IP-адреса через NetworkInterface
        var ipAddress = "Unknown"
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (networkInterface in interfaces) {
                if (networkInterface.name == "wlan0") {
                    val addresses = networkInterface.inetAddresses
                    while (addresses.hasMoreElements()) {
                        val inetAddress = addresses.nextElement()
                        if (!inetAddress.isLoopbackAddress && inetAddress is java.net.Inet4Address) {
                            ipAddress = inetAddress.hostAddress ?: "Unknown"
                            break
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("NetworkInterface", "Error getting IP Address: ${e.message}")
        }

        // Получение координат (latitude и longitude)
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        var latitude = "Unknown"
        var longitude = "Unknown"

        try {
            val locationProviders = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            for (provider in locationProviders) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    val location: Location? = locationManager.getLastKnownLocation(provider)
                    if (location != null) {
                        latitude = location.latitude.toString()
                        longitude = location.longitude.toString()
                        break // Остановка после получения первого валидного местоположения
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("LocationManager", "Error getting location: ${e.message}")
        }

        return mapOf(
            "batteryPercentage" to batteryPercentage,
            "model" to model,
            "operatingSystem" to operatingSystem,
            "simCard" to simCardPresent,
            "airplaneMode" to airplaneMode,
            "networkPermission" to networkPermission,
            "smsPermission" to smsPermission,
            "networkName" to networkName,
            "ipAddress" to ipAddress,
            "latitude" to latitude,
            "longitude" to longitude
        )
    }

    // Включение/выключение всех слушателей
    private fun toggleListeners() {
        if (isListening) {
            stopListeners()
        } else {
            checkPermissions()
        }
    }

    private fun startListeners() {
        startSmsListener()
        isListening = true
    }

    private fun stopListeners() {
        stopSmsListener()
        isListening = false
    }

    // Слушатель SMS
    private fun startSmsListener() {
        if (smsReceiver != null) return

        val intentFilter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")

        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    val pdus = bundle?.get("pdus") as? Array<*> ?: return
                    for (pdu in pdus) {
                        val smsMessage = SmsMessage.createFromPdu(pdu as ByteArray)

                        val originatingAddress = smsMessage.originatingAddress
                        val messageBody = smsMessage.messageBody
                        val timestampMillis = smsMessage.timestampMillis

                        // Сохранение данных сообщения
                        val messageData = mapOf(
                            "from" to (originatingAddress ?: ""),
                            "message" to messageBody,
                            "timestamp" to timestampMillis.toString()
                        )

                        // Добавление сообщения в список полученных сообщений
                        receivedMessages.add(messageData)

                        // Логирование сообщения в консоль для отладки
                        Log.d("SMSReceiver", "🔴 *** SMS FROM: $originatingAddress, MESSAGE: $messageBody, TIMESTAMP: $timestampMillis *** 🔴")

                        // Отправка данных в Flutter
                        channel.invokeMethod("onMessageReceived", messageData)
                    }
                }
            }
        }

        registerReceiver(smsReceiver, intentFilter)
    }

    private fun stopSmsListener() {
        if (smsReceiver != null) {
            unregisterReceiver(smsReceiver)
            smsReceiver = null
        }
    }

    @SuppressLint("NewApi")
    private fun checkPermissions() {
        if (checkSelfPermission(android.Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(android.Manifest.permission.ACCESS_NETWORK_STATE) != PackageManager.PERMISSION_GRANTED) {

            requestPermissions(
                arrayOf(
                    android.Manifest.permission.RECEIVE_SMS,
                    android.Manifest.permission.READ_SMS,
                    android.Manifest.permission.ACCESS_NETWORK_STATE
                ),
                1
            )
        } else {
            startListeners()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1 && grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startListeners()
        } else {
            Toast.makeText(this, "Permissions required!", Toast.LENGTH_SHORT).show()
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

    override fun onDestroy() {
        super.onDestroy()
        stopListeners()
    }
}
