import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _commentController = TextEditingController();

  int? userId;
  String? userName, userEmail, userPhone, userRole, userDegree, userSection;
  String selectedCategory = '';
  String selectedLocation = '';
  String selectedPriority = 'Medium';
  File? _image;
  final ImagePicker _picker = ImagePicker();

  String searchQuery = '';
  String filterStatus = 'all';
  String _currentTab = 'own'; // 'own' or 'all'
  List<String> categories = [
    'Room/Facility Issues (AC, Lights, Furniture)',
    'Cleanliness Issues',
    'Safety Concerns',
    'Equipment/Lab Issues',
    'Other'
  ];
  List<String> locations = [
    'Library - 1st Floor',
    'Library - 2nd Floor',
    'Library - 3rd Floor',
    'Cafeteria - Main',
    'Cafeteria - Mini',
    'Parking Lot A',
    'Parking Lot B',
    'Classroom Building',
    'Lab Building',
    'Sports Complex',
    'Other'
  ];
  List<String> priorities = ['Low', 'Medium', 'High'];
  List<Map<String, dynamic>> complaints = [], currentComments = [];
  bool isLoading = false;
  int? expandedComplaintId;

  @override
  void initState() {
    super.initState();
    // Set default values
    selectedCategory = categories[0];
    selectedLocation = locations[0];
    
    _loadUserData();
    _loadOptions();
    _loadComplaints();
  }

Future<void> _loadUserData() async {
  print('🔄 Loading user data from SharedPreferences...');
  final prefs = await SharedPreferences.getInstance();
  
  final loadedUserId = prefs.getInt('userId');
  final loadedUserName = prefs.getString('full_name');
  final loadedUserRole = prefs.getString('role');
  final loadedUserDegree = prefs.getString('degree');
  final loadedUserSection = prefs.getString('section');
  final loadedUserEmail = prefs.getString('email');
  final loadedUserPhone = prefs.getString('phone_number');
  
  print('📋 Loaded user data:');
  print('   userId: $loadedUserId');
  print('   userName: $loadedUserName');
  print('   userRole: $loadedUserRole');
  print('   userDegree: $loadedUserDegree');
  print('   userSection: $loadedUserSection');
  print('   userEmail: $loadedUserEmail');
  print('   userPhone: $loadedUserPhone');
  
  setState(() {
    userId = loadedUserId;
    userName = loadedUserName;
    userEmail = loadedUserEmail;
    userPhone = loadedUserPhone;
    userRole = loadedUserRole;
    userDegree = loadedUserDegree;
    userSection = loadedUserSection;
  });
  
  print('✅ User data loaded into state');
  
  // ✅ FIX: Load complaints AFTER user data is loaded
  if (userId != null && userRole != null) {
    print('✅ User data valid, calling _loadComplaints');
    await _loadComplaints();
  } else {
    print('❌ User data invalid, cannot load complaints');
  }
}

Future<void> _markAllComplaintsAsViewed() async {
  try {
    final session = await LocalStorage.getUserSession();
    if (session == null) return;
    
    final response = await http.post(
      Uri.parse('http://192.168.100.63:3000/mark-all-complaints-viewed'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': session['userId'],
        'userRole': session['role'],
      }),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      print('✅ All complaints marked as viewed');
    }
  } catch (e) {
    print('❌ Error marking complaints as viewed: $e');
  }
}

  Future<void> _loadOptions() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.100.63:3000/get-complaint-options'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Options loaded successfully');
        setState(() {
          // Only update if data exists and is not empty
          if ((data['categories'] as List?)?.isNotEmpty ?? false) {
            categories = List<String>.from(data['categories']);
            selectedCategory = categories[0];
          }
          if ((data['locations'] as List?)?.isNotEmpty ?? false) {
            locations = List<String>.from(data['locations']);
            selectedLocation = locations[0];
          }
          if ((data['priorities'] as List?)?.isNotEmpty ?? false) {
            priorities = List<String>.from(data['priorities']);
          }
        });
      } else {
        print('⚠️ Backend options endpoint returned ${response.statusCode}. Using defaults.');
      }
    } catch (e) {
      print('⚠️ Could not load options from backend: $e. Using defaults.');
      // Silently use defaults - don't show error to user
    }
  }

