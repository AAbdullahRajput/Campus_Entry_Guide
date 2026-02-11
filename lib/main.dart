import 'package:campus_entry_guide/admin_dashboard.dart';
import 'package:campus_entry_guide/login_page.dart';
import 'package:campus_entry_guide/student_dashboard.dart';
import 'package:campus_entry_guide/teacher_dashboard.dart';
import 'package:flutter/material.dart';
import 'services/local_storage.dart';
import 'services/reminder_service.dart';
import '../services/notification_service.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notification Service
  await NotificationService().initialize();

  // ✅ START REMINDER BACKGROUND SERVICE
  print('🚀 Starting reminder background service from main.dart');
  ReminderService.startReminderBackgroundService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Entry Guide',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const SplashScreen(), // ✅ Start with splash screen
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

// ✅ SPLASH SCREEN WITH AUTO-LOGIN CHECK
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Show splash for at least 1.5 seconds for better UX
    await Future.delayed(const Duration(milliseconds: 1500));
    
    print("🔍 Checking login status...");
    
    final isLoggedIn = await LocalStorage.isLoggedIn();
    
    if (!mounted) return;

    if (isLoggedIn) {
      // User is logged in, get complete session data
      final session = await LocalStorage.getUserSession();
      
      if (session != null) {
        final role = session['role'];
        final userId = session['userId'];
        
        print('✅ Auto-login: User is logged in as $role (ID: $userId)');
        print('📋 Session data:');
        print('   Full Name: ${session['full_name']}');
        print('   Email: ${session['email']}');
        print('   Degree: ${session['degree']}');
        print('   Section: ${session['section']}');
        print('   Department: ${session['department']}');
        
        // Navigate to appropriate dashboard
        Widget dashboard;
        if (role == 'Student') {
          dashboard = StudentShell(userData: session);
        } else if (role == 'Teacher') {
          dashboard = TeacherShell(userData: session);
        } else if (role == 'Admin') {
          dashboard = AdminShell(userData: session);
        } else {
          print('❌ Unknown role: $role - Going to login');
          dashboard = const LoginScreen();
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => dashboard),
        );
      } else {
        // Session data invalid, go to login
        print('❌ Session data is null - Going to login');
        _navigateToLogin();
      }
    } else {
      // Not logged in, go to login screen
      print('❌ User not logged in - Going to login');
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon/Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              
              // App Name
              const Text(
                'Campus Entry Guide',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              
              // Tagline
              const Text(
                'Your Campus Companion',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 50),
              
              // Loading Indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              
              // Loading Text
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}