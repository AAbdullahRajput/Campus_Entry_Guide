import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class Announcement {
  final int id;
  String title;
  String description;
  String category;
  String targetRole;
  String? imageUrl;
  final DateTime createdAt;
  DateTime? updatedAt;
  int isActive;
  final String createdBy;
  final String? adminProfileImage;
  final int createdById;
  

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetRole,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    required this.isActive,
    required this.createdBy,
    this.adminProfileImage,
    required this.createdById,  // ← ADD THIS LINE
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      targetRole: json['target_role'] ?? 'all',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isActive: json['is_active'] ?? 1,
      createdBy: json['created_by_name'] ?? 'Unknown Admin',
      adminProfileImage: json['admin_profile_image'],
      createdById: (json['created_by'] is int) ? json['created_by'] : 0,
    );
  }
}

class AnnouncementsManagementPage extends StatefulWidget {
  final int adminId;
  final String adminName;

  const AnnouncementsManagementPage({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<AnnouncementsManagementPage> createState() => _AnnouncementsManagementPageState();
}

class _AnnouncementsManagementPageState extends State<AnnouncementsManagementPage> {
  List<Announcement> announcements = [];
  bool isLoading = true;
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String selectedTarget = 'All';
  String selectedOwnership = 'All'; 
  final ImagePicker _imagePicker = ImagePicker();

  final String baseUrl = 'http://192.168.100.63:3000';

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
  try {
    print('🔄 Fetching announcements for admin ID: ${widget.adminId}');
    print('🔄 Admin Name: ${widget.adminName}');
    
   final response = await http.post(
  Uri.parse('$baseUrl/get-all-announcements'),  // 👈 Shows all announcements
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({}),  // No filter
).timeout(const Duration(seconds: 10));

    print('📡 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // 🔍 DEBUG PRINTS
      print('📥 Received ${data['announcements'].length} announcements');
      if (data['announcements'].isNotEmpty) {
        var firstAnn = data['announcements'][0];
        print('✅ First announcement check:');
        print('   - ID: ${firstAnn['id']}');
        print('   - Title: ${firstAnn['title']}');
        print('   - Created by ID: ${firstAnn['created_by']}');
        print('   - Created by name: ${firstAnn['created_by_name']}');
        print('   - Current admin ID: ${widget.adminId}');
        print('   - Can edit/delete: ${firstAnn['created_by'] == widget.adminId}');
      }
      
      setState(() {
        announcements = (data['announcements'] as List)
            .map((a) => Announcement.fromJson(a))
            .toList();
        isLoading = false;
      });
      } else {
        _showError('Failed to fetch announcements');
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() => isLoading = false);
    }
  }

  List<Announcement> get filteredAnnouncements {
    return announcements.where((ann) {
      final matchesCategory = selectedCategory == 'All' || ann.category.toLowerCase() == selectedCategory.toLowerCase();
      final matchesStatus = selectedStatus == 'All' ||
          (selectedStatus == 'Active' && ann.isActive == 1) ||
          (selectedStatus == 'Inactive' && ann.isActive == 0);
          final matchesOwnership = selectedOwnership == 'All' ||
          (selectedOwnership == 'My Posts' && ann.createdById == widget.adminId) ||
          (selectedOwnership == 'Others' && ann.createdById != widget.adminId);
      
      String annRole = ann.targetRole.toLowerCase();
      String selectedRoleLower = selectedTarget.toLowerCase();
      
      final matchesTarget = selectedTarget == 'All' || 
          annRole == 'all' ||
          annRole == selectedRoleLower ||
          (selectedRoleLower == 'students' && annRole == 'students') ||
          (selectedRoleLower == 'teachers' && annRole == 'teachers');
      
      return matchesCategory && matchesStatus && matchesTarget && matchesOwnership;
    }).toList();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'event':
        return Colors.amber;
      case 'academic':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return Icons.school;
      case 'event':
        return Icons.event;
      case 'emergency':
        return Icons.warning;
      default:
        return Icons.campaign;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      _showError('Failed to process image: $e');
      return null;
    }
  }

