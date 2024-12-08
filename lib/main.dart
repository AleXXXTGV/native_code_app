import 'package:flutter/material.dart';
import 'package:native_code_app/screens/splash_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEBF0F5), // Цвет фона всех страниц
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEBF0F5), // Цвет AppBar по умолчанию
          elevation: 0,
        ),
      ),
      home: const SplashScreen(), // SplashScreen как стартовая страница
    );
  }
}
