import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpPage extends StatefulWidget {
  final String mobileNumber;
  OtpPage({required this.mobileNumber});

  @override
  _OtpPageState createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const platform = MethodChannel('uniqueChannelName');
  final _otpControllers = List.generate(4, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _startSmsListener();
  }

  Future<void> _startSmsListener() async {
    try {
      await platform.invokeMethod('startSmsListener');
      platform.setMethodCallHandler(_handleOtp);
    } on PlatformException catch (e) {
      print("Failed to start SMS listener: ${e.message}");
    }
  }

  Future<void> _handleOtp(MethodCall call) async {
    if (call.method == "onOtpReceived") {
      String otp = call.arguments;
      _setOtpFields(otp);
    }
  }

  void _setOtpFields(String otp) {
    if (otp.length == 4) {
      for (int i = 0; i < 4; i++) {
        _otpControllers[i].text = otp[i];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OTP Verification'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Enter OTP sent to ${widget.mobileNumber}'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              return SizedBox(
                width: 50,
                child: TextField(
                  controller: _otpControllers[index],
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(counterText: ''),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}        