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

  // ✅ UPDATED - Save user session data after login
  static Future<void> saveUserSession({
    required int userId,
    required String email,
    required String role,
    required String fullName,
    String? phoneNumber,
    String? degree,        // ✅ ADD THIS
    String? section,       // ✅ ADD THIS
    String? department,    // ✅ ADD THIS
    String? aridNo,        // ✅ ADD THIS
    String? semesterNo,    // ✅ ADD THIS
    String? subjectName,   // ✅ ADD THIS
    String? shift,         // ✅ ADD THIS
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
    await prefs.setString('email', email);
    await prefs.setString('role', role);
    await prefs.setString('full_name', fullName);
    
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await prefs.setString('phone_number', phoneNumber);
    }
    
    // ✅ Save role-specific fields
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
      await prefs.setString('arid_no', aridNo);
    }
    if (semesterNo != null && semesterNo.isNotEmpty) {
      await prefs.setString('semester_no', semesterNo);
    }
    if (subjectName != null && subjectName.isNotEmpty) {
      await prefs.setString('subject_name', subjectName);
    }
    if (shift != null && shift.isNotEmpty) {
      await prefs.setString('shift', shift);
    }
    
    // ✅ Save isLoggedIn flag
    await prefs.setBool('isLoggedIn', true);
    
    print('✅ User session saved:');
    print('   userId: $userId');
    print('   email: $email');
    print('   role: $role');
    print('   full_name: $fullName');
    print('   phone_number: ${phoneNumber ?? "Not provided"}');
    print('   degree: ${degree ?? "Not provided"}');
    print('   section: ${section ?? "Not provided"}');
    print('   department: ${department ?? "Not provided"}');
  }

  // ✅ UPDATED - Get user session data
  static Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final email = prefs.getString('email');
    final role = prefs.getString('role');
    final fullName = prefs.getString('full_name');
    final phoneNumber = prefs.getString('phone_number');
    final degree = prefs.getString('degree');
    final section = prefs.getString('section');
    final department = prefs.getString('department');
    final aridNo = prefs.getString('arid_no');
    final semesterNo = prefs.getString('semester_no');
    final subjectName = prefs.getString('subject_name');
    final shift = prefs.getString('shift');

    // If essential data is missing, return null
    if (userId == null || email == null || role == null || fullName == null) {
      print('⚠️ User session not found or incomplete');
      return null;
    }

    return {
      'userId': userId,
      'email': email,
      'role': role,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'degree': degree,
      'section': section,
      'department': department,
      'arid_no': aridNo,
      'semester_no': semesterNo,
      'subject_name': subjectName,
      'shift': shift,
    };
  }

  // ✅ ADD THIS - Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // ✅ UPDATED - Clear user session (logout)
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('full_name');
    await prefs.remove('phone_number');
    await prefs.remove('degree');
    await prefs.remove('section');
    await prefs.remove('department');
    await prefs.remove('arid_no');
    await prefs.remove('semester_no');
    await prefs.remove('subject_name');
    await prefs.remove('shift');
    await prefs.setBool('isLoggedIn', false);
    print('✅ User session cleared');
  }
}