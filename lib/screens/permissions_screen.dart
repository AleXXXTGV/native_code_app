import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:native_code_app/screens/qr_scan_page.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    await _checkPermission(
      Permission.location,
      (value) => hasLocationPermission = value,
    );
    await _checkPermission(
      Permission.phone,
      (value) => hasPhonePermission = value,
    );
    await _checkPermission(
      Permission.camera,
      (value) => hasCameraPermission = value,
    );
    await _checkPermission(
      Permission.sms,
      (value) => hasSmsPermission = value,
    );
    await _checkNotificationPermission();
    setState(() {});
  }

  Future<void> _checkPermission(
      Permission permission, Function(bool) onStatusUpdate) async {
    final status = await permission.status;
    onStatusUpdate(status.isGranted);
  }

  Future<void> _checkNotificationPermission() async {
    final permissionGranted =
        await NotificationListenerService.isPermissionGranted();
    setState(() {
      isListening = permissionGranted;
    });
  }

  Future<void> _requestPermission(
      Permission permission, Function(bool) onStatusUpdate) async {
    final status = await permission.request();
    onStatusUpdate(status.isGranted);
    setState(() {});
  }

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
          Center(
            child: SvgPicture.asset(
              'assets/images/background_logo.svg',
              width: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
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
                            SwitchListTile(
                              title: const Text(
                                "Захват и передача уведомлений",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: isListening,
                              onChanged: (value) async {
                                if (!isListening) {
                                  await NotificationListenerService
                                      .requestPermission();
                                  _checkNotificationPermission();
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
                            SwitchListTile(
                              title: const Text(
                                "Доступ к локации",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasLocationPermission,
                              onChanged: (value) async {
                                if (!hasLocationPermission) {
                                  await _requestPermission(
                                      Permission.location,
                                      (value) => hasLocationPermission = value);
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
                            SwitchListTile(
                              title: const Text(
                                "Доступ к данным оператора",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasPhonePermission,
                              onChanged: (value) async {
                                if (!hasPhonePermission) {
                                  await _requestPermission(
                                      Permission.phone,
                                      (value) => hasPhonePermission = value);
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
                            SwitchListTile(
                              title: const Text(
                                "Доступ к камере",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasCameraPermission,
                              onChanged: (value) async {
                                if (!hasCameraPermission) {
                                  await _requestPermission(
                                      Permission.camera,
                                      (value) => hasCameraPermission = value);
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
                            SwitchListTile(
                              title: const Text(
                                "Доступ к SMS",
                                style: TextStyle(color: Colors.black),
                              ),
                              value: hasSmsPermission,
                              onChanged: (value) async {
                                if (!hasSmsPermission) {
                                  await _requestPermission(
                                      Permission.sms,
                                      (value) => hasSmsPermission = value);
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
