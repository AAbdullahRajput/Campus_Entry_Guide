import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'teachers_list_page.dart';
import 'students_hierarchy_page.dart';

class AdminMonitoringPage extends StatefulWidget {
  final String adminId;
  final String adminName;

  const AdminMonitoringPage({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  bool isLoading = false;
  Map<String, dynamic> dashboardStats = {};
  List<dynamic> recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      await _loadDashboardStatistics();
      await _loadRecentActivity();
    } catch (e) {
      print("Error loading data: $e");
      _showErrorSnackbar("Failed to load data");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadDashboardStatistics() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminDashboard),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': widget.adminId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          dashboardStats = data['statistics'] ?? {};
        });
      }
    } catch (e) {
      print("Error loading dashboard stats: $e");
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminRecentActivity),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': widget.adminId, 'limit': 20}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          recentActivity = data['activities'] ?? [];
        });
      }
    } catch (e) {
      print("Error loading activity: $e");
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
          "Admin Monitoring",
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Main Statistics Cards
                    const Text(
                      "Overview",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatisticsGrid(),
                    
                    const SizedBox(height: 30),
                    
                    // Quick Actions
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    
                    const SizedBox(height: 30),
                    
                    // Recent Activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Activity",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _navigateToActivityLog(),
                          child: const Text("View All"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRecentActivityList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, ${widget.adminName}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Manage your institution effectively",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    // Parse present_percentage safely
    double presentPercentage = 0.0;
    if (dashboardStats['present_percentage'] != null) {
      if (dashboardStats['present_percentage'] is String) {
        presentPercentage = double.tryParse(dashboardStats['present_percentage']) ?? 0.0;
      } else {
        presentPercentage = (dashboardStats['present_percentage'] as num).toDouble();
      }
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          "Teachers",
          "${dashboardStats['total_teachers'] ?? 0}",
          Icons.people,
          const Color(0xFF667EEA),
        ),
        _buildStatCard(
          "Students",
          "${dashboardStats['total_students'] ?? 0}",
          Icons.school,
          const Color(0xFF43CEA2),
        ),
        _buildStatCard(
          "Total Records",
          "${dashboardStats['total_attendance_records'] ?? 0}",
          Icons.assignment,
          const Color(0xFFFA709A),
        ),
        _buildStatCard(
          "Present Rate",
          "${presentPercentage.toStringAsFixed(1)}%",
          Icons.check_circle,
          const Color(0xFFFEE140),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14), // Reduced from 16
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6), // Reduced from 8
          Flexible( // Wrapped in Flexible
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2), // Reduced from 4
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "View Teachers",
                Icons.people,
                const Color(0xFF667EEA),
                () => _navigateToTeachersList(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                "View Students",
                Icons.school,
                const Color(0xFF43CEA2),
                () => _navigateToStudentsHierarchy(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    if (recentActivity.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                "No recent activity",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentActivity.length > 5 ? 5 : recentActivity.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          final activity = recentActivity[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: _getActivityColor(activity['activity_type']).withOpacity(0.1),
              child: Icon(
                _getActivityIcon(activity['activity_type']),
                color: _getActivityColor(activity['activity_type']),
                size: 18,
              ),
            ),
            title: Text(
              activity['actor'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Text(
              activity['description'] ?? '',
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              _formatTimestamp(activity['timestamp'] ?? ''),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          );
        },
      ),
    );
  }

  // Navigation Methods
  void _navigateToTeachersList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeachersListPage(
          adminId: widget.adminId,
          adminName: widget.adminName,
        ),
      ),
    );
  }

  void _navigateToStudentsHierarchy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentsHierarchyPage(
          adminId: widget.adminId,
          adminName: widget.adminName,
        ),
      ),
    );
  }

  void _navigateToDepartmentStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartmentStatsPage(
          adminId: widget.adminId,
          adminName: widget.adminName,
        ),
      ),
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsPage(
          adminId: widget.adminId,
          adminName: widget.adminName,
        ),
      ),
    );
  }

  void _navigateToActivityLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityLogPage(
          adminId: widget.adminId,
          adminName: widget.adminName,
        ),
      ),
    );
  }

  // Helper Methods
  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'enrollment':
        return Icons.person_add;
      case 'attendance':
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'enrollment':
        return const Color(0xFF43CEA2);
      case 'attendance':
        return const Color(0xFF667EEA);
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp;
    }
  }
}

// Placeholder Pages
class DepartmentStatsPage extends StatelessWidget {
  final String adminId;
  final String adminName;

  const DepartmentStatsPage({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Department Statistics",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
            ),
          ),
        ),
      ),
      body: const Center(
        child: Text("Department Statistics - Coming Soon"),
      ),
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  final String adminId;
  final String adminName;

  const AnalyticsPage({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Analytics",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFEE140), Color(0xFFFA709A)],
            ),
          ),
        ),
      ),
      body: const Center(
        child: Text("Analytics - Coming Soon"),
      ),
    );
  }
}

class ActivityLogPage extends StatelessWidget {
  final String adminId;
  final String adminName;

  const ActivityLogPage({
    super.key,
    required this.adminId,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Activity Log",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
        ),
      ),
      body: const Center(
        child: Text("Activity Log - Coming Soon"),
      ),
    );
  }
}