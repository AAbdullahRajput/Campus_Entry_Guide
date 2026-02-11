import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';

class ReminderSettingsDialog extends StatefulWidget {
  final dynamic schedule;
  final int userId;
  final String userRole;
  final Map<String, dynamic>? existingReminder;

  const ReminderSettingsDialog({
    Key? key,
    required this.schedule,
    required this.userId,
    required this.userRole,
    this.existingReminder,
  }) : super(key: key);

  @override
  State<ReminderSettingsDialog> createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<ReminderSettingsDialog> {
  final NotificationService _notificationService = NotificationService();

  late bool _isEnabled;
  late int _reminderMinutes;
  late String _vibrationPattern;
  late String _notificationTone;
  late String _repeatType;
  bool _isSaving = false;

  final List<int> _minuteOptions = [5, 10, 15, 20, 30, 45, 60];
  final Map<String, String> _vibrationOptions = {
    'none': 'No Vibration',
    'short': 'Short (1 buzz)',
    'long': 'Long (2 sec)',
    'pattern': 'Pattern (3 buzzes)',
  };
  final Map<String, String> _toneOptions = {
    'default': '🔔 Default',
    'bell': '🔔 Bell',
    'chime': '🎵 Chime',
    'alert': '⚠️ Alert',
  };
  final Map<String, String> _repeatOptions = {
    'once': 'Once',
    'daily': 'Daily (Same day each week)',
    'weekly': 'Every Week',
  };

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  void _initializeSettings() {
    if (widget.existingReminder != null) {
      _isEnabled = widget.existingReminder!['is_enabled'] == 1;
      _reminderMinutes = widget.existingReminder!['reminder_minutes'] ?? 10;
      _vibrationPattern = widget.existingReminder!['vibration_pattern'] ?? 'short';
      _notificationTone = widget.existingReminder!['notification_tone'] ?? 'default';
      _repeatType = widget.existingReminder!['repeat_type'] ?? 'daily';
    } else {
      _isEnabled = false;
      _reminderMinutes = 10;
      _vibrationPattern = 'short';
      _notificationTone = 'default';
      _repeatType = 'daily';
    }
  }

  Future<void> _saveReminder() async {
    setState(() => _isSaving = true);

    try {
      await ReminderService.setReminder(
        scheduleId: widget.schedule['id'],
        userId: widget.userId,
        userRole: widget.userRole,
        reminderMinutes: _reminderMinutes,
        notificationTone: _notificationTone,
        vibrationPattern: _vibrationPattern,
        repeatType: _repeatType,
        isEnabled: _isEnabled,
      );

      if (_isEnabled) {
        await _notificationService.scheduleClassReminder(
          scheduleId: widget.schedule['id'],
          subjectName: widget.schedule['subject_name'],
          dayOfWeek: widget.schedule['day_of_week'],
          startTime: widget.schedule['start_time'],
          roomNumber: widget.schedule['room_number'],
          minutesBefore: _reminderMinutes,
          vibrationPattern: _vibrationPattern,
          notificationTone: _notificationTone,
        );

        print('✅ Reminder scheduled successfully');
      } else {
        await _notificationService.cancelReminder(widget.schedule['id']);
        print('🚫 Reminder cancelled');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEnabled
                ? '✅ Reminder set for $_reminderMinutes minutes before class'
                : '🚫 Reminder disabled',
          ),
          backgroundColor: _isEnabled ? Colors.green : Colors.orange,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('❌ Error saving reminder: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteReminder() async {
    try {
      await ReminderService.deleteReminder(
        scheduleId: widget.schedule['id'],
        userId: widget.userId,
      );

      await _notificationService.cancelReminder(widget.schedule['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Reminder deleted'),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('❌ Error deleting reminder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEnabled ? Icons.notifications_active : Icons.notifications_off,
            color: _isEnabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Set Reminder')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.schedule['subject_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.schedule['day_of_week']} • ${_formatTime(widget.schedule['start_time'])}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    '📍 ${widget.schedule['room_number']}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Enable/Disable Toggle
            SwitchListTile(
              title: const Text(
                'Enable Reminder',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_isEnabled ? 'Reminder is ON' : 'Reminder is OFF'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() => _isEnabled = value);
              },
              activeColor: Colors.green,
            ),

            if (_isEnabled) ...[
              const Divider(height: 30),

              // Reminder Time
              const Text(
                'Remind me before:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _minuteOptions.map((minutes) {
                  final isSelected = _reminderMinutes == minutes;
                  return ChoiceChip(
                    label: Text('$minutes min'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _reminderMinutes = minutes);
                      }
                    },
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Vibration Pattern
              const Text(
                'Vibration:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ..._vibrationOptions.entries.map((entry) {
                return RadioListTile<String>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: _vibrationPattern,
                  onChanged: (value) {
                    setState(() => _vibrationPattern = value!);
                    _notificationService.playVibration(value!);
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),

              const SizedBox(height: 20),

              // Notification Tone
              const Text(
                'Notification Sound:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ..._toneOptions.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    onPressed: () {
                      _notificationService.playTone(entry.key);
                    },
                    tooltip: 'Preview',
                  ),
                  leading: Radio<String>(
                    value: entry.key,
                    groupValue: _notificationTone,
                    onChanged: (value) {
                      setState(() => _notificationTone = value!);
                    },
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),

              const SizedBox(height: 20),

              // Repeat Type
              const Text(
                'Repeat:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _repeatType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _repeatOptions.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _repeatType = value!);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.existingReminder != null)
          TextButton(
            onPressed: _isSaving ? null : _deleteReminder,
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveReminder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple, foregroundColor: Colors.white
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save',style: TextStyle(
              color: Colors.white, ),
        ),
        )
      ],
    );
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}