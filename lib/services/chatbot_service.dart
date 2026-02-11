import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatbotService {
  static const String baseUrl = "http://192.168.100.63:3000";

  static Future<Map<String, dynamic>> sendMessage({
    required int userId,
    required String userRole,
    required String message,
    String? sessionId,
    String? userFullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chatbot-query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'userRole': userRole,
          'message': message,
          'sessionId': sessionId,
          'userFullName': userFullName,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Bot Response: ${data['intent']} (${data['confidence']})');
        return data;
      } else {
        print('❌ Server error: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Chatbot Error: $e');
      return {
        'response': 'Sorry, I\'m having trouble connecting. Please check your internet.',
        'error': true,
      };
    }
  }

  static Future<List<dynamic>> getHistory({
  required String sessionId,
  required int userId,
  required String userRole,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/get-chatbot-history'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionId': sessionId,
        'userId': userId,          // ADD THIS
        'userRole': userRole,      // ADD THIS
        'limit': 50,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['history'] ?? [];
    }
    return [];
  } catch (e) {
    print('❌ History Error: $e');
    return [];
  }
}

  static Future<bool> clearConversation({
  required String sessionId,
  required int userId,
  required String userRole,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/clear-chatbot-conversation'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionId': sessionId,
        'userId': userId,          // ADD THIS
        'userRole': userRole,      // ADD THIS
      }),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  } catch (e) {
    print('❌ Clear Error: $e');
    return false;
  }
}

  static Future<Map<String, List<dynamic>>> getCommonQuestions({
    required String userRole,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get-common-questions?userRole=$userRole'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, List<dynamic>>.from(data['questions'] ?? {});
      }
      return {};
    } catch (e) {
      print('❌ Common Questions Error: $e');
      return {};
    }
  }

  static Future<bool> submitFeedback({
    required int messageId,
    required int userId,
    required String userRole,
    required int rating,
    String? feedbackText,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit-chatbot-feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messageId': messageId,
          'userId': userId,
          'userRole': userRole,
          'rating': rating,
          'feedbackText': feedbackText,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('✅ Feedback submitted: $rating/5');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Feedback Error: $e');
      return false;
    }
  }

  static Future<void> saveSessionId(String sessionId, int userId, String userRole) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chatbot_session_${userRole}_$userId';  // CHANGE THIS LINE
    await prefs.setString(key, sessionId);
    print('✅ Session saved for $userRole $userId');
  } catch (e) {
    print('❌ Session save error: $e');
  }
}

  static Future<String?> getSessionId(int userId, String userRole) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chatbot_session_${userRole}_$userId';  // CHANGE THIS LINE
    final sessionId = prefs.getString(key);
    if (sessionId != null) {
      print('✅ Session found for $userRole $userId');
    }
    return sessionId;
  } catch (e) {
    print('❌ Session get error: $e');
    return null;
  }
}

  static Future<void> clearSessionId(int userId, String userRole) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chatbot_session_${userRole}_$userId';  // CHANGE THIS LINE
    await prefs.remove(key);
    print('✅ Session cleared for $userRole $userId');
  } catch (e) {
    print('❌ Session clear error: $e');
  }
}
}