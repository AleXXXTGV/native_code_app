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
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; // Для работы с геолокацией
import 'package:native_code_app/screens/login_screen.dart';
import 'dart:io'; // Нужно для exit(0)

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> receivedNotifications = [];
  bool isListening = false;
  StreamSubscription<ServiceNotificationEvent>? _notificationSubscription;
  Map<String, String> packageNames = {};
  String? _lastSmsContent;
  Timer? _healthCheckTimer;
  Timer? _locationCheckTimer;
  String terminalId = "Unknown";
  bool isCheckingLocation = false;

  static const platform = MethodChannel('notificationChannel');

  @override
  void initState() {
    super.initState();
    _setSmsListener(); // Установка обработчика для получения SMS
    _loadTerminalIdAndCheck(); // Сначала загружаем и проверяем terminalId
  }

  /// **Запускает таймер для `_sendHealthCheck()` каждые 30 секунд**
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel(); // Если таймер уже запущен, сбрасываем его
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHealthCheck();
    });
  }

  @override
  void dispose() {
    _stopNotificationListener();
    _stopHealthCheckTimer();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

  /// **Загрузка terminalId и проверка**
  Future<void> _loadTerminalIdAndCheck() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storedTerminalId = prefs.getString('terminalId');

    if (storedTerminalId == null || storedTerminalId.isEmpty) {
      log("🔴 *** Terminal ID not found, logging out... *** 🔴");
      _logout(); // Если terminalId нет, выходим из системы
      return;
    }

    setState(() {
      terminalId = storedTerminalId;
    });

    // После этого продолжаем проверки
    _checkPermissionsAndLocation();
  }

  /// **Проверка всех разрешений и состояния геолокации**
  Future<void> _checkPermissionsAndLocation() async {
    try {
      final bool isLocationEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!isLocationEnabled) {
        _showLocationDisabledModal();
        return;
      }

      if (!await NotificationListenerService.isPermissionGranted()) {
        _showMissingPermissionsModal(["Уведомления"]);
        return;
      }

      _initializeListeners();
      _startHealthCheckTimer();
    } catch (e) {
      log("🔴 Ошибка проверки разрешений: $e");
    }
  }

  /// **Модалка при отсутствии других разрешений**
  void _showMissingPermissionsModal(List<String> missingPermissions) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Необходимо предоставить разрешения"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                missingPermissions.map((perm) => Text("• $perm")).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await NotificationListenerService.requestPermission();
                Navigator.of(context).pop();
                _checkPermissionsAndLocation();
              },
              child: const Text("Разрешить уведомления"),
            ),
            TextButton(
              onPressed: () {
                exit(0);
              },
              child: const Text("Закрыть приложение"),
            ),
          ],
        );
      },
    );
  }

  /// **Модалка о выключенной геолокации**
  void _showLocationDisabledModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Геолокация отключена"),
          content: const Text(
              "Приложение не может работать без включенной геолокации. Пожалуйста, включите её в настройках."),
          actions: [
            TextButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
              child: const Text("Открыть настройки"),
            ),
            TextButton(
              onPressed: () {
                exit(0);
              },
              child: const Text("Закрыть приложение"),
            ),
          ],
        );
      },
    );
  }

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

  void _initializeListeners() async {
    await _checkAndRequestNotificationPermission();
    await _toggleListeners(); // Автоматически запускаем слушатели
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    final permissionGranted =
        await NotificationListenerService.isPermissionGranted();
    if (!permissionGranted) {
      await NotificationListenerService.requestPermission();
    }
  }

  // Метод для установки слушателя SMS через платформенный канал
  void _setSmsListener() {
    log("🟢 *** Слушатель SMS запущен ***");
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
      // Вывод содержимого event в консоль
      log("🟢 *** Received SMS Event: ${messageData.toString()} ***");
      final int unixTimestamp = int.parse(messageData["timestamp"]);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final String? terminalId = prefs.getString('terminalId');
      // Добавляем смс в вёсртку
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
      } else {
        log("🔴 *** Failed to send SMS: ${response.statusCode}, response: ${response.body}, body: ${jsonEncode(body)} *** 🔴");
      }
    } catch (e) {
      log("🔴 *** Error processing SMS: $e *** 🔴");
    }
  }

  Future<void> _toggleListeners() async {
    try {
      // Проверяем разрешения для уведомлений
      final notificationPermissionGranted =
          await Permission.notification.isGranted;

      // Проверяем разрешения для SMS
      final smsPermissionGranted = await Permission.sms.isGranted;

      if (!notificationPermissionGranted) {
        // Запрос разрешения для уведомлений
        final notificationPermissionStatus =
            await NotificationListenerService.isPermissionGranted();
        if (!notificationPermissionStatus) {
          log("🔴 *** Notification permission not granted *** 🔴");
          _showErrorDialog(
              "Пожалуйста, предоставьте разрешение на уведомления.");
          return; // Выход, если разрешение не предоставлено
        }
      }

      if (!smsPermissionGranted) {
        // Запрос разрешения для SMS
        final smsPermissionStatus = await Permission.sms.request();
        if (!smsPermissionStatus.isGranted) {
          log("🔴 *** SMS permission not granted *** 🔴");
          _showErrorDialog("Пожалуйста, предоставьте разрешение на SMS.");
          return; // Выход, если разрешение не предоставлено
        }
      }

      setState(() {
        isListening = true;
      });

      if (isListening) {
        _sendHealthCheck();
        _startNotificationListener();
      } else {
        _stopNotificationListener();
      }
    } on PlatformException catch (e) {
      log("🔴 *** Error toggling listeners: ${e.message} *** 🔴");
      _showErrorDialog("Произошла ошибка при переключении слушателей.");
    }
  }

  // Метод для отображения диалога с ошибкой
  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Запрет закрытия по нажатию вне окна
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ошибка"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _startNotificationListener() {
    log("🟢 *** Слушатель уведомлений запущен ***");
    _notificationSubscription ??=
        NotificationListenerService.notificationsStream.listen(
      (event) async {
        try {
          // Вывод содержимого event в консоль
          log("🟢 *** Received Notification Event: ${event.toString()} ***");

          // Проверяем, если уведомление удалено, пропускаем обработку
          if (event.hasRemoved == true) {
            log("🔴 *** Notification ignored due to hasRemoved === true ***");
            return;
          }

          final appName = await _getAppName(event.packageName ?? '');
          final DateTime timestamp = DateTime.now();
          final int unixTimestamp = timestamp.millisecondsSinceEpoch;

          final SharedPreferences prefs = await SharedPreferences.getInstance();
          final String? token = prefs.getString('token');
          final String? terminalId = prefs.getString('terminalId');
          // Добавляем уведомление в вёрстку
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
              "timestamp": DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp),
              "isExpanded": false,
            });
          });

          if (token == null || terminalId == null) {
            log("🔴 *** Token or terminalId not found in shared preferences *** 🔴");
            return;
          }

          final Map<String, dynamic> body = {
            "terminal_id": terminalId,
            "sender": event.packageName ?? '',
            "title": event.title ?? '',
            "text": event.content ?? '',
            "date_time": unixTimestamp,
          };

          final client = http.Client();
          try {
            final response = await client
                .post(
                  Uri.parse(
                      'https://flackopay.net/api/payment-verifications/notifications'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              log("🟢 *** Notification successfully sent to server *** 🟢");
            } else {
              log("🔴 *** Failed to send notification: ${response.statusCode}, response: ${response.body}, body: ${jsonEncode(body)} *** 🔴");
            }
          } on TimeoutException {
            log("🔴 *** Notification request timed out *** 🔴");
          } finally {
            client.close();
          }
        } catch (e) {
          log("🔴 *** Error processing notification: $e *** 🔴");
        }
      },
    );
  }

  void _stopNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
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

      // Вывод содержимого event в консоль
      log("🟢 *** Received Notification Event: ${body.toString()} ***");

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

  Future<void> _showLogoutConfirmationDialog() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Запрет закрытия по нажатию вне окна
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Подтверждение выхода"),
          content: const Text("Вы уверены, что хотите выйти?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Отмена выхода
              },
              child: const Text("Отмена"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Подтвердить выход
              },
              child: const Text("Выйти"),
            ),
          ],
        );
      },
    );

    // Если пользователь подтвердил выход, вызываем _logout
    if (confirmLogout == true) {
      await _logout();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Идентификатор Терминала:',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              terminalId,
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
              onPressed:
                  _showLogoutConfirmationDialog, // Теперь вызывается метод с модалкой
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
