package com.example.native_code_app

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.telephony.SmsMessage
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val channelName = "uniqueChannelName"
    private lateinit var channel: MethodChannel
    private var smsReceiver: BroadcastReceiver? = null
    private val receivedMessages: MutableList<String> = mutableListOf()
    private var isListening = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "toggleSmsListener" -> {
                    toggleSmsListener()
                    result.success(isListening)
                }
                "getReceivedMessages" -> {
                    result.success(receivedMessages)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun toggleSmsListener() {
        if (isListening) {
            stopSmsListener()
        } else {
            checkSmsPermissions()
        }
    }

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

                        // Получение всех возможных данных из сообщения
                        val originatingAddress = smsMessage.originatingAddress       // Номер отправителя
                        val messageBody = smsMessage.messageBody                     // Текст сообщения
                        val timestampMillis = smsMessage.timestampMillis             // Время отправки сообщения
                        val serviceCenterAddress = smsMessage.serviceCenterAddress   // Адрес центра обслуживания SMS

                        Log.d("SMSReceiver", "Message received:")
                        Log.d("SMSReceiver", "From: $originatingAddress")
                        Log.d("SMSReceiver", "Message: $messageBody")
                        Log.d("SMSReceiver", "Timestamp: $timestampMillis")
                        Log.d("SMSReceiver", "Service Center Address: $serviceCenterAddress")

                        // Сохранение всех данных в удобном формате
                        val messageData = mapOf(
                            "from" to originatingAddress,
                            "message" to messageBody,
                            "timestamp" to timestampMillis,
                            "serviceCenterAddress" to serviceCenterAddress,
                        )

                        // Добавление данных в список
                        receivedMessages.add(messageData.toString())

                        // Отправка данных в Flutter
                        channel.invokeMethod("onMessageReceived", messageData)
                    }
                }
            }
        }

        registerReceiver(smsReceiver, intentFilter)
        isListening = true
        Log.d("SMSReceiver", "SMS Listener started")
    }

    private fun stopSmsListener() {
        if (smsReceiver != null) {
            unregisterReceiver(smsReceiver)
            smsReceiver = null
            isListening = false
            Log.d("SMSReceiver", "SMS Listener stopped")
        }
    }

    @SuppressLint("NewApi")
    private fun checkSmsPermissions() {
        if (checkSelfPermission(android.Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {

            requestPermissions(
                arrayOf(
                    android.Manifest.permission.RECEIVE_SMS,
                    android.Manifest.permission.READ_SMS
                ),
                1
            )
        } else {
            startSmsListener()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startSmsListener()
        } else {
            Toast.makeText(this, "SMS permissions required!", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopSmsListener()
    }
}