  // ✅ NEW METHOD: Build Profile Avatar with actual image or default icon
  Widget _buildProfileAvatar(Announcement announcement, {double radius = 20}) {
  // 🔍 DEBUG
  print('🖼️ Building avatar for: ${announcement.createdBy}');
  print('   Has image: ${announcement.adminProfileImage != null}');
  
  if (announcement.adminProfileImage != null && announcement.adminProfileImage!.isNotEmpty) {
    print('   ✅ Showing actual profile image');
      // Show actual profile image
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(
            base64Decode(announcement.adminProfileImage!),
          ),
          backgroundColor: Colors.grey.shade200,
        );
      } catch (e) {
        // If image fails to decode, show default
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF11998e),
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: radius * 1.2,
          ),
        );
      }
    } else {
      // Show default person icon
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF11998e),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: radius * 1.2,
        ),
      );
    }
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'General';
    String selectedTarget = 'All';
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create Announcement',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Post a new announcement',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: Colors.grey.shade600,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Title Field
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 2)),
                    ),
                    child: TextField(
                      controller: titleController,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Announcement Title',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        prefixIcon: Icon(Icons.title_rounded, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description Field
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: descriptionController,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'Write your announcement details here...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                        prefixIcon: Icon(Icons.description_rounded, color: Colors.grey.shade600),
                        prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category and Target Row
                  StatefulBuilder(
                    builder: (context, setStateDialog) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButton<String>(
                                    value: selectedCategory,
                                    isExpanded: true,
                                    underline: Container(),
                                    icon: Icon(Icons.category_rounded, color: Colors.grey.shade600, size: 20),
                                    items: ['General', 'Academic', 'Event', 'Emergency']
                                        .map((cat) => DropdownMenuItem(
                                              value: cat,
                                              child: Text(cat),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setStateDialog(() => selectedCategory = value ?? 'General');
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButton<String>(
                                    value: selectedTarget,
                                    isExpanded: true,
                                    underline: Container(),
                                    icon: Icon(Icons.people_rounded, color: Colors.grey.shade600, size: 20),
                                    items: ['All', 'Students', 'Teachers']
                                        .map((target) => DropdownMenuItem(
                                              value: target,
                                              child: Text(target),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setStateDialog(() => selectedTarget = value ?? 'All');
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Image Upload Section
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            children: [
                              if (selectedImage != null)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      child: Image.file(
                                        selectedImage!,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => setStateDialog(() => selectedImage = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withOpacity(0.3),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.image_rounded,
                                      size: 40,
                                      color: const Color(0xFF11998e),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
                                        if (image != null) {
                                          setStateDialog(() => selectedImage = File(image.path));
                                        }
                                      },
                                      icon: const Icon(Icons.add_photo_alternate_rounded),
                                      label: const Text('Add Image to Announcement'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF11998e),
                                      ),
                                    ),
                                    Text(
                                      'Optional • JPG, PNG up to 5MB',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
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
                  const SizedBox(height: 24),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
                              _showError('Please fill all required fields');
                              return;
                            }

                            String? imageBase64;
                            if (selectedImage != null) {
                              imageBase64 = await _convertImageToBase64(selectedImage!);
                            }

                            try {
                              print('📤 Creating announcement...');
                              print('Admin Name: ${widget.adminName}');
                              print('Admin ID: ${widget.adminId}');
                              
                              final response = await http.post(
                                Uri.parse('$baseUrl/create-announcement'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'title': titleController.text,
                                  'description': descriptionController.text,
                                  'category': selectedCategory.toLowerCase(),
                                  'target_role': selectedTarget.toLowerCase(),
                                  'image_url': imageBase64,
                                  'created_by': widget.adminId,
                                }),
                              ).timeout(const Duration(seconds: 10));

                              print('Response: ${response.statusCode}');
                              print('Body: ${response.body}');

                              if (response.statusCode == 201) {
                                Navigator.pop(context);
                                _fetchAnnouncements();
                                _showSuccess('Announcement published successfully!');
                                Navigator.pop(context, true);
                              } else {
                                _showError('Failed to create announcement');
                              }
                            } catch (e) {
                              print('❌ Error: $e');
                              _showError('Error: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF11998e),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Publish',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Announcement announcement) {
    final titleController = TextEditingController(text: announcement.title);
    final descriptionController = TextEditingController(text: announcement.description);
    String selectedCategory = announcement.category[0].toUpperCase() + announcement.category.substring(1);
    String selectedTarget = announcement.targetRole == 'all' ? 'All' : 
                           announcement.targetRole == 'students' ? 'Students' : 'Teachers';
    int isActive = announcement.isActive;
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Announcement',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Update announcement details',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: Colors.grey.shade600,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Title Field
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 2)),
                    ),
                    child: TextField(
                      controller: titleController,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Announcement Title',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        prefixIcon: Icon(Icons.title_rounded, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description Field
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: descriptionController,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'Announcement details...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                        prefixIcon: Icon(Icons.description_rounded, color: Colors.grey.shade600),
                        prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category, Target, and Status
                  StatefulBuilder(
                    builder: (context, setStateDialog) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButton<String>(
                                    value: selectedCategory,
                                    isExpanded: true,
                                    underline: Container(),
                                    icon: Icon(Icons.category_rounded, color: Colors.grey.shade600, size: 20),
                                    items: ['General', 'Academic', 'Event', 'Emergency']
                                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                        .toList(),
                                    onChanged: (value) {
                                      setStateDialog(() => selectedCategory = value ?? 'General');
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButton<String>(
                                    value: selectedTarget,
                                    isExpanded: true,
                                    underline: Container(),
                                    icon: Icon(Icons.people_rounded, color: Colors.grey.shade600, size: 20),
                                    items: ['All', 'Students', 'Teachers']
                                        .map((target) => DropdownMenuItem(value: target, child: Text(target)))
                                        .toList(),
                                    onChanged: (value) {
                                      setStateDialog(() => selectedTarget = value ?? 'All');
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<int>(
                              value: isActive,
                              isExpanded: true,
                              underline: Container(),
                              icon: Icon(Icons.check_circle_rounded, color: Colors.grey.shade600, size: 20),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Active')),
                                DropdownMenuItem(value: 0, child: Text('Inactive')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() => isActive = value ?? 1);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Image Upload Section
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            children: [
                              if (selectedImage != null)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      child: Image.file(
                                        selectedImage!,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => setStateDialog(() => selectedImage = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8)],
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (announcement.imageUrl != null && selectedImage == null)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      child: Image.memory(
                                        base64Decode(announcement.imageUrl!),
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Current',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(Icons.image_rounded, size: 40, color: const Color(0xFF11998e)),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
                                        if (image != null) {
                                          setStateDialog(() => selectedImage = File(image.path));
                                        }
                                      },
                                      icon: const Icon(Icons.add_photo_alternate_rounded),
                                      label: const Text('Change Image'),
                                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF11998e)),
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
                  const SizedBox(height: 24),
                  // ActionContinue10:33 AMButtons
Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: () => Navigator.pop(context),
style: OutlinedButton.styleFrom(
side: const BorderSide(color: Colors.grey, width: 1.5),
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
child: const Text(
'Cancel',
style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
overflow: TextOverflow.ellipsis,
),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton(
onPressed: () async {
String? imageBase64 = announcement.imageUrl;
if (selectedImage != null) {
imageBase64 = await _convertImageToBase64(selectedImage!);
}
                        try {
                          final response = await http.post(
                            Uri.parse('$baseUrl/update-announcement'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'id': announcement.id,
                              'title': titleController.text,
                              'description': descriptionController.text,
                              'category': selectedCategory.toLowerCase(),
                              'target_role': selectedTarget.toLowerCase(),
                              'image_url': imageBase64,
                              'is_active': isActive,
                            }),
                          ).timeout(const Duration(seconds: 10));

                          if (response.statusCode == 200) {
                            Navigator.pop(context);
                            _fetchAnnouncements();
                            _showSuccess('Announcement updated successfully!');
                          } else {
                            _showError('Failed to update announcement');
                          }
                        } catch (e) {
                          _showError('Error: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11998e),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Update',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
void _deleteAnnouncement(Announcement announcement) {
showDialog(
context: context,
builder: (context) => Dialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
elevation: 20,
child: Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
color: Colors.white,
),
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.red.withOpacity(0.1),
shape: BoxShape.circle,
),
child: const Icon(
Icons.warning_rounded,
color: Colors.red,
size: 48,
),
),
const SizedBox(height: 20),
const Text(
'Delete Announcement',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: Colors.black,
),
),
const SizedBox(height: 12),
Text(
'Are you sure you want to delete "${announcement.title}"? This action cannot be undone.',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade600,
height: 1.5,
),
),
const SizedBox(height: 24),
Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: () => Navigator.pop(context),
style: OutlinedButton.styleFrom(
side: BorderSide(color: Colors.grey.shade300, width: 1.5),
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
),
child: const Text(
'Cancel',
style: TextStyle(
fontWeight: FontWeight.w600,
fontSize: 14,
color: Colors.black87,
),
),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton(
onPressed: () async {
try {
final response = await http.post(
Uri.parse('$baseUrl/delete-announcement'),
headers: {'Content-Type': 'application/json'},
body: jsonEncode({'id': announcement.id}),
).timeout(const Duration(seconds: 10));
if (response.statusCode == 200) {
Navigator.pop(context);
_fetchAnnouncements();
_showSuccess('Announcement deleted successfully');
} else {
_showError('Failed to delete announcement');
}
} catch (e) {
_showError('Error: $e');
}
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
elevation: 0,
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.delete_rounded, size: 18, color: Colors.white),
SizedBox(width: 6),
Text(
'Delete',
style: TextStyle(
fontWeight: FontWeight.w600,
fontSize: 14,
color: Colors.white,
),
),
],
),
),
),
],
),
],
),
),
),
),
);
}
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF5F7FB),
appBar: AppBar(
title: const Text('Announcements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
centerTitle: true,
elevation: 0,
backgroundColor: const Color(0xFF11998e),
leading: IconButton(
icon: const Icon(Icons.arrow_back, color: Colors.white),
onPressed: () => Navigator.pop(context),
),
),
body: isLoading
? const Center(child: CircularProgressIndicator())
: Column(
children: [
// Beautiful Filters Section
Container(
decoration: BoxDecoration(
color: Colors.white,
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.05),
blurRadius: 10,
offset: const Offset(0, 2),
),
],
),
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  const Text(
    'Filter Announcements',
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.grey,
    ),
  ),
  const SizedBox(height: 12),
  
  // First Row: Category and Status
  Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Category',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedCategory,
                  underline: Container(),
                  icon: const Icon(Icons.category, color: Color(0xFF11998e), size: 18),
                  onChanged: (value) => setState(() => selectedCategory = value ?? 'All'),
                  items: ['All', 'General', 'Academic', 'Event', 'Emergency']
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Status',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedStatus,
                  underline: Container(),
                  icon: const Icon(Icons.check_circle, color: Color(0xFF11998e), size: 18),
                  onChanged: (value) => setState(() => selectedStatus = value ?? 'All'),
                  items: ['All', 'Active', 'Inactive']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
  const SizedBox(height: 10),
  
  // Second Row: Target and Ownership
  Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Target',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedTarget,
                  underline: Container(),
                  icon: const Icon(Icons.people, color: Color(0xFF11998e), size: 18),
                  onChanged: (value) => setState(() => selectedTarget = value ?? 'All'),
                  items: ['All', 'Students', 'Teachers']
                      .map((target) => DropdownMenuItem(
                            value: target,
                            child: Text(
                              target,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'My Announcements',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedOwnership,
                  underline: Container(),
                  icon: const Icon(Icons.filter_alt, color: Color(0xFF11998e), size: 18),
                  onChanged: (value) => setState(() => selectedOwnership = value ?? 'All'),
                  items: ['All', 'My Posts', 'Others']
                      .map((ownership) => DropdownMenuItem(
                            value: ownership,
                            child: Text(
                              ownership,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                ),
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
child: filteredAnnouncements.isEmpty
? Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.campaign, size: 64, color: Colors.grey.shade300),
const SizedBox(height: 16),
Text(
'No announcements found',
style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
),
],
),
)
: ListView.builder(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
itemCount: filteredAnnouncements.length,
itemBuilder: (context, index) {
final announcement = filteredAnnouncements[index];
final categoryColor = _getCategoryColor(announcement.category);
final isInactive = announcement.isActive == 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isInactive ? Colors.grey.shade100 : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: isInactive ? Border.all(color: Colors.grey.shade300, width: 1) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Admin Header Section
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // ✅ UPDATED: Admin Avatar with actual profile picture
                                          _buildProfileAvatar(announcement, radius: 20),
                                          const SizedBox(width: 12),
                                          // Admin Name and Date
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  announcement.createdBy,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatDateTime(announcement.createdAt),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Menu Button
                                    // Menu Button - Only show for own announcements
if (announcement.createdById == widget.adminId)
  PopupMenuButton<String>(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 8,
    icon: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isInactive ? Colors.grey.shade200 : const Color(0xFF11998e).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.more_vert,
        color: isInactive ? Colors.grey.shade400 : const Color(0xFF11998e),
        size: 20,
      ),
    ),
    itemBuilder: (context) => <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'edit',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF11998e).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit_rounded, 
                size: 18, 
                color: Color(0xFF11998e),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Edit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_rounded, 
                size: 18, 
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete', 
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
    onSelected: (value) {
      if (value == 'edit') {
        _showEditDialog(announcement);
      } else if (value == 'delete') {
        _deleteAnnouncement(announcement);
      }
    },
  ),
                                  ],
                                ),
                              ),
                              // Divider
                              Divider(height: 1, color: Colors.grey.shade200),
                              // Image with Category Badge
                              if (announcement.imageUrl != null)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(0),
                                        topRight: Radius.circular(0),
                                        bottomLeft: Radius.circular(0),
                                        bottomRight: Radius.circular(0),
                                      ),
                                      child: Image.memory(
                                        base64Decode(announcement.imageUrl!),
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // Category Badge (Top Left)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: categoryColor,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: categoryColor.withOpacity(0.3),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getCategoryIcon(announcement.category),
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              announcement.category,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      announcement.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isInactive ? Colors.grey.shade600 : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      announcement.description,
                                      style: TextStyle(
                                        color: isInactive ? Colors.grey.shade500 : Colors.grey.shade700,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
  floatingActionButton: FloatingActionButton(
    onPressed: _showCreateDialog,
    backgroundColor: const Color(0xFF11998e),
    elevation: 8,
    child: const Icon(Icons.add, color: Colors.white, size: 28),
  ),
);
}
}