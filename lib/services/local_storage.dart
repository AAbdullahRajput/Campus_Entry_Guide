import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // Save login credentials when "Remember Me" is checked
  static Future<void> saveCredentials(
    String email,
    String password,
    String role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    await prefs.setString('saved_role', role);
    print('✅ Remember Me credentials saved');
  }

  // Clear saved login credentials
  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.remove('saved_role');
    print('✅ Saved credentials cleared');
  }

  // ✅ SAVE USER SESSION - Use consistent keys
  static Future<void> saveUserSession({
    required int userId,
    required String email,
    required String role,
    required String fullName,
    String? phoneNumber,
    String? degree,
    String? section,
    String? department,
    String? aridNo,
    dynamic semesterNo,  // Can be String or int
    String? subjectName,
    String? shift,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save required fields
    await prefs.setInt('userId', userId);
    await prefs.setString('email', email);
    await prefs.setString('role', role);
    await prefs.setString('fullName', fullName);  // ✅ CHANGED to camelCase
    await prefs.setBool('isLoggedIn', true);
    
    // Save optional fields only if they exist
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await prefs.setString('phoneNumber', phoneNumber);
    }
    if (degree != null && degree.isNotEmpty) {
      await prefs.setString('degree', degree);
    }
    if (section != null && section.isNotEmpty) {
      await prefs.setString('section', section);
    }
    if (department != null && department.isNotEmpty) {
      await prefs.setString('department', department);
    }
    if (aridNo != null && aridNo.isNotEmpty) {
      await prefs.setString('aridNo', aridNo);
    }
    if (semesterNo != null) {
      await prefs.setString('semesterNo', semesterNo.toString());
    }
    if (subjectName != null && subjectName.isNotEmpty) {
      await prefs.setString('subjectName', subjectName);
    }
    if (shift != null && shift.isNotEmpty) {
      await prefs.setString('shift', shift);
    }
    
    print('✅ User session saved:');
    print('   userId: $userId');
    print('   email: $email');
    print('   role: $role');
    print('   fullName: $fullName');
    print('   phoneNumber: ${phoneNumber ?? "Not provided"}');
    print('   degree: ${degree ?? "Not provided"}');
    print('   section: ${section ?? "Not provided"}');
    print('   department: ${department ?? "Not provided"}');
  }

  // ✅ GET USER SESSION - Use same consistent keys
  static Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if logged in
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) {
      print('⚠️ User not logged in');
      return null;
    }
    
    // Get required fields
    final userId = prefs.getInt('userId');
    final email = prefs.getString('email');
    final role = prefs.getString('role');
    final fullName = prefs.getString('fullName');  // ✅ CHANGED to camelCase
    
    // If essential data is missing, return null
    if (userId == null || email == null || role == null) {
      print('⚠️ User session incomplete - missing required fields');
      return null;
    }

    // Get optional fields
    final phoneNumber = prefs.getString('phoneNumber');
    final degree = prefs.getString('degree');
    final section = prefs.getString('section');
    final department = prefs.getString('department');
    final aridNo = prefs.getString('aridNo');
    final semesterNo = prefs.getString('semesterNo');
    final subjectName = prefs.getString('subjectName');
    final shift = prefs.getString('shift');

    final session = {
      'userId': userId,
      'email': email,
      'role': role,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'degree': degree,
      'section': section,
      'department': department,
      'aridNo': aridNo,
      'semesterNo': semesterNo,
      'subjectName': subjectName,
      'shift': shift,
      'isLoggedIn': true,
    };
    
    print('✅ User session retrieved:');
    print('   userId: $userId');
    print('   role: $role');
    print('   degree: $degree');
    print('   section: $section');
    
    return session;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Clear user session (logout)
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();  // Clear everything
    print('✅ User session cleared (logged out)');
  }
}