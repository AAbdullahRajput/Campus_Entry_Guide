import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';


class ReminderService {
  static const String baseUrl = "http://192.168.100.63:3000";
  static Timer? _reminderCheckTimer;
  static final Set<String> _notifiedReminders = {}; // Changed to String for date tracking

  // ✅ START THE REMINDER BACKGROUND SERVICE
  static void startReminderBackgroundService() {
    if (_reminderCheckTimer != null) {
      print('⚠️ Reminder service already running');
      return;
    }

    print('🚀 Starting background reminder service');
    print('   Checking every 30 seconds');

    // Check every 30 seconds
    _reminderCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkAndTriggerReminders();
    });

    // Also check immediately
    _checkAndTriggerReminders();
  }

  // ✅ STOP THE REMINDER BACKGROUND SERVICE
  static void stopReminderBackgroundService() {
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = null;
    print('⏹️ Reminder service stopped');
  }

  // ✅ CHECK AND TRIGGER REMINDERS (FIXED)
  static Future<void> _checkAndTriggerReminders() async {
    try {
      final now = DateTime.now();
      final currentTimeInMinutes = now.hour * 60 + now.minute;
      final currentDay = _getDayName(now.weekday);

      print('\n⏰ [${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}] Checking reminders on $currentDay');
      print('   Current time in minutes: $currentTimeInMinutes');

      // Get all active reminders
      final reminders = await _getAllActiveReminders();
      print('   Found ${reminders.length} active reminders');

      if (reminders.isEmpty) {
        print('   ⚠️ No active reminders found');
        return;
      }

      for (var reminder in reminders) {
        try {
          final scheduleId = reminder['schedule_id'];
          
          // ✅ Create unique key per day
          final notificationKey = '${scheduleId}-${now.year}-${now.month}-${now.day}';
          
          // Skip if already notified today
          if (_notifiedReminders.contains(notificationKey)) {
            print('   ⏭️ Skipping schedule $scheduleId (already notified today)');
            continue;
          }

          // ✅ FIX: Data is now directly in reminder, not nested
          final dayOfWeek = reminder['day_of_week']?.toString() ?? '';
          
          // Check if it's the right day
          if (dayOfWeek.toLowerCase() != currentDay.toLowerCase()) {
            print('   ⏭️ Skipping schedule $scheduleId (wrong day: $dayOfWeek vs $currentDay)');
            continue;
          }

          // Parse class time
          final startTimeStr = reminder['start_time']?.toString() ?? '';
          if (startTimeStr.isEmpty) {
            print('   ⚠️ No start time for schedule $scheduleId');
            continue;
          }

          final int classTimeInMinutes = _parseTimeToMinutes(startTimeStr);
          final int reminderMinutes = (reminder['reminder_minutes'] ?? 10) as int;
          final int reminderTimeInMinutes = classTimeInMinutes - reminderMinutes;

          print('   📍 Schedule $scheduleId (${reminder['subject_name']}):');
          print('      Class at: ${_minutesToTimeString(classTimeInMinutes)} ($classTimeInMinutes min)');
          print('      Remind at: ${_minutesToTimeString(reminderTimeInMinutes)} ($reminderTimeInMinutes min)');
          print('      Current: ${_minutesToTimeString(currentTimeInMinutes)} ($currentTimeInMinutes min)');
          print('      Difference: ${currentTimeInMinutes - reminderTimeInMinutes} minutes');

          // ✅ Check if it's time to trigger (within 2-minute window)
          // ✅ Check if it's time to trigger (within 2-minute window)
          final int triggerTime = reminderTimeInMinutes.toInt();
          if (currentTimeInMinutes >= triggerTime && 
              currentTimeInMinutes <= triggerTime + 2) {
            
            print('   🔔 TRIGGERING REMINDER for schedule $scheduleId!');
            
            await _triggerReminder(
              scheduleId: scheduleId,
              schedule: reminder,
              reminderMinutes: reminderMinutes,
              vibrationPattern: reminder['vibration_pattern'] ?? 'short',
              notificationTone: reminder['notification_tone'] ?? 'default',
            );

            // Mark as notified for today
            _notifiedReminders.add(notificationKey);
            print('   ✅ Marked as notified: $notificationKey');

            // Clear at midnight
            final midnight = DateTime(now.year, now.month, now.day + 1);
            final timeUntilMidnight = midnight.difference(now);
            Future.delayed(timeUntilMidnight, () {
              _notifiedReminders.remove(notificationKey);
              print('🌙 Cleared notification flag at midnight: $notificationKey');
            });
          } else {
            final diff = reminderTimeInMinutes - currentTimeInMinutes;
            if (diff > 0 && diff < 60) {
              print('   ⏳ Reminder will trigger in $diff minutes');
            }
          }
        } catch (e) {
          print('   ❌ Error processing reminder: $e');
        }
      }
    } catch (e) {
      print('❌ Error checking reminders: $e');
    }
  }

  // ✅ GET ALL ACTIVE REMINDERS WITH SCHEDULE INFO
  static Future<List<dynamic>> _getAllActiveReminders() async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/get-all-active-reminders"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reminders'] ?? [];
      }
      return [];
    } catch (e) {
      print('❌ Error fetching reminders: $e');
      return [];
    }
  }

  // ✅ TRIGGER REMINDER (Show notification)
 static Future<void> _triggerReminder({
  required int scheduleId,
  required Map<String, dynamic> schedule,
  required int reminderMinutes,
  required String vibrationPattern,
  required String notificationTone,
}) async {
  try {
    print('📢 ========================================');
    print('📢 REMINDER TRIGGERED!');
    print('📢 ========================================');
    print('   Subject: ${schedule['subject_name']}');
    print('   Room: ${schedule['room_number']}');
    print('   Time: ${schedule['start_time']}');
    print('   Minutes before: $reminderMinutes');
    print('📢 ========================================');

    // Update backend that reminder was sent
    await http.post(
      Uri.parse("$baseUrl/log-reminder-triggered"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "schedule_id": scheduleId,
        "triggered_at": DateTime.now().toIso8601String(),
      }),
    );

    // ✅ Vibration & tone
    try {
      await NotificationService().playVibration(vibrationPattern);
      await NotificationService().playTone(notificationTone);
      print('✅ Reminder vibration & tone played successfully');
    } catch (e) {
      print('❌ Failed to vibrate or play tone: $e');
    }

    // ✅ Show real notification

    await NotificationService().showLocalNotification(
      title: 'Class Reminder: ${schedule['subject_name']}',
      body:
          'Starts in $reminderMinutes minutes in Room ${schedule['room_number']}',
    );

  } catch (e) {
    print('❌ Error triggering reminder: $e');
  }
}


  // ✅ HELPER: Convert time string (HH:MM:SS) to minutes
  static int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      return hours * 60 + minutes;
    } catch (e) {
      print('❌ Error parsing time: $timeStr - $e');
      return 0;
    }
  }

  // ✅ HELPER: Convert minutes back to time string
  static String _minutesToTimeString(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // ✅ HELPER: Get day name from weekday
  static String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  // Set or update a reminder
  static Future<Map<String, dynamic>> setReminder({
    required int scheduleId,
    required int userId,
    required String userRole,
    required int reminderMinutes,
    required String notificationTone,
    required String vibrationPattern,
    required String repeatType,
    required bool isEnabled,
  }) async {
    try {
      print('📤 Setting reminder for schedule $scheduleId');

      final response = await http.post(
        Uri.parse("$baseUrl/set-schedule-reminder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "schedule_id": scheduleId,
          "user_id": userId,
          "user_role": userRole,
          "reminder_minutes": reminderMinutes,
          "notification_tone": notificationTone,
          "vibration_pattern": vibrationPattern,
          "repeat_type": repeatType,
          "is_enabled": isEnabled,
        }),
      );

      print('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Reset notified reminders when setting new reminder
        if (isEnabled) {
          final now = DateTime.now();
          final key = '${scheduleId}-${now.year}-${now.month}-${now.day}';
          _notifiedReminders.remove(key);
        }
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to set reminder: ${response.body}');
      }
    } catch (e) {
      print('❌ Error setting reminder: $e');
      rethrow;
    }
  }

  // Get all reminders for a user
  static Future<List<dynamic>> getReminders({
    required int userId,
    required String userRole,
    int? scheduleId,
  }) async {
    try {
      print('📥 Fetching reminders for user $userId');

      final response = await http.post(
        Uri.parse("$baseUrl/get-schedule-reminders"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "user_role": userRole,
          if (scheduleId != null) "schedule_id": scheduleId,
        }),
      );

      print('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reminders'] ?? [];
      } else {
        throw Exception('Failed to fetch reminders: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching reminders: $e');
      rethrow;
    }
  }

  // Get single reminder for a specific schedule
  static Future<Map<String, dynamic>?> getSingleReminder({
    required int scheduleId,
    required int userId,
  }) async {
    try {
      print('📥 Fetching reminder for schedule $scheduleId');

      final response = await http.post(
        Uri.parse("$baseUrl/get-single-reminder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "schedule_id": scheduleId,
          "user_id": userId,
        }),
      );

      print('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reminder'];
      } else {
        throw Exception('Failed to fetch reminder: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching reminder: $e');
      return null;
    }
  }

  // Delete a reminder
  static Future<Map<String, dynamic>> deleteReminder({
    required int scheduleId,
    required int userId,
  }) async {
    try {
      print('🗑️ Deleting reminder for schedule $scheduleId');

      final response = await http.post(
        Uri.parse("$baseUrl/delete-schedule-reminder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "schedule_id": scheduleId,
          "user_id": userId,
        }),
      );

      print('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final now = DateTime.now();
        final key = '${scheduleId}-${now.year}-${now.month}-${now.day}';
        _notifiedReminders.remove(key);
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to delete reminder: ${response.body}');
      }
    } catch (e) {
      print('❌ Error deleting reminder: $e');
      rethrow;
    }
  }

  // Toggle reminder on/off
  static Future<Map<String, dynamic>> toggleReminder({
    required int scheduleId,
    required int userId,
    required bool isEnabled,
  }) async {
    try {
      print('🔄 Toggling reminder for schedule $scheduleId to ${isEnabled ? "ON" : "OFF"}');

      final response = await http.post(
        Uri.parse("$baseUrl/toggle-schedule-reminder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "schedule_id": scheduleId,
          "user_id": userId,
          "is_enabled": isEnabled,
        }),
      );

      print('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (!isEnabled) {
          final now = DateTime.now();
          final key = '${scheduleId}-${now.year}-${now.month}-${now.day}';
          _notifiedReminders.remove(key);
        }
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to toggle reminder: ${response.body}');
      }
    } catch (e) {
      print('❌ Error toggling reminder: $e');
      rethrow;
    }
  }

  // Get timetable PDF
  static Future<Map<String, dynamic>?> getTimetablePDF({
    required int userId,
    required String userRole,
  }) async {
    try {
      print('📄 Fetching timetable PDF for user $userId');

      final response = await http.post(
        Uri.parse("$baseUrl/get-timetable-pdf"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "user_role": userRole,
        }),
      );

      print('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['pdf'];
      } else if (response.statusCode == 404) {
        print('⚠️ No PDF found');
        return null;
      } else {
        throw Exception('Failed to fetch PDF: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching PDF: $e');
      return null;
    }
  }
}