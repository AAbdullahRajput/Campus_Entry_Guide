import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Common
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  String passwordStrength = "";

  // Student
  final aridNoController = TextEditingController();
  final degreeController = TextEditingController();
  final semesterController = TextEditingController();
  final sectionController = TextEditingController();

  // Teacher
  final departmentController = TextEditingController();
  List<TextEditingController> subjectControllers = [TextEditingController()];
  String teacherShift = 'Morning';

  // Admin
  final adminDepartmentController = TextEditingController();
  final AdminIdController = TextEditingController();
  final officeNameController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  String selectedRole = 'Student';

  // Animation
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _animController.forward();
  }

  // ================= VALIDATORS =================

  String? requiredValidator(String? v, String label) {
    if (v == null || v.trim().isEmpty) return "$label is required";
    return null;
  }

  String? emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return "Email is required";
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(v)) return "Enter a valid email (example@domain.com)";
    return null;
  }

  String? passwordValidator(String? v) {
    if (v == null || v.isEmpty) return "Password is required";
    if (v.length < 6) return "Minimum 6 characters required";
    return null;
  }

  String? confirmPasswordValidator(String? v) {
    if (v != passwordController.text) return "Passwords do not match";
    return null;
  }

  @override
  void dispose() {
    for (var c in [
      fullNameController,
      emailController,
      passwordController,
      confirmPasswordController,
      phoneController,
      aridNoController,
      degreeController,
      semesterController,
      sectionController,
      departmentController,
      adminDepartmentController,
      AdminIdController,
      officeNameController,
      ...subjectControllers,
    ]) {
      c.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  void _clearAllFields() {
    for (var c in [
      fullNameController,
      emailController,
      passwordController,
      confirmPasswordController,
      phoneController,
      aridNoController,
      degreeController,
      semesterController,
      sectionController,
      departmentController,
      adminDepartmentController,
      AdminIdController,
      officeNameController,
      ...subjectControllers,
    ]) {
      c.clear();
    }
    subjectControllers = [TextEditingController()];
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top Image
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.33,
              width: double.infinity,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/register.jpg"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          // Bottom Card
          DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.7,
            maxChildSize: 0.99,
            builder: (context, scrollController) {
              return SlideTransition(
                position: _slideAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const Text(
                            "Create Account",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          // Role Dropdown
                          _dropdown(
                            value: selectedRole,
                            items: ['Student', 'Teacher', 'Admin'],
                            hint: "Role",
                            onChanged: (v) {
                              setState(() {
                                selectedRole = v!;
                                _clearAllFields();
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          _field(fullNameController, "Full Name", Icons.person,
                              validator: (v) => requiredValidator(v, "Full Name")),
                          if (selectedRole == 'Student') ...[
                            _field(aridNoController, "ARID No", Icons.badge,
                                validator: (v) => requiredValidator(v, "ARID No")),
                            _field(degreeController, "Degree", Icons.school,
                                validator: (v) => requiredValidator(v, "Degree")),
                            _field(semesterController, "Semester No", Icons.confirmation_number,
                                validator: (v) => requiredValidator(v, "Semester")),
                            _field(sectionController, "Section", Icons.group,
                                validator: (v) => requiredValidator(v, "Section")),
                          ],
                          if (selectedRole == 'Teacher') ...[
                            _field(departmentController, "Department", Icons.apartment,
                                validator: (v) => requiredValidator(v, "Department")),
                            const SizedBox(height: 12),
                            const Text("Subjects",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 8),
                            ...List.generate(subjectControllers.length, (i) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _field(subjectControllers[i], "Subject Name", Icons.book,
                                        validator: (v) => requiredValidator(v, "Subject")),
                                  ),
                                  if (subjectControllers.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          subjectControllers.removeAt(i);
                                        });
                                      },
                                    ),
                                ],
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => setState(
                                    () => subjectControllers.add(TextEditingController())),
                                child: const Text("+ Add Subject", style: TextStyle(color: Colors.green)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _dropdown(
                              value: teacherShift,
                              items: ['Morning', 'Evening'],
                              hint: "Shift",
                              onChanged: (v) => setState(() => teacherShift = v!),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (selectedRole == 'Admin') ...[
                            _field(adminDepartmentController, "Department", Icons.apartment,
                                validator: (v) => requiredValidator(v, "Department")),
                            _field(AdminIdController, "Admin ID", Icons.badge,
                                validator: (v) => requiredValidator(v, "Admin ID")),
                            _field(officeNameController, "Office Name", Icons.business,
                                validator: (v) => requiredValidator(v, "Office Name")),
                          ],
                          _field(phoneController, "Phone Number", Icons.phone,
                              validator: (v) => requiredValidator(v, "Phone Number")),
                          _field(emailController, "Email", Icons.email, validator: emailValidator),
                          _passwordField(passwordController, "Password", obscurePassword, () {
                            setState(() => obscurePassword = !obscurePassword);
                          }, validator: passwordValidator),
                          _passwordField(confirmPasswordController, "Confirm Password", obscureConfirmPassword, () {
                            setState(() => obscureConfirmPassword = !obscureConfirmPassword);
                          }, validator: confirmPasswordValidator),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _register,
                              child: const Text("Register"),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Already have an account? ", style: TextStyle(color: Colors.black)),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration: const Duration(milliseconds: 400),
                                        pageBuilder: (_, __, ___) => const LoginScreen(),
                                        transitionsBuilder: (_, animation, __, child) {
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
                                  },
                                  child: const Text("Login", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= COMPONENTS =================

  InputDecoration _decoration(String hint) => InputDecoration(
        filled: true,
        fillColor: Colors.green.shade50,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(fontSize: 12),
      );

  Widget _field(TextEditingController c, String h, IconData i,
          {String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: TextFormField(
          controller: c,
          validator: validator,
          decoration: _decoration(h).copyWith(
            prefixIcon: Icon(i, color: Colors.green),
          ),
        ),
      );

  Widget _passwordField(TextEditingController c, String h, bool obscure,
          VoidCallback toggle,
          {String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: TextFormField(
          controller: c,
          obscureText: obscure,
          validator: validator,
          decoration: _decoration(h).copyWith(
            prefixIcon: const Icon(Icons.lock, color: Colors.green),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: toggle,
            ),
          ),
        ),
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.green),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        decoration: _decoration(hint),
      );

  // ================= SUBMIT =================

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> data = {
      "role": selectedRole,
      "full_name": fullNameController.text.trim(),
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "phone_number": phoneController.text.trim(),
    };

    if (selectedRole == "Student") {
      data.addAll({
        "arid_no": aridNoController.text.trim(),
        "degree": degreeController.text.trim(),
        "semester_no": semesterController.text.trim(),
        "section": sectionController.text.trim(),
      });
    } else if (selectedRole == "Teacher") {
      data.addAll({
        "department": departmentController.text.trim(),
        "subject_name": subjectControllers.map((c) => c.text.trim()).join(","),
        "shift": teacherShift,
      });
    } else if (selectedRole == "Admin") {
      data.addAll({
        "department": adminDepartmentController.text.trim(),
        "admin_id": AdminIdController.text.trim(),
        "office_name": officeNameController.text.trim(),
      });
    }

    try {
      var url = Uri.parse("http://192.168.100.63:3000/register");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("Server Response: ${response.body}");

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registered successfully!")),
        );
        _clearAllFields();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        var res = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res["message"] ?? "Registration failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
