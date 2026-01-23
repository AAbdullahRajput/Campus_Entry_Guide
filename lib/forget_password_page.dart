import 'package:flutter/material.dart';
import 'otp_verify_page.dart';
import 'api_service.dart';

enum ResetMethod { email, phone }

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  ResetMethod? selectedMethod;

  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  final String role = "Student"; // later make dynamic if needed

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Forgot Password",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// 🌿 TOP IMAGE
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  "assets/images/register.jpg",
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 35),

            /// 🟢 TITLE & SUBTITLE
            const Text(
              "Account Recovery",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose your preferred recovery method",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 30),

            /// 📦 METHOD CARDS
            _methodCard(
              icon: Icons.email_rounded,
              title: "Recover via Email",
              subtitle: "Get OTP on your email",
              selected: selectedMethod == ResetMethod.email,
              onTap: () {
                setState(() {
                  selectedMethod = ResetMethod.email;
                });
              },
            ),

            const SizedBox(height: 15),

            // _methodCard(
            //   icon: Icons.phone_android_rounded,
            //   title: "Recover via Phone",
            //   subtitle: "Get OTP on your phone",
            //   selected: selectedMethod == ResetMethod.phone,
            //   onTap: () {
            //     setState(() {
            //       selectedMethod = ResetMethod.phone;
            //     });
            //   },
            // ),

            const SizedBox(height: 30),

            /// 📧 EMAIL SECTION
            if (selectedMethod == ResetMethod.email) _emailSection(),

            /// 📱 PHONE SECTION
            // if (selectedMethod == ResetMethod.phone) _phoneSection(),
          ],
        ),
      ),
    );
  }

  /// ================= UI COMPONENTS =================

  Widget _methodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.green.shade50 : Colors.white,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? Colors.green : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? Colors.green : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emailSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Email Address",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: "your@email.com",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.email_outlined, color: Colors.green.shade600),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _continueButton(() async {
            final email = emailController.text.trim();

            if (email.isEmpty) {
              _showError("Please enter your email address");
              return;
            }

            if (!_isValidEmail(email)) {
              _showError("Please enter a valid email address");
              return;
            }

            setState(() => isLoading = true);

            try {
              final result = await ApiService.sendEmailOtp(email, role);

              if (!mounted) return;

              setState(() => isLoading = false);

              if (result['statusCode'] == 200) {
                _showSuccessDialog(
                  title: "OTP Sent Successfully!",
                  message:
                      "A 6-digit verification code has been sent to your email address.\n\nPlease check your inbox (and spam folder) for the OTP.",
                  icon: Icons.mark_email_read_rounded,
                  onContinue: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtpVerifyPage(
                          method: ResetMethod.email,
                          value: email,
                          role: role,
                        ),
                      ),
                    );
                  },
                );
              } else {
                _showError(result['body']['message'] ?? "Email not found in database");
              }
            } catch (e) {
              if (!mounted) return;
              setState(() => isLoading = false);
              _showError("Network error. Please check your connection");
            }
          }),
        ],
      ),
    );
  }

  // Widget _phoneSection() {
  //   return AnimatedContainer(
  //     duration: const Duration(milliseconds: 300),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           "Phone Number",
  //           style: TextStyle(
  //             fontSize: 15,
  //             fontWeight: FontWeight.w600,
  //             color: Colors.grey.shade800,
  //           ),
  //         ),
  //         const SizedBox(height: 10),
  //         TextField(
  //           controller: phoneController,
  //           keyboardType: TextInputType.phone,
  //           enabled: !isLoading,
  //           decoration: InputDecoration(
  //             hintText: "03197630363",
  //             hintStyle: TextStyle(color: Colors.grey.shade400),
  //             prefixIcon: Icon(Icons.phone_android_rounded, color: Colors.green.shade600),
  //             filled: true,
  //             fillColor: Colors.grey.shade50,
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide.none,
  //             ),
  //             enabledBorder: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide(color: Colors.grey.shade200),
  //             ),
  //             focusedBorder: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: const BorderSide(color: Colors.green, width: 2),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 24),
  //         _continueButton(() async {
  //           final phone = phoneController.text.trim();

  //           if (phone.isEmpty) {
  //             _showError("Please enter your phone number");
  //             return;
  //           }

  //           if (!_isValidPhone(phone)) {
  //             _showError("Please enter a valid phone number (e.g., 03197630363)");
  //             return;
  //           }

  //           setState(() => isLoading = true);

  //           try {
  //             final result = await ApiService.sendPhoneOtp(phone, role);

  //             if (!mounted) return;

  //             setState(() => isLoading = false);

  //             if (result['statusCode'] == 200) {
  //               _showSuccessDialog(
  //                 title: "OTP Sent Successfully!",
  //                 message:
  //                     "A 6-digit verification code has been sent to your phone number via SMS.\n\nPlease check your messages for the OTP.",
  //                 icon: Icons.sms_rounded,
  //                 onContinue: () {
  //                   Navigator.pop(context);
  //                   Navigator.push(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (_) => OtpVerifyPage(
  //                         method: ResetMethod.phone,
  //                         value: phone,
  //                         role: role,
  //                       ),
  //                     ),
  //                   );
  //                 },
  //               );
  //             } else {
  //               _showError(result['body']['message'] ?? "Phone number not found in database");
  //             }
  //           } catch (e) {
  //             if (!mounted) return;
  //             setState(() => isLoading = false);
  //             _showError("Network error. Please check your connection");
  //           }
  //         }),
  //       ],
  //     ),
  //   );
  // }

  Widget _continueButton(VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.green.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                "Continue",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // Validation helpers
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  // bool _isValidPhone(String phone) {
  //   return RegExp(r'^[0-9]{11}$').hasMatch(phone);
  // }

  // Success Dialog
  void _showSuccessDialog({
    required String title,
    required String message,
    required IconData icon,
    required VoidCallback onContinue,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 56,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onContinue,
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Error message
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
}