import 'package:campus_entry_guide/change_password_page.dart';
import 'package:campus_entry_guide/notification_page.dart';
import 'package:campus_entry_guide/student_enrollment_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_storage.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get user session from local storage
      final session = await LocalStorage.getUserSession();
      final userId = session['userId'];
      final role = session['role'];

      if (userId == null || role == null) {
        setState(() {
          _error = "Session expired. Please login again.";
          _isLoading = false;
        });
        return;
      }

      print("📋 Fetching profile for User ID: $userId, Role: $role");

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-user-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'role': role,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      print("📡 Response Status: ${response.statusCode}");
      print("📡 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _profileData = data['userData'];
          _isLoading = false;
        });
        print("✅ Profile data loaded successfully");
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _error = errorData['message'] ?? "Failed to load profile";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching profile: $e");
      setState(() {
        _error = "Network error. Please try again.";
        _isLoading = false;
      });
    }
  }

  // ✅ FETCH STUDENT ATTENDANCE STATISTICS
  Future<Map<String, dynamic>> _fetchStudentAttendanceStats() async {
    try {
      final session = await LocalStorage.getUserSession();
      final userId = session?['userId'];

      if (userId == null) {
        throw Exception('User session not found');
      }

      print('📊 Fetching attendance stats for student ID: $userId');

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-student-attendance-stats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': userId}),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching attendance stats: $e');
      throw e;
    }
  }

  // ✅ FETCH TEACHER STATISTICS
  Future<Map<String, dynamic>> _fetchTeacherStatistics() async {
    try {
      final session = await LocalStorage.getUserSession();
      final userId = session?['userId'];

      if (userId == null) {
        throw Exception('User session not found');
      }

      print('📊 Fetching teacher statistics for ID: $userId');

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-teacher-statistics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'teacher_id': userId}),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching teacher statistics: $e');
      throw e;
    }
  }

  // ✅ FETCH ADMIN STATISTICS
  Future<Map<String, dynamic>> _fetchAdminStatistics() async {
    try {
      final session = await LocalStorage.getUserSession();
      final userId = session?['userId'];

      if (userId == null) {
        throw Exception('User session not found');
      }

      print('📊 Fetching admin statistics for ID: $userId');

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-admin-statistics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': userId}),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching admin statistics: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF11998e),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchUserProfile,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11998e),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final role = _profileData!['role'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchUserProfile,
        color: const Color(0xFF11998e),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(role),
              const SizedBox(height: 30),
              _buildProfileInfo(role),
              const SizedBox(height: 30),
              _buildStatistics(role),
              const SizedBox(height: 30),
              _buildSettings(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        "Profile",
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
    );
  }

  Widget _buildProfileHeader(String role) {
    final fullName = _profileData!['full_name'] ?? 'User';
    final department = role != 'Student' 
      ? (_profileData!['department'] ?? 'Not assigned')
      : (_profileData!['degree'] ?? 'Not assigned');
    final profileImage = _profileData!['profile_image'];
    
    IconData roleIcon;
    if (role == 'Student') {
      roleIcon = Icons.school;
    } else if (role == 'Teacher') {
      roleIcon = Icons.person;
    } else {
      roleIcon = Icons.admin_panel_settings;
    }

    return Center(
      child: Column(
        children: [
          // Profile Image with circular avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF11998e),
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? MemoryImage(base64Decode(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Icon(roleIcon, size: 50, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            department,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF11998e).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: Color(0xFF11998e),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(String role) {
    final email = _profileData!['email'] ?? 'Not provided';
    final phoneNumber = _profileData!['phone_number'] ?? 'Not provided';
    final department = _profileData!['department'] ?? 'Not assigned';

    List<Widget> infoCards = [
      _profileInfoCard(
        icon: Icons.email_rounded,
        title: "Email",
        value: email,
      ),
      const SizedBox(height: 12),
      _profileInfoCard(
        icon: Icons.phone_rounded,
        title: "Phone",
        value: phoneNumber,
      ),
      const SizedBox(height: 12),
    ];

    // Only show department for Teacher and Admin, not for Students
    if (role != 'Student') {
      infoCards.add(
        _profileInfoCard(
          icon: Icons.apartment_rounded,
          title: "Department",
          value: department,
        ),
      );
      infoCards.add(const SizedBox(height: 12));
    }

    // Role-specific fields
    if (role == 'Student') {
      final aridNo = _profileData!['arid_no'] ?? 'Not assigned';
      final semester = _profileData!['semester'] ?? 'Not assigned';
      final section = _profileData!['section'] ?? 'Not assigned';

      infoCards.addAll([
        _profileInfoCard(
          icon: Icons.badge_rounded,
          title: "ARID Number",
          value: aridNo,
        ),
        const SizedBox(height: 12),
        _profileInfoCard(
          icon: Icons.school_rounded,
          title: "Semester",
          value: semester,
        ),
        const SizedBox(height: 12),
        _profileInfoCard(
          icon: Icons.class_rounded,
          title: "Section",
          value: section,
        ),
      ]);
    } else if (role == 'Teacher') {
      final subjectName = _profileData!['subject_name'] ?? 'Not assigned';
      final shift = _profileData!['shift'] ?? 'Not assigned';

      infoCards.addAll([
        _profileInfoCard(
          icon: Icons.book_rounded,
          title: "Subject",
          value: subjectName,
        ),
        const SizedBox(height: 12),
        _profileInfoCard(
          icon: Icons.schedule_rounded,
          title: "Shift",
          value: shift,
        ),
      ]);
    } else if (role == 'Admin') {
      final adminId = _profileData!['admin_id'] ?? 'Not assigned';
      final officeName = _profileData!['office_name'] ?? 'Not assigned';

      infoCards.addAll([
        _profileInfoCard(
          icon: Icons.badge_rounded,
          title: "Admin ID",
          value: adminId,
        ),
        const SizedBox(height: 12),
        _profileInfoCard(
          icon: Icons.business_rounded,
          title: "Office",
          value: officeName,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoCards,
    );
  }

  Widget _profileInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF11998e).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF11998e), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED STATISTICS METHOD
  Widget _buildStatistics(String role) {
    if (role == 'Student') {
      return FutureBuilder<Map<String, dynamic>>(
        future: _fetchStudentAttendanceStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(40),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF11998e)),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorStats();
          }

          final stats = snapshot.data!;
          return _buildStudentAttendanceStats(stats);
        },
      );
    } else if (role == 'Teacher') {
      return FutureBuilder<Map<String, dynamic>>(
        future: _fetchTeacherStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(40),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF11998e)),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorStats();
          }

          final stats = snapshot.data!;
          return _buildTeacherPerformanceStats(stats);
        },
      );
    } else {
      return _buildAdminStats();
    }
  }

  // ✅ BUILD STUDENT ATTENDANCE STATS
  Widget _buildStudentAttendanceStats(Map<String, dynamic> stats) {
    final overallPercentage = (stats['overall_percentage'] ?? 0.0) is int
        ? (stats['overall_percentage'] as int).toDouble()
        : (stats['overall_percentage'] ?? 0.0) as double;
    
    final totalPresent = stats['total_present'] ?? 0;
    final totalAbsent = stats['total_absent'] ?? 0;
    final totalClasses = stats['total_classes'] ?? 0;
    final subjects = stats['subjects'] as List<dynamic>? ?? [];

    // Determine status color
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (overallPercentage >= 90) {
      statusColor = const Color(0xFF4CAF50); // Green
      statusText = "Excellent";
      statusIcon = Icons.check_circle;
    } else if (overallPercentage >= 75) {
      statusColor = const Color(0xFFFFA726); // Orange
      statusText = "Good";
      statusIcon = Icons.warning_amber_rounded;
    } else if (overallPercentage >= 50) {
      statusColor = const Color(0xFFFF7043); // Deep Orange
      statusText = "Average";
      statusIcon = Icons.info_outline;
    } else {
      statusColor = const Color(0xFFEF5350); // Red
      statusText = "Needs Attention";
      statusIcon = Icons.error_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Attendance Statistics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF11998e)),
              onPressed: () {
                setState(() {}); // Trigger rebuild to refresh data
              },
              tooltip: 'Refresh Stats',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Overall Attendance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor, statusColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Overall Attendance",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${overallPercentage.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: Colors.white, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick Stats Row
        Row(
          children: [
            Expanded(
              child: _quickStatCard(
                "Present",
                "$totalPresent",
                Icons.check_circle_outline,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickStatCard(
                "Absent",
                "$totalAbsent",
                Icons.cancel_outlined,
                const Color(0xFFEF5350),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickStatCard(
                "Total",
                "$totalClasses",
                Icons.calendar_today,
                const Color(0xFF11998e),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Subject-wise Breakdown
        if (subjects.isNotEmpty) ...[
          const Text(
            "Subject-wise Breakdown",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...subjects.map((subject) {
            final subjectName = subject['course_name'] ?? 'Unknown';
            final present = subject['attended_classes'] ?? 0;
            final total = subject['total_classes'] ?? 1;
            final percentage = total > 0 ? (present / total * 100) : 0.0;

            return _subjectAttendanceCard(
              subjectName,
              present,
              total,
              percentage,
            );
          }).toList(),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.school_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  "No subjects enrolled yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickStatCard(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),  // Changed from 16 to 12
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3), width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,  // ADDED THIS LINE
      children: [
        Icon(icon, color: color, size: 24),  // Changed from 28 to 24
        const SizedBox(height: 6),  // Changed from 8 to 6
        Text(
          value,
          style: TextStyle(
            fontSize: 20,  // Changed from 22 to 20
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),  // Changed from 4 to 2
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,  // Changed from 11 to 10
          ),
        ),
      ],
    ),
  );
}

  Widget _subjectAttendanceCard(String subject, int present, int total, double percentage) {
    Color barColor;
    if (percentage >= 90) {
      barColor = const Color(0xFF4CAF50);
    } else if (percentage >= 75) {
      barColor = const Color(0xFFFFA726);
    } else if (percentage >= 50) {
      barColor = const Color(0xFFFF7043);
    } else {
      barColor = const Color(0xFFEF5350);
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
                child: Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "${percentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "$present/$total",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ BUILD TEACHER PERFORMANCE STATS
  Widget _buildTeacherPerformanceStats(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Teaching Statistics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF11998e)),
              onPressed: () {
                setState(() {}); // Trigger rebuild
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Overall Performance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Classes Taught",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${stats['total_classes'] ?? 0}",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "This Semester",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick Stats Row
        Row(
          children: [
            Expanded(
              child: _quickStatCard(
                "Subjects",
                "${stats['total_subjects'] ?? 0}",
                Icons.book,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickStatCard(
                "Sections",
                "${stats['total_sections'] ?? 0}",
                Icons.class_,
                const Color(0xFFFFA726),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickStatCard(
                "Students",
                "${stats['total_students'] ?? 0}",
                Icons.people,
                const Color(0xFF11998e),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Average Attendance Performance
        const Text(
          "Class Performance",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Average Class Attendance",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "${stats['avg_attendance']?.toStringAsFixed(1) ?? '0.0'}%",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getAttendanceColor(stats['avg_attendance']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (stats['avg_attendance'] ?? 0) / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    _getAttendanceColor(stats['avg_attendance']),
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Subject-wise Performance
        if (stats['subjects'] != null && (stats['subjects'] as List).isNotEmpty) ...[
          const Text(
            "Subject-wise Performance",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...(stats['subjects'] as List).map((subject) {
            return _subjectPerformanceCard(subject);
          }).toList(),
        ],
      ],
    );
  }

  Color _getAttendanceColor(dynamic percentage) {
    double? percent;
    
    if (percentage == null) return Colors.grey;
    
    if (percentage is int) {
      percent = percentage.toDouble();
    } else if (percentage is double) {
      percent = percentage;
    } else {
      return Colors.grey;
    }
    
    if (percent >= 90) return const Color(0xFF4CAF50);
    if (percent >= 75) return const Color(0xFFFFA726);
    if (percent >= 50) return const Color(0xFFFF7043);
    return const Color(0xFFEF5350);
  }

  Widget _subjectPerformanceCard(Map<String, dynamic> subject) {
    final subjectName = subject['subject_name'] ?? 'Unknown';
    final classesTaken = subject['classes_taken'] ?? 0;
    final avgAttendance = (subject['avg_attendance'] ?? 0.0) is int
        ? (subject['avg_attendance'] as int).toDouble()
        : (subject['avg_attendance'] ?? 0.0) as double;
    final totalStudents = subject['total_students'] ?? 0;

    final Color barColor = _getAttendanceColor(avgAttendance);

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
                      subjectName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$totalStudents students • $classesTaken classes",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${avgAttendance.toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: avgAttendance / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "Unable to load statistics",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {}); // Trigger rebuild
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998e),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD ADMIN STATISTICS
  Widget _buildAdminStats() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAdminStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF11998e)),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorStats();
        }

        final stats = snapshot.data!;
        return _buildAdminPerformanceStats(stats);
      },
    );
  }

  // ✅ BUILD ADMIN PERFORMANCE STATS
  Widget _buildAdminPerformanceStats(Map<String, dynamic> stats) {
    final presentPercentage = (stats['present_percentage'] ?? 0.0) is int
        ? (stats['present_percentage'] as int).toDouble()
        : (stats['present_percentage'] ?? 0.0) as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Administration Overview",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF11998e)),
              onPressed: () {
                setState(() {}); // Trigger rebuild
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Overall System Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "System Attendance",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${presentPercentage.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "${stats['total_attendance_records'] ?? 0} Total Records",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick Stats Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _quickStatCard(
              "Teachers",
              "${stats['total_teachers'] ?? 0}",
              Icons.people,
              const Color(0xFF667EEA),
            ),
            _quickStatCard(
              "Students",
              "${stats['total_students'] ?? 0}",
              Icons.school,
              const Color(0xFF43CEA2),
            ),
            _quickStatCard(
              "Subjects",
              "${stats['total_subjects'] ?? 0}",
              Icons.book,
              const Color(0xFFFFA726),
            ),
            _quickStatCard(
              "Sections",
              "${stats['total_sections'] ?? 0}",
              Icons.class_,
              const Color(0xFF11998e),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Complaints Overview
        const Text(
          "Complaints Overview",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _complaintStatItem(
                    "Pending",
                    "${stats['pending_complaints'] ?? 0}",
                    Colors.orange,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _complaintStatItem(
                    "In Progress",
                    "${stats['in_progress_complaints'] ?? 0}",
                    Colors.blue,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _complaintStatItem(
                    "Resolved",
                    "${stats['resolved_complaints'] ?? 0}",
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Attendance Stats
        Row(
          children: [
            Expanded(
              child: _attendanceStatCard(
                "Present",
                "${stats['total_present'] ?? 0}",
                Icons.check_circle_outline,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _attendanceStatCard(
                "Absent",
                "${stats['total_absent'] ?? 0}",
                Icons.cancel_outlined,
                const Color(0xFFEF5350),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Department-wise Performance
        if (stats['departments'] != null && (stats['departments'] as List).isNotEmpty) ...[
          const Text(
            "Department Performance",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...(stats['departments'] as List).map((dept) {
            return _departmentPerformanceCard(dept);
          }).toList(),
        ],
      ],
    );
  }

  Widget _complaintStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _attendanceStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _departmentPerformanceCard(Map<String, dynamic> dept) {
    final deptName = dept['department'] ?? 'Unknown';
    final teachers = dept['total_teachers'] ?? 0;
    final students = dept['total_students'] ?? 0;
    final subjects = dept['total_subjects'] ?? 0;
    final avgAttendance = (dept['avg_attendance'] ?? 0.0) is int
        ? (dept['avg_attendance'] as int).toDouble()
        : (dept['avg_attendance'] ?? 0.0) as double;

    final Color barColor = _getAttendanceColor(avgAttendance);

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
                      deptName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$teachers teachers • $students students • $subjects subjects",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${avgAttendance.toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: avgAttendance / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Settings",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _settingsTile(Icons.refresh, "Refresh Profile", onTap: _fetchUserProfile),
        _settingsTile(Icons.edit, "Edit Profile", onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfilePage(profileData: _profileData!),
            ),
          );
          
          // If profile was updated, refresh the data
          if (result == true) {
            _fetchUserProfile();
          }
        }),
        _settingsTile(Icons.lock, "Change Password", onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
          );
        }),
        if (_profileData!['role'] == 'Student')
          _settingsTile(
            Icons.school,
            "Course Enrollment",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentSelfEnrollmentScreen(
                    userId: _profileData!['id'],
                    userName: _profileData!['full_name'],
                    userEmail: _profileData!['email'],
                    degree: _profileData!['degree'] ?? '',
                    section: _profileData!['section'] ?? '',
                    semesterNo: _profileData!['semester'] ?? '',
                  ),
                ),
              );
            },
          ),
        _settingsTile(Icons.notifications, "Notifications", onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationPage()),
          );
        }),
        _settingsTile(Icons.logout, "Logout", color: Colors.red, onTap: _showLogoutDialog),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        leading: Icon(icon, color: color ?? const Color(0xFF11998e), size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.green),
            const SizedBox(width: 10),
            const Text("Logout"),
          ],
        ),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await LocalStorage.clearSession();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}