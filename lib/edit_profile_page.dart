import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'local_storage.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage({super.key, required this.profileData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  String? _base64Image;
  File? _imageFile;
  
  // Common fields
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  
  // Student-specific
  TextEditingController? _aridNoController;
  TextEditingController? _degreeController;
  TextEditingController? _semesterController;
  TextEditingController? _sectionController;
  
  // Teacher-specific
  TextEditingController? _subjectController;
  TextEditingController? _shiftController;
  
  // Admin-specific
  TextEditingController? _adminIdController;
  TextEditingController? _officeController;

  @override
  void initState() {
    super.initState();
    
    // Initialize common controllers
    _fullNameController = TextEditingController(text: widget.profileData['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.profileData['phone_number'] ?? '');
    _departmentController = TextEditingController(text: widget.profileData['department'] ?? '');
    
    // Initialize role-specific controllers
    final role = widget.profileData['role'];
    
    if (role == 'Student') {
      _aridNoController = TextEditingController(text: widget.profileData['arid_no'] ?? '');
      _degreeController = TextEditingController(text: widget.profileData['degree'] ?? '');
      _semesterController = TextEditingController(text: widget.profileData['semester'] ?? '');
      _sectionController = TextEditingController(text: widget.profileData['section'] ?? '');
    } else if (role == 'Teacher') {
      _subjectController = TextEditingController(text: widget.profileData['subject_name'] ?? '');
      _shiftController = TextEditingController(text: widget.profileData['shift'] ?? '');
    } else if (role == 'Admin') {
      _adminIdController = TextEditingController(text: widget.profileData['admin_id'] ?? '');
      _officeController = TextEditingController(text: widget.profileData['office_name'] ?? '');
    }
    
    // Load existing profile image if available
    _base64Image = widget.profileData['profile_image'];
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _aridNoController?.dispose();
    _degreeController?.dispose();
    _semesterController?.dispose();
    _sectionController?.dispose();
    _subjectController?.dispose();
    _shiftController?.dispose();
    _adminIdController?.dispose();
    _officeController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70, // Compress to reduce size
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final fileSize = bytes.length;
        
        // Check file size (limit to 1MB for better performance)
        if (fileSize > 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image too large. Please choose an image under 1MB.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = base64Encode(bytes);
        });

        print("✅ Image selected - Size: ${(fileSize / 1024).toStringAsFixed(2)} KB");
      }
    } catch (e) {
      print("❌ Error picking image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF11998e)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF11998e)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_base64Image != null && _base64Image!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageFile = null;
                    _base64Image = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = await LocalStorage.getUserSession();
      final userId = session['userId'];
      final role = widget.profileData['role'];

      Map<String, dynamic> updateData = {
        'userId': userId,
        'role': role,
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        // 'department': _departmentController.text.trim(),
        'profile_image': _base64Image,
      };

      // Add role-specific data
      if (role == 'Student') {
        updateData['arid_no'] = _aridNoController!.text.trim();
        updateData['degree'] = _degreeController!.text.trim();
        updateData['semester_no'] = _semesterController!.text.trim();
        updateData['section'] = _sectionController!.text.trim();
      } else if (role == 'Teacher') {
        updateData['department'] = _departmentController.text.trim();
        updateData['subject_name'] = _subjectController!.text.trim();
        updateData['shift'] = _shiftController!.text.trim();
      } else if (role == 'Admin') {
        updateData['department'] = _departmentController.text.trim();
        updateData['admin_id'] = _adminIdController!.text.trim();
        updateData['office_name'] = _officeController!.text.trim();
      }

      print("📤 Sending update request: ${updateData.keys}");

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/update-user-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      print("📡 Response Status: ${response.statusCode}");
      print("📡 Response Body: ${response.body}");

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        
        // Update local storage with new name
        await LocalStorage.saveUserSession(
          userId: userId,
          email: widget.profileData['email'],
          role: role,
          fullName: _fullNameController.text.trim(),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Return true to indicate success
        Navigator.pop(context, true);
      } else {
        final errorData = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ Error updating profile: $e");
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profileData['role'];
    
    IconData roleIcon;
    if (role == 'Student') {
      roleIcon = Icons.school;
    } else if (role == 'Teacher') {
      roleIcon = Icons.person;
    } else {
      roleIcon = Icons.admin_panel_settings;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF11998e)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Image Section
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: const Color(0xFF11998e),
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_base64Image != null && _base64Image!.isNotEmpty
                                    ? MemoryImage(base64Decode(_base64Image!))
                                    : null),
                            child: (_imageFile == null && (_base64Image == null || _base64Image!.isEmpty))
                                ? Icon(roleIcon, size: 60, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF11998e),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to change photo',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Common Fields
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.trim().length != 11) {
                          return 'Phone number must be 11 digits';
                        }
                        if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                          return 'Phone number must contain only digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _departmentController,
                      label: 'Department',
                      icon: Icons.apartment,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter department';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email (non-editable)
                    _buildTextField(
                      controller: TextEditingController(text: widget.profileData['email']),
                      label: 'Email',
                      icon: Icons.email,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Role-specific fields
                    if (role == 'Student') ..._buildStudentFields(),
                    if (role == 'Teacher') ..._buildTeacherFields(),
                    if (role == 'Admin') ..._buildAdminFields(),

                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF11998e),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildStudentFields() {
    return [
      _buildTextField(
        controller: _aridNoController!,
        label: 'ARID Number',
        icon: Icons.badge,
        maxLength: 10,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter ARID number';
          }
          if (value.trim().length > 10) {
            return 'ARID number cannot exceed 10 characters';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _degreeController!,
        label: 'Degree',
        icon: Icons.school,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter degree';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _semesterController!,
        label: 'Semester',
        icon: Icons.calendar_today,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter semester';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _sectionController!,
        label: 'Section',
        icon: Icons.class_,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter section';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildTeacherFields() {
    return [
      _buildTextField(
        controller: _subjectController!,
        label: 'Subject',
        icon: Icons.book,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter subject';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _shiftController!,
        label: 'Shift',
        icon: Icons.schedule,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter shift';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildAdminFields() {
    return [
      _buildTextField(
        controller: _adminIdController!,
        label: 'Admin ID',
        icon: Icons.badge,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter admin ID';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _officeController!,
        label: 'Office Name',
        icon: Icons.business,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter office name';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF11998e)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF11998e), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        counterText: '',
      ),
    );
  }
}