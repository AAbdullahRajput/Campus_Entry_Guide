import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'degree_sections_page.dart';

class StudentsHierarchyPage extends StatefulWidget {
  final String adminId;
  final String adminName;

  const StudentsHierarchyPage({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<StudentsHierarchyPage> createState() => _StudentsHierarchyPageState();
}

class _StudentsHierarchyPageState extends State<StudentsHierarchyPage> {
  bool isLoading = false;
  Map<String, dynamic> semesterStats = {};

  @override
  void initState() {
    super.initState();
    _loadSemesterStats();
  }

  Future<void> _loadSemesterStats() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminSemesterStats),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': widget.adminId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          semesterStats = data['semester_stats'] ?? {};
        });
      }
    } catch (e) {
      print("Error loading semester stats: $e");
      _showErrorSnackbar("Failed to load data");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Students by Semester",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF43CEA2), Color(0xFF185A9D)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSemesterStats,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSemesterStats,
              child: semesterStats.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _buildSemesterCards(),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No students found",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSemesterCards() {
    List<Widget> cards = [];
    
    semesterStats.forEach((semester, stats) {
      cards.add(_buildSemesterCard(semester, stats));
      cards.add(const SizedBox(height: 12));
    });
    
    return cards;
  }

  Widget _buildSemesterCard(String semester, Map<String, dynamic> stats) {
    final semesterColor = _getSemesterColor(int.tryParse(semester) ?? 1);
    
    // Parse avg_attendance safely
    double avgAttendance = 0.0;
    if (stats['avg_attendance'] != null) {
      if (stats['avg_attendance'] is String) {
        avgAttendance = double.tryParse(stats['avg_attendance']) ?? 0.0;
      } else {
        avgAttendance = (stats['avg_attendance'] as num).toDouble();
      }
    }
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DegreeSectionsPage(
              adminId: widget.adminId,
              semesterNo: semester,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: semesterColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school,
                    color: semesterColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_getOrdinal(semester)} Semester",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${stats['total_students']} Students",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.school,
                  "${stats['total_degrees']}",
                  "Degrees",
                  semesterColor,
                ),
                _buildStatItem(
                  Icons.class_,
                  "${stats['total_sections']}",
                  "Sections",
                  semesterColor,
                ),
                _buildStatItem(
                  Icons.percent,
                  "${avgAttendance.toStringAsFixed(1)}%",
                  "Attendance",
                  semesterColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Color _getSemesterColor(int semester) {
    final colors = [
      const Color(0xFF667EEA),
      const Color(0xFF43CEA2),
      const Color(0xFFFA709A),
      const Color(0xFFFEE140),
      const Color(0xFF185A9D),
      const Color(0xFF764BA2),
      const Color(0xFFFFB347),
      const Color(0xFF6A11CB),
    ];
    return colors[(semester - 1) % colors.length];
  }

  String _getOrdinal(String number) {
    final num = int.tryParse(number) ?? 1;
    if (num % 100 >= 11 && num % 100 <= 13) {
      return "${num}th";
    }
    switch (num % 10) {
      case 1:
        return "${num}st";
      case 2:
        return "${num}nd";
      case 3:
        return "${num}rd";
      default:
        return "${num}th";
    }
  }
}