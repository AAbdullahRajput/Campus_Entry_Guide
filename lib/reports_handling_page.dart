import 'package:flutter/material.dart';

class ReportsHandlingPage extends StatefulWidget {
  const ReportsHandlingPage({super.key});

  @override
  State<ReportsHandlingPage> createState() => _ReportsHandlingPageState();
}

class _ReportsHandlingPageState extends State<ReportsHandlingPage> {
  String selectedTab = "All";

  final List<Map<String, dynamic>> reports = [
    {
      'id': '#2341',
      'type': 'Lost Item',
      'title': 'Lost Laptop',
      'description': 'Black Dell laptop lost in Library Building, 3rd floor',
      'reporter': 'Sarah Johnson',
      'date': '2 hours ago',
      'status': 'Pending',
      'icon': Icons.laptop,
      'color': const Color(0xFFFF512F),
    },
    {
      'id': '#2340',
      'type': 'Found Item',
      'title': 'Found Keys',
      'description': 'Set of keys found near the cafeteria entrance',
      'reporter': 'Mike Chen',
      'date': '5 hours ago',
      'status': 'In Progress',
      'icon': Icons.vpn_key,
      'color': const Color(0xFF43CEA2),
    },
    {
      'id': '#2339',
      'type': 'Complaint',
      'title': 'Broken AC Unit',
      'description': 'Air conditioning not working in Room 304',
      'reporter': 'Emily Davis',
      'date': '1 day ago',
      'status': 'Resolved',
      'icon': Icons.ac_unit,
      'color': const Color(0xFF667EEA),
    },
    {
      'id': '#2338',
      'type': 'Lost Item',
      'title': 'Lost Phone',
      'description': 'iPhone 13 Pro lost in parking lot B',
      'reporter': 'David Wilson',
      'date': '2 days ago',
      'status': 'Resolved',
      'icon': Icons.phone_android,
      'color': const Color(0xFFFF512F),
    },
  ];

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
      body: Column(
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
    if (selectedTab == "All") return reports;
    if (selectedTab == "Lost") {
      return reports.where((r) => r['type'] == 'Lost Item').toList();
    }
    if (selectedTab == "Found") {
      return reports.where((r) => r['type'] == 'Found Item').toList();
    }
    if (selectedTab == "Complaints") {
      return reports.where((r) => r['type'] == 'Complaint').toList();
    }
    return reports;
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox("Total", "24", const Color(0xFF667EEA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox("Pending", "8", const Color(0xFFFFB347)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox("Resolved", "16", const Color(0xFF43CEA2)),
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
      child: Row(
        children: [
          _buildTab("All"),
          _buildTab("Lost"),
          _buildTab("Found"),
          _buildTab("Complaints"),
        ],
      ),
    );
  }

  Widget _buildTab(String label) {
    final isSelected = selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (report['status'] != 'Resolved')
                      TextButton.icon(
                        onPressed: () {
                          _showStatusUpdateDialog(context, report);
                        },
                        icon: const Icon(Icons.update, size: 16),
                        label: const Text("Update Status"),
                        style: TextButton.styleFrom(
                          foregroundColor: report['color'],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        _showReportDetailsDialog(context, report);
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text("View Details"),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF667EEA),
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

  void _showStatusUpdateDialog(BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Status"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Report: ${report['title']}"),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "New Status",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              value: report['status'],
              items: ['Pending', 'In Progress', 'Resolved']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Status updated successfully!")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF512F),
            ),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showReportDetailsDialog(BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Report ID", report['id']),
              _buildDetailRow("Type", report['type']),
              _buildDetailRow("Reporter", report['reporter']),
              _buildDetailRow("Date", report['date']),
              _buildDetailRow("Status", report['status']),
              const SizedBox(height: 12),
              const Text(
                "Description:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(report['description']),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}