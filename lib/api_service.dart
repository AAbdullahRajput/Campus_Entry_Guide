import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for backend
  // static const String baseUrl = 'http://10.0.2.2:3000'; // Android emulator
  static const String baseUrl = 'http://192.168.100.63:3000';
  // For iOS simulator use: 'http://localhost:3000'
  // For physical device use: 'http://192.168.208.1:3000'

  // ===================== REGISTER =====================
  static Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Network error: ${e.toString()}'},
      };
    }
  }

  // ===================== LOGIN =====================
  static Future<Map<String, dynamic>> login(
      String email, String password, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Server error', 'error': e.toString()},
      };
    }
  }

  // // ===================== GOOGLE LOGIN =====================
  // static Future<Map<String, dynamic>> googleLogin(
  //     String email, String fullName, String defaultPassword) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/google-login'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'email': email,
  //         'full_name': fullName,
  //         'default_password': defaultPassword,
  //       }),
  //     );

  //     return {
  //       'statusCode': response.statusCode,
  //       'body': jsonDecode(response.body),
  //     };
  //   } catch (e) {
  //     return {
  //       'statusCode': 500,
  //       'body': {'message': 'Server error', 'error': e.toString()},
  //     };
  //   }
  // }

  // // ===================== GOOGLE CHECK EMAIL =====================
  // static Future<Map<String, dynamic>> googleCheckEmail(String email) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/google-check-email'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({'email': email}),
  //     );

  //     return {
  //       'statusCode': response.statusCode,
  //       'body': jsonDecode(response.body),
  //     };
  //   } catch (e) {
  //     return {
  //       'statusCode': 500,
  //       'body': {'message': 'Server error', 'error': e.toString()},
  //     };
  //   }
  // }

  // // ===================== GOOGLE VERIFY OTP =====================
  // static Future<Map<String, dynamic>> googleVerifyOtp(String email, String otp) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/google-verify-otp'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'email': email,
  //         'otp': otp,
  //       }),
  //     );

  //     return {
  //       'statusCode': response.statusCode,
  //       'body': jsonDecode(response.body),
  //     };
  //   } catch (e) {
  //     return {
  //       'statusCode': 500,
  //       'body': {'message': 'Server error', 'error': e.toString()},
  //     };
  //   }
  // }

  // ===================== EMAIL OTP =====================
  static Future<Map<String, dynamic>> sendEmailOtp(String email, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-email-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'role': role,
        }),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Server error', 'error': e.toString()},
      };
    }
  }

  static Future<Map<String, dynamic>> verifyEmailOtp(
      String email, String otp, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-email-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'role': role,
        }),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Server error', 'error': e.toString()},
      };
    }
  }

  // ===================== PHONE OTP =====================
  static Future<Map<String, dynamic>> sendPhoneOtp(String phone, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-phone-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'role': role,
        }),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Server error', 'error': e.toString()},
      };
    }
  }

  static Future<Map<String, dynamic>> verifyPhoneOtp(
      String phone, String otp, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-phone-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
          'role': role,
        }),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Server error', 'error': e.toString()},
      };
    }
  }
}