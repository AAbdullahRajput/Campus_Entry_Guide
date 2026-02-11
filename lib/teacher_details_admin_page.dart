import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class TeacherDetailsAdminPage extends StatefulWidget {
  final String adminId;
  final int teacherId;
  final String teacherName;

  const TeacherDetailsAdminPage({
    super.key,
    required this.adminId,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherDetailsAdminPage> createState() => _TeacherDetailsAdminPageState();
}

class _TeacherDetailsAdminPageState extends State<TeacherDetailsAdminPage> {
  bool isLoading = true;
  Map<String, dynamic> teacherData = {};
  List<dynamic> subjects = [];
  List<dynamic> recentActivity = [];
  Map<String, dynamic> statistics = {};

  @override
  void initState() {
    super.initState();
    _loadTeacherDetails();
  }

  Future<void> _loadTeacherDetails() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminTeacherDetails),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'teacher_id': widget.teacherId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          teacherData = data['teacher'];
          subjects = data['subjects'];
          recentActivity = data['recent_activity'];
          statistics = data['statistics'];
        });
      }
    } catch (e) {
      print("Error: $e");
      _showErrorSnackbar("Failed to load teacher details");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          widget.teacherName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeacherDetails,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeacherDetails,
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
                      "Teaching Subjects",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildSubjectsList(),
                    const SizedBox(height: 20),
                    const Text(
                      "Recent Activity",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentActivity(),
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
            backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
            backgroundImage: teacherData['profile_image'] != null
                ? NetworkImage(teacherData['profile_image'])
                : null,
            child: teacherData['profile_image'] == null
                ? const Icon(Icons.person, size: 50, color: Color(0xFF667EEA))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherData['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.email, teacherData['email'] ?? ''),
                _buildInfoRow(Icons.phone, teacherData['phone_number'] ?? 'N/A'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: teacherData['is_active'] == 1
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    teacherData['is_active'] == 1 ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: teacherData['is_active'] == 1 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    // Parse average_attendance safely
    double avgAttendance = 0.0;
    if (statistics['average_attendance'] != null) {
      if (statistics['average_attendance'] is String) {
        avgAttendance = double.tryParse(statistics['average_attendance']) ?? 0.0;
      } else {
        avgAttendance = (statistics['average_attendance'] as num).toDouble();
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
          "Subjects",
          "${statistics['total_subjects'] ?? 0}",
          Icons.book,
          const Color(0xFF667EEA),
        ),
        _buildStatCard(
          "Students",
          "${statistics['total_students'] ?? 0}",
          Icons.people,
          const Color(0xFF43CEA2),
        ),
        _buildStatCard(
          "Classes",
          "${statistics['total_classes'] ?? 0}",
          Icons.class_,
          const Color(0xFFFFB347),
        ),
        _buildStatCard(
          "Attendance",
          "${avgAttendance.toStringAsFixed(1)}%",
          Icons.check_circle,
          const Color(0xFF185A9D),
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

  Widget _buildSubjectsList() {
    if (subjects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No subjects assigned"),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return _buildSubjectCard(subject);
      },
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final attendancePercentage = subject['total_records'] > 0
        ? (subject['total_present'] / subject['total_records'] * 100)
        : 0.0;

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
                      subject['subject_name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subject['section_list'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildSubjectInfo(Icons.people, "${subject['enrolled_students']} Students"),
              _buildSubjectInfo(Icons.class_, "${subject['classes_conducted']} Classes"),
              _buildSubjectInfo(
                Icons.check_circle,
                "${attendancePercentage.toStringAsFixed(1)}%",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    if (recentActivity.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No recent activity"),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentActivity.length > 10 ? 10 : recentActivity.length,
      itemBuilder: (context, index) {
        final activity = recentActivity[index];
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
              Icon(Icons.history, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${activity['subject_name']} - ${activity['section']}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${activity['students_marked']} students (${activity['present_count']} present)",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                activity['date'],
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}