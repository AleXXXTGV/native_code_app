import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_code_app/screens/main_page.dart';
import 'package:http/http.dart' as http;

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  Barcode? _barcode; // Переменная для хранения результата сканирования
  final MobileScannerController _controller = MobileScannerController();
  bool isLoading = false; // Индикатор загрузки для кнопки

  @override
  void initState() {
    super.initState();
    _controller.start(); // Запускаем сканер сразу при инициализации
  }

  Future<void> _saveTerminalId(String terminalId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('terminalId', terminalId);
  }

  // Метод для выполнения запроса на верификацию терминала
  Future<void> _verifyTerminal(String terminalId) async {
    setState(() {
      isLoading = true; // Начинаем загрузку
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token'); // Получаем токен из shared_preferences

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

  // Метод для отображения данных штрихкода
  Widget _buildBarcode(Barcode? value) {
    if (value == null) {
      return const Text(
        'Сканируйте что-нибудь!',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.rawValue ?? 'Нет данных для отображения.',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  // Метод для обработки результата сканирования и обновления состояния
  void _handleBarcode(BarcodeCapture barcodes) {
    setState(() {
      _barcode = barcodes.barcodes.firstOrNull;

      if (_barcode != null) {
        // Выводим значение штрихкода в консоль
        print("🔴 *** SCANNED BARCODE VALUE: ${_barcode!.rawValue} *** 🔴");
      } else {
        print("🔴 *** SCANNED BARCODE: NULL *** 🔴");
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Сканер QR-кода',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _handleBarcode,
          ),
          Positioned(
            top: 150,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 20,
            child: Column(
              children: [
                const Text(
                  'Идентификатор Терминала:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                StreamBuilder<BarcodeCapture>(
                  stream: _controller.barcodes,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final barcode = snapshot.data!.barcodes.firstOrNull;
                      return _buildBarcode(barcode);
                    } else {
                      return _buildBarcode(null);
                    }
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            child: ElevatedButton(
              onPressed: _barcode != null && _barcode?.rawValue != null && !isLoading
                  ? () async {
                      await _saveTerminalId(_barcode!.rawValue!);
                      await _verifyTerminal(_barcode!.rawValue!); // Выполняем запрос на верификацию
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _barcode != null && _barcode?.rawValue != null && !isLoading
                    ? const Color(0xFF086AEB)
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 100,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Text(
                      'Продолжить',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
