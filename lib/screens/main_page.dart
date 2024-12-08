// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart'; // Добавленный импорт для работы с разрешениями
import 'package:native_code_app/screens/login_screen.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> receivedNotifications = [];
  bool isListening = false; // Переключатель слушателей (по умолчанию выключен)
  StreamSubscription<ServiceNotificationEvent>? _notificationSubscription;
  Map<String, String> packageNames = {};
  String? _lastSmsContent;
  Timer? _healthCheckTimer;
  String terminalId = "Unknown";

  static const platform = MethodChannel('notificationChannel');

  @override
  void initState() {
    super.initState();
    _initializeListeners(); // Инициализация слушателей
    _setSmsListener(); // Установка обработчика для получения SMS
    _startHealthCheckTimer(); // Запуск таймера для healthcheck
    _loadTerminalId(); // Загрузка terminalId из SharedPreferences
  }

  @override
  void dispose() {
    _stopNotificationListener();
    _stopHealthCheckTimer();
    super.dispose();
  }

  // Метод для получения имен приложений из их packageName
  Future<String> _getAppName(String packageName) async {
    if (packageNames.containsKey(packageName)) {
      return packageNames[packageName]!;
    }
    try {
      final String appName =
          await platform.invokeMethod('getAppName', packageName);
      packageNames[packageName] = appName;
      return appName;
    } catch (e) {
      log('🔴 *** Error getting app name: $e *** 🔴');
      return packageName;
    }
  }

  // Инициализация всех слушателей
  void _initializeListeners() async {
    await _checkAndRequestNotificationPermission();
    setState(() {
      isListening = false; // Оставляем слушатели выключенными по умолчанию
    });
  }

  // Проверка разрешений для уведомлений
  Future<void> _checkAndRequestNotificationPermission() async {
    final permissionGranted =
        await NotificationListenerService.isPermissionGranted();
    if (!permissionGranted) {
      await NotificationListenerService.requestPermission();
    }
  }

  // Переключение всех слушателей
  Future<void> _toggleListeners() async {
    try {
      final bool result =
          await platform.invokeMethod('toggleListeners') ?? false;
      setState(() {
        isListening = result;
      });

      if (isListening) {
        _startNotificationListener();
      } else {
        _stopNotificationListener();
      }
    } on PlatformException catch (e) {
      log("🔴 *** Error toggling listeners: ${e.message} *** 🔴");
    }
  }

