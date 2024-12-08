import 'dart:async';
import 'package:flutter/material.dart';
import 'package:native_code_app/screens/login_screen.dart';
import 'package:native_code_app/screens/main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  // Функция для перехода на следующую страницу
  Future<void> _navigateToNextScreen() async {
    // Симуляция загрузки на 3 секунды
    await Future.delayed(const Duration(seconds: 3));
    
    // Проверяем, сохранены ли данные авторизации
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? token = prefs.getString('token');
    final String? terminalId = prefs.getString('terminalId');

    // Переход на MainPage, если пользователь авторизован и данные валидны
    if (isLoggedIn && token != null && terminalId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    } else {
      // Переход на LoginScreen, если данные авторизации отсутствуют
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg', // Путь к SVG файлу логотипа
              height: 150,
            ),
            const SizedBox(height: 16),
            const Text(
              'FlackoPay',
              style: TextStyle(
                fontFamily: 'Aclonica',
                fontSize: 32,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
