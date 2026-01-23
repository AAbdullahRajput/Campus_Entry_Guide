import 'package:campus_entry_guide/change_password_page.dart';
import 'package:campus_entry_guide/notification_page.dart';
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
    : (_profileData!['degree'] ?? 'Not assigned'); // Show degree for students instead
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

  Widget _buildStatistics(String role) {
    String stat1Title, stat1Value, stat2Title, stat2Value;

    if (role == 'Student') {
      stat1Title = "Attendance";
      stat1Value = "92%";
      stat2Title = "Present Days";
      stat2Value = "87";
    } else if (role == 'Teacher') {
      stat1Title = "Classes Taken";
      stat1Value = "95";
      stat2Title = "Present Rate";
      stat2Value = "98%";
    } else {
      stat1Title = "Users Managed";
      stat1Value = "250+";
      stat2Title = "Tasks Done";
      stat2Value = "156";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role == 'Admin' ? "Administration Statistics" : "Attendance Statistics",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(stat1Title, stat1Value, const Color(0xFF11998e)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(stat2Title, stat2Value, const Color(0xFF38ef7d)),
            ),
          ],
        ),
      ],
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