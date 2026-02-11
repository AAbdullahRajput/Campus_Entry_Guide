import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class StudentDetailsAdminPage extends StatefulWidget {
  final String adminId;
  final int studentId;
  final String studentName;

  const StudentDetailsAdminPage({
    super.key,
    required this.adminId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDetailsAdminPage> createState() => _StudentDetailsAdminPageState();
}

class _StudentDetailsAdminPageState extends State<StudentDetailsAdminPage> {
  bool isLoading = true;
  Map<String, dynamic> studentData = {};
  List<dynamic> courses = [];
  List<dynamic> recentAttendance = [];
  Map<String, dynamic> statistics = {};

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminStudentDetails),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'student_id': widget.studentId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          studentData = data['student'];
          courses = data['courses'];
          recentAttendance = data['recent_attendance'];
          statistics = data['statistics'];
        });
      }
    } catch (e) {
      print("Error: $e");
      _showErrorSnackbar("Failed to load student details");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addAttendanceForCourse(Map<String, dynamic> course) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    final status = await _showAttendanceStatusDialog();
    if (status == null) return;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminAddAttendance),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'student_id': widget.studentId,
          'student_name': studentData['name'],
          'schedule_id': course['schedule_id'],
          'date': selectedDate.toIso8601String().split('T')[0],
          'status': status,
        }),
      );

      if (response.statusCode == 201) {
        _showSuccessSnackbar("Attendance added successfully");
        _loadStudentDetails();
      } else {
        final data = jsonDecode(response.body);
        _showErrorSnackbar(data['message'] ?? 'Failed to add attendance');
      }
    } catch (e) {
      _showErrorSnackbar("Error adding attendance");
    }
  }

  Future<void> _editAttendance(Map<String, dynamic> record) async {
    final newStatus = await _showAttendanceStatusDialog();
    if (newStatus == null) return;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminEditAttendance),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'attendance_id': record['id'],
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackbar("Attendance updated successfully");
        _loadStudentDetails();
      } else {
        _showErrorSnackbar("Failed to update attendance");
      }
    } catch (e) {
      _showErrorSnackbar("Error updating attendance");
    }
  }

  Future<void> _deleteAttendance(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Attendance"),
        content: const Text("Are you sure you want to delete this attendance record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminDeleteAttendance),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'attendance_id': record['id'],
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackbar("Attendance deleted successfully");
        _loadStudentDetails();
      } else {
        _showErrorSnackbar("Failed to delete attendance");
      }
    } catch (e) {
      _showErrorSnackbar("Error deleting attendance");
    }
  }

  Future<String?> _showAttendanceStatusDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark Attendance"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text("Present"),
              onTap: () => Navigator.pop(context, 'present'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text("Absent"),
              onTap: () => Navigator.pop(context, 'absent'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          widget.studentName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF43CEA2), Color(0xFF185A9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudentDetails,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStudentDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 20),
                    _buildStatisticsGrid(),
                    const SizedBox(height: 20),
                    const Text(
                      "Enrolled Courses",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildCoursesList(),
                    const SizedBox(height: 20),
                    const Text(
                      "Recent Attendance Records",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentAttendance(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF43CEA2).withOpacity(0.1),
            backgroundImage: studentData['profile_image'] != null
                ? NetworkImage(studentData['profile_image'])
                : null,
            child: studentData['profile_image'] == null
                ? const Icon(Icons.person, size: 50, color: Color(0xFF43CEA2))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentData['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.badge, studentData['arid_no'] ?? 'N/A'),
                _buildInfoRow(Icons.email, studentData['email'] ?? ''),
                _buildInfoRow(
                  Icons.class_,
                  "${studentData['degree']}-${studentData['section']} (Sem ${studentData['semester_no']})",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    // Parse overall_attendance safely
    double overallAttendance = 0.0;
    if (statistics['overall_attendance'] != null) {
      if (statistics['overall_attendance'] is String) {
        overallAttendance = double.tryParse(statistics['overall_attendance']) ?? 0.0;
      } else {
        overallAttendance = (statistics['overall_attendance'] as num).toDouble();
      }
    }

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          "Courses",
          "${statistics['total_courses'] ?? 0}",
          Icons.book,
          const Color(0xFF667EEA),
        ),
        _buildStatCard(
          "Classes",
          "${statistics['total_classes'] ?? 0}",
          Icons.class_,
          const Color(0xFFFFB347),
        ),
        _buildStatCard(
          "Attended",
          "${statistics['total_attended'] ?? 0}",
          Icons.check_circle,
          const Color(0xFF43CEA2),
        ),
        _buildStatCard(
          "Attendance",
          "${overallAttendance.toStringAsFixed(1)}%",
          Icons.percent,
          _getAttendanceColor(overallAttendance),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8), // Increased from 6
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4), // Increased from 3
          Flexible( // Wrapped in Flexible
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: 2), // Increased from 1
          Flexible( // Wrapped in Flexible
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    if (courses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No enrolled courses"),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return _buildCourseCard(course);
      },
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    // Parse attendance_percentage safely
    double percentage = 0.0;
    if (course['attendance_percentage'] != null) {
      if (course['attendance_percentage'] is String) {
        percentage = double.tryParse(course['attendance_percentage']) ?? 0.0;
      } else {
        percentage = (course['attendance_percentage'] as num).toDouble();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['subject_name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      course['teacher_name'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getAttendanceColor(percentage).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        color: _getAttendanceColor(percentage),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF43CEA2)),
                    onPressed: () => _addAttendanceForCourse(course),
                    tooltip: "Add Attendance",
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${course['attended_classes']} / ${course['total_classes']} classes attended",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendance() {
    if (recentAttendance.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No attendance records"),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentAttendance.length > 15 ? 15 : recentAttendance.length,
      itemBuilder: (context, index) {
        final record = recentAttendance[index];
        return _buildAttendanceRecord(record);
      },
    );
  }

  Widget _buildAttendanceRecord(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            record['status'] == 'present' ? Icons.check_circle : Icons.cancel,
            color: record['status'] == 'present' ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['subject_name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  record['teacher_name'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record['date'],
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                record['time'],
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
            onSelected: (value) {
              if (value == 'edit') {
                _editAttendance(record);
              } else if (value == 'delete') {
                _deleteAttendance(record);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}