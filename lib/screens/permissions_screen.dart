import 'package:flutter/material.dart';
import 'dart:ui'; // Для использования эффекта блюра
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:native_code_app/screens/qr_scan_page.dart'; // Добавьте путь к странице со сканером QR
import 'package:flutter_svg/flutter_svg.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  bool isListening = false;
  bool hasLocationPermission = false;
  bool hasPhonePermission = false;
  bool hasCameraPermission = false;
  bool hasSmsPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Метод для отслеживания изменений жизненного цикла приложения
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Проверяем разрешение после возврата из настроек
      _checkPermissions();
    }
  }

  // Проверка всех необходимых разрешений
  Future<void> _checkPermissions() async {
    await _checkNotificationPermission();
    await _checkLocationPermission();
    await _checkPhonePermission();
    await _checkCameraPermission();
    await _checkSmsPermission();
  }

  // Проверка текущего статуса разрешения на уведомления
  Future<void> _checkNotificationPermission() async {
    final permissionGranted =
        await NotificationListenerService.isPermissionGranted();
    setState(() {
      isListening = permissionGranted;
    });
  }

  // Проверка текущего статуса разрешения на локацию
  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    setState(() {
      hasLocationPermission = status.isGranted;
    });
  }

  // Проверка текущего статуса разрешения на телефон
  Future<void> _checkPhonePermission() async {
    final status = await Permission.phone.status;
    setState(() {
      hasPhonePermission = status.isGranted;
    });
  }

  // Проверка текущего статуса разрешения на камеру
  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      hasCameraPermission = status.isGranted;
    });
  }

  // Проверка текущего статуса разрешения на SMS
  Future<void> _checkSmsPermission() async {
    final status = await Permission.sms.status;
    setState(() {
      hasSmsPermission = status.isGranted;
    });
  }

  // Метод для открытия настроек уведомлений
  void openNotificationSettings() async {
    final permissionGranted =
        await NotificationListenerService.isPermissionGranted();
    if (!permissionGranted) {
      await NotificationListenerService.requestPermission();
    }
  }

  // Метод для запроса разрешения на локацию
  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() {
      hasLocationPermission = status.isGranted;
    });
  }

  // Метод для запроса разрешения на телефон
  Future<void> _requestPhonePermission() async {
    final status = await Permission.phone.request();
    setState(() {
      hasPhonePermission = status.isGranted;
    });
  }

  // Метод для запроса разрешения на камеру
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      hasCameraPermission = status.isGranted;
    });
  }

  // Метод для запроса разрешения на SMS
  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    setState(() {
      hasSmsPermission = status.isGranted;
    });
  }

  // Метод для открытия страницы сканера QR-кода
  void openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool allPermissionsGranted = isListening &&
        hasLocationPermission &&
        hasPhonePermission &&
        hasCameraPermission &&
        hasSmsPermission;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF0F5),
      body: Stack(
        children: [
          // Логотип на заднем фоне
          Center(
            child: SvgPicture.asset(
              'assets/images/background_logo.svg',
              width: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
          // Контент сверху
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: 80,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'FlackoPay',
                    style: TextStyle(
                      fontFamily: 'Aclonica',
                      fontSize: 32,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Блок с разрешениями
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD9E3EE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                'Разрешения',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF086AEB),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                'Нужно дать все необходимые разрешения для работы',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF787878),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Разрешение на уведомления
                            SwitchListTile(
                              title: const Text(
                                "Захват и передача уведомлений",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: isListening,
                              onChanged: (value) async {
                                if (value) {
                                  openNotificationSettings();
                                } else {
                                  setState(() {
                                    isListening = false;
                                  });
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF086AEB),
                              inactiveThumbColor: const Color(0xFF086AEB),
                              inactiveTrackColor: Colors.transparent,
                              trackOutlineColor: MaterialStateProperty.all(
                                  const Color(0xFF086AEB)),
                            ),
                            const SizedBox(height: 10),
                            // Разрешение на локацию
                            SwitchListTile(
                              title: const Text(
                                "Доступ к локации",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasLocationPermission,
                              onChanged: (value) async {
                                if (value) {
                                  await _requestLocationPermission();
                                } else {
                                  setState(() {
                                    hasLocationPermission = false;
                                  });
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF086AEB),
                              inactiveThumbColor: const Color(0xFF086AEB),
                              inactiveTrackColor: Colors.transparent,
                              trackOutlineColor: MaterialStateProperty.all(
                                  const Color(0xFF086AEB)),
                            ),
                            const SizedBox(height: 10),
                            // Разрешение на доступ к данным мобильного оператора
                            SwitchListTile(
                              title: const Text(
                                "Доступ к данным оператора",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasPhonePermission,
                              onChanged: (value) async {
                                if (value) {
                                  await _requestPhonePermission();
                                } else {
                                  setState(() {
                                    hasPhonePermission = false;
                                  });
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF086AEB),
                              inactiveThumbColor: const Color(0xFF086AEB),
                              inactiveTrackColor: Colors.transparent,
                              trackOutlineColor: MaterialStateProperty.all(
                                  const Color(0xFF086AEB)),
                            ),
                            const SizedBox(height: 10),
                            // Разрешение на камеру
                            SwitchListTile(
                              title: const Text(
                                "Доступ к камере",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasCameraPermission,
                              onChanged: (value) async {
                                if (value) {
                                  await _requestCameraPermission();
                                } else {
                                  setState(() {
                                    hasCameraPermission = false;
                                  });
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF086AEB),
                              inactiveThumbColor: const Color(0xFF086AEB),
                              inactiveTrackColor: Colors.transparent,
                              trackOutlineColor: MaterialStateProperty.all(
                                  const Color(0xFF086AEB)),
                            ),
                            const SizedBox(height: 10),
                            // Разрешение на SMS
                            SwitchListTile(
                              title: const Text(
                                "Доступ к SMS",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasSmsPermission,
                              onChanged: (value) async {
                                if (value) {
                                  await _requestSmsPermission();
                                } else {
                                  setState(() {
                                    hasSmsPermission = false;
                                  });
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF086AEB),
                              inactiveThumbColor: const Color(0xFF086AEB),
                              inactiveTrackColor: Colors.transparent,
                              trackOutlineColor: MaterialStateProperty.all(
                                  const Color(0xFF086AEB)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Кнопка продолжить
                  ElevatedButton(
                    onPressed: allPermissionsGranted ? openQRScanner : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allPermissionsGranted
                          ? const Color(0xFF086AEB)
                          : Colors.grey[400],
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 100,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Продолжить',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
