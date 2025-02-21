import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:native_code_app/screens/main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scanner_page.dart'; // Импортируем страницу сканера

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final TextEditingController _tokenController = TextEditingController();
  bool isLoading = false;

  Future<void> _verifyTerminal() async {
    // Проверяем, что пользователь ввёл terminalId
    log("Введённый текст в инпут ${_tokenController.text}");
    if (_tokenController.text.isEmpty) {
      return;
    }

    setState(() {
      isLoading = true; // Начинаем загрузку
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token =
        prefs.getString('token'); // Получаем токен из shared_preferences

    if (token == null) {
      setState(() {
        isLoading = false; // Прекращаем загрузку при отсутствии токена
      });
      // Если токен не найден, выводим ошибку
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Не удалось получить токен. Пожалуйста, войдите снова.")),
      );
      return;
    }

    final String terminalId = _tokenController.text;

    try {
      // Формируем URL и отправляем PATCH запрос
      final response = await http.patch(
        Uri.parse('https://flackopay.net/api/terminals/$terminalId/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Сохраняем terminalId в SharedPreferences перед переходом на главную страницу
        await prefs.setString('terminalId', terminalId);

        // Если запрос успешный, переходим на главную страницу
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      } else {
        // Если статус ответа отличается от 200, выводим ошибку
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Не удалось верифицировать терминал. Проверьте данные и попробуйте снова.")),
        );
      }
    } catch (e) {
      // Обработка ошибки сети или запроса
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка сети: $e")),
      );
    } finally {
      setState(() {
        isLoading = false; // Прекращаем загрузку
      });
    }
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD9E3EE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Center(
                              child: Text(
                                'Отсканируйте QR',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF086AEB),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text(
                                'На вашем устройстве отсутствуют данные с сервера, чтобы отсканируйте QR код с сайта чтобы продолжить',
                                style: TextStyle(
                                  color: Color(0xFF787878),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _tokenController,
                              decoration: InputDecoration(
                                labelText: "Токен",
                                labelStyle: const TextStyle(
                                  color: Color(0xFF787878),
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 15),
                            const Center(
                              child: Text(
                                "или",
                                style: TextStyle(
                                  color: Color(0xFF787878),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ScannerPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Сканировать QR-код",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF086AEB),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            if (_tokenController.text.isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _verifyTerminal,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF086AEB),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        )
                                      : const Text(
                                          'Продолжить',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                ),
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
