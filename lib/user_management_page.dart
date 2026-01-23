import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart'; // Add this import at the top

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Search Controllers
  final TextEditingController _studentSearchController = TextEditingController();
  final TextEditingController _teacherSearchController = TextEditingController();
  
  // Data Lists
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  List<Map<String, dynamic>> allTeachers = [];
  List<Map<String, dynamic>> filteredTeachers = [];
  
  // Filter Options (from database)
  List<String> degrees = ['All'];
  List<String> sections = ['All'];
  List<String> semesters = ['All'];
  List<String> departments = ['All'];
  List<String> subjects = ['All'];
  List<String> shifts = ['All'];
  
  // Selected Filters
  String selectedDegree = 'All';
  String selectedSection = 'All';
  String selectedSemester = 'All';
  String selectedDepartment = 'All';
  String selectedSubject = 'All';
  String selectedShift = 'All';
  
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        searchQuery = '';
        _studentSearchController.clear();
        _teacherSearchController.clear();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentSearchController.dispose();
    _teacherSearchController.dispose();
    super.dispose();
  }

  // ===================== API CALLS =====================
  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _loadFilterOptions(),
      _loadStudents(),
      _loadTeachers(),
    ]);
    setState(() => isLoading = false);
  }

Future<void> _loadFilterOptions() async {
  try {
    final response = await http.get(
      Uri.parse(ApiConfig.getFilterOptions),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        // Convert to Set then back to List to remove exact duplicates
        degrees = ['All', ...List<String>.from(data['degrees'] ?? []).toSet()];
        sections = ['All', ...List<String>.from(data['sections'] ?? []).toSet()];
        semesters = ['All', ...List<String>.from(data['semesters'] ?? []).toSet()];
        departments = ['All', ...List<String>.from(data['departments'] ?? []).toSet()];
        subjects = ['All', ...List<String>.from(data['subjects'] ?? []).toSet()];
        shifts = ['All', ...List<String>.from(data['shifts'] ?? []).toSet()];
        
        // IMPORTANT: Debug print to check for duplicates
        print('=== FILTER OPTIONS LOADED ===');
        print('Degrees: $degrees');
        print('Sections: $sections');
        print('Semesters: $semesters');
        print('Departments: $departments');
        print('Subjects: $subjects');
        print('Shifts: $shifts');
      });
    }
  } catch (e) {
    print('Error loading filter options: $e');
  }
}

  Future<void> _loadStudents() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getAllStudents),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          allStudents = List<Map<String, dynamic>>.from(data['students'] ?? []);
          _applyStudentFilters();
        });
      }
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getAllTeachers),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          allTeachers = List<Map<String, dynamic>>.from(data['teachers'] ?? []);
          _applyTeacherFilters();
        });
      }
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> _deleteStudent(int id) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteStudent),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Student deleted successfully', Colors.green);
        _loadStudents();
      } else {
        _showSnackBar('Failed to delete student', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteTeacher(int id) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteTeacher),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Teacher deleted successfully', Colors.green);
        _loadTeachers();
      } else {
        _showSnackBar('Failed to delete teacher', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // ===================== FILTER LOGIC =====================
  void _applyStudentFilters() {
    setState(() {
      filteredStudents = allStudents.where((student) {
        // Degree filter
        if (selectedDegree != 'All' && student['degree'] != selectedDegree) {
          return false;
        }
        
        // Section filter
        if (selectedSection != 'All' && student['section'] != selectedSection) {
          return false;
        }
        
        // Semester filter
        if (selectedSemester != 'All' && student['semester_no'].toString() != selectedSemester) {
          return false;
        }
        
        // Search filter
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          return student['full_name'].toString().toLowerCase().contains(query) ||
                 student['email'].toString().toLowerCase().contains(query) ||
                 student['arid_no'].toString().toLowerCase().contains(query) ||
                 student['degree'].toString().toLowerCase().contains(query) ||
                 student['section'].toString().toLowerCase().contains(query);
        }
        
        return true;
      }).toList();
    });
  }

  void _applyTeacherFilters() {
    setState(() {
      filteredTeachers = allTeachers.where((teacher) {
        // Department filter
        if (selectedDepartment != 'All' && teacher['department'] != selectedDepartment) {
          return false;
        }
        
        // Subject filter (handles multiple subjects)
        if (selectedSubject != 'All') {
          final teacherSubjects = teacher['subject_name'].toString().split(',').map((s) => s.trim()).toList();
          if (!teacherSubjects.contains(selectedSubject)) {
            return false;
          }
        }
        
        // Shift filter
        if (selectedShift != 'All' && teacher['shift'] != selectedShift) {
          return false;
        }
        
        // Search filter
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          return teacher['full_name'].toString().toLowerCase().contains(query) ||
                 teacher['email'].toString().toLowerCase().contains(query) ||
                 teacher['department'].toString().toLowerCase().contains(query) ||
                 teacher['subject_name'].toString().toLowerCase().contains(query) ||
                 teacher['shift'].toString().toLowerCase().contains(query);
        }
        
        return true;
      }).toList();
    });
  }

  void _onStudentSearch(String query) {
    setState(() {
      searchQuery = query;
      _applyStudentFilters();
    });
  }

  void _onTeacherSearch(String query) {
    setState(() {
      searchQuery = query;
      _applyTeacherFilters();
    });
  }

  // ===================== UI BUILDERS =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "User Management",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Configure Filters',
            onPressed: () => _showFilterConfigDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "Students"),
            Tab(text: "Teachers"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStudentTab(),
                _buildTeacherTab(),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        if (_tabController.index == 0) {
          _showAddStudentDialog();
        } else {
          _showAddTeacherDialog();
        }
      },
      backgroundColor: const Color(0xFF667EEA),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        "Add ${_tabController.index == 0 ? 'Student' : 'Teacher'}",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
    );
  }

