import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'admin_dashboard.dart';
import 'forget_password_page.dart';

class OtpVerifyPage extends StatefulWidget {
  final ResetMethod method;
  final String value;
  final String role;

  const OtpVerifyPage({
    super.key,
    required this.method,
    required this.value,
    required this.role,
  });

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final otpController = TextEditingController();
  int secondsLeft = 60;
  Timer? timer;
  bool isVerifying = false;
  bool canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      secondsLeft = 60;
      canResend = false;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (secondsLeft == 0) {
        t.cancel();
        if (mounted) {
          setState(() => canResend = true);
        }
      } else {
        if (mounted) {
          setState(() => secondsLeft--);
        }
      }
    });
  }

  Future<void> _resendOtp() async {
    if (!canResend || isVerifying) return;

    setState(() => isVerifying = true);

    try {
      final res = widget.method == ResetMethod.email
          ? await ApiService.sendEmailOtp(widget.value, widget.role)
          : await ApiService.sendPhoneOtp(widget.value, widget.role);

      if (!mounted) return;

      setState(() => isVerifying = false);

      if (res['statusCode'] == 200) {
        _showSuccess("OTP resent successfully");
        _startTimer();
      } else {
        _showError(res['body']['message'] ?? "Failed to resend OTP");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isVerifying = false);
      _showError("Network error: ${e.toString()}");
    }
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();

    // Validation
    if (otp.isEmpty) {
      _showError("Please enter the OTP");
      return;
    }

    if (otp.length != 6) {
      _showError("OTP must be 6 digits");
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(otp)) {
      _showError("OTP must contain only numbers");
      return;
    }

    if (isVerifying) return;

    setState(() => isVerifying = true);

    try {
      print("Verifying OTP: $otp for ${widget.value}");

      final res = widget.method == ResetMethod.email
          ? await ApiService.verifyEmailOtp(widget.value, otp, widget.role)
          : await ApiService.verifyPhoneOtp(widget.value, otp, widget.role);

      print("Response: ${res['statusCode']} - ${res['body']}");

      if (!mounted) return;

      setState(() => isVerifying = false);

      if (res['statusCode'] == 200) {
        _showSuccessDialog();
        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

        final role = res['body']['user']['role'];
        _navigate(role);
      } else {
        _showError(res['body']['message'] ?? "Invalid or expired OTP");
      }
    } catch (e) {
      print("Error verifying OTP: $e");
      if (!mounted) return;
      setState(() => isVerifying = false);
      _showError("Network error: ${e.toString()}");
    }
  }

  void _navigate(String role) {
    Widget page;
    if (role == "Student") {
      page = const StudentShell();
    } else if (role == "Teacher") {
      page = const TeacherShell();
    } else {
      page = const AdminShell();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        elevation: 6,
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.green.shade50],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Verification Successful!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Welcome back!\nRedirecting to your dashboard...",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Verify OTP",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            /// 🔐 LOCK ICON
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: Colors.green.shade700,
              ),
            ),

            const SizedBox(height: 32),

            /// 📱 TITLE
            const Text(
              "Verification Code",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            /// 📧 SUBTITLE
            Text(
              widget.method == ResetMethod.email
                  ? "A verification code has been sent to your email"
                  : "A verification code has been sent to your phone",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getMaskedValue(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),

            const SizedBox(height: 40),

            /// 🔢 OTP INPUT BOX
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: otpController,
                maxLength: 6,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                enabled: !isVerifying,
                style: TextStyle(
                  fontSize: 36,
                  letterSpacing: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  border: InputBorder.none,
                  hintText: "------",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    letterSpacing: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// ⏱️ TIMER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: canResend ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 20,
                    color: canResend ? Colors.red.shade600 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    canResend ? "OTP expired" : "Expires in $secondsLeft seconds",
                    style: TextStyle(
                      fontSize: 15,
                      color: canResend ? Colors.red.shade600 : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            /// ✅ VERIFY BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.green.withOpacity(0.3),
                ),
                onPressed: isVerifying ? null : _verifyOtp,
                child: isVerifying
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Verify & Login",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔄 RESEND OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code?",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: canResend && !isVerifying ? _resendOtp : null,
                  child: Text(
                    "Resend",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: canResend && !isVerifying
                          ? Colors.green.shade700
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// ℹ️ HELP TEXT
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Enter the 6-digit code sent to your ${widget.method == ResetMethod.email ? 'email' : 'phone'}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMaskedValue() {
    if (widget.method == ResetMethod.email) {
      final parts = widget.value.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final domain = parts[1];

        if (username.length <= 2) {
          return '${username[0]}***@$domain';
        } else {
          final masked = username.substring(0, 2) + '*' * (username.length - 2);
          return '$masked@$domain';
        }
      }
    } else {
      if (widget.value.length > 7) {
        final start = widget.value.substring(0, 6);
        final end = widget.value.substring(widget.value.length - 3);
        return '$start***$end';
      } else if (widget.value.length > 3) {
        final start = widget.value.substring(0, 2);
        final end = widget.value.substring(widget.value.length - 2);
        return '$start***$end';
      }
    }
    return widget.value;
  }
}