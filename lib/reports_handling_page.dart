import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Import your ApiConfig
// import 'api_config.dart';

class ReportsHandlingPage extends StatefulWidget {
  const ReportsHandlingPage({super.key});

  @override
  State<ReportsHandlingPage> createState() => _ReportsHandlingPageState();
}

class _ReportsHandlingPageState extends State<ReportsHandlingPage> {
  String selectedTab = "All";
  bool isLoading = false;

  // ✅ Admin credentials from SharedPreferences
  int? adminId;
  String adminRole = 'Admin';

  List<Map<String, dynamic>> lostFoundReports = [];
 

  @override
  void initState() {
    super.initState();
    _loadAdminCredentials();
    _loadLostFoundReports();
  }

  // ✅ Load admin credentials from SharedPreferences
  Future<void> _loadAdminCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        adminId = prefs.getInt('userId');
        adminRole = prefs.getString('role') ?? 'Admin';
      });
      
      print('✅ Admin credentials loaded:');
      print('   Admin ID: $adminId');
      print('   Admin Role: $adminRole');
      
      if (adminId == null || adminId == 0) {
        _showSnack('Warning: Admin credentials not found');
      }
    } catch (e) {
      print('❌ Error loading admin credentials: $e');
      _showSnack('Failed to load admin credentials');
    }
  }

  Future<void> _loadLostFoundReports() async {
    setState(() => isLoading = true);

    try {
      // Replace with: ApiConfig.getAdminLostFoundReports
      final response = await http.get(
        Uri.parse('http://192.168.100.63:3000/get-admin-lost-found-reports'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          lostFoundReports = List<Map<String, dynamic>>.from(data['reports']);
        });
      }
    } catch (e) {
      _showSnack('Failed to load reports: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteReport(int itemId) async {
    // ✅ Validate admin credentials before deletion
    if (adminId == null || adminId == 0) {
      _showSnack('Error: Invalid admin credentials. Please login again.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text(
            'Are you sure you want to permanently delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
      print('🗑️ Attempting to delete item:');
      print('   Item ID: $itemId');
      print('   Admin ID: $adminId');
      print('   Admin Role: $adminRole');

      // Replace with: ApiConfig.deleteLostFoundItem
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/delete-lost-found-item'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'itemId': itemId,
          'userId': adminId,  // ✅ Now using actual admin ID
          'userRole': adminRole,  // ✅ Using loaded admin role
        }),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        _showSnack('Report deleted successfully');
        await _loadLostFoundReports();
      } else {
        final data = json.decode(response.body);
        _showSnack(data['message'] ?? 'Failed to delete report');
      }
    } catch (e) {
      print('❌ Delete error: $e');
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Reports Handling",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsRow(),
                _buildTabBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _getFilteredReports().length,
                    itemBuilder: (context, index) {
                      return _buildReportCard(_getFilteredReports()[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  List<Map<String, dynamic>> _getFilteredReports() {
    if (selectedTab == "All") {
      return [...lostFoundReports];
    }
    if (selectedTab == "Lost") {
      return lostFoundReports.where((r) => r['type'] == 'lost').toList();
    }
    if (selectedTab == "Found") {
      return lostFoundReports.where((r) => r['type'] == 'found').toList();
    }
    if (selectedTab == "Returned") {
      return lostFoundReports.where((r) => r['status'] == 'returned').toList();
    }
    return [];
  }

  Widget _buildStatsRow() {
    final totalLost = lostFoundReports.where((r) => r['type'] == 'lost').length;
    final totalFound = lostFoundReports.where((r) => r['type'] == 'found').length;
    final totalReturned = lostFoundReports.where((r) => r['status'] == 'returned').length;
    final totalPending = lostFoundReports.where((r) => r['status'] == 'pending').length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox("Total", "${lostFoundReports.length}",
                const Color(0xFF667EEA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox("Pending", "$totalPending", const Color(0xFFFFB347)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox("Returned", "$totalReturned", const Color(0xFF43CEA2)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
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
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTab("All"),
            _buildTab("Lost"),
            _buildTab("Found"),
            _buildTab("Returned"),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label) {
    final isSelected = selectedTab == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    // Check if it's a Lost/Found item or Complaint
    final bool isLostFound = report.containsKey('item_name');

    if (isLostFound) {
      return _buildLostFoundCard(report);
    } else {
      return _buildComplaintCard(report);
    }
  }

  Widget _buildLostFoundCard(Map<String, dynamic> item) {
    final bool isPending = item['status'] == 'pending';
    final bool isReturned = item['status'] == 'returned';
    final bool hasClaimer = item['claimed_by_id'] != null;

    Color typeColor = item['type'] == 'lost' ? const Color(0xFFFF512F) : const Color(0xFF43CEA2);
    Color statusColor = isReturned ? const Color(0xFF43CEA2) : const Color(0xFFFFB347);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['type'] == 'lost' ? Icons.search_off : Icons.search,
                    color: typeColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#LF-${item['id']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['type'] == 'lost' ? 'LOST' : 'FOUND',
                              style: TextStyle(
                                fontSize: 10,
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['item_name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isReturned ? 'Returned' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Images
          if (item['image1'] != null || item['image2'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (item['image1'] != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(item['image1']),
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (item['image1'] != null && item['image2'] != null)
                    const SizedBox(width: 8),
                  if (item['image2'] != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(item['image2']),
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Item Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.category, 'Category', item['category']),
                _buildDetailRow(Icons.location_on, 'Location', item['location']),
                _buildDetailRow(Icons.access_time, 'Reported', _formatDate(item['reported_at'])),
              ],
            ),
          ),

          const Divider(height: 32),

          // Reporter Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '👤 REPORTER (Person who reported):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name', item['reported_by_name']),
                      _buildInfoRow('Email', item['reported_by_email']),
                      if (item['reported_by_phone'] != null)
                        _buildInfoRow('Phone', item['reported_by_phone']),
                      _buildInfoRow('Role', item['reported_by_role']),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Claimer Info (if claimed)
          if (hasClaimer) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReturned
                        ? '✅ CLAIMER (Verified Owner):'
                        : '⏳ CLAIMER (Pending Verification):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReturned ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isReturned ? Colors.green.shade200 : Colors.orange.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Name', item['claimed_by_name']),
                        _buildInfoRow('Email', item['claimed_by_email']),
                        if (item['claimed_by_phone'] != null)
                          _buildInfoRow('Phone', item['claimed_by_phone']),
                        _buildInfoRow('Role', item['claimed_by_role']),
                        _buildInfoRow('Claimed', _formatDate(item['claimed_at'])),
                        if (isReturned)
                          _buildInfoRow('Verified', _formatDate(item['verified_at'])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showFullDetailsDialog(item),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Full Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF667EEA),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _deleteReport(item['id']),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> report) {
    Color statusColor;
    if (report['status'] == 'Pending') {
      statusColor = const Color(0xFFFFB347);
    } else if (report['status'] == 'In Progress') {
      statusColor = const Color(0xFF667EEA);
    } else {
      statusColor = const Color(0xFF43CEA2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: report['color'].withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: report['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    report['icon'],
                    color: report['color'],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            report['id'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: report['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              report['type'],
                              style: TextStyle(
                                fontSize: 10,
                                color: report['color'],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report['status'],
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      report['reporter'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      report['date'],
                      style: TextStyle(
                        fontSize: 13,
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
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullDetailsDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['item_name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogRow('Report ID', '#LF-${item['id']}'),
              _buildDialogRow('Type', item['type'] == 'lost' ? 'Lost Item' : 'Found Item'),
              _buildDialogRow('Category', item['category']),
              _buildDialogRow('Location', item['location']),
              _buildDialogRow('Status', item['status']),
              _buildDialogRow('Reported', _formatDate(item['reported_at'])),
              const Divider(),
              const Text('Reporter:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDialogRow('Name', item['reported_by_name']),
              _buildDialogRow('Email', item['reported_by_email']),
              _buildDialogRow('Role', item['reported_by_role']),
              if (item['claimed_by_id'] != null) ...[
                const Divider(),
                const Text('Claimer:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildDialogRow('Name', item['claimed_by_name']),
                _buildDialogRow('Email', item['claimed_by_email']),
                _buildDialogRow('Role', item['claimed_by_role']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}