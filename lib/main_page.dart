import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const platform = MethodChannel('uniqueChannelName');
  List<Map<String, dynamic>> receivedMessages = [];
  bool isListening = false;

  Future<void> toggleSmsListener() async {
    try {
      final result = await platform.invokeMethod<bool>('toggleSmsListener');
      setState(() {
        isListening = result ?? false;
      });

      if (isListening) {
        await fetchMessages();
      }
    } on PlatformException catch (e) {
      print("Error toggling SMS listener: ${e.message}");
    }
  }

  Future<void> fetchMessages() async {
    try {
      final messages = await platform.invokeMethod<List<dynamic>>('getReceivedMessages');
      setState(() {
        receivedMessages = messages
                ?.map((msg) => Map<String, dynamic>.from(msg))
                .toList() ??
            [];
      });
    } on PlatformException catch (e) {
      print("Error fetching messages: ${e.message}");
    }
  }

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler((call) async {
      if (call.method == "onMessageReceived") {
        final messageData = Map<String, dynamic>.from(call.arguments);
        setState(() {
          receivedMessages.add(messageData);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native SMS Listener'),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Enable SMS Listener"),
            value: isListening,
            onChanged: (value) async {
              await toggleSmsListener();
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: receivedMessages.length,
              itemBuilder: (context, index) {
                final message = receivedMessages[index];
                return ListTile(
                  title: Text("From: ${message['from'] ?? 'Unknown'}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Message: ${message['message'] ?? 'No content'}"),
                      Text("Timestamp: ${DateTime.fromMillisecondsSinceEpoch(message['timestamp'] as int)}"),
                      if (message['serviceCenterAddress'] != null)
                        Text("Service Center: ${message['serviceCenterAddress']}"),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
