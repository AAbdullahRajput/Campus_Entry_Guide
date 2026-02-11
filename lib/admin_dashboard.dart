import 'package:campus_entry_guide/announcements_page.dart';
import 'package:campus_entry_guide/complaint_handling_page.dart';
import 'package:campus_entry_guide/data_monitoring_page.dart';
import 'package:campus_entry_guide/map_screen.dart';
import 'package:campus_entry_guide/notification_page.dart';
import 'package:campus_entry_guide/reports_handling_page.dart';
import 'package:campus_entry_guide/user_management_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/local_storage.dart';

// ================== LOCATION PIN PAINTER ==================
class LocationPinPainter extends CustomPainter {
  final Color color;

  LocationPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    final width = size.width;
    final height = size.height;
    
    path.addOval(Rect.fromCircle(
      center: Offset(width / 2, height * 0.3),
      radius: width * 0.35,
    ));
    
    path.moveTo(width / 2, height);
    path.lineTo(width * 0.3, height * 0.55);
    path.arcToPoint(
      Offset(width * 0.7, height * 0.55),
      radius: Radius.circular(width * 0.35),
      clockwise: false,
    );
    path.close();

    canvas.drawPath(path, paint);
    
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(width / 2, height * 0.3),
      width * 0.15,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================== MAIN SHELL WITH BOTTOM NAVIGATION ==================
class AdminShell extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const AdminShell({super.key, this.userData});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showBottomBar = false;
  