Future<void> _loadComplaints() async {
  print('🔄 _loadComplaints called');
  print('   userId: $userId');
  print('   userRole: $userRole');
  print('   filterStatus: $filterStatus');
  print('   searchQuery: $searchQuery');
  
  if (userId == null || userRole == null) {
    print('❌ userId or userRole is null, skipping load');
    return;
  }
  
  setState(() => isLoading = true);

  try {
    final requestBody = {
      'userId': userId,
      'userRole': userRole,
      'searchQuery': searchQuery.isNotEmpty ? searchQuery : null,
      'status': filterStatus != 'all' ? filterStatus : null,
    };
    
    print('📤 Sending request with body: $requestBody');
    
    final response = await http.post(
      Uri.parse('http://192.168.100.63:3000/get-user-complaints'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Decoded data - complaints count: ${data['complaints']?.length ?? 0}');
      
      setState(() {
        complaints = List<Map<String, dynamic>>.from(data['complaints']);
      });
      
      print('📋 Loaded ${complaints.length} complaints into state');
      
      if (complaints.isNotEmpty) {
        print('📋 First complaint data:');
        print('   ID: ${complaints[0]['id']}');
        print('   Name: ${complaints[0]['reported_by_name']}');
        print('   Degree: ${complaints[0]['reported_by_degree']}');
        print('   Section: ${complaints[0]['reported_by_section']}');
        print('   Status: ${complaints[0]['status']}');
        print('   isOwnComplaint: ${complaints[0]['isOwnComplaint']}');
      }
    } else {
      print('❌ Failed with status: ${response.statusCode}');
      _showSnack('Failed to load complaints: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error loading complaints: $e');
    print('❌ Stack trace: ${StackTrace.current}');
    _showSnack('Error: $e');
  } finally {
    setState(() => isLoading = false);
    print('🏁 _loadComplaints finished, isLoading now false');
  }
}

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<String?> _imageToBase64(File? image) async {
    if (image == null) return null;
    return base64Encode(await image.readAsBytes());
  }

Future<void> _submitComplaint() async {
  if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
    _showSnack('Please fill in all required fields');
    return;
  }

  // ✅ ADD DEBUG LOGGING
  print('📝 Submitting complaint with user data:');
  print('   userId: $userId');
  print('   userName: $userName');
  print('   userRole: $userRole');
  print('   userDegree: $userDegree');
  print('   userSection: $userSection');
  print('   userEmail: $userEmail');

  setState(() => isLoading = true);

  try {
    final imageBase64 = await _imageToBase64(_image);
    
    // ✅ Build request body with proper handling
    final requestBody = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'category': selectedCategory,
      'location': selectedLocation,
      'priority': selectedPriority,
      'image': imageBase64,
      'reported_by_id': userId,
      'reported_by_name': userName,
      'reported_by_email': userEmail,
      'reported_by_phone': userPhone,
      'reported_by_role': userRole,
      'reported_by_degree': userDegree,
      'reported_by_section': userSection,
      'reported_by_department': userRole == 'Student' ? userDegree : (userDegree ?? 'Not Specified'),
    };
    
    print('📤 Request body: ${json.encode(requestBody)}');
    
    final response = await http.post(
      Uri.parse('http://192.168.100.63:3000/create-complaint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    if (response.statusCode == 201) {
      _showSnack('Complaint submitted successfully! ✅');
      _clearForm();
      _loadComplaints();
    } else {
      final data = json.decode(response.body);
      _showSnack(data['message'] ?? 'Failed');
    }
  } catch (e) {
    print('❌ Error submitting complaint: $e');
    _showSnack('Error: $e');
  } finally {
    setState(() => isLoading = false);
  }
}

  Future<void> _updateComplaint(int complaintId) async {
    if (_titleController.text.isEmpty) {
      _showSnack('Please fill required fields');
      return;
    }

    setState(() => isLoading = true);

    try {
      final imageBase64 = await _imageToBase64(_image);
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/update-complaint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'complaintId': complaintId,
          'userId': userId,
          'userRole': userRole,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'category': selectedCategory,
          'location': selectedLocation,
          'priority': selectedPriority,
          'image': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Updated successfully! ✅');
        _clearForm();
        _loadComplaints();
      } else {
        _showSnack('Failed to update');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteComplaint(int complaintId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Complaint?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/delete-complaint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'complaintId': complaintId,
          'userId': userId,
          'userRole': userRole,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Deleted successfully');
        _loadComplaints();
      } else {
        _showSnack('Failed to delete');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _verifyComplaint(int complaintId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Resolution'),
        content: const Text(
          'Is the issue actually resolved?\n\nAfter verification, admin can delete. You cannot delete after verification.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Allow Delete'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/verify-complaint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'complaintId': complaintId,
          'userId': userId,
          'userRole': userRole,
          'allowAdminDelete': result,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Verified! ✅');
        _loadComplaints();
      } else {
        _showSnack('Failed');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadComments(int complaintId) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-complaint-comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'complaintId': complaintId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentComments = List<Map<String, dynamic>>.from(data['comments']);
        });
      }
    } catch (e) {
      _showSnack('Failed to load comments: $e');
    }
  }

  Future<void> _addComment(int complaintId) async {
  if (_commentController.text.isEmpty) {
    _showSnack('Enter a comment');
    return;
  }

  print('📝 Adding comment for complaint $complaintId');
  print('   User: $userName ($userRole)');
  print('   Comment: ${_commentController.text}');

  try {
    final response = await http.post(
      Uri.parse('http://192.168.100.63:3000/add-complaint-comment'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'complaintId': complaintId,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'comment': _commentController.text,
      }),
    );

    print('📝 Response status: ${response.statusCode}');
    print('📝 Response body: ${response.body}');

    if (response.statusCode == 201) {
      print('✅ Comment added successfully');
      _commentController.clear();
      await _loadComments(complaintId); // Reload comments
      setState(() {}); // Force rebuild
    } else {
      print('❌ Failed to add comment: ${response.statusCode}');
      print('   Response: ${response.body}');
      _showSnack('Failed to add comment');
    }
  } catch (e) {
    print('❌ Error adding comment: $e');
    _showSnack('Error: $e');
  }
}

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _image = null;
      selectedPriority = 'Medium';
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Widget _highlightSearchText(String text) {
    if (searchQuery.isEmpty) {
      return Text(text);
    }

    final query = searchQuery.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(query);

    if (index == -1) {
      return Text(text);
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, index),
            style: const TextStyle(color: Colors.black87),
          ),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xFFFF512F),
            ),
          ),
          TextSpan(
            text: text.substring(index + query.length),
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }

