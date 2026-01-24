import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminComplaintHandlingPage extends StatefulWidget {
  const AdminComplaintHandlingPage({super.key});

  @override
  State<AdminComplaintHandlingPage> createState() => _AdminComplaintHandlingPageState();
}

class _AdminComplaintHandlingPageState extends State<AdminComplaintHandlingPage> {
  final _searchController = TextEditingController();
  final _responseController = TextEditingController();

  String _currentTab = 'all';
  String searchQuery = '';
  String filterStatus = 'all';
  String filterCategory = 'all';
  String filterPriority = 'all';
  String filterLocation = 'all';

  List<Map<String, dynamic>> allComplaints = [];
  List<Map<String, dynamic>> filteredComplaints = [];
  bool isLoading = false;
  int? expandedComplaintId;

  List<String> categories = [];
  List<String> locations = [];
  List<String> priorities = ['Low', 'Medium', 'High'];

  int? adminId;
  String? adminName;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadOptions();
    _loadComplaints();
  }

  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      adminId = prefs.getInt('userId');
      adminName = prefs.getString('full_name');
    });
  }

  Future<void> _loadOptions() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.100.63:3000/get-complaint-options'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          categories = List<String>.from(data['categories']);
          locations = List<String>.from(data['locations']);
        });
      }
    } catch (e) {
      _showSnack('Failed to load options: $e');
    }
  }

  Future<void> _loadComplaints() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-admin-complaints'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'reporterRole': _currentTab == 'all' ? null : (_currentTab == 'student' ? 'Student' : 'Teacher'),
          'status': filterStatus != 'all' ? filterStatus : null,
          'category': filterCategory != 'all' ? filterCategory : null,
          'priority': filterPriority != 'all' ? filterPriority : null,
          'location': filterLocation != 'all' ? filterLocation : null,
          'searchQuery': searchQuery.isNotEmpty ? searchQuery : null,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          allComplaints = List<Map<String, dynamic>>.from(data['complaints']);
          filteredComplaints = allComplaints;
        });
        
        print('📋 Admin loaded ${allComplaints.length} complaints');
        if (allComplaints.isNotEmpty) {
          print('📋 First complaint data:');
          print('   Name: ${allComplaints[0]['reported_by_name']}');
          print('   Degree: ${allComplaints[0]['reported_by_degree']}');
          print('   Section: ${allComplaints[0]['reported_by_section']}');
        }
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateComplaintStatus(int complaintId, String newStatus) async {
    if (adminId == null || adminName == null) {
      _showSnack('Admin information not found');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/update-complaint-status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'complaintId': complaintId,
          'status': newStatus,
          'adminId': adminId,
          'adminName': adminName,
          'adminResponse': _responseController.text.isNotEmpty ? _responseController.text : null,
        }),
      );

      if (response.statusCode == 200) {
        _responseController.clear();
        _showSnack('Complaint status updated to $newStatus ✅');
        setState(() => expandedComplaintId = null);
        _loadComplaints();
      } else {
        _showSnack('Failed to update status');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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

  Future<void> _deleteComplaint(int complaintId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Complaint?'),
        content: const Text('This action cannot be undone.'),
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
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/delete-complaint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'complaintId': complaintId,
          'userId': adminId,
          'userRole': 'Admin',
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
              backgroundColor: Color(0xFF8360c3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Complaint Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8360c3), Color(0xFF2ebf91)]),
          ),
        ),
      ),
      body: isLoading && allComplaints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

  Widget _buildSearchSection() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() => searchQuery = val);
        _loadComplaints();
      },
      decoration: InputDecoration(
        hintText: 'Search by title, description, name, or email...',
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
    final studentCount = allComplaints.where((c) => c['reported_by_role'] == 'Student').length;
    final teacherCount = allComplaints.where((c) => c['reported_by_role'] == 'Teacher').length;
    final allCount = allComplaints.length;

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
          _buildTab('All', 'all', allCount),
          _buildTab('Students', 'student', studentCount),
          _buildTab('Teachers', 'teacher', teacherCount),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value, int count) {
    final isActive = _currentTab == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _currentTab = value);
          _loadComplaints();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF8360c3) : Colors.transparent,
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
                  color: isActive ? const Color(0xFF8360c3) : Colors.grey.shade600,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF8360c3).withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? const Color(0xFF8360c3) : Colors.grey.shade600,
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
          _buildStatusFilterChip('Pending', 'pending'),
          _buildStatusFilterChip('In Progress', 'in_progress'),
          _buildStatusFilterChip('Resolved', 'resolved'),
          _buildDropdownFilterChip('Category', filterCategory, ['all', ...categories], (val) {
            setState(() => filterCategory = val);
            _loadComplaints();
          }),
          _buildDropdownFilterChip('Priority', filterPriority, ['all', ...priorities], (val) {
            setState(() => filterPriority = val);
            _loadComplaints();
          }),
          _buildDropdownFilterChip('Location', filterLocation, ['all', ...locations], (val) {
            setState(() => filterLocation = val);
            _loadComplaints();
          }),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
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
        selectedColor: const Color(0xFF8360c3).withOpacity(0.3),
        checkmarkColor: const Color(0xFF8360c3),
      ),
    );
  }

  Widget _buildDropdownFilterChip(String label, String currentValue, List<String> items, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        initialValue: currentValue,
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => items.map((item) {
          final displayLabel = item == 'all' ? 'All' : item;
          return PopupMenuItem(
            value: item,
            child: Text(displayLabel),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentValue == 'all' ? label : currentValue,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintsList() {
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
    final isExpanded = expandedComplaintId == complaint['id'];
    final statusColor = complaint['status'] == 'pending'
        ? Colors.orange
        : complaint['status'] == 'in_progress'
            ? Colors.blue
            : Colors.green;
    final statusLabel = complaint['status'] == 'pending'
        ? '⏳ Pending'
        : complaint['status'] == 'in_progress'
            ? '🔧 Working'
            : '✅ Resolved';

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
              color: const Color(0xFF8360c3).withOpacity(0.1),
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
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
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
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
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
                        if (complaint['reported_by_role'] == 'Student') ...[
                          if (complaint['reported_by_degree'] != null || complaint['reported_by_section'] != null)
                            Text(
                              '${complaint['reported_by_degree'] ?? 'N/A'} - ${complaint['reported_by_section'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            )
                          else
                            Text(
                              'Student',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ] else if (complaint['reported_by_role'] == 'Teacher') ...[
                          if (complaint['reported_by_department'] != null)
                            Text(
                              complaint['reported_by_department'],
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            )
                          else
                            Text(
                              'Teacher',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                        if (complaint['reported_by_email'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            complaint['reported_by_email'],
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (complaint['status'] == 'pending')
                  ElevatedButton.icon(
                    onPressed: () => _updateComplaintStatus(complaint['id'], 'in_progress'),
                    icon: const Icon(Icons.build, size: 16),
                    label: const Text('Start Work'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 180, 198, 211)),
                  ),
                if (complaint['status'] == 'in_progress')
                  ElevatedButton.icon(
                    onPressed: () => _updateComplaintStatus(complaint['id'], 'resolved'),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Mark Resolved'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 154, 187, 155)),
                  ),
                if ((complaint['verified_by_reporter'] == 1 || complaint['verified_by_reporter'] == true) &&
                    (complaint['allow_admin_delete'] == 1 || complaint['allow_admin_delete'] == true))
                  ElevatedButton.icon(
                    onPressed: () => _deleteComplaint(complaint['id']),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 180, 154, 152)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    expandedComplaintId = null;
                  } else {
                    expandedComplaintId = complaint['id'];
                  }
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.note, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Add Response'),
                  const Spacer(),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  TextField(
                    controller: _responseController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add admin response/notes...',
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => expandedComplaintId = null);
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (complaint['status'] == 'pending') {
                              _updateComplaintStatus(complaint['id'], 'in_progress');
                            } else if (complaint['status'] == 'in_progress') {
                              _updateComplaintStatus(complaint['id'], 'resolved');
                            } else {
                              _showSnack('Complaint already resolved');
                            }
                          },
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Send'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8360c3)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _responseController.dispose();
    super.dispose();
  }
}