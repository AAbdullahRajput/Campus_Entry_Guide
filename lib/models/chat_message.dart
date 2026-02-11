import 'dart:convert';

class ChatMessage {
  final int? id;
  final String message;
  final String response;
  final bool isUser;
  final DateTime timestamp;
  final String? intent;
  final double? confidence;
  final Map<String, dynamic>? entities;
  int? userRating; // Added for user ratings
  bool hasBeenRated; // Track if message has been rated

  ChatMessage({
    this.id,
    required this.message,
    required this.response,
    required this.isUser,
    required this.timestamp,
    this.intent,
    this.confidence,
    this.entities,
    this.userRating,
    this.hasBeenRated = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
  Map<String, dynamic>? parsedEntities;
  if (json['entities'] != null) {
    if (json['entities'] is String) {
      try {
        parsedEntities = Map<String, dynamic>.from(jsonDecode(json['entities']));
      } catch (e) {
        print('Error parsing entities: $e');
        parsedEntities = {};
      }
    } else if (json['entities'] is Map) {
      parsedEntities = Map<String, dynamic>.from(json['entities']);
    }
  }

  return ChatMessage(
    id: json['id'],
    message: json['message'] ?? '',
    response: json['response'] ?? 'Sorry, I encountered an error.',
    isUser: false,
    timestamp: json['created_at'] != null
        ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
        : DateTime.now(),
    intent: json['intent'] ?? 'unknown',
    confidence: json['confidence'] != null
        ? double.tryParse(json['confidence'].toString()) ?? 0.0
        : 0.0,
    entities: parsedEntities ?? {},
    hasBeenRated: false,
  );
}


  factory ChatMessage.user(String message) {
    return ChatMessage(
      message: message,
      response: '',
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.bot(
    String response, {
    String? intent,
    double? confidence,
    int? id,
  }) {
    return ChatMessage(
      id: id,
      message: '',
      response: response,
      isUser: false,
      timestamp: DateTime.now(),
      intent: intent,
      confidence: confidence,
      hasBeenRated: false,
    );
  }

  // Helper method to get confidence percentage
  String get confidencePercentage {
    if (confidence == null) return 'N/A';
    return '${(confidence! * 100).toStringAsFixed(0)}%';
  }

  // Helper method to get intent display name
  String get intentDisplayName {
    if (intent == null) return 'Unknown';
    return intent!.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  // Method to update rating
  ChatMessage copyWithRating(int rating) {
    return ChatMessage(
      id: id,
      message: message,
      response: response,
      isUser: isUser,
      timestamp: timestamp,
      intent: intent,
      confidence: confidence,
      entities: entities,
      userRating: rating,
      hasBeenRated: true,
    );
  }

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'response': response,
      'intent': intent,
      'confidence': confidence,
      'entities': entities != null ? jsonEncode(entities) : null,
      'timestamp': timestamp.toIso8601String(),
      'userRating': userRating,
    };
  }
}