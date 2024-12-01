import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Импортируем библиотеку для работы с SVG

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> receivedNotifications = [];
  bool isListening = false;
  StreamSubscription<ServiceNotificationEvent>? _subscription;

  // Method channel to interact with native Android code
  static const platform = MethodChannel('notificationChannel');

  // Map to cache app names by package name to avoid multiple lookups
  Map<String, String> packageNames = {};

  // Check and request notification permission
  Future<void> checkAndRequestPermission() async {
    final permissionGranted =
        await NotificationListenerService.isPermissionGranted();
    if (!permissionGranted) {
      final status = await NotificationListenerService.requestPermission();
      log("Permission granted: $status");
    }
  }

  // Get app name by package name using native Android code
  Future<String> getAppName(String packageName) async {
    // Check if the package name is already cached
    if (packageNames.containsKey(packageName)) {
      return packageNames[packageName]!;
    }
    try {
      final String appName =
          await platform.invokeMethod('getAppName', packageName);
      // Cache the app name
      packageNames[packageName] = appName;
      return appName;
    } catch (e) {
      log('Error getting app name: $e');
      return packageName; // Fallback to package name if something goes wrong
    }
  }

  // Start listening for notifications
  void startListening() {
    _subscription ??=
        NotificationListenerService.notificationsStream.listen((event) async {
      log("Received notification: $event");
      final appName = await getAppName(event.packageName ?? '');
      final DateTime timestamp = DateTime.now();
      final String formattedTimestamp = DateFormat('dd-MM-yyyy HH:mm').format(timestamp);
      setState(() {
        receivedNotifications.add(
          {
            "notification": ServiceNotificationEvent(
              id: event.id,
              packageName: appName,
              title: event.title,
              content: event.content,
              appIcon: event.appIcon,
            ),
            "timestamp": formattedTimestamp,
            "isExpanded": false, // By default, the notification is not expanded
          },
        );
      });
    });
  }

  // Stop listening for notifications
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void initState() {
    super.initState();
    checkAndRequestPermission();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0F5), // Background color of the page
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Прозрачный цвет для AppBar
        elevation: 0,
        automaticallyImplyLeading: false,
        forceMaterialTransparency: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: () {
                // Navigate to login page and clear saved data
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF54D50), // Цвет кнопки выхода
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                minimumSize: const Size(43, 30), // Размер кнопки
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
            const SizedBox(height: 20), // Отступ сверху для логотипа и кнопки выхода
            Center(
              child: Column(
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg', // Путь к файлу SVG
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
                "Захват и передача уведомлений",
                style: TextStyle(color: Colors.black),
              ),
              value: isListening,
              onChanged: (value) async {
                setState(() {
                  isListening = value;
                });
                if (isListening) {
                  startListening();
                } else {
                  stopListening();
                }
              },
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF086AEB),
              inactiveThumbColor: const Color(0xFF086AEB),
              inactiveTrackColor: Colors.transparent,
              trackOutlineColor: MaterialStateProperty.all(const Color(0xFF086AEB)),
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
              flex: 4, // Занимает 40% высоты экрана
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: SvgPicture.asset(
                        'assets/images/background_logo.svg', // SVG фон
                        height: MediaQuery.of(context).size.height * 0.36, // 90% от высоты контейнера
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.15), // Уменьшение темноты фона
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
                          final notification = notificationMap["notification"] as ServiceNotificationEvent;
                          final String timestamp = notificationMap["timestamp"] ?? 'Unknown Time';
                          final bool isExpanded = notificationMap["isExpanded"] ?? false;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                notificationMap["isExpanded"] = !isExpanded;
                              });
                            },
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300), // Плавная анимация
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
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'NOTIFICATION received:',
                                            style: TextStyle(
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
                                      Text(
                                        'Sender: "${notification.packageName}"',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isExpanded) ...[
                                        const SizedBox(height: 4),
                                        if (notification.content != null)
                                          Text(
                                            'Body: "${notification.content}"',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Status: "Success"',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
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