String _formatDateTime(dynamic dateTime) {
  if (dateTime == null) return 'Unknown';
  
  try {
    DateTime dt;
    if (dateTime is String) {
      dt = DateTime.parse(dateTime);
    } else {
      return 'Unknown';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  } catch (e) {
    return 'Unknown';
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Complaints', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
          ),
        ),
      ),
      body: isLoading && complaints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubmitSection(),
                  const SizedBox(height: 25),
                  _buildSearchSection(),
                  const SizedBox(height: 15),
                  _buildTabSection(),
                  const SizedBox(height: 15),
                  _buildFilterSection(),
                  const SizedBox(height: 15),
                  _buildComplaintsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSubmitSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 File a Complaint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField('Title*', _titleController),
            const SizedBox(height: 12),
            _buildTextField('Description*', _descriptionController, maxLines: 3),
            const SizedBox(height: 12),
            _buildDropdown('Category*', selectedCategory, categories, (val) {
              if (val != null) {
                setState(() => selectedCategory = val);
              }
            }),
            const SizedBox(height: 12),
            _buildDropdown('Location*', selectedLocation, locations, (val) {
              if (val != null) {
                setState(() => selectedLocation = val);
              }
            }),
            const SizedBox(height: 12),
            _buildDropdown('Priority', selectedPriority, priorities, (val) {
              if (val != null) {
                setState(() => selectedPriority = val);
              }
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, color: Colors.red),
                    label: Text(_image == null ? 'Upload Image' : 'Image ✓', style: const TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ],
            ),
            if (_image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_image!, height: 100, fit: BoxFit.cover)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF512F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Submit Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() => searchQuery = val);
        _loadComplaints();
      },
      decoration: InputDecoration(
        hintText: 'Search by title, description...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => searchQuery = '');
                  _loadComplaints();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

Widget _buildTabSection() {
  final ownCount = complaints.where((c) => c['isOwnComplaint'] == true).length;
  final allCount = complaints.length;

  return Container(
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
    child: Row(
      children: [
        _buildTabButton('My Complaints', 'own', ownCount),
        _buildTabButton('All Complaints', 'all', allCount),
      ],
    ),
  );
}

Widget _buildTabButton(String label, String value, int count) {
  final isActive = _currentTab == value;
  return Expanded(
    child: InkWell(
      onTap: () {
        setState(() => _currentTab = value);
        // ✅ ADD THIS: Mark as viewed when switching to "All Complaints"
        if (value == 'all') {
          _markAllComplaintsAsViewed();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFFF512F) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFFF512F) : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFF512F).withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFFFF512F) : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Pending', 'pending'),
          _buildFilterChip('Working', 'in_progress'),
          _buildFilterChip('Resolved', 'resolved'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => filterStatus = isSelected ? 'all' : value);
          _loadComplaints();
        },
        selectedColor: const Color(0xFFFF512F).withOpacity(0.3),
        checkmarkColor: const Color(0xFFFF512F),
      ),
    );
  }

