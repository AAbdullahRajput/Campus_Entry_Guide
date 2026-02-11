import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudentSelfEnrollmentScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String degree;
  final String section;
  final String semesterNo;

  const StudentSelfEnrollmentScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.degree,
    required this.section,
    required this.semesterNo,
  });

  @override
  State<StudentSelfEnrollmentScreen> createState() => _StudentSelfEnrollmentScreenState();
}

class _StudentSelfEnrollmentScreenState extends State<StudentSelfEnrollmentScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableCourses = [];
  List<Map<String, dynamic>> _enrolledCourses = [];
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() => _isLoading = true);

    try {
      print('📚 Fetching courses for self-enrollment...');
      
      final availableResponse = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-courses-for-self-enrollment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'degree': widget.degree,
          'section': widget.section,
          'semester_no': widget.semesterNo,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📋 Fetching enrolled courses...');
      
      final enrolledResponse = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-self-enrolled-courses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': widget.userId}),
      ).timeout(const Duration(seconds: 10));

      if (availableResponse.statusCode == 200 && enrolledResponse.statusCode == 200) {
        final availableData = jsonDecode(availableResponse.body);
        final enrolledData = jsonDecode(enrolledResponse.body);

        setState(() {
          _availableCourses = List<Map<String, dynamic>>.from(availableData['courses'] ?? []);
          _enrolledCourses = List<Map<String, dynamic>>.from(enrolledData['enrollments'] ?? []);
          _statistics = availableData['statistics'];
          _isLoading = false;
        });

        print('✅ Loaded ${_availableCourses.length} subjects');
        print('✅ Loaded ${_enrolledCourses.length} enrolled courses');
      } else {
        throw Exception('Failed to fetch courses');
      }
    } catch (e) {
      print('❌ Error fetching courses: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showEnrollmentWarningDialog(Map<String, dynamic> course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Important Notice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Before Enrolling',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you have FAILED (F grade) or received a D grade in any previous related course, please DO NOT enroll.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact the Student Office for clarification and course information before proceeding.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enrolling with a failed or D grade in related courses may result in automatic failure during the result process.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showTeacherSelectionDialog(course);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998e),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'I Understand, Continue',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showTeacherSelectionDialog(Map<String, dynamic> course) {
    final subjectName = course['subject_name'] ?? '';
    final classCode = course['class_code'] ?? '';
    final teachers = List<Map<String, dynamic>>.from(course['available_teachers'] ?? []);

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No teachers available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Teacher',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subjectName,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              final teacherName = teacher['teacher_name'] ?? 'Unknown';
              final teacherEmail = teacher['teacher_email'] ?? '';
              
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _enrollInCourse(course, teacher);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF11998e),
                        child: Text(
                          teacherName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacherName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (teacherEmail.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                teacherEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _enrollInCourse(Map<String, dynamic> course, Map<String, dynamic> teacher) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Enrolling...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/self-enroll-in-course'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'student_name': widget.userName,
          'student_email': widget.userEmail,
          'student_degree': widget.degree,
          'student_section': widget.section,
          'student_semester_no': widget.semesterNo,
          'subject_name': course['subject_name'],
          'class_code': course['class_code'],
          'teacher_id': teacher['teacher_id'],
          'teacher_name': teacher['teacher_name'],
          'teacher_email': teacher['teacher_email'],
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully enrolled in ${course['subject_name']}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        await _fetchCourses();
      } else if (response.statusCode == 400) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Enrollment Issue'),
                ],
              ),
              content: Text(data['message'] ?? 'Enrollment failed'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Enrollment failed');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _unenrollFromCourse(int enrollmentId, String subjectName, String teacherName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Unenrolling...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/unenroll-from-course'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'enrollment_id': enrollmentId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully unenrolled from $subjectName'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        await _fetchCourses();
      } else {
        throw Exception('Unenroll failed');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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
          "Course Enrollment",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCourses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    if (_statistics != null) _buildStatisticsCard(),
                    const SizedBox(height: 24),

                    Text(
                      "Available Courses",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Choose your teacher for each course",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_availableCourses.isEmpty)
                      _buildEmptyState()
                    else
                      ..._availableCourses.map((course) => _buildCourseCard(course)),

                    const SizedBox(height: 24),

                    Text(
                      "My Enrolled Courses",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_enrolledCourses.length} ${_enrolledCourses.length == 1 ? 'course' : 'courses'} active",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_enrolledCourses.isEmpty)
                      _buildNoEnrollmentsCard()
                    else
                      ..._enrolledCourses.map((enrollment) => _buildEnrolledCourseCard(enrollment)),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              widget.userName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667EEA),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.degree} - Section ${widget.section} (Semester ${widget.semesterNo})",
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
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    final totalSubjects = _statistics!['total_subjects'] ?? 0;
    final totalTeachers = _statistics!['total_teachers'] ?? 0;
    final enrolledCount = _statistics!['student_enrollments'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.book_outlined,
              'Subjects',
              totalSubjects.toString(),
              const Color(0xFF11998e),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _buildStatItem(
              Icons.people_outline,
              'Teachers',
              totalTeachers.toString(),
              Colors.blue,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _buildStatItem(
              Icons.check_circle_outline,
              'Enrolled',
              enrolledCount.toString(),
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final subjectName = course['subject_name'] ?? 'Unknown Subject';
    final classCode = course['class_code'] ?? '';
    final isEnrolled = course['is_enrolled'] == true;
    final enrolledTeacher = course['enrolled_teacher'];
    final schedules = List<Map<String, dynamic>>.from(course['schedules'] ?? []);
    final teacherCount = (course['available_teachers'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEnrolled 
                  ? Colors.green.withOpacity(0.1)
                  : const Color(0xFF11998e).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEnrolled ? Colors.green : const Color(0xFF11998e),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEnrolled ? Icons.check_circle : Icons.subject,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (classCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          classCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (isEnrolled && enrolledTeacher != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                enrolledTeacher['teacher_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isEnrolled)
                  IconButton(
                    onPressed: () => _showUnenrollDialog(
                      enrolledTeacher['enrollment_id'],
                      enrolledTeacher['teacher_name'],
                      subjectName,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,   // 🔴 background
                      foregroundColor: Colors.white, // ⚪ icon color
                    ),
                    icon: const Icon(Icons.cancel),
                    tooltip: "Unenroll",
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _showEnrollmentWarningDialog(course),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text("Enroll"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF11998e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          if (!isEnrolled && teacherCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '$teacherCount ${teacherCount == 1 ? 'teacher' : 'teachers'} available - Click "Enroll" to choose',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          
          if (schedules.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text(
                        "Schedule (${schedules.length} ${schedules.length == 1 ? 'slot' : 'slots'})",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...schedules.take(3).map((schedule) {
                    final day = schedule['day_of_week'] ?? '';
                    final startTime = schedule['start_time'] ?? '';
                    final endTime = schedule['end_time'] ?? '';
                    final room = schedule['room_number'] ?? '';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$day ${startTime.substring(0, 5)}-${endTime.substring(0, 5)}${room.isNotEmpty ? ' • Room $room' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }).toList(),
                  if (schedules.length > 3)
                    Text(
                      '+ ${schedules.length - 3} more...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnrolledCourseCard(Map<String, dynamic> enrollment) {
    final subjectName = enrollment['subject_name'] ?? 'Unknown';
    final teacherName = enrollment['teacher_name'] ?? 'N/A';
    final classCode = enrollment['class_code'] ?? '';
    final schedules = List<Map<String, dynamic>>.from(enrollment['schedules'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (classCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          classCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              teacherName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _showUnenrollDialog(
                    enrollment['id'],
                    teacherName,
                    subjectName,
                  ),
                  tooltip: "Unenroll",
                ),
              ],
            ),
            
            if (schedules.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          "Your Schedule",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...schedules.map((schedule) {
                      final day = schedule['day_of_week'] ?? '';
                      final startTime = schedule['start_time'] ?? '';
                      final endTime = schedule['end_time'] ?? '';
                      final room = schedule['room_number'] ?? '';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '$day ${startTime.substring(0, 5)}-${endTime.substring(0, 5)}${room.isNotEmpty ? ' • Room $room' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUnenrollDialog(int enrollmentId, String teacherName, String subjectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Confirm Unenrollment"),
          ],
        ),
        content: Text(
          "Are you sure you want to unenroll from:\n\n"
          "$subjectName\nwith $teacherName?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unenrollFromCourse(enrollmentId, subjectName, teacherName);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Unenroll"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "No courses in your timetable",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEnrollmentsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.class_, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                "You haven't enrolled in any courses yet",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Click 'Enroll' on any course above to get started",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}