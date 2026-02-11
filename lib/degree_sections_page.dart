import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'section_students_page.dart';

class DegreeSectionsPage extends StatefulWidget {
  final String adminId;
  final String semesterNo;

  const DegreeSectionsPage({
    super.key,
    required this.adminId,
    required this.semesterNo,
  });

  @override
  State<DegreeSectionsPage> createState() => _DegreeSectionsPageState();
}

class _DegreeSectionsPageState extends State<DegreeSectionsPage> {
  bool isLoading = false;
  Map<String, List<dynamic>> degreeData = {};

  @override
  void initState() {
    super.initState();
    _loadDegreeData();
  }

  Future<void> _loadDegreeData() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminDegreeSections),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'semester_no': widget.semesterNo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          degreeData = Map<String, List<dynamic>>.from(
            (data['degrees'] as Map).map(
              (key, value) => MapEntry(key, List<dynamic>.from(value)),
            ),
          );
        });
      }
    } catch (e) {
      print("Error loading degree data: $e");
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
        title: Text(
          "Semester ${widget.semesterNo} - Programs",
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadDegreeData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDegreeData,
              child: degreeData.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _buildDegreeCards(),
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
            "No programs found",
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

  List<Widget> _buildDegreeCards() {
    List<Widget> cards = [];
    
    degreeData.forEach((degree, sections) {
      cards.add(_buildDegreeCard(degree, sections));
      cards.add(const SizedBox(height: 16));
    });
    
    return cards;
  }

  Widget _buildDegreeCard(String degree, List<dynamic> sections) {
    final degreeColor = _getDegreeColor(degree);
    
    return Container(
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
          // Degree Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [degreeColor, degreeColor.withOpacity(0.7)],
              ),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        degree,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${sections.length} Section${sections.length > 1 ? 's' : ''}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sections Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                return _buildSectionCard(degree, section, degreeColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String degree, Map<String, dynamic> section, Color color) {
    // Parse avg_attendance safely
    double attendance = 0.0;
    if (section['avg_attendance'] != null) {
      if (section['avg_attendance'] is String) {
        attendance = double.tryParse(section['avg_attendance']) ?? 0.0;
      } else {
        attendance = (section['avg_attendance'] as num).toDouble();
      }
    }
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SectionStudentsPage(
              adminId: widget.adminId,
              degree: degree,
              section: section['section'],
              semesterNo: widget.semesterNo,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10), // Reduced from 12
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Added to prevent overflow
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Sec ${section['section']}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 6), // Reduced from 8
            Flexible( // Wrapped in Flexible
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "${section['student_count']}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2), // Reduced from 4
            Flexible( // Wrapped in Flexible
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getAttendanceColor(attendance).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${attendance.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getAttendanceColor(attendance),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDegreeColor(String degree) {
    final colors = {
      'BSCS': const Color(0xFF667EEA),
      'BSSE': const Color(0xFF43CEA2),
      'BSIT': const Color(0xFFFA709A),
      'BSAI': const Color(0xFFFEE140),
      'BSDS': const Color(0xFF185A9D),
      'MSCS': const Color(0xFF764BA2),
    };
    return colors[degree] ?? const Color(0xFF667EEA);
  }

  Color _getAttendanceColor(double attendance) {
    if (attendance >= 75) return Colors.green;
    if (attendance >= 50) return Colors.orange;
    return Colors.red;
  }
}