Widget _buildComplaintsList() {
  // ✅ DEBUG: Check what data we have
  print('🔍 _buildComplaintsList called');
  print('   Total complaints: ${complaints.length}');
  print('   Current tab: $_currentTab');
  print('   Filter status: $filterStatus');
  
  List<Map<String, dynamic>> filteredComplaints = complaints;
  
  if (_currentTab == 'own') {
    filteredComplaints = complaints.where((c) => 
      (c['isOwnComplaint'] == true || c['isOwnComplaint'] == 1)
    ).toList();
  }

  print('   Filtered complaints: ${filteredComplaints.length}');
  
  // Rest of your existing code...

    if (filteredComplaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No complaints found.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredComplaints.length,
      itemBuilder: (context, index) => _buildComplaintCard(filteredComplaints[index]),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    // Handle type conversions for boolean fields
    final isOwn = (complaint['isOwnComplaint'] == true || complaint['isOwnComplaint'] == 1) ?? false;
    final canEdit = (complaint['canEdit'] == true || complaint['canEdit'] == 1) ?? false;
    final canDelete = (complaint['canDelete'] == true || complaint['canDelete'] == 1) ?? false;
    final isResolved = complaint['status'] == 'resolved';
    final isVerified = (complaint['verified_by_reporter'] == true || complaint['verified_by_reporter'] == 1) ?? false;
    final isExpanded = expandedComplaintId == complaint['id'];

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF512F).withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlightSearchText(complaint['title'] ?? ''),
                          const SizedBox(height: 4),
                          Text(complaint['category'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: complaint['status'] == 'pending'
                            ? Colors.orange
                            : complaint['status'] == 'in_progress'
                                ? Colors.blue
                                : Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        complaint['status'] == 'pending' ? '⏳ Pending' : complaint['status'] == 'in_progress' ? '🔧 Working' : '✅ Resolved',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(complaint['location'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(width: 16),
                    Icon(Icons.flag, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(complaint['priority'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
  padding: const EdgeInsets.all(12),
  child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        complaint['reported_by_name'] ?? 'Anonymous',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ✅ ROLE BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: complaint['reported_by_role'] == 'Student' 
                              ? Colors.blue.shade100 
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          complaint['reported_by_role'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: complaint['reported_by_role'] == 'Student' 
                                ? Colors.blue.shade700 
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ✅ SHOW DEGREE + SECTION FOR STUDENTS, DEPARTMENT FOR TEACHERS
                  if (complaint['reported_by_role'] == 'Student') ...[
                    if (complaint['reported_by_degree'] != null || complaint['reported_by_section'] != null)
                      Text(
                        '${complaint['reported_by_degree'] ?? 'N/A'} - ${complaint['reported_by_section'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ] else if (complaint['reported_by_role'] == 'Teacher') ...[
                    if (complaint['reported_by_department'] != null)
                      Text(
                        complaint['reported_by_department'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      Text(
                        'Teacher',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                  if (complaint['reported_by_email'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      complaint['reported_by_email'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              _formatDateTime(complaint['created_at']),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    ),
  ),
),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _highlightSearchText(complaint['description'] ?? ''),
          ),
          if (complaint['image'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(base64Decode(complaint['image']), height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          if (complaint['admin_response'] != null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🔧 Admin Response',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (complaint['admin_started_at'] != null)
                Text(
                  _formatDateTime(complaint['admin_started_at']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            complaint['admin_response'],
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
          ),
        ],
      ),
    ),
  ),
if (complaint['status'] == 'resolved' && complaint['resolved_at'] != null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text(
            'Resolved on ${_formatDateTime(complaint['resolved_at'])}',
            style: TextStyle(fontSize: 11, color: Colors.green.shade700),
          ),
        ],
      ),
    ),
  ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    expandedComplaintId = null;
                  } else {
                    expandedComplaintId = complaint['id'];
                    _loadComments(complaint['id']);
                  }
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.comment, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Comments'),
                  const Spacer(),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ...currentComments.map((comment) {
  final isAdmin = (comment['user_role'] ?? '').toString().toLowerCase() == 'admin';
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: isAdmin ? Border.all(color: Colors.blue.shade200) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment['user_name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  comment['user_role'] ?? 'User',
                  style: TextStyle(
                    fontSize: 9,
                    color: isAdmin ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(comment['created_at']),
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment['comment'] ?? '',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    ),
  );
}).toList(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add comment...',
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        onPressed: () => _addComment(complaint['id']),
                        backgroundColor: const Color.fromARGB(255, 212, 90, 66),
                        child: const Icon(Icons.send, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                if (isOwn && canEdit)
                  ElevatedButton.icon(
                    onPressed: () => _editComplaint(complaint),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 207, 222, 235)),
                  ),
                if (isOwn && canDelete)
                  ElevatedButton.icon(
                    onPressed: () => _deleteComplaint(complaint['id']),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 221, 179, 176)),
                  ),
                if (isOwn && isResolved && !isVerified)
                  ElevatedButton.icon(
                    onPressed: () => _verifyComplaint(complaint['id']),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 145, 196, 146)),
                  ),
                if (isVerified)
  Chip(
    avatar: const Icon(Icons.verified, color: Colors.green, size: 18),
    label: const Text('Verified'),
    backgroundColor: Colors.green.shade100,
  ),
// ✅ ADD THIS: Show delete option to admin for verified complaints
if (!isOwn && userRole == 'Admin' && isVerified && (complaint['allow_admin_delete'] == 1 || complaint['allow_admin_delete'] == true))
  ElevatedButton.icon(
    onPressed: () => _deleteComplaint(complaint['id']),
    icon: const Icon(Icons.delete, size: 16),
    label: const Text('Delete'),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    // Ensure value is valid
    String finalValue = (value.isNotEmpty && items.contains(value)) 
        ? value 
        : (items.isNotEmpty ? items[0] : '');
    
    return DropdownButtonFormField<String>(
      value: finalValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Tooltip(
          message: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      )).toList(),
      onChanged: onChanged,
    );
  }

  void _editComplaint(Map<String, dynamic> complaint) {
    _titleController.text = complaint['title'];
    _descriptionController.text = complaint['description'];
    setState(() {
      selectedCategory = complaint['category'];
      selectedLocation = complaint['location'];
      selectedPriority = complaint['priority'];
    });
    _showSnack('Edit above and submit to update');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}