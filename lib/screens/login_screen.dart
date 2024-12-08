import 'package:flutter/material.dart';
import 'dart:ui'; // Для использования эффекта блюра
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_code_app/screens/permissions_screen.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Начальная позиция за правой границей экрана
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final String username = _emailController.text;
    final String password = _passwordController.text;

    // URL для логина
    const String url = 'https://flackopay.net/api/login';

    try {
      // Выполняем POST-запрос
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': username,
          'password': password,
        },
      );

      // Обработка ответа
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print("Response Data: $responseData");
        // Проверяем успешность логина
        if (responseData.containsKey('access_token')) {
          // Показываем успешное сообщение
          _showToast(
            message: "Успешно зашли в аккаунт",
            color: const Color(0xFF01CC55),
            icon: Icons.check_circle_outline,
          );

          // Сохраняем информацию о логине
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('token', responseData['access_token']); // Сохраняем токен

          // Задержка перед переходом на следующую страницу (разрешения)
          Future.delayed(const Duration(seconds: 2, milliseconds: 500)).then((_) {
            _animationController.reverse().then((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const PermissionsPage()),
              );
            });
          });
        } else {
          // Показываем сообщение об ошибке
          _showToast(
            message: responseData['message'] ?? "Логин или пароль неверный",
            color: const Color(0xFFF54D50),
            icon: Icons.error_outline,
          );
        }
      } else {
        // Показываем сообщение об ошибке
        _showToast(
          message: "Логин или пароль неверный",
          color: const Color(0xFFF54D50),
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      // Обработка исключения (например, если нет доступа к интернету)
      print("Exception occurred: $e");
      _showToast(
        message: "Непредвиденная ошибка, попробуйте позже",
        color: const Color(0xFFF54D50),
        icon: Icons.error_outline,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showToast({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 50,
          right: 20,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
    _animationController.forward();

    // Показать уведомление на 1.5 секунды, затем скрыть и после еще 1.5 секунды перенаправить
    Future.delayed(const Duration(seconds: 1, milliseconds: 500)).then((_) {
      _animationController.reverse().then((_) {
        overlayEntry.remove();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  // Блок с формой логина
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD9E3EE),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Вход в аккаунт',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF086AEB),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Логин',
                                  style: TextStyle(
                                    color: Color(0xFF787878),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                      horizontal: 9,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  'Пароль',
                                  style: TextStyle(
                                    color: Color(0xFF787878),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                      horizontal: 9,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF086AEB),
                                            padding: const EdgeInsets.symmetric(vertical: 15),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(7),
                                            ),
                                          ),
                                          child: const Text(
                                            'Вход',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
