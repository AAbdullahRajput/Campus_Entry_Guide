import 'package:flutter/material.dart';
import 'login_page.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'admin_dashboard.dart';
import 'local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if user is already logged in
  final session = await LocalStorage.getUserSession();
  final isLoggedIn = session['isLoggedIn'] ?? false;
  final role = session['role'];
  final userId = session['userId'];
  final email = session['email'];
  final fullName = session['fullName'];

  Widget homeScreen = const LoginScreen(); // default screen

  if (isLoggedIn && role != null && userId != null) {
    print("✅ User already logged in - Role: $role, ID: $userId");
    
    // Create userData map
    final userData = {
      'id': userId,
      'role': role,
      'email': email,
      'full_name': fullName,
    };

    // Route user to dashboard according to role
    if (role == 'Student') {
      homeScreen = StudentShell(userData: userData);
    } else if (role == 'Teacher') {
      homeScreen = TeacherShell(userData: userData);
    } else if (role == 'Admin') {
      homeScreen = AdminShell(userData: userData);
    }
  } else {
    print("❌ No active session - Showing login screen");
  }

  runApp(MyApp(homeScreen: homeScreen));
}

class MyApp extends StatelessWidget {
  final Widget homeScreen;

  const MyApp({super.key, required this.homeScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Entry Guide',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: homeScreen,
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}