// Запуск слушателя уведомлений
  void _startNotificationListener() {
    _notificationSubscription ??=
        NotificationListenerService.notificationsStream.listen(
      (event) async {
        try {
          final appName = await _getAppName(event.packageName ?? '');
          final DateTime timestamp = DateTime.now();
          final int unixTimestamp = timestamp.millisecondsSinceEpoch;

          final SharedPreferences prefs = await SharedPreferences.getInstance();
          final String? token = prefs.getString('token');
          final String? terminalId = prefs.getString('terminalId');

          if (token == null || terminalId == null) {
            log("🔴 *** Token or terminalId not found in shared preferences *** 🔴");
            return;
          }

          final Map<String, dynamic> body = {
            "terminal_id": terminalId,
            "sender": event.packageName ?? '',
            "title": event.title ?? '',
            "text": event.content ?? '',
            "date_time":
                unixTimestamp, // Используем Unix Timestamp как целое число
          };

          // Отправка уведомления на сервер
          final response = await http.post(
            Uri.parse(
                'https://flackopay.net/api/payment-verifications/notifications'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );

          if (response.statusCode == 200) {
            log("🟢 *** Notification successfully sent to server *** 🟢");
            setState(() {
              receivedNotifications.add({
                "type": "NOTIFICATION received",
                "notification": ServiceNotificationEvent(
                  id: event.id,
                  packageName: appName,
                  title: event.title,
                  content: event.content,
                  appIcon: event.appIcon,
                ),
                "timestamp":
                    DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp),
                "isExpanded": false,
              });
            });
          } else {
            log("🔴 *** Failed to send notification: ${response.statusCode}, response: ${response.body}, body: ${jsonEncode(body)} *** 🔴");
          }
        } catch (e) {
          log("🔴 *** Error processing notification: $e *** 🔴");
        }
      },
    );
  }

  // Остановка слушателя уведомлений
  void _stopNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  // Метод для установки слушателя SMS через платформенный канал
  void _setSmsListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "onMessageReceived") {
        final Map<String, dynamic> messageData =
            Map<String, dynamic>.from(call.arguments);
        _handleIncomingSms(messageData);
      }
    });
  }

  // Метод для обработки входящих SMS и добавления их в список
  void _handleIncomingSms(Map<String, dynamic> messageData) async {
    try {
      final int unixTimestamp = int.parse(messageData["timestamp"]);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final String? terminalId = prefs.getString('terminalId');

      if (token == null || terminalId == null) {
        log("🔴 *** Token or terminalId not found in shared preferences *** 🔴");
        return;
      }

      final Map<String, dynamic> body = {
        "terminal_id": terminalId,
        "sender": messageData["from"],
        "text": messageData["message"],
        "date_time": unixTimestamp, // Используем Unix Timestamp как целое число
      };

      // Отправляем SMS на сервер
      final response = await http.post(
        Uri.parse('https://flackopay.net/api/payment-verifications/sms'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        log("🟢 *** SMS successfully sent to server *** 🟢");
        _lastSmsContent = messageData["message"];
        setState(() {
          receivedNotifications.add({
            "type": "SMS received",
            "sms": {
              "from": messageData["from"],
              "message": messageData["message"],
            },
            "timestamp": DateFormat('dd-MM-yyyy HH:mm:ss')
                .format(DateTime.fromMillisecondsSinceEpoch(unixTimestamp)),
            "isExpanded": false,
          });
        });
      } else {
        log("🔴 *** Failed to send SMS: ${response.statusCode}, response: ${response.body}, body: ${jsonEncode(body)} *** 🔴");
      }
    } catch (e) {
      log("🔴 *** Error processing SMS: $e *** 🔴");
    }
  }

  // Метод для регулярного выполнения healthcheck
  void _startHealthCheckTimer() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHealthCheck();
    });
  }

  void _stopHealthCheckTimer() {
    _healthCheckTimer?.cancel();
  }

  // Функция для получения внешнего IP-адреса
  Future<String> _getExternalIPAddress() async {
    try {
      final response =
          await http.get(Uri.parse('https://api64.ipify.org?format=json'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['ip'] ?? "Unknown";
      } else {
        log("🔴 *** Failed to get external IP address, status code: ${response.statusCode} *** 🔴");
        return "Unknown";
      }
    } catch (e) {
      log("🔴 *** Error getting external IP address: $e *** 🔴");
      return "Unknown";
    }
  }

  Future<void> _sendHealthCheck() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final String? terminalId = prefs.getString('terminalId');

      if (token == null || terminalId == null) {
        log("🔴 *** Token or terminalId not found in shared preferences for healthcheck *** 🔴");
        return;
      }

      // Вызов платформенного метода для получения данных об устройстве
      final Map<dynamic, dynamic>? deviceInfo =
          await platform.invokeMethod('getDeviceInfo');

      if (deviceInfo == null) {
        log("🔴 *** Failed to get device info from native code *** 🔴");
        return;
      }

      // Получение внешнего IP-адреса
      final String externalIpAddress = await _getExternalIPAddress();

      // Отправка запроса на сервер с реальными данными
      final Map<String, dynamic> body = {
        "sim_card": deviceInfo['simCard'] ?? false,
        "airplane_mode": deviceInfo['airplaneMode'] ?? false,
        "battery_percentage": deviceInfo['batteryPercentage'] ?? 0,
        "model": deviceInfo['model'] ?? "Unknown",
        "operating_system": deviceInfo['operatingSystem'] ?? "Unknown",
        "network_permission": await Permission.phone.isGranted,
        "sms_permission": await Permission.sms.isGranted,
        "notification_permission": isListening,
        "network_name": deviceInfo['networkName'] ?? "Unknown",
        "ip_address": externalIpAddress, // Использование внешнего IP-адреса
        "latitude": deviceInfo['latitude'] ?? "Unknown",
        "longitude": deviceInfo['longitude'] ?? "Unknown"
      };

      final response = await http.patch(
        Uri.parse(
            'https://flackopay.net/api/v2/terminals/$terminalId/healthcheck'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        log("🟢 *** Healthcheck successfully sent to server *** 🟢");
      } else {
        log("🔴 *** Failed to send healthcheck: ${response.statusCode}, response: ${response.body}, body: ${jsonEncode(body)} *** 🔴");
      }
    } catch (e) {
      log("🔴 *** Error sending healthcheck: $e *** 🔴");
    }
  }

