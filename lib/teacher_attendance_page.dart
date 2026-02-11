import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class TeacherAttendancePage extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const TeacherAttendancePage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _subjects = [];

  Position? _currentPosition;
  bool _isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTeacherSubjects();
  }

  Future<void> _fetchTeacherSubjects() async {
    setState(() => _isLoading = true);

    try {
      print('📚 Fetching subjects for teacher ${widget.teacherId}...');

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-teacher-subjects-grouped'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'teacher_id': widget.teacherId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        
        for (var subject in subjects) {
          if (subject['avg_attendance'] is String) {
            subject['avg_attendance'] = double.tryParse(subject['avg_attendance']) ?? 0.0;
          }
        }
        
        setState(() {
          _subjects = subjects;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load subjects');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ⬇️ ADD THESE THREE NEW METHODS
  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required for GPS attendance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLocationLoading = false;
      });

      return position;
    } catch (e) {
      setState(() => _isLocationLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _checkActiveSession(Map<String, dynamic> subject, Map<String, dynamic> section) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-active-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['active_session'] != null) {
          _showActiveSessionDialog(subject, section, data['active_session']);
        }
      }
    } catch (e) {
      print('Error checking session: $e');
    }
  }

  Future<void> _showSectionsForSubject(Map<String, dynamic> subject) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-subject-sections'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sections = List<Map<String, dynamic>>.from(data['sections'] ?? []);
        
        for (var section in sections) {
          if (section['avg_attendance'] is String) {
            section['avg_attendance'] = double.tryParse(section['avg_attendance']) ?? 0.0;
          }
        }

        if (!mounted) return;
        _showSectionsDialog(subject, sections);
      } else {
        throw Exception('Failed to load sections');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSectionsDialog(
    Map<String, dynamic> subject,
    List<Map<String, dynamic>> sections,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject['course_name'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select a section to manage',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Sections List
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.class_outlined, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No sections found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return _buildSectionCard(subject, section);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> subject, Map<String, dynamic> section) {
    final studentCount = section['enrolled_count'] ?? 0;
    final classesTaken = section['classes_taken'] ?? 0;
    final avgAttendance = section['avg_attendance'] ?? 0.0;

    final Color attendanceColor = avgAttendance >= 75
        ? Colors.green
        : avgAttendance >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _showManagementOptions(subject, section);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                attendanceColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [attendanceColor.withOpacity(0.7), attendanceColor],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: attendanceColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.class_, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${section['degree']}-${section['section']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Semester ${section['semester_no']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.people_rounded,
                        '$studentCount',
                        'Students',
                        Colors.blue,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    Expanded(
                      child: _buildStatItem(
                        Icons.event_note_rounded,
                        '$classesTaken',
                        'Classes',
                        Colors.purple,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    Expanded(
                      child: _buildStatItem(
                        Icons.analytics_rounded,
                        '${avgAttendance.toInt()}%',
                        'Avg.',
                        attendanceColor,
                      ),
                    ),
                  ],
                ),
                if (classesTaken > 0) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: avgAttendance / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(attendanceColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showManagementOptions(Map<String, dynamic> subject, Map<String, dynamic> section) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Manage Attendance',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${section['degree']}-${section['section']}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            // ⬇️ ADD THIS NEW GPS OPTION
            _buildOptionCard(
              icon: Icons.location_on,
              title: 'Start GPS Attendance',
              subtitle: 'Enable location-based attendance',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _startGPSAttendanceSession(subject, section);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.edit_calendar_rounded,
              title: 'Mark Today\'s Attendance',
              subtitle: 'Mark attendance for all students',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showStudentsForAttendance(subject, section);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.people_alt_rounded,
              title: 'View Students List',
              subtitle: 'Manage individual student records',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showStudentsListForManagement(subject, section);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStudentsListForManagement(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-section-students-attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final students = List<Map<String, dynamic>>.from(data['students'] ?? []);

        if (!mounted) return;
        _showStudentsManagementSheet(subject, section, students);
      } else {
        throw Exception('Failed to load students');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStudentsManagementSheet(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    List<Map<String, dynamic>> students,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${section['degree']}-${section['section']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${students.length} students enrolled',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No students enrolled',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return _buildStudentManagementCard(subject, section, student);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentManagementCard(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    Map<String, dynamic> student,
  ) {
    final totalClasses = student['total_classes'] ?? 0;
    final attendedClasses = student['attended_classes'] ?? 0;
    final percentage = totalClasses > 0 ? (attendedClasses / totalClasses * 100) : 0.0;

    final Color percentageColor = percentage >= 75
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: percentageColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _viewStudentAttendanceDetails(subject, section, student),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: percentageColor.withOpacity(0.2),
                    child: Text(
                      student['student_name'].toString().substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: percentageColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['student_name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (student['arid_no'] != null)
                          Text(
                            'ARID: ${student['arid_no']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: percentageColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${percentage.toInt()}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: percentageColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$attendedClasses/$totalClasses',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: totalClasses > 0 ? percentage / 100 : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(percentageColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addAttendanceForStudent(subject, section, student),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Attendance'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewStudentAttendanceDetails(subject, section, student),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('View History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667EEA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAttendanceForStudent(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    Map<String, dynamic> student,
  ) async {
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'present';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_circle, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Add Attendance',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['student_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ARID: ${student['arid_no'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() => selectedDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Attendance Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Present'),
                      selected: selectedStatus == 'present',
                      selectedColor: Colors.green,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedStatus = 'present');
                        }
                      },
                      avatar: selectedStatus == 'present'
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                      labelStyle: TextStyle(
                        color: selectedStatus == 'present' ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Absent'),
                      selected: selectedStatus == 'absent',
                      selectedColor: Colors.red,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedStatus = 'absent');
                        }
                      },
                      avatar: selectedStatus == 'absent'
                          ? const Icon(Icons.close, color: Colors.white, size: 18)
                          : null,
                      labelStyle: TextStyle(
                        color: selectedStatus == 'absent' ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'date': selectedDate,
                'status': selectedStatus,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/add-single-attendance-record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'student_id': student['student_id'],
          'student_name': student['student_name'],
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
          'date': DateFormat('yyyy-MM-dd').format(result['date']),
          'status': result['status'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(data['message'] ?? 'Attendance added successfully')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          // Refresh the list
          Navigator.pop(context);
          _showStudentsListForManagement(subject, section);
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to add attendance');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showStudentsForAttendance(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-section-students-attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final students = List<Map<String, dynamic>>.from(data['students'] ?? []);

        if (!mounted) return;
        _showAttendanceMarkingSheet(subject, section, students);
      } else {
        throw Exception('Failed to load students');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _viewStudentAttendanceDetails(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    Map<String, dynamic> student,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-student-attendance-by-course'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': student['student_id'],
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        _showStudentDetailedAttendance(student, data, subject, section);
      } else {
        throw Exception('Failed to load student attendance details');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStudentDetailedAttendance(
    Map<String, dynamic> student,
    Map<String, dynamic> attendanceData,
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
  ) {
    final records = List<Map<String, dynamic>>.from(attendanceData['records'] ?? []);
    final totalClasses = attendanceData['totalClasses'] ?? 0;
    final attendedClasses = attendanceData['attendedClasses'] ?? 0;
    final percentage = attendanceData['percentage'] ?? 0.0;

    final Color percentageColor = percentage >= 75
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [percentageColor.withOpacity(0.8), percentageColor],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Text(
                      student['student_name'].toString().substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: percentageColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    student['student_name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (student['arid_no'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ARID: ${student['arid_no']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildHeaderStatWhite('Total', '$totalClasses'),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                        _buildHeaderStatWhite('Present', '$attendedClasses'),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                        _buildHeaderStatWhite('Absent', '${totalClasses - attendedClasses}'),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                        _buildHeaderStatWhite('Rate', '${percentage.toInt()}%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Attendance History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${records.length} records',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No attendance records yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final isPresent = record['status'] == 'present';
                        final date = record['date'] ?? 'Unknown Date';
                        final time = record['time'] ?? '';
                        final recordId = record['record_id'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isPresent
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPresent ? Icons.check : Icons.close,
                                color: isPresent ? Colors.green : Colors.red,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              _formatDate(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: time.isNotEmpty
                                ? Text(
                                    'Time: $time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  )
                                : null,
                            trailing: PopupMenuButton(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isPresent ? Icons.cancel : Icons.check_circle,
                                        size: 20,
                                        color: isPresent ? Colors.red : Colors.green,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(isPresent ? 'Mark Absent' : 'Mark Present'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('Delete Record'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'toggle') {
                                  _updateAttendanceRecord(
                                    recordId,
                                    isPresent ? 'absent' : 'present',
                                    student,
                                    subject,
                                    section,
                                  );
                                } else if (value == 'delete') {
                                  _deleteAttendanceRecord(
                                    recordId,
                                    student,
                                    subject,
                                    section,
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ⬇️ ADD THESE FOUR NEW METHODS

  Future<void> _startGPSAttendanceSession(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
  ) async {
    // Get current location
    final position = await _getCurrentLocation();
    if (position == null) return;

    // Confirm starting session
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.lightGreen],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Start GPS Session', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will enable students to mark attendance using GPS.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Your Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Lat: ${position.latitude.toStringAsFixed(6)}'),
                  Text('Lng: ${position.longitude.toStringAsFixed(6)}'),
                  const SizedBox(height: 8),
                  const Text('Students within 50 meters can mark attendance.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/start-attendance-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showActiveSessionDialog(subject, section, data);
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to start session');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showActiveSessionDialog(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    Map<String, dynamic> sessionData,
  ) {
    final sessionId = sessionData['session_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Session Active', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      '${section['degree']}-${section['section']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subject['course_name'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Students can now mark attendance from their devices',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SessionStatistics(sessionId: sessionId, teacherId: widget.teacherId),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _endAttendanceSession(sessionId, context),
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('End Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endAttendanceSession(int sessionId, BuildContext dialogContext) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/end-attendance-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'teacher_id': widget.teacherId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        Navigator.pop(dialogContext);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Session ended'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to end session');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildHeaderStatWhite(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _updateAttendanceRecord(
    int recordId,
    String newStatus,
    Map<String, dynamic> student,
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/update-single-attendance-record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'record_id': recordId,
          'status': newStatus,
          'teacher_id': widget.teacherId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${data['message']}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          _viewStudentAttendanceDetails(subject, section, student);
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to update');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAttendanceRecord(
    int recordId,
    Map<String, dynamic> student,
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this attendance record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/delete-attendance-record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'record_id': recordId,
          'teacher_id': widget.teacherId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${data['message']}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          _viewStudentAttendanceDetails(subject, section, student);
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to delete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('EEEE, MMM d, y').format(dt);
    } catch (e) {
      return date;
    }
  }

  void _showAttendanceMarkingSheet(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    List<Map<String, dynamic>> students,
  ) {
    final Map<int, String> attendanceStatus = {};
    for (var student in students) {
      attendanceStatus[student['student_id']] = 'present';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_calendar, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Mark Attendance',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            subject['course_name'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${section['degree']}-${section['section']} • ${students.length} students',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            for (var student in students) {
                              attendanceStatus[student['student_id']] = 'present';
                            }
                          });
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('All Present'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            for (var student in students) {
                              attendanceStatus[student['student_id']] = 'absent';
                            }
                          });
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('All Absent'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No students enrolled',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final studentId = student['student_id'];
                          final status = attendanceStatus[studentId] ?? 'present';
                          final totalClasses = student['total_classes'] ?? 0;
                          final attendedClasses = student['attended_classes'] ?? 0;
                          final percentage = totalClasses > 0
                              ? (attendedClasses / totalClasses * 100)
                              : 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: status == 'present'
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: status == 'present'
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                        child: Text(
                                          student['student_name']
                                              .toString()
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: status == 'present'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student['student_name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (student['arid_no'] != null)
                                              Text(
                                                'ARID: ${student['arid_no']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: percentage >= 75
                                                  ? Colors.green.shade50
                                                  : percentage >= 50
                                                      ? Colors.orange.shade50
                                                      : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${percentage.toInt()}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: percentage >= 75
                                                    ? Colors.green.shade700
                                                    : percentage >= 50
                                                        ? Colors.orange.shade700
                                                        : Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$attendedClasses/$totalClasses',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            setModalState(() {
                                              attendanceStatus[studentId] = 'present';
                                            });
                                          },
                                          icon: Icon(
                                            Icons.check_circle,
                                            size: 18,
                                            color: status == 'present'
                                                ? Colors.white
                                                : Colors.green,
                                          ),
                                          label: Text(
                                            'Present',
                                            style: TextStyle(
                                              color: status == 'present'
                                                  ? Colors.white
                                                  : Colors.green,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: status == 'present'
                                                ? Colors.green
                                                : null,
                                            side: BorderSide(
                                              color: Colors.green,
                                              width: status == 'present' ? 0 : 1,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            setModalState(() {
                                              attendanceStatus[studentId] = 'absent';
                                            });
                                          },
                                          icon: Icon(
                                            Icons.cancel,
                                            size: 18,
                                            color: status == 'absent'
                                                ? Colors.white
                                                : Colors.red,
                                          ),
                                          label: Text(
                                            'Absent',
                                            style: TextStyle(
                                              color: status == 'absent'
                                                  ? Colors.white
                                                  : Colors.red,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor:
                                                status == 'absent' ? Colors.red : null,
                                            side: BorderSide(
                                              color: Colors.red,
                                              width: status == 'absent' ? 0 : 1,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _submitAttendance(
                          subject,
                          section,
                          attendanceStatus,
                          students,
                        ),
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Submit Attendance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667EEA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAttendance(
    Map<String, dynamic> subject,
    Map<String, dynamic> section,
    Map<int, String> attendanceStatus,
    List<Map<String, dynamic>> students,
  ) async {
    try {
      Navigator.pop(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final attendanceList = students.map((student) {
        return {
          'student_id': student['student_id'],
          'student_name': student['student_name'],
          'status': attendanceStatus[student['student_id']] ?? 'present',
        };
      }).toList();

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/mark-attendance-by-course'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacherId,
          'course_id': subject['course_name'],
          'degree': section['degree'],
          'section': section['section'],
          'semester_no': section['semester_no'],
          'attendance': attendanceList,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }),
      ).timeout(const Duration(seconds: 15));

      Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(data['message'] ?? 'Attendance marked successfully')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        _fetchTeacherSubjects();
      } else {
        throw Exception(data['message'] ?? 'Failed to submit attendance');
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Attendance Management",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // ⬇️ ADD THIS ACTIONS SECTION
        actions: [
          IconButton(
            icon: _isLocationLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _currentPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: Colors.white,
                  ),
            onPressed: _getCurrentLocation,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTeacherSubjects,
              child: _subjects.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        return _buildSubjectCard(subject);
                      },
                    ),
            ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final totalSections = subject['total_sections'] ?? 0;
    final totalStudents = subject['total_students'] ?? 0;
    final avgAttendance = subject['avg_attendance'] ?? 0.0;

    final Color attendanceColor = avgAttendance >= 75
        ? Colors.green
        : avgAttendance >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showSectionsForSubject(subject),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                avgAttendance > 0 ? attendanceColor.withOpacity(0.05) : Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.book, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject['course_name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subject['course_code'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.class_rounded,
                        '$totalSections',
                        'Section${totalSections != 1 ? 's' : ''}',
                        Colors.purple,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    Expanded(
                      child: _buildStatItem(
                        Icons.people_rounded,
                        '$totalStudents',
                        'Students',
                        Colors.blue,
                      ),
                    ),
                    if (avgAttendance > 0) ...[
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildStatItem(
                          Icons.analytics_rounded,
                          '${avgAttendance.toInt()}%',
                          'Avg.',
                          attendanceColor,
                        ),
                      ),
                    ],
                  ],
                ),
                if (avgAttendance > 0) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: avgAttendance / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(attendanceColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'No Subjects Assigned',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t been assigned to teach any subjects yet',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
// ⬇️ ADD THIS ENTIRE WIDGET CLASS
class _SessionStatistics extends StatefulWidget {
  final int sessionId;
  final int teacherId;

  const _SessionStatistics({
    required this.sessionId,
    required this.teacherId,
  });

  @override
  State<_SessionStatistics> createState() => _SessionStatisticsState();
}

class _SessionStatisticsState extends State<_SessionStatistics> {
  int _markedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    Future.delayed(const Duration(seconds: 5), _autoRefresh);
  }

  void _autoRefresh() {
    if (mounted) {
      _loadStatistics();
      Future.delayed(const Duration(seconds: 5), _autoRefresh);
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-session-statistics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'teacher_id': widget.teacherId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _markedCount = data['total_marked'] ?? 0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            '$_markedCount students marked attendance',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}