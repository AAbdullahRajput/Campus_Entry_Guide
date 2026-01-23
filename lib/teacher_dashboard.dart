import 'package:campus_entry_guide/map_screen.dart';
import 'package:campus_entry_guide/notification_page.dart';
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_storage.dart';

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
class TeacherShell extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const TeacherShell({super.key, this.userData});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showBottomBar = false;

  // ✅ ADD THIS - Key to access dashboard state
  final GlobalKey<_TeacherDashboardState> _dashboardKey = GlobalKey<_TeacherDashboardState>();

  @override
  void initState() {
    super.initState();
    // Animate bottom bar after a delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showBottomBar = true);
      }
    });
  }

  // ✅ ADD THIS METHOD - Refresh notification count
  void _refreshNotificationCount() {
    _dashboardKey.currentState?._fetchUnreadCount();
  }

  void _onNavTap(int index) {
    if (index == 1) {
      // Navigate to Map Page with animation
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
      // Navigate to Profile Page with animation
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
    final userName = widget.userData?['full_name'] ?? widget.userData?['name'] ?? 'Teacher';
    final userEmail = widget.userData?['email'] ?? 'teacher@campus.edu';
    final userImage = widget.userData?['profile_image'];

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TeacherDashboard(
            key: _dashboardKey, // ✅ ADD THIS - Pass the key
            userName: userName,
            userEmail: userEmail,
            userImage: userImage,
            scaffoldKey: _scaffoldKey,
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

// ================== TEACHER DASHBOARD SCREEN ==================
class TeacherDashboard extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userImage;
  final GlobalKey<ScaffoldState> scaffoldKey;
  
  const TeacherDashboard({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userImage,
    required this.scaffoldKey,
  });

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> with WidgetsBindingObserver {
  bool _showAppBar = false;
  bool _showWelcome = false;
  bool _showCards = false;
  int _unreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAnimations();
    _fetchUnreadCount();
    WidgetsBinding.instance.addObserver(this);
    // ✅ Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchUnreadCount();
    });
  }

  void _startAnimations() {
    // AppBar animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showAppBar = true);
    });
    
    // Welcome text animation
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _showWelcome = true);
    });
    
    // Cards animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showCards = true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUnreadCount();  // ✅ Refresh when app comes to foreground
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

  @override
  void dispose() {
    _refreshTimer?.cancel();  // ✅ Stop timer when leaving page
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
                "Teacher Dashboard",
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
                      icon: const Icon(Icons.notifications_rounded, color: Colors.white),
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
                        _fetchUnreadCount();  // Refresh count when returning
                      },
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.yellow,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadCount > 99 ? '99+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.red,
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
                        "Manage your classes and students",
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
                  icon: Icons.camera_alt_rounded,
                  title: "Mark Attendance",
                  subtitle: "AI Face Recognition",
                  gradient: const [Color(0xFF43CEA2), Color(0xFF185A9D)],
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
                  icon: Icons.check_circle_outline_rounded,
                  title: "View Attendance",
                  subtitle: "Class-wise records",
                  gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
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
                  icon: Icons.schedule_rounded,
                  title: "Timetable",
                  subtitle: "View class schedule",
                  gradient: const [Color(0xFFFFB347), Color(0xFFFFCC33)],
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
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Chatbot Help",
                  subtitle: "Quick assistance",
                  gradient: const [Color(0xFF36D1DC), Color(0xFF5B86E5)],
                ),
              ),
            ),
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
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title - Feature coming soon")),
        );
      },
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