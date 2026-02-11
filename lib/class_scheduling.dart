import 'package:campus_entry_guide/pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/reminder_service.dart';
import '../services/notification_service.dart';
import '../widgets/reminder_settings_dialog.dart';

class ClassSchedulingScreen extends StatefulWidget {
  final int userId;
  final String userRole;
  final String userName;
  final String? degree;
  final String? section;
  final String? semesterNo;

  const ClassSchedulingScreen({
    Key? key,
    required this.userId,
    required this.userRole,
    required this.userName,
    this.degree,
    this.section,
    this.semesterNo,
  }) : super(key: key);

  @override
  State<ClassSchedulingScreen> createState() => _ClassSchedulingScreenState();
}

class _ClassSchedulingScreenState extends State<ClassSchedulingScreen> {
  bool isLoading = true;
  bool isUploading = false;
  List<dynamic> schedules = [];
  Map<String, List<dynamic>> groupedSchedules = {};
  String selectedDay = 'all';
  int totalClasses = 0;
  Map<int, Map<String, dynamic>> reminders = {};
  bool _remindersLoaded = false;

  final List<String> days = ['all', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _validateInputs();
    fetchSchedules();
    _loadReminders();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      await _notificationService.requestPermission();
      print('✅ Notifications initialized successfully');
    } catch (e) {
      print('❌ Notification initialization error: $e');
    }
  }

  Future<void> _loadReminders() async {
    try {
      print('📥 Loading reminders for user ${widget.userId}...');
      final reminderList = await ReminderService.getReminders(
        userId: widget.userId,
        userRole: widget.userRole,
      );

      setState(() {
        reminders = {};
        for (var r in reminderList) {
          reminders[r['schedule_id']] = r;
        }
        _remindersLoaded = true;
      });

      print('✅ Loaded ${reminders.length} reminders');
    } catch (e) {
      print('❌ Error loading reminders: $e');
      setState(() => _remindersLoaded = true);
    }
  }

  void _validateInputs() {
    print('🔍 [VALIDATION] Checking ClassSchedulingScreen inputs:');
    print('   userId: ${widget.userId} (type: ${widget.userId.runtimeType})');
    print('   userRole: ${widget.userRole}');
    print('   userName: ${widget.userName}');
    print('   degree: ${widget.degree} (type: ${widget.degree.runtimeType})');
    print('   section: ${widget.section} (type: ${widget.section.runtimeType})');
    print('   semesterNo: ${widget.semesterNo} (type: ${widget.semesterNo.runtimeType})');

    if (widget.userRole == 'Student') {
      if (widget.degree == null || widget.degree!.isEmpty) {
        print('❌ [VALIDATION] ERROR: degree is null or empty!');
        _showErrorAndGoBack('Missing degree information');
        return;
      }
      if (widget.section == null || widget.section!.isEmpty) {
        print('❌ [VALIDATION] ERROR: section is null or empty!');
        _showErrorAndGoBack('Missing section information');
        return;
      }
      if (widget.semesterNo == null || widget.semesterNo!.isEmpty) {
        print('❌ [VALIDATION] ERROR: semesterNo is null or empty!');
        _showErrorAndGoBack('Missing semester information');
        return;
      }
      print('✅ [VALIDATION] All student fields are valid');
    }
  }

  void _showErrorAndGoBack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> fetchSchedules() async {
    print('\n🔍 [TIMETABLE] fetchSchedules() called');
    print('📊 User Role: ${widget.userRole}');
    print('📊 User ID: ${widget.userId}');
    print('📊 Degree: ${widget.degree}');
    print('📊 Section: ${widget.section}');
    print('📊 Semester No: ${widget.semesterNo}');
    print('📊 Selected Day: $selectedDay');
    print('📊 User Name: ${widget.userName}'); 

    setState(() => isLoading = true);

    try {
      if (widget.userRole == 'Student') {
        if (widget.degree == null || widget.degree!.isEmpty ||
            widget.section == null || widget.section!.isEmpty ||
            widget.semesterNo == null || widget.semesterNo!.isEmpty) {
          throw Exception(
            'Missing required fields - degree: ${widget.degree}, section: ${widget.section}, semesterNo: ${widget.semesterNo}',
          );
        }
      }

      // ✅ For teachers, verify userId exists
    if (widget.userRole == 'Teacher' && widget.userId == null) {
      throw Exception('Teacher ID is required');
    }

      final url = widget.userRole == 'Teacher'
          ? Uri.parse("http://192.168.100.63:3000/get-teacher-schedules")
          : Uri.parse("http://192.168.100.63:3000/get-student-schedules");

      final body = widget.userRole == 'Teacher'
          ? {
              "teacher_id": widget.userId,
              "day_of_week": selectedDay,
            }
          : {
              "degree": widget.degree,
              "section": widget.section,
              "semesterNo": widget.semesterNo,
              "day_of_week": selectedDay,
            };

      print('📍 Request URL: $url');
      print('📦 Request Body: ${jsonEncode(body)}');
      print('⏳ Sending request...');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout after 10 seconds');
        },
      );

      print('📡 Response received!');
      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('✅ Parsing response data...');
        print('📊 Schedules count: ${(data['schedules'] as List?)?.length ?? 0}');
        print('📊 Total classes: ${data['totalClasses'] ?? 0}');

        setState(() {
          schedules = data['schedules'] ?? [];
          groupedSchedules = Map<String, List<dynamic>>.from(
            (data['groupedSchedules'] as Map).map(
              (key, value) => MapEntry(key, List<dynamic>.from(value)),
            ),
          );
          totalClasses = data['totalClasses'] ?? 0;
          isLoading = false;
        });

        print('✅ State updated successfully!');
        print('📊 Final schedules count: ${schedules.length}');
      } else {
        print('❌ Server returned error status: ${response.statusCode}');
        throw Exception('Server returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('💥 ERROR in fetchSchedules: $e');
      print('📍 Error type: ${e.runtimeType}');

      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading schedules: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: fetchSchedules,
            ),
          ),
        );
      }
    }
  }

  Future<void> _viewTimetablePDF() async {
    try {
      print('📄 Fetching timetable PDF...');

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final pdfData = await ReminderService.getTimetablePDF(
        userId: widget.userId,
        userRole: widget.userRole,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (pdfData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 No timetable PDF found. Please upload one first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      print('✅ PDF data retrieved, opening viewer...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(
            pdfBase64: pdfData['base64'],
            filename: pdfData['filename'] ?? 'timetable.pdf',
            shift: pdfData['shift'],
            semester: pdfData['semester'],
            version: pdfData['version'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('❌ Error viewing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReminderSettings(dynamic schedule) async {
    final scheduleId = schedule['id'];
    final existingReminder = reminders[scheduleId];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReminderSettingsDialog(
        schedule: schedule,
        userId: widget.userId,
        userRole: widget.userRole,
        existingReminder: existingReminder,
      ),
    );

    if (result == true) {
      await _loadReminders();
    }
  }

  Future<void> uploadTimetable() async {
    try {
      print('📁 Opening file picker...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) {
        print('❌ No file selected');
        return;
      }

      print('✅ File selected: ${result.files.single.name}');
      print('📏 File size: ${result.files.single.size} bytes');

      setState(() => isUploading = true);

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final base64Pdf = base64Encode(bytes);

      print('🔄 Converting to base64... Size: ${base64Pdf.length} chars');
      print('📤 Uploading to server...');

      final response = await http.post(
        Uri.parse("http://192.168.100.63:3000/upload-timetable"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": widget.userId,
          "userRole": widget.userRole,
          "degree": widget.degree,
          "section": widget.section,
          "semesterNo": widget.semesterNo,
          "teacherName": widget.userName,
          "pdfBase64": base64Pdf,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Upload timeout - PDF might be too large');
        },
      );

      print('📡 Upload response received!');
      print('📊 Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      setState(() => isUploading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('✅ Upload successful!');
        print('📊 Total classes parsed: ${data['totalClasses']}');

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(width: 10),
                const Text('Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ Timetable uploaded and parsed successfully!'),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow('Total Classes:', '${data['totalClasses'] ?? 0}'),
                      _statRow('Shift:', data['shift'] ?? 'Unknown'),
                      if (data['semester'] != null)
                        _statRow('Semester:', data['semester']),
                      if (data['version'] != null)
                        _statRow('Version:', data['version']),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  print('🔄 Refreshing schedules...');
                  fetchSchedules();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      print('💥 Upload error: $e');
      print('📍 Error type: ${e.runtimeType}');

      setState(() => isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload error: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

 void _showCreateScheduleDialog() {
  final subjectController = TextEditingController();
  final classCodeController = TextEditingController();
  final descriptionController = TextEditingController();
  final roomController = TextEditingController();
  final buildingController = TextEditingController();

  final degreeController = TextEditingController(
    text: widget.userRole == 'Student' ? widget.degree : '',
  );
  final sectionController = TextEditingController(
    text: widget.userRole == 'Student' ? widget.section : '',
  );
  final semesterController = TextEditingController(
    text: widget.userRole == 'Student' ? widget.semesterNo : '',
  );

  String selectedDay = 'Monday';
  TimeOfDay selectedStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay selectedEndTime = const TimeOfDay(hour: 8, minute: 50);

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(widget.userRole == 'Teacher' 
          ? 'Add Class to Teach' 
          : 'Add New Schedule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: classCodeController,
                decoration: const InputDecoration(labelText: 'Class Code'),
              ),
              const SizedBox(height: 10),
              
              // ✅ For teachers, these are editable (which section they're teaching)
              TextField(
                controller: degreeController,
                decoration: InputDecoration(
                  labelText: 'Degree *',
                  enabled: true, // ✅ Changed: Always enabled
                  hintText: widget.userRole == 'Teacher' ? 'e.g., BSCS, BSAI' : null,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sectionController,
                decoration: InputDecoration(
                  labelText: 'Section *',
                  enabled: true, // ✅ Changed: Always enabled
                  hintText: widget.userRole == 'Teacher' ? 'e.g., A, B, C' : null,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: semesterController,
                decoration: InputDecoration(
                  labelText: 'Semester No *',
                  enabled: true, // ✅ Changed: Always enabled
                  hintText: widget.userRole == 'Teacher' ? 'e.g., 1, 2, 3' : null,
                ),
                keyboardType: TextInputType.number,
              ),
              
              // ✅ ADD THIS: Show teacher's name (read-only for teachers)
              if (widget.userRole == 'Teacher') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: widget.userName),
                  decoration: const InputDecoration(
                    labelText: 'Teacher Name',
                    enabled: false,
                  ),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              
              const SizedBox(height: 10),
              
              // Day Dropdown
              DropdownButton<String>(
                value: selectedDay,
                isExpanded: true,
                items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                    .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDay = value ?? 'Monday';
                  });
                },
              ),
              const SizedBox(height: 10),
              
              // ✅ START TIME PICKER
              ListTile(
                title: const Text('Start Time *'),
                subtitle: Text(selectedStartTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: selectedStartTime,
                  );
                  if (picked != null) {
                    setState(() {
                      selectedStartTime = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              
              // ✅ END TIME PICKER
              ListTile(
                title: const Text('End Time *'),
                subtitle: Text(selectedEndTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: selectedEndTime,
                  );
                  if (picked != null) {
                    setState(() {
                      selectedEndTime = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              
              TextField(
                controller: roomController,
                decoration: const InputDecoration(labelText: 'Room Number *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: buildingController,
                decoration: const InputDecoration(labelText: 'Building'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (subjectController.text.isEmpty ||
                  degreeController.text.isEmpty ||
                  sectionController.text.isEmpty ||
                  semesterController.text.isEmpty ||
                  roomController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields (*)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // ✅ Convert TimeOfDay to HH:mm:ss format
              final startTimeStr = '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}:00';
              final endTimeStr = '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}:00';

              Navigator.pop(context);
              _createSchedule(
                subjectController.text,
                classCodeController.text,
                descriptionController.text,
                selectedDay,
                startTimeStr,  // ✅ Pass converted time
                endTimeStr,    // ✅ Pass converted time
                roomController.text,
                buildingController.text,
                degreeController.text,
                sectionController.text,
                semesterController.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Create Schedule'),
          ),
        ],
      ),
    ),
  );
}
  Future<void> _createSchedule(
    String subject,
    String classCode,
    String description,
    String day,
    String startTime,
    String endTime,
    String room,
    String building,
    String degree,
    String section,
    String semesterNo,
  ) async {
    try {
      print('📝 Creating schedule with:');
      print('   Subject: $subject');
      print('   Degree: $degree');
      print('   Section: $section');
      print('   Semester No: $semesterNo');
      print('   User Role: ${widget.userRole}');

      final response = await http.post(
        Uri.parse("http://192.168.100.63:3000/create-class-schedule"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "subject_name": subject,
          "class_code": classCode.isEmpty ? null : classCode,
          "description": description.isEmpty ? null : description,
          "day_of_week": day,
          "start_time": startTime,
          "end_time": endTime,
          "room_number": room,
          "building": building.isEmpty ? null : building,
          "degree": degree,
          "section": section,
          "semester": null,
          "semester_no": int.parse(semesterNo),

          "teacher_id": widget.userRole == 'Teacher' ? widget.userId : null,
          "teacher_name": widget.userRole == 'Teacher' ? widget.userName : null,

          "teacher_email": null,
          "teacher_department": null,
          "created_by_id": widget.userId,
          "created_by_role": widget.userRole,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Schedule created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        fetchSchedules();
      } else {
        throw Exception('Failed to create schedule: ${response.body}');
      }
    } catch (e) {
      print('❌ Create schedule error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditScheduleDialog(dynamic schedule) {
    final subjectController = TextEditingController(text: schedule['subject_name']);
    final classCodeController = TextEditingController(text: schedule['class_code'] ?? '');
    final descriptionController = TextEditingController(text: schedule['description'] ?? '');
    final roomController = TextEditingController(text: schedule['room_number']);
    final buildingController = TextEditingController(text: schedule['building'] ?? '');

    String selectedDay = schedule['day_of_week'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Schedule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: classCodeController,
                decoration: const InputDecoration(labelText: 'Class Code'),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedDay,
                isExpanded: true,
                items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                    .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                    .toList(),
                onChanged: (value) {
                  selectedDay = value ?? 'Monday';
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roomController,
                decoration: const InputDecoration(labelText: 'Room Number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: buildingController,
                decoration: const InputDecoration(labelText: 'Building'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateSchedule(
                schedule['id'],
                subjectController.text,
                classCodeController.text,
                descriptionController.text,
                selectedDay,
                schedule['start_time'],
                schedule['end_time'],
                roomController.text,
                buildingController.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewTimetablePDF() async {
    try {
      print('📁 Opening file picker for preview...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final base64Pdf = base64Encode(bytes);

      print('🔄 Sending PDF for preview...');

      final response = await http.post(
        Uri.parse("http://192.168.100.63:3000/read-timetable-pdf"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"pdfBase64": base64Pdf}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final preview = data['preview'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('📄 PDF Preview'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _previewRow('Total Lines:', '${preview['totalLines']}'),
                  _previewRow('Shift:', preview['shift']),
                  _previewRow('Semester:', preview['semester'] ?? 'Not detected'),
                  _previewRow('Version:', preview['version'] ?? 'Not detected'),
                  const SizedBox(height: 15),
                  const Text(
                    'Available Sections:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...((preview['availableSections'] as List).map((s) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 4),
                        child: Text('• ${s['code']}'),
                      ))),
                  const SizedBox(height: 15),
                  const Text(
                    'Raw Text Preview (First 50 lines):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      preview['rawTextPreview'],
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Preview error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  

  Future<void> _updateSchedule(
    int scheduleId,
    String subject,
    String classCode,
    String description,
    String day,
    String startTime,
    String endTime,
    String room,
    String building,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("http://192.168.100.63:3000/update-class-schedule"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "schedule_id": scheduleId,
          "user_id": widget.userId,
          "user_role": widget.userRole,
          "subject_name": subject,
          "class_code": classCode.isEmpty ? null : classCode,
          "description": description.isEmpty ? null : description,
          "day_of_week": day,
          "start_time": startTime,
          "end_time": endTime,
          "room_number": room,
          "building": building.isEmpty ? null : building,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Schedule updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        fetchSchedules();
      } else {
        throw Exception('Failed to update schedule');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    try {
      final response = await http.post(
        Uri.parse("http://192.168.100.63:3000/delete-class-schedule"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "schedule_id": scheduleId,
          "user_id": widget.userId,
          "user_role": widget.userRole,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Schedule deleted successfully!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        fetchSchedules();
      } else {
        throw Exception('Failed to delete schedule');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(int scheduleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule(scheduleId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 172, 39, 248), foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userRole == 'Teacher' ? 'My Teaching Schedule' : 'My Class Schedule'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _viewTimetablePDF,
            tooltip: 'View PDF',
          ),
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _previewTimetablePDF,
            tooltip: 'Preview PDF',
          ),
          IconButton(
            icon: Icon(isUploading ? Icons.hourglass_empty : Icons.upload_file),
            onPressed: isUploading ? null : uploadTimetable,
            tooltip: 'Upload Timetable PDF',
            style: IconButton.styleFrom(
            foregroundColor: Colors.white,
          ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showCreateScheduleDialog(),
            tooltip: 'Add Manual Schedule',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.deepPurple.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.userRole == 'Teacher'
                      ? widget.userName
                      : '${widget.degree}-${widget.section}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalClasses Classes This Week',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                if (isUploading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🤖 AI is parsing your timetable...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final isSelected = selectedDay == day;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(day == 'all' ? 'All Days' : day),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => selectedDay = day);
                      fetchSchedules();
                    },
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : schedules.isEmpty
                    ? _buildEmptyState()
                    : selectedDay == 'all'
                        ? _buildGroupedScheduleList()
                        : _buildDayScheduleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'No Classes Scheduled',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            widget.userRole == 'Teacher'
                ? 'Upload your timetable PDF or tap + to add manually'
                : 'Upload your section\'s timetable PDF to see your schedule',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: uploadTimetable,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Timetable PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedScheduleList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: days.skip(1).map((day) {
        final daySchedules = groupedSchedules[day] ?? [];
        if (daySchedules.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${daySchedules.length} ${daySchedules.length == 1 ? 'class' : 'classes'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...daySchedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
            const SizedBox(height: 10),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDayScheduleList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: schedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
    );
  }

  Widget _buildScheduleCard(dynamic schedule) {
    final startTime = _formatTime(schedule['start_time']);
    final endTime = _formatTime(schedule['end_time']);
    final duration = _calculateDuration(schedule['start_time'], schedule['end_time']);
    final isParsedFromPdf = schedule['parsed_from_pdf'] == 1;
    final scheduleId = schedule['id'];
    final hasReminder = reminders.containsKey(scheduleId);
    final reminderEnabled = hasReminder && reminders[scheduleId]!['is_enabled'] == 1;
    final canEdit = true;
    final canDelete = true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showScheduleDetails(schedule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple, Colors.deepPurple.shade300],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$startTime - $endTime',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      duration,
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isParsedFromPdf) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Parsed from PDF',
                      child: Icon(Icons.smart_toy, size: 16, color: Colors.blue.shade700),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      reminderEnabled ? Icons.notifications_active : Icons.notifications_none,
                      color: reminderEnabled ? Colors.green : Colors.grey,
                      size: 22,
                    ),
                    onPressed: () => _showReminderSettings(schedule),
                    tooltip: reminderEnabled ? 'Reminder ON' : 'Set Reminder',
                  ),
                  if (canEdit || canDelete)
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (context) => [
                        if (canEdit)
                          const PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                        if (canDelete)
                          const PopupMenuItem(value: 'delete', child: Text('🗑️ Delete')),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditScheduleDialog(schedule);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(schedule['id']);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                schedule['subject_name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (schedule['class_code'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  schedule['class_code'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.userRole == 'Student'
                          ? schedule['teacher_name']
                          : '${schedule['degree']}-${schedule['section']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    schedule['room_number'],
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  if (schedule['building'] != null) ...[
                    Text(
                      ' • ${schedule['building']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
              if (hasReminder && reminderEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Reminder: ${reminders[scheduleId]!['reminder_minutes']} min before',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showScheduleDetails(dynamic schedule) {
    final scheduleId = schedule['id'];
    final hasReminder = reminders.containsKey(scheduleId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(schedule['subject_name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Class Code', schedule['class_code'] ?? 'N/A'),
              _detailRow('Day', schedule['day_of_week']),
              _detailRow('Time', '${_formatTime(schedule['start_time'])} - ${_formatTime(schedule['end_time'])}'),
              _detailRow('Duration', _calculateDuration(schedule['start_time'], schedule['end_time'])),
              _detailRow('Room', schedule['room_number']),
              if (schedule['building'] != null)
                _detailRow('Building', schedule['building']),
              if (widget.userRole == 'Student')
                _detailRow('Teacher', schedule['teacher_name']),
              if (widget.userRole == 'Teacher')
                _detailRow('Section', '${schedule['degree']}-${schedule['section']}'),
              if (schedule['semester'] != null)
                _detailRow('Semester', schedule['semester']),
              if (schedule['shift'] != null)
                _detailRow('Shift', schedule['shift']),
              if (schedule['parsed_from_pdf'] == 1)
                _detailRow('Source', '🤖 AI Parsed from PDF'),
              if (hasReminder)
                _detailRow(
                  'Reminder',
                  reminders[scheduleId]!['is_enabled'] == 1
                      ? '✅ ON (${reminders[scheduleId]!['reminder_minutes']} min before)'
                      : '🔕 OFF',
                ),
              if (schedule['description'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(schedule['description'], style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showReminderSettings(schedule);
            },
            icon: Icon(
              hasReminder && reminders[scheduleId]!['is_enabled'] == 1
                  ? Icons.notifications_active
                  : Icons.notifications_none,
            ),
            label: Text(
              hasReminder && reminders[scheduleId]!['is_enabled'] == 1
                  ? 'Edit Reminder'
                  : 'Set Reminder',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
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

  String _calculateDuration(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final duration = endMinutes - startMinutes;
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}