import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'admin_dashboard.dart';
import 'register_page.dart';
import 'forget_password_page.dart';
import 'services/api_service.dart';
import '../services/local_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
  String selectedRole = 'Student';
  bool isLoading = false;

  late AnimationController _controller;
  late Animation<Offset> fromLeft;
  late Animation<Offset> fromRight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    fromLeft = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    fromRight = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final savedRole = prefs.getString('saved_role');
    if (savedEmail != null && savedPassword != null && savedRole != null) {
      emailController.text = savedEmail;
      passwordController.text = savedPassword;
      selectedRole = savedRole;
      setState(() {});
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (rememberMe) {
      await LocalStorage.saveCredentials(
        emailController.text,
        passwordController.text,
        selectedRole,
      );
    } else {
      await LocalStorage.clearSavedCredentials();
    }
  }

  void _clearLoginState() {
    emailController.clear();
    passwordController.clear();
    rememberMe = false;
    obscurePassword = true;
    selectedRole = 'Student';
    setState(() {});
  }

  String? emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return "Email is required";
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!regex.hasMatch(v.trim()))
      return "Enter a valid email (example@domain.com)";
    return null;
  }

  String? passwordValidator(String? v) {
    if (v == null || v.isEmpty) return "Password is required";
    if (v.length < 6) return "Minimum 6 characters required";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: screenHeight * 0.38,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/login.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideTransition(
                          position: fromRight,
                          child: const Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SlideTransition(
                          position: fromLeft,
                          child: const Text(
                            "Login to your account",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 25),
                        SlideTransition(
                          position: fromRight,
                          child: _buildInputField(
                            controller: emailController,
                            icon: Icons.email_outlined,
                            hint: "Email",
                            validator: emailValidator,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SlideTransition(
                          position: fromLeft,
                          child: _buildInputField(
                            controller: passwordController,
                            icon: Icons.lock_outline,
                            hint: "Password",
                            isPassword: true,
                            validator: passwordValidator,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SlideTransition(
                          position: fromRight,
                          child: DropdownButtonFormField<String>(
                            value: selectedRole,
                            items: ['Student', 'Teacher', 'Admin']
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => selectedRole = v!),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.green.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        SlideTransition(
                          position: fromLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: rememberMe,
                                    activeColor: Colors.green,
                                    onChanged: (v) =>
                                        setState(() => rememberMe = v!),
                                  ),
                                  const Text("Remember Me"),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgetPasswordScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SlideTransition(
                          position: fromRight,
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "Login",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        SlideTransition(
                          position: fromRight,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration:
                                            const Duration(milliseconds: 450),
                                        pageBuilder: (_, __, ___) =>
                                            const RegistrationScreen(),
                                        transitionsBuilder:
                                            (_, animation, __, child) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.1),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                    _clearLoginState();
                                  },
                                  child: const Text(
                                    "Sign up",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscurePassword : false,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.green.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.green),
        hintText: hint,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.green,
                ),
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
              )
            : null,
      ),
    );
  }

  // ✅ UPDATED LOGIN METHOD - Saves all user data
  Future<void> _login() async {
    print("🔍 Login button pressed");
    print("📧 Email: ${emailController.text.trim()}");
    print("🔐 Password length: ${passwordController.text.length}");
    print("👤 Selected Role: $selectedRole");
    
    if (_formKey.currentState!.validate()) {
      print("✅ Form validated successfully");
      setState(() => isLoading = true);

      try {
        print("📡 Calling ApiService.login...");
        
        final res = await ApiService.login(
          emailController.text.trim(),
          passwordController.text,
          selectedRole,
        );

        print("📥 API Response received");
        print("📊 Full response: $res");

        if (!mounted) return;
        setState(() => isLoading = false);

        final statusCode = res['statusCode'];
        final body = res['body'];

        print("📊 Status Code: $statusCode");
        print("📊 Response Body: $body");

        if (statusCode == 200) {
          print("✅ Login successful! Saving credentials...");
          await _saveCredentials();
          
          final userRole = body['user']['role'];
          final userData = body['user'];
          
          print("💾 Saving complete user session...");
          print("   User ID: ${userData['id']}");
          print("   Email: ${userData['email']}");
          print("   Role: $userRole");
          print("   Full Name: ${userData['full_name']}");
          print("   Phone: ${userData['phone_number']}");
          
          // ✅ STUDENT FIELDS
          print("   Degree: ${userData['degree']}");
          print("   Section: ${userData['section']}");
          print("   ARID No: ${userData['arid_no']}");
          print("   Semester: ${userData['semester_no']}");
          
          
          // ✅ TEACHER FIELDS
          print("   Department: ${userData['department']}");
          print("   Subject: ${userData['subject_name']}");
          print("   Shift: ${userData['shift']}");
          
          // ✅ SAVE COMPLETE SESSION WITH ALL ROLE-SPECIFIC FIELDS
          await LocalStorage.saveUserSession(
            userId: userData['id'],
            email: userData['email'],
            role: userRole,
            fullName: userData['full_name'],
            phoneNumber: userData['phone_number'],
            // Student fields
            degree: userData['degree'],
            section: userData['section'],
            aridNo: userData['arid_no'],
            semesterNo: userData['semester_no'],
            
            
            // Teacher fields
            department: userData['department'],
            subjectName: userData['subject_name'],
            shift: userData['shift'],
          );
          
          print("✅ Complete session saved! Navigating to dashboard...");
          _navigateToRole(userRole, userData);
        } else {
          print("❌ Login failed with status: $statusCode");
          print("❌ Error message: ${body['message']}");
          _showErrorDialog(
            context,
            "Login Failed",
            body['message'] ?? "Invalid email or password",
          );
        }
      } catch (e, stackTrace) {
        print("❌ Exception occurred during login:");
        print("❌ Error: $e");
        print("❌ Stack trace: $stackTrace");
        
        if (!mounted) return;
        setState(() => isLoading = false);
        _showErrorDialog(
          context,
          "Error",
          "An error occurred: ${e.toString()}",
        );
      }
    } else {
      print("❌ Form validation failed");
    }
  }

  void _navigateToRole(String role, Map<String, dynamic> userData) {
    if (role == 'Student') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentShell(userData: userData),
        ),
      );
    } else if (role == 'Teacher') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherShell(userData: userData),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminShell(userData: userData),
        ),
      );
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}