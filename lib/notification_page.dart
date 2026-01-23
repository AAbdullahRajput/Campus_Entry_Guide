import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_storage.dart';

// ================== NOTIFICATION MODEL ==================
class NotificationItem {
  final int id;
  final String title;
  final String description;
  final String category;
  final String targetRole;
  final String? imageUrl;
  final DateTime createdAt;
  final String createdBy;
  final String? adminProfileImage;
  bool isRead; // Changed to mutable
  final DateTime? readAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetRole,
    this.imageUrl,
    required this.createdAt,
    required this.createdBy,
    this.adminProfileImage,
    required this.isRead,
    this.readAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      targetRole: json['target_role'] ?? 'all',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      createdBy: json['created_by_name'] ?? 'Unknown Admin',
      adminProfileImage: json['admin_profile_image'],
      isRead: (json['is_read'] ?? 0) == 1,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }
}

// ================== NOTIFICATION PAGE ==================
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationItem> notifications = [];
  List<NotificationItem> filteredNotifications = [];
  bool isLoading = true;
  String selectedCategory = 'All';
  int unreadCount = 0;
  
  // User data
  int? userId;
  String? userRole;
  String? userName;

  final String baseUrl = 'http://192.168.100.63:3000';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final session = await LocalStorage.getUserSession();
    if (session != null) {
      setState(() {
        userId = session['userId'];
        userRole = session['role'];
        userName = session['fullName'];
      });
      print('📱 User Session Loaded: ID=$userId, Role=$userRole, Name=$userName');
      _fetchNotifications();
    } else {
      print('❌ No user session found');
      _showError('Please login again');
    }
  }

  Future<void> _fetchNotifications() async {
    if (userId == null || userRole == null) {
      print('❌ Cannot fetch notifications: Missing user data');
      return;
    }

    setState(() => isLoading = true);

    try {
      print('🔄 Fetching notifications for User ID: $userId, Role: $userRole');
      
      final response = await http.post(
        Uri.parse('$baseUrl/get-user-notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'userRole': userRole,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          notifications = (data['notifications'] as List)
              .map((n) => NotificationItem.fromJson(n))
              .toList();
          unreadCount = data['unreadCount'] ?? 0;
          _applyFilter();
          isLoading = false;
        });

        print('✅ Loaded ${notifications.length} notifications ($unreadCount unread)');
        print('📊 Categories: ${notifications.map((n) => n.category).toSet()}');
      } else {
        _showError('Failed to load notifications');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      _showError('Error: $e');
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    if (selectedCategory == 'All') {
      filteredNotifications = List.from(notifications);
    } else {
      filteredNotifications = notifications
          .where((n) => n.category.toLowerCase() == selectedCategory.toLowerCase())
          .toList();
    }
    
    // Sort: Unread first, then by date
    filteredNotifications.sort((a, b) {
      // First sort by read status (unread first)
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      // Then sort by date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead || userId == null || userRole == null) {
      print('⚠️ Already read or missing user data');
      return;
    }

    // Optimistically update UI
    setState(() {
      notification.isRead = true;
      unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
      _applyFilter(); // Re-sort after marking as read
    });

    try {
      print('📖 Marking notification ${notification.id} as read');
      
      final response = await http.post(
        Uri.parse('$baseUrl/mark-notification-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'announcementId': notification.id,
          'userId': userId,
          'userRole': userRole,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Notification marked as read successfully');
      } else {
        print('⚠️ Failed to mark as read on server');
        // Revert optimistic update
        setState(() {
          notification.isRead = false;
          unreadCount++;
          _applyFilter();
        });
      }
    } catch (e) {
      print('❌ Error marking as read: $e');
      // Revert optimistic update
      setState(() {
        notification.isRead = false;
        unreadCount++;
        _applyFilter();
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
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
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildProfileAvatar(NotificationItem notification, {double radius = 18}) {
    if (notification.adminProfileImage != null && notification.adminProfileImage!.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(
            base64Decode(notification.adminProfileImage!),
          ),
          backgroundColor: Colors.grey.shade200,
        );
      } catch (e) {
        return _buildDefaultAvatar(radius);
      }
    } else {
      return _buildDefaultAvatar(radius);
    }
  }

  Widget _buildDefaultAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF11998e),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: radius * 1.1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF11998e)))
          : Column(
              children: [
                // Filter Section
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter by Category',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF11998e).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$unreadCount unread',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF11998e),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('General'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Academic'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Event'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Emergency'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Notifications List
                Expanded(
                  child: filteredNotifications.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchNotifications,
                          color: const Color(0xFF11998e),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = filteredNotifications[index];
                              return _buildNotificationCard(notification);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String category) {
    final isSelected = selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = category;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF11998e) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF11998e) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
  final categoryColor = _getCategoryColor(notification.category);
  final isUnread = !notification.isRead;

  return GestureDetector(
    onTap: () {
      if (!notification.isRead) {
        _markAsRead(notification);
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: isUnread
            ? Border.all(color: const Color(0xFF11998e), width: 2)
            : Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: isUnread 
                ? const Color(0xFF11998e).withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: isUnread ? 15 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Admin Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildProfileAvatar(notification, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.createdBy,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF11998e),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(notification.createdAt),
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
          Divider(height: 1, color: Colors.grey.shade200),
          
          // ✅ Image with Category Badge (if image exists)
          if (notification.imageUrl != null)
            Stack(
              children: [
                ClipRRect(
                  child: Image.memory(
                    base64Decode(notification.imageUrl!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Category Badge on Image
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
                          _getCategoryIcon(notification.category),
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          
          // Content Section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Category Badge (if NO image exists, show at top of content)
                if (notification.imageUrl == null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(notification.category),
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          notification.category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Title
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Description
                Text(
                  notification.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Mark as Read prompt for unread notifications
                if (isUnread) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11998e).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 14,
                          color: const Color(0xFF11998e),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to mark as read',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF11998e),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedCategory != 'All'
                ? 'No $selectedCategory notifications'
                : 'Check back later for updates',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}