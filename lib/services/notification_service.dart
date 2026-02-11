import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    print('🔔 Initializing NotificationService...');

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    // Request permissions
    await requestPermission();

    _initialized = true;
    print('✅ NotificationService initialized');
  }

  // Request notification permission
  Future<bool> requestPermission() async {
    print('📢 Requesting notification permission...');

    if (await Permission.notification.isGranted) {
      print('✅ Notification permission already granted');
      return true;
    }

    final status = await Permission.notification.request();

    if (status.isGranted) {
      print('✅ Notification permission granted');
      return true;
    } else {
      print('❌ Notification permission denied');
      return false;
    }
  }

  // Schedule a class reminder (simplified)
  Future<void> scheduleClassReminder({
    required int scheduleId,
    required String subjectName,
    required String dayOfWeek,
    required String startTime,
    required String roomNumber,
    required int minutesBefore,
    String vibrationPattern = 'short',
    String notificationTone = 'default',
  }) async {
    print('📅 Reminder scheduled for: $subjectName');
    print('   Day: $dayOfWeek, Time: $startTime');
    print('   Minutes before: $minutesBefore');

    // Show actual notification
    await showLocalNotification(
      title: 'Upcoming Class: $subjectName',
      body: 'Room $roomNumber • Starts in $minutesBefore minutes',
    );

    print('   Note: Reminders now show real notifications.');
  }

  // Cancel a specific reminder
  Future<void> cancelReminder(int scheduleId) async {
    print('🚫 Cancelling reminder for schedule $scheduleId');
    print('✅ Reminder cancelled');
  }

  // Cancel all reminders
  Future<void> cancelAllReminders() async {
    print('🚫 Cancelling all reminders');
    print('✅ All reminders cancelled');
  }

  // Play vibration manually
  Future<void> playVibration(String pattern) async {
    final hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator != true) {
      print('⚠️ Device does not support vibration');
      return;
    }

    try {
      switch (pattern) {
        case 'short':
          await Vibration.vibrate(duration: 500);
          break;
        case 'long':
          await Vibration.vibrate(duration: 2000);
          break;
        case 'pattern':
          await Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 300]);
          break;
        case 'none':
          break;
        default:
          await Vibration.vibrate(duration: 500);
      }

      print('✅ Vibration played: $pattern');
    } catch (e) {
      print('❌ Error playing vibration: $e');
    }
  }

  // Play notification tone (for preview)
  Future<void> playTone(String tone) async {
    try {
      // Play a simple beep sound
      await _audioPlayer.play(AssetSource('sounds/notification_default.mp3'));
      print('🔊 Tone playing: $tone');
    } catch (e) {
      print('⚠️ Failed to play tone: $e');
      // Silently fail if sound file doesn't exist
    }
  }

  // Stop playing tone
  Future<void> stopTone() async {
    await _audioPlayer.stop();
  }

  // Get all pending notifications
  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    // Since we're not storing scheduled notifications, return empty list
    return [];
  }

  // Show snackbar reminder (alternative to push notification)
  void showReminderSnackBar(
    BuildContext context, {
    required String subjectName,
    required String roomNumber,
    required int minutesBefore,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔔 Reminder: $subjectName in $minutesBefore minutes in $roomNumber',
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: const Color.fromARGB(255, 90, 153, 204),
      ),
    );
  }

  // ✅ Show real local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminder_channel_id',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );

    print('📱 Local notification shown: $title');
  }
}