  final GlobalKey<_AdminDashboardState> _dashboardKey = GlobalKey<_AdminDashboardState>();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showBottomBar = true);
      }
    });
  }

  void _refreshNotificationCount() {
    _dashboardKey.currentState?._fetchUnreadCount();
  }

  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MapPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.userData?['full_name'] ?? widget.userData?['name'] ?? 'Admin';
    final userEmail = widget.userData?['email'] ?? 'admin@campus.edu';
    final userImage = widget.userData?['profile_image'];

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AdminDashboard(
            key: _dashboardKey,
            userName: userName,
            userEmail: userEmail,
            userImage: userImage,
            scaffoldKey: _scaffoldKey,
            userData: widget.userData,
          ),
        ],
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: _showBottomBar ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        child: _buildCurvedBottomBar(),
      ),
    );
  }

  Widget _buildCurvedBottomBar() {
    return Container(
      height: 80,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 80),
            painter: CurvedBottomBarPainter(),
          ),
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.dashboard_rounded,
                    index: 0,
                    label: "Dashboard",
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -25),
                  child: _buildCenterMapButton(),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.person_rounded,
                    index: 2,
                    label: "Profile",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => _onNavTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF11998e) : Colors.grey.shade400,
                size: isActive ? 30 : 28,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isActive ? const Color(0xFF11998e) : Colors.grey.shade500,
                fontSize: isActive ? 12 : 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterMapButton() {
    return GestureDetector(
      onTap: () => _onNavTap(1),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF11998e).withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            CustomPaint(
              size: const Size(38, 38),
              painter: LocationPinPainter(
                color: const Color(0xFF11998e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== CURVED BOTTOM BAR PAINTER ==================
class CurvedBottomBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width * 0.34, 0);

    path.quadraticBezierTo(
      size.width * 0.39, 0,
      size.width * 0.42, -12,
    );

    path.quadraticBezierTo(
      size.width * 0.46, -22,
      size.width * 0.50, -26,
    );

    path.quadraticBezierTo(
      size.width * 0.54, -22,
      size.width * 0.58, -12,
    );

    path.quadraticBezierTo(
      size.width * 0.61, 0,
      size.width * 0.66, 0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawShadow(
      path,
      Colors.black.withOpacity(0.15),
      10,
      false,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================== ADMIN DASHBOARD SCREEN ==================
class AdminDashboard extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userImage;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Map<String, dynamic>? userData; 
  
  const AdminDashboard({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userImage,
    required this.scaffoldKey,
    this.userData,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with WidgetsBindingObserver {
  bool _showAppBar = false;
  bool _showWelcome = false;
  bool _showCards = false;
  int _unreadCount = 0;
  int _unreadComplaintsCount = 0;
  int _lastViewedComplaintsCount = 0;
  Timer? _refreshTimer;
  Timer? _complaintsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startAnimations();
    _fetchUnreadCount();
    _fetchUnreadComplaintsCount();
    WidgetsBinding.instance.addObserver(this);
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchUnreadCount();
    });
    
    _complaintsRefreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _fetchUnreadComplaintsCount();
    });
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showAppBar = true);
    });
    
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _showWelcome = true);
    });
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showCards = true);
    });
  }

  void _onAnnouncementPosted() {
    print('📢 Announcement posted! Refreshing count...');
    _fetchUnreadCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUnreadCount();
      _fetchUnreadComplaintsCount();
    }
  }
  
  Future<void> _fetchUnreadCount() async {
    try {
      final session = await LocalStorage.getUserSession();
      if (session == null) return;
      
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-unread-count'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': session['userId'],
          'userRole': session['role'],
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _unreadCount = data['unreadCount'] ?? 0;
        });
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
  }

  Future<void> _fetchUnreadComplaintsCount() async {
  try {
    final session = await LocalStorage.getUserSession();
    if (session == null) return;
    
    final response = await http.post(
      Uri.parse('http://192.168.100.63:3000/get-admin-complaints'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'reporterRole': null,
        'status': null,
        'category': null,
        'priority': null,
        'location': null,
        'searchQuery': null,
      }),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final complaints = List<Map<String, dynamic>>.from(data['complaints']);
      
      final pendingCount = complaints.where((c) => 
        c['status'] == 'pending' || c['status'] == 'in_progress'
      ).length;
      
      // Load the last viewed count from SharedPreferences
      final prefs = await SharedPreferences.getInstance(); // ✅ Changed this line
      _lastViewedComplaintsCount = prefs.getInt('last_viewed_complaints_count') ?? 0;
      
      // Only show badge if there are NEW complaints (count increased)
      setState(() {
        if (pendingCount > _lastViewedComplaintsCount) {
          _unreadComplaintsCount = pendingCount - _lastViewedComplaintsCount;
        } else {
          _unreadComplaintsCount = 0;
        }
      });
      
      print('📊 Admin unread complaints count: $_unreadComplaintsCount');
      print('📊 Current pending: $pendingCount, Last viewed: $_lastViewedComplaintsCount');
    }
  } catch (e) {
    print('❌ Error fetching complaints count: $e');
  }
}


  @override
  void dispose() {
    _refreshTimer?.cancel();
    _complaintsRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedSlide(
          offset: _showAppBar ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showAppBar ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: AppBar(
              title: const Text(
                "Admin Dashboard",
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
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_rounded, color: Colors.yellow),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, animation, __) => const NotificationPage(),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                        _fetchUnreadCount();
                      },
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadCount > 99 ? '99+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSlide(
                offset: _showWelcome ? Offset.zero : const Offset(-1, 0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _showWelcome ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, ${widget.userName} 👋",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Manage campus operations efficiently",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildDashboardGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AnimatedCard(
                show: _showCards,
                delay: 0,
                fromLeft: true,
                child: _dashboardCard(
                  context,
                  icon: Icons.people_alt_rounded,
                  title: "User Management",
                  subtitle: "Add, edit & remove users",
                  gradient: const [
                    Color(0xFF667EEA),
                    Color(0xFF764BA2),
                  ],
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 350),
                        pageBuilder: (_, __, ___) =>
                            const UserManagementPage(),
                        transitionsBuilder: (_, animation, __, child) {
                          final slide = Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return SlideTransition(
                            position: slide,
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnimatedCard(
                show: _showCards,
                delay: 100,
                fromLeft: false,
                child: _dashboardCard(
                  context,
                  icon: Icons.analytics_rounded,
                  title: "Data Monitoring",
                  subtitle: "Track usage & updates",
                  gradient: const [Color(0xFF43CEA2), Color(0xFF185A9D)],
onTap: () async {
  // Get user session data from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getInt('userId')?.toString() ?? '';
  final role = prefs.getString('role') ?? '';
  
  // ✅ FIXED: Use 'fullName' instead of 'userName'
  final fullName = prefs.getString('fullName') ?? 'Admin';
  
  // Verify user is an admin
  if (role != 'Admin') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Admin privileges required.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (userId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login first')),
    );
    return;
  }
  
  Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => AdminMonitoringPage(
        adminId: userId,
        adminName: fullName,  // ✅ Pass fullName here
      ),
      transitionsBuilder: (_, animation, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return SlideTransition(
          position: slide,
          child: child,
        );
      },
    ),
  );
},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AnimatedCard(
                show: _showCards,
                delay: 200,
                fromLeft: true,
                child: _dashboardCard(
                  context,
                  icon: Icons.campaign_rounded,
                  title: "Announcements",
                  subtitle: "Post campus notices",
                  gradient: const [Color(0xFFFFB347), Color(0xFFFFCC33)],
                  onTap: () async {
                    await Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 350),
                        pageBuilder: (_, __, ___) =>
                         AnnouncementsManagementPage(
                          adminId: widget.userData?['id'] ?? 0,
                          adminName: widget.userData?['full_name'] ?? 'Admin',
                        ),
                        transitionsBuilder: (_, animation, __, child) {
                          final slide = Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return SlideTransition(
                            position: slide,
                            child: child,
                          );
                        },
                      ),
                    );
                    _fetchUnreadCount();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnimatedCard(
                show: _showCards,
                delay: 300,
                fromLeft: false,
                child: _dashboardCard(
                  context,
                  icon: Icons.report_problem_rounded,
                  title: "Reports Handling",
                  subtitle: "Lost & Found / Complaints",
                  gradient: const [Color(0xFFFF512F), Color(0xFFDD2476)],
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 350),
                        pageBuilder: (_, __, ___) =>
                            const ReportsHandlingPage(),
                        transitionsBuilder: (_, animation, __, child) {
                          final slide = Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return SlideTransition(
                            position: slide,
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AnimatedCard(
                show: _showCards,
                delay: 400,
                fromLeft: true,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _dashboardCard(
                        context,
                        icon: Icons.manage_accounts_rounded,
                        title: "Complaint Management",
                        subtitle: "Student & Teacher Issues",
                        gradient: const [Color(0xFF8360c3), Color(0xFF2ebf91)],
                        onTap: () async {
  // Calculate current pending count before navigation
  final session = await LocalStorage.getUserSession();
  if (session != null) {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-admin-complaints'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reporterRole': null,
          'status': null,
          'category': null,
          'priority': null,
          'location': null,
          'searchQuery': null,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final complaints = List<Map<String, dynamic>>.from(data['complaints']);
        
        final pendingCount = complaints.where((c) => 
          c['status'] == 'pending' || c['status'] == 'in_progress'
        ).length;
        
        // Save this as the "last viewed" count
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_viewed_complaints_count', pendingCount);
        
        print('✅ Saved last viewed count: $pendingCount');
        
        // Clear the badge immediately
        setState(() {
          _unreadComplaintsCount = 0;
          _lastViewedComplaintsCount = pendingCount;
        });
      }
    } catch (e) {
      print('❌ Error saving viewed count: $e');
    }
  }
  
  await Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const AdminComplaintHandlingPage(),
      transitionsBuilder: (_, animation, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );
        return SlideTransition(
          position: slide,
          child: child,
        );
      },
    ),
  );
  
  // Refresh after returning from the page
  _fetchUnreadComplaintsCount();
},
                      ),
                    ),
                    if (_unreadComplaintsCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              _unreadComplaintsCount > 9 ? '9+' : '$_unreadComplaintsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    VoidCallback? onTap, 
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withOpacity(0.9),
              child: Icon(icon, size: 28, color: Colors.black87),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== ANIMATED CARD WRAPPER ==================
class _AnimatedCard extends StatefulWidget {
  final bool show;
  final int delay;
  final bool fromLeft;
  final Widget child;

  const _AnimatedCard({
    required this.show,
    required this.delay,
    required this.fromLeft,
    required this.child,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : Offset(widget.fromLeft ? -1 : 1, 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: widget.child,
      ),
    );
  }
}