Widget _buildStudentTab() {
  return Column(
    children: [
      _buildSearchBar(_studentSearchController, _onStudentSearch, "Search students..."),
      _buildStudentFilters(),
      _buildResultCount(filteredStudents.length, "Students"),
      Expanded(
        child: filteredStudents.isEmpty
            ? _buildEmptyState("No students found")
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  return _buildStudentCard(filteredStudents[index]);
                },
              ),
      ),
    ],
  );
}

Widget _buildTeacherTab() {
  return Column(
    children: [
      _buildSearchBar(_teacherSearchController, _onTeacherSearch, "Search teachers..."),
      _buildTeacherFilters(),
      _buildResultCount(filteredTeachers.length, "Teachers"),
      Expanded(
        child: filteredTeachers.isEmpty
            ? _buildEmptyState("No teachers found")
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredTeachers.length,
                itemBuilder: (context, index) {
                  return _buildTeacherCard(filteredTeachers[index]);
                },
              ),
      ),
    ],
  );
}

  Widget _buildSearchBar(TextEditingController controller, Function(String) onChanged, String hint) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.grey.shade400),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStudentFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterDropdown(
              "Degree",
              selectedDegree,
              degrees,
              (value) {
                setState(() {
                  selectedDegree = value!;
                  _applyStudentFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              "Section",
              selectedSection,
              sections,
              (value) {
                setState(() {
                  selectedSection = value!;
                  _applyStudentFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              "Semester",
              selectedSemester,
              semesters,
              (value) {
                setState(() {
                  selectedSemester = value!;
                  _applyStudentFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            if (selectedDegree != 'All' || selectedSection != 'All' || selectedSemester != 'All')
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedDegree = 'All';
                    selectedSection = 'All';
                    selectedSemester = 'All';
                    _applyStudentFilters();
                  });
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text("Clear Filters"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterDropdown(
              "Department",
              selectedDepartment,
              departments,
              (value) {
                setState(() {
                  selectedDepartment = value!;
                  _applyTeacherFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              "Subject",
              selectedSubject,
              subjects,
              (value) {
                setState(() {
                  selectedSubject = value!;
                  _applyTeacherFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterDropdown(
              "Shift",
              selectedShift,
              shifts,
              (value) {
                setState(() {
                  selectedShift = value!;
                  _applyTeacherFilters();
                });
              },
            ),
            const SizedBox(width: 8),
            if (selectedDepartment != 'All' || selectedSubject != 'All' || selectedShift != 'All')
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedDepartment = 'All';
                    selectedSubject = 'All';
                    selectedShift = 'All';
                    _applyTeacherFilters();
                  });
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text("Clear Filters"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: value != 'All' ? const Color(0xFF667EEA).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != 'All' ? const Color(0xFF667EEA) : Colors.grey.shade300,
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        icon: Icon(
          Icons.arrow_drop_down,
          color: value != 'All' ? const Color(0xFF667EEA) : Colors.grey.shade600,
        ),
        style: TextStyle(
          fontSize: 14,
          color: value != 'All' ? const Color(0xFF667EEA) : Colors.grey.shade800,
          fontWeight: value != 'All' ? FontWeight.bold : FontWeight.normal,
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text("$label: $item"),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildResultCount(int count, String type) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$count $type Found",
        style: const TextStyle(
          color: Color(0xFF667EEA),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ),
  );
}

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
// Add this helper method first (add it above _buildStudentCard)
Widget _buildProfileAvatar(Map<String, dynamic> user) {
  final profileImage = user['profile_image'];
  
  // If no profile image, show default icon
  if (profileImage == null || profileImage.toString().isEmpty) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
      child: const Icon(Icons.person, color: Color(0xFF667EEA), size: 30),
    );
  }
  
  final imageStr = profileImage.toString();
  
  // Check if it's a base64 string (starts with /9j or data:image)
  if (imageStr.startsWith('/9j') || imageStr.startsWith('iVBOR') || imageStr.contains('data:image')) {
    try {
      // Remove data:image prefix if present
      String base64String = imageStr;
      if (imageStr.contains(',')) {
        base64String = imageStr.split(',')[1];
      }
      
      // Decode base64 to bytes
      final bytes = base64Decode(base64String);
      
      return CircleAvatar(
        radius: 30,
        backgroundImage: MemoryImage(bytes),
        backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      return CircleAvatar(
        radius: 30,
        backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
        child: const Icon(Icons.person, color: Color(0xFF667EEA), size: 30),
      );
    }
  }
  
  // Otherwise, treat it as a URL
  return CircleAvatar(
    radius: 30,
    backgroundImage: NetworkImage(imageStr),
    backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
    onBackgroundImageError: (exception, stackTrace) {
      print('Error loading image: $exception');
    },
  );
}

// Updated _buildStudentCard
Widget _buildStudentCard(Map<String, dynamic> student) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
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
        // Avatar - UPDATED
        _buildProfileAvatar(student),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHighlightedText(
                student['full_name'] ?? 'N/A',
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _buildHighlightedText(
                student['email'] ?? 'N/A',
                TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildInfoChip("ARID: ${student['arid_no'] ?? 'N/A'}", Colors.blue),
                  _buildInfoChip("${student['degree'] ?? 'N/A'}", Colors.purple),
                  _buildInfoChip("Section ${student['section'] ?? 'N/A'}", Colors.orange),
                  _buildInfoChip("Sem ${student['semester_no'] ?? 'N/A'}", Colors.green),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20, color: Color(0xFF667EEA)),
                  SizedBox(width: 8),
                  Text("Edit"),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Delete"),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditStudentDialog(student);
            } else if (value == 'delete') {
              _showDeleteConfirmation('Student', student['full_name'], () {
                _deleteStudent(student['id']);
              });
            }
          },
        ),
      ],
    ),
  );
}

// Updated _buildTeacherCard
Widget _buildTeacherCard(Map<String, dynamic> teacher) {
  final subjects = teacher['subject_name']?.toString().split(',') ?? [];
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
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
        // Avatar - UPDATED
        _buildProfileAvatar(teacher),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHighlightedText(
                teacher['full_name'] ?? 'N/A',
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _buildHighlightedText(
                teacher['email'] ?? 'N/A',
                TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildInfoChip(teacher['department'] ?? 'N/A', Colors.purple),
                  ...subjects.map((subject) => _buildInfoChip(subject.trim(), Colors.blue)),
                  _buildInfoChip(teacher['shift'] ?? 'N/A', Colors.orange),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20, color: Color(0xFF667EEA)),
                  SizedBox(width: 8),
                  Text("Edit"),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Delete"),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditTeacherDialog(teacher);
            } else if (value == 'delete') {
              _showDeleteConfirmation('Teacher', teacher['full_name'], () {
                _deleteTeacher(teacher['id']);
              });
            }
          },
        ),
      ],
    ),
  );
}

  Widget _buildHighlightedText(String text, TextStyle style) {
    if (searchQuery.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    
    if (!lowerText.contains(lowerQuery)) {
      return Text(text, style: style);
    }

    final startIndex = lowerText.indexOf(lowerQuery);
    final endIndex = startIndex + lowerQuery.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: text.substring(0, startIndex), style: style),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: style.copyWith(
              backgroundColor: Colors.yellow.shade300,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(endIndex), style: style),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ===================== DIALOGS =====================
  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final aridController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedDegree = degrees.firstWhere((d) => d != 'All', orElse: () => 'BSCS');
    String selectedSection = sections.firstWhere((s) => s != 'All', orElse: () => 'A');
    String selectedSemester = semesters.firstWhere((s) => s != 'All', orElse: () => '1');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add New Student"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aridController,
                  decoration: InputDecoration(
                    labelText: "ARID Number *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                value: selectedDegree,
                decoration: InputDecoration(
                  labelText: "Degree *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                // ✅ FIX: Add .toSet()
                items: degrees.where((d) => d != 'All').toSet().map((degree) {
                  return DropdownMenuItem(value: degree, child: Text(degree));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedDegree = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: InputDecoration(
                  labelText: "Section *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                // ✅ FIX: Add .toSet()
                items: sections.where((s) => s != 'All').toSet().map((section) {
                  return DropdownMenuItem(value: section, child: Text(section));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedSection = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSemester,
                decoration: InputDecoration(
                  labelText: "Semester *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                // ✅ FIX: Add .toSet()
                items: semesters.where((s) => s != 'All').toSet().map((sem) {
                  return DropdownMenuItem(value: sem, child: Text(sem));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedSemester = value!),
              ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    aridController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  _showSnackBar('Please fill all required fields', Colors.red);
                  return;
                }

                try {
                  final response = await http.post(
                    Uri.parse(ApiConfig.addStudent), // ← CHANGE THIS
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'full_name': nameController.text,
                      'email': emailController.text,
                      'arid_no': aridController.text,
                      'phone_number': phoneController.text,
                      'password': passwordController.text,
                      'degree': selectedDegree,
                      'section': selectedSection,
                      'semester_no': selectedSemester,
                    }),
                  );

                  if (response.statusCode == 201) {
                    Navigator.pop(context);
                    _showSnackBar('Student added successfully!', Colors.green);
                    _loadStudents();
                  } else {
                    final data = json.decode(response.body);
                    _showSnackBar(data['message'] ?? 'Failed to add student', Colors.red);
                  }
                } catch (e) {
                  _showSnackBar('Error: $e', Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
              child: const Text("Add Student"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedDepartment = departments.firstWhere((d) => d != 'All', orElse: () => 'CS');
    String selectedShift = shifts.firstWhere((s) => s != 'All', orElse: () => 'Morning');
    List<String> selectedSubjects = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add New Teacher"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: InputDecoration(
                    labelText: "Department *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: departments.where((d) => d != 'All').map((dept) {
                    return DropdownMenuItem(value: dept, child: Text(dept));
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedDepartment = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedShift,
                  decoration: InputDecoration(
                    labelText: "Shift *",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: shifts.where((s) => s != 'All').map((shift) {
                    return DropdownMenuItem(value: shift, child: Text(shift));
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedShift = value!),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          "Subjects * (Select multiple)",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                      Wrap(
                        children: subjects.where((s) => s != 'All').map((subject) {
                          final isSelected = selectedSubjects.contains(subject);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(subject),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedSubjects.add(subject);
                                  } else {
                                    selectedSubjects.remove(subject);
                                  }
                                });
                              },
                              selectedColor: const Color(0xFF667EEA).withOpacity(0.3),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    passwordController.text.isEmpty ||
                    selectedSubjects.isEmpty) {
                  _showSnackBar('Please fill all required fields', Colors.red);
                  return;
                }

                try {
                  final response = await http.post(
                    Uri.parse(ApiConfig.addTeacher),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'full_name': nameController.text,
                      'email': emailController.text,
                      'phone_number': phoneController.text,
                      'password': passwordController.text,
                      'department': selectedDepartment,
                      'subject_name': selectedSubjects.join(', '),
                      'shift': selectedShift,
                    }),
                  );

                  if (response.statusCode == 201) {
                    Navigator.pop(context);
                    _showSnackBar('Teacher added successfully!', Colors.green);
                    _loadTeachers();
                  } else {
                    final data = json.decode(response.body);
                    _showSnackBar(data['message'] ?? 'Failed to add teacher', Colors.red);
                  }
                } catch (e) {
                  _showSnackBar('Error: $e', Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
              child: const Text("Add Teacher"),
            ),
          ],
        ),
      ),
    );
  }

// ===================== COMPLETE FIXED EDIT STUDENT DIALOG =====================
void _showEditStudentDialog(Map<String, dynamic> student) {
  final nameController = TextEditingController(text: student['full_name']);
  final aridController = TextEditingController(text: student['arid_no']);
  final phoneController = TextEditingController(text: student['phone_number']);
  String selectedDegree = student['degree'] ?? degrees.firstWhere((d) => d != 'All', orElse: () => 'BSCS');
  String selectedSection = student['section'] ?? sections.firstWhere((s) => s != 'All', orElse: () => 'A');
  String selectedSemester = student['semester_no'].toString();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Edit Student"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aridController,
                decoration: InputDecoration(
                  labelText: "ARID Number",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDegree,
                decoration: InputDecoration(
                  labelText: "Degree",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: degrees.where((d) => d != 'All').map((degree) {
                  return DropdownMenuItem(value: degree, child: Text(degree));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedDegree = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: InputDecoration(
                  labelText: "Section",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: sections.where((s) => s != 'All').map((section) {
                  return DropdownMenuItem(value: section, child: Text(section));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedSection = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSemester,
                decoration: InputDecoration(
                  labelText: "Semester",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: semesters.where((s) => s != 'All').map((sem) {
                  return DropdownMenuItem(value: sem, child: Text(sem));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedSemester = value!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse(ApiConfig.updateStudent),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'id': student['id'],
                    'full_name': nameController.text,
                    'arid_no': aridController.text,
                    'phone_number': phoneController.text,
                    'degree': selectedDegree,
                    'section': selectedSection,
                    'semester_no': selectedSemester,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _showSnackBar('Student updated successfully!', Colors.green);
                  _loadStudents();
                } else {
                  _showSnackBar('Failed to update student', Colors.red);
                }
              } catch (e) {
                _showSnackBar('Error: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
            child: const Text("Update"),
          ),
        ],
      ),
    ),
  );
}

// ===================== COMPLETE FIXED EDIT TEACHER DIALOG =====================
void _showEditTeacherDialog(Map<String, dynamic> teacher) {
  final nameController = TextEditingController(text: teacher['full_name']);
  final phoneController = TextEditingController(text: teacher['phone_number']);
  String selectedDepartment = teacher['department'] ?? departments.firstWhere((d) => d != 'All', orElse: () => 'CS');
  String selectedShift = teacher['shift'] ?? shifts.firstWhere((s) => s != 'All', orElse: () => 'Morning');
  List<String> selectedSubjects = teacher['subject_name']?.toString().split(',').map((s) => s.trim()).toList() ?? [];

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Edit Teacher"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDepartment,
                decoration: InputDecoration(
                  labelText: "Department",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: departments.where((d) => d != 'All').map((dept) {
                  return DropdownMenuItem(value: dept, child: Text(dept));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedDepartment = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedShift,
                decoration: InputDecoration(
                  labelText: "Shift",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: shifts.where((s) => s != 'All').map((shift) {
                  return DropdownMenuItem(value: shift, child: Text(shift));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedShift = value!),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        "Subjects (Select multiple)",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    Wrap(
                      children: subjects.where((s) => s != 'All').map((subject) {
                        final isSelected = selectedSubjects.contains(subject);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(subject),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedSubjects.add(subject);
                                } else {
                                  selectedSubjects.remove(subject);
                                }
                              });
                            },
                            selectedColor: const Color(0xFF667EEA).withOpacity(0.3),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse(ApiConfig.updateTeacher),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'id': teacher['id'],
                    'full_name': nameController.text,
                    'phone_number': phoneController.text,
                    'department': selectedDepartment,
                    'subject_name': selectedSubjects.join(', '),
                    'shift': selectedShift,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _showSnackBar('Teacher updated successfully!', Colors.green);
                  _loadTeachers();
                } else {
                  _showSnackBar('Failed to update teacher', Colors.red);
                }
              } catch (e) {
                _showSnackBar('Error: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
            child: const Text("Update"),
          ),
        ],
      ),
    ),
  );
}

  void _showDeleteConfirmation(String type, String name, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete $type"),
        content: Text("Are you sure you want to permanently delete $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showFilterConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 6,
        child: AlertDialog(
          title: const Text("Configure Filters"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  labelColor: Color(0xFF667EEA),
                  tabs: [
                    Tab(text: "Degrees"),
                    Tab(text: "Sections"),
                    Tab(text: "Semesters"),
                    Tab(text: "Departments"),
                    Tab(text: "Subjects"),
                    Tab(text: "Shifts"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildFilterConfigList('degree', degrees),
                      _buildFilterConfigList('section', sections),
                      _buildFilterConfigList('semester', semesters),
                      _buildFilterConfigList('department', departments),
                      _buildFilterConfigList('subject', subjects),
                      _buildFilterConfigList('shift', shifts),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterConfigList(String filterType, List<String> items) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: items.where((i) => i != 'All').length,
            itemBuilder: (context, index) {
              final item = items.where((i) => i != 'All').toList()[index];
              return ListTile(
                title: Text(item),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteFilterOption(filterType, item),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddFilterDialog(filterType),
            icon: const Icon(Icons.add),
            label: const Text("Add New"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
          ),
        ),
      ],
    );
  }

  void _showAddFilterDialog(String filterType) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New ${filterType.capitalize()}"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: filterType.capitalize(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              
              try {
                final response = await http.post(
                  Uri.parse(ApiConfig.addFilterOption),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'filter_type': filterType,
                    'filter_value': controller.text,
                  }),
                );

                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _showSnackBar('Filter option added successfully!', Colors.green);
                  _loadFilterOptions();
                } else {
                  _showSnackBar('Failed to add filter option', Colors.red);
                }
              } catch (e) {
                _showSnackBar('Error: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFilterOption(String filterType, String value) async {
    try {
      final response = await http.post(
         Uri.parse(ApiConfig.deleteFilterOption),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'filter_type': filterType,
          'filter_value': value,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Filter option deleted successfully!', Colors.green);
        _loadFilterOptions();
      } else {
        _showSnackBar('Failed to delete filter option', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}