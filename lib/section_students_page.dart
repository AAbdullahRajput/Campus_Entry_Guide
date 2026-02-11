import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'student_details_admin_page.dart';

class SectionStudentsPage extends StatefulWidget {
  final String adminId;
  final String degree;
  final String section;
  final String semesterNo;

  const SectionStudentsPage({
    super.key,
    required this.adminId,
    required this.degree,
    required this.section,
    required this.semesterNo,
  });

  @override
  State<SectionStudentsPage> createState() => _SectionStudentsPageState();
}

class _SectionStudentsPageState extends State<SectionStudentsPage> {
  bool isLoading = false;
  List<dynamic> students = [];
  List<dynamic> filteredStudents = [];
  String searchQuery = '';
  String sortBy = 'name'; // name, arid_no, attendance

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminSectionStudents),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'degree': widget.degree,
          'section': widget.section,
          'semester_no': widget.semesterNo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          students = data['students'] ?? [];
          filteredStudents = students;
          _sortStudents();
        });
      }
    } catch (e) {
      print("Error loading students: $e");
      _showErrorSnackbar("Failed to load students");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterStudents(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredStudents = students;
      } else {
        filteredStudents = students.where((student) {
          final name = student['name'].toString().toLowerCase();
          final aridNo = student['arid_no'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || aridNo.contains(searchLower);
        }).toList();
      }
      _sortStudents();
    });
  }

  void _sortStudents() {
    setState(() {
      if (sortBy == 'name') {
        filteredStudents.sort((a, b) => 
          a['name'].toString().compareTo(b['name'].toString()));
      } else if (sortBy == 'arid_no') {
        filteredStudents.sort((a, b) => 
          a['arid_no'].toString().compareTo(b['arid_no'].toString()));
      } else if (sortBy == 'attendance') {
        filteredStudents.sort((a, b) {
          final aAtt = (a['overall_attendance'] ?? 0).toDouble();
          final bAtt = (b['overall_attendance'] ?? 0).toDouble();
          return bAtt.compareTo(aAtt);
        });
      }
    });
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sort By"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('Name', 'name'),
            _buildSortOption('ARID Number', 'arid_no'),
            _buildSortOption('Attendance', 'attendance'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: sortBy,
      onChanged: (newValue) {
        setState(() {
          sortBy = newValue!;
          _sortStudents();
        });
        Navigator.pop(context);
      },
    );
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
    final totalStudents = students.length;
    
    // Calculate average attendance safely
    double avgAttendance = 0.0;
    if (totalStudents > 0) {
      double sum = 0.0;
      for (var student in students) {
        if (student['overall_attendance'] != null) {
          if (student['overall_attendance'] is String) {
            sum += double.tryParse(student['overall_attendance']) ?? 0.0;
          } else {
            sum += (student['overall_attendance'] as num).toDouble();
          }
        }
      }
      avgAttendance = sum / totalStudents;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          "${widget.degree} - Section ${widget.section}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: "Sort",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(Icons.people, "$totalStudents Students"),
                _buildStatChip(
                  Icons.percent,
                  "${avgAttendance.toStringAsFixed(1)}% Avg",
                  _getAttendanceColor(avgAttendance),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: _filterStudents,
              decoration: InputDecoration(
                hintText: 'Search by name or ARID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          // Students List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadStudents,
                    child: filteredStudents.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              return _buildStudentCard(student, index + 1);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF43CEA2)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color ?? const Color(0xFF43CEA2)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF43CEA2),
            ),
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
          Icon(Icons.person_search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? "No students found" : "No matching students",
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

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    // Parse overall_attendance safely
    double attendance = 0.0;
    if (student['overall_attendance'] != null) {
      if (student['overall_attendance'] is String) {
        attendance = double.tryParse(student['overall_attendance']) ?? 0.0;
      } else {
        attendance = (student['overall_attendance'] as num).toDouble();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF43CEA2).withOpacity(0.1),
          backgroundImage: student['profile_image'] != null
              ? NetworkImage(student['profile_image'])
              : null,
          child: student['profile_image'] == null
              ? Text(
                  "#$index",
                  style: const TextStyle(
                    color: Color(0xFF43CEA2),
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          student['name'] ?? 'Unknown',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              student['arid_no'] ?? 'N/A',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(Icons.book, "${student['enrolled_courses'] ?? 0} Courses"),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAttendanceColor(attendance).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: _getAttendanceColor(attendance),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${attendance.toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: _getAttendanceColor(attendance),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailsAdminPage(
                adminId: widget.adminId,
                studentId: student['id'],
                studentName: student['name'],
              ),
            ),
          ).then((_) => _loadStudents()); // Reload after returning
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double attendance) {
    if (attendance >= 75) return Colors.green;
    if (attendance >= 50) return Colors.orange;
    return Colors.red;
  }
}