// Метод для загрузки terminalId из SharedPreferences
  Future<void> _loadTerminalId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      terminalId = prefs.getString('terminalId') ?? "Unknown";
    });
  }

  // Логаут с остановкой всех слушателей и таймера healthcheck
  Future<void> _logout() async {
    _stopNotificationListener();
    _stopHealthCheckTimer();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'Идентификатор Терминала: $terminalId',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF54D50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                minimumSize: const Size(43, 30),
              ),
              child: const Text(
                'Выйти',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: 50,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FlackoPay',
                    style: TextStyle(
                      fontFamily: 'Aclonica',
                      fontSize: 24,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text(
                "Захват и передача уведомлений и SMS",
                style: TextStyle(color: Colors.black),
              ),
              value: isListening,
              onChanged: (value) {
                _toggleListeners();
              },
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF086AEB),
              inactiveThumbColor: const Color(0xFF086AEB),
              inactiveTrackColor: Colors.transparent,
              trackOutlineColor:
                  MaterialStateProperty.all(const Color(0xFF086AEB)),
            ),
            const SizedBox(height: 20),
            const Text(
              "Логи",
              style: TextStyle(
                color: Color(0xFF086AEB),
                fontWeight: FontWeight.w500,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: SvgPicture.asset(
                        'assets/images/background_mainpage_logo.svg',
                        height: MediaQuery.of(context).size.height * 0.36,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.15),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    RawScrollbar(
                      thumbVisibility: true,
                      radius: const Radius.circular(10),
                      thickness: 5,
                      thumbColor: const Color(0xFF086AEB),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: receivedNotifications.length,
                        itemBuilder: (context, index) {
                          final notificationMap = receivedNotifications[index];
                          final String type = notificationMap["type"] ??
                              "NOTIFICATION received";
                          final String timestamp =
                              notificationMap["timestamp"] ?? 'Unknown Time';
                          final bool isExpanded =
                              notificationMap["isExpanded"] ?? false;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                notificationMap["isExpanded"] = !isExpanded;
                              });
                            },
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            type,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w400,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            timestamp,
                                            style: const TextStyle(
                                              color: Color(0xFF086AEB),
                                              fontWeight: FontWeight.w400,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (type == "SMS received") ...[
                                        Text(
                                          'Sender: "${notificationMap["sms"]["from"]}"',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (isExpanded)
                                          Text(
                                            'Message: "${notificationMap["sms"]["message"]}"',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                      ] else if (type ==
                                          "NOTIFICATION received") ...[
                                        Text(
                                          'Sender: "${notificationMap["notification"].packageName}"',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (isExpanded) ...[
                                          if (notificationMap["notification"]
                                                  .title !=
                                              null)
                                            Text(
                                              'Title: "${notificationMap["notification"].title}"',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          if (notificationMap["notification"]
                                                  .content !=
                                              null)
                                            Text(
                                              'Body: "${notificationMap["notification"].content}"',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
