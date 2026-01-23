import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

class LocalStorage {
  // ================= SAVE USER SESSION =================
  static Future<void> saveUserSession({
    required int userId,
    required String email,
    required String role,
    required String fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
    await prefs.setString('email', email);
    await prefs.setString('role', role);
    await prefs.setString('fullName', fullName);
    await prefs.setBool('isLoggedIn', true);
  }

  // ================= GET USER SESSION =================
  static Future<Map<String, dynamic>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getInt('userId'),
      'email': prefs.getString('email'),
      'role': prefs.getString('role'),
      'fullName': prefs.getString('fullName'),
      'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
    };
  }

  // ================= CHECK IF LOGGED IN =================
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // ================= CLEAR SESSION (LOGOUT) =================
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('fullName');
    await prefs.setBool('isLoggedIn', false);
  }

  // ================= LEGACY: GET CREDENTIALS (for remember me) =================
  static Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('email'),
      'password': prefs.getString('password'),
      'role': prefs.getString('role'),
    };
  }
}