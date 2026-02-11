import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class StudentAttendancePage extends StatefulWidget {
  final int userId;
  final String userName;

  const StudentAttendancePage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _enrolledSubjects = [];
  late TabController _tabController;
  Position? _currentPosition;
  bool _isLocationLoading = false;
  bool _isFaceRegistered = false;
  bool _checkingFaceRegistration = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEnrolledSubjects();
    _requestLocationPermission();
    _checkFaceRegistration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // CHECK FACE REGISTRATION STATUS
  // ============================================
  Future<void> _checkFaceRegistration() async {
    setState(() => _checkingFaceRegistration = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/check-face-registered'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': widget.userId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isFaceRegistered = data['face_registered'] == true;
          _checkingFaceRegistration = false;
        });
        print('✅ Face registration status: $_isFaceRegistered');
      }
    } catch (e) {
      print('❌ Error checking face registration: $e');
      setState(() => _checkingFaceRegistration = false);
    }
  }

  Future<void> _fetchEnrolledSubjects() async {
    setState(() => _isLoading = true);

    try {
      print('Fetching attendance for student ID: ${widget.userId}');
      
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-student-attendance-details'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': widget.userId}),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        
        for (var subject in subjects) {
          if (subject['percentage'] is String) {
            subject['percentage'] = double.tryParse(subject['percentage']) ?? 0.0;
          } else if (subject['percentage'] is int) {
            subject['percentage'] = (subject['percentage'] as int).toDouble();
          }
          
          if (subject['total_classes'] is String) {
            subject['total_classes'] = int.tryParse(subject['total_classes']) ?? 0;
          }
          
          if (subject['attended_classes'] is String) {
            subject['attended_classes'] = int.tryParse(subject['attended_classes']) ?? 0;
          }
          
          if (subject['records'] == null) {
            subject['records'] = [];
          } else if (subject['records'] is! List) {
            subject['records'] = [];
          }
        }
        
        setState(() {
          _enrolledSubjects = subjects;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load subjects: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching attendance: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _fetchEnrolledSubjects,
            ),
          ),
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLocationLoading = false;
      });

      return position;
    } catch (e) {
      setState(() => _isLocationLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ============================================
  // SHOW ATTENDANCE METHOD SELECTION
  // ============================================
  Future<void> _showAttendanceMethodDialog(Map<String, dynamic> subject) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Title
            const Text(
              'Select Attendance Method',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // GPS Option
            _buildMethodOption(
              icon: Icons.gps_fixed,
              title: 'GPS Location',
              subtitle: 'Mark attendance using your location',
              gradientColors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
              onTap: () {
                Navigator.pop(context);
                _markGPSAttendance(subject);
              },
            ),
            const SizedBox(height: 16),

            // Face Recognition Option
            _buildMethodOption(
              icon: Icons.face,
              title: 'Face Recognition',
              subtitle: _isFaceRegistered 
                  ? 'Verify your identity with face scan' 
                  : 'Register your face first',
              gradientColors: _isFaceRegistered
                  ? const [Color(0xFF11998E), Color(0xFF38EF7D)]
                  : [Colors.grey.shade400, Colors.grey.shade500],
              onTap: _isFaceRegistered
                  ? () {
                      Navigator.pop(context);
                      _markFaceAttendance(subject);
                    }
                  : () {
                      Navigator.pop(context);
                      _showRegisterFaceDialog();
                    },
              trailing: !_isFaceRegistered
                  ? const Icon(Icons.lock, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing
            else
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================
  // REGISTER FACE DIALOG
  // ============================================
  void _showRegisterFaceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.face, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Register Face', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: const Text(
          'You need to register your face before using face recognition for attendance. '
          'This is a one-time setup process.\n\n'
          'Would you like to register your face now?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToFaceRegistration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Register Now'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // NAVIGATE TO FACE REGISTRATION
  // ============================================
  void _navigateToFaceRegistration() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationPage(
          userId: widget.userId,
          userName: widget.userName,
        ),
      ),
    );

    if (result == true) {
      // Face registered successfully
      await _checkFaceRegistration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Face registered successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ============================================
  // MARK GPS ATTENDANCE (existing method)
  // ============================================
  Future<void> _markGPSAttendance(Map<String, dynamic> subject) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final checkResponse = await http.post(
        Uri.parse('http://192.168.100.63:3000/check-session-for-student'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'schedule_id': subject['schedule_id'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      final checkData = jsonDecode(checkResponse.body);

      if (!checkData['can_mark_attendance']) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Not Available', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              content: Text(checkData['reason'] ?? 'Cannot mark attendance'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      _markGPSAttendanceWithLocation(subject, checkData);
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markGPSAttendanceWithLocation(
    Map<String, dynamic> subject,
    Map<String, dynamic> sessionData,
  ) async {
    final position = await _getCurrentLocation();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get your location. Please enable GPS.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final teacherLat = double.tryParse(sessionData['teacher_latitude'].toString()) ?? 0.0;
    final teacherLng = double.tryParse(sessionData['teacher_longitude'].toString()) ?? 0.0;
    final radiusMeters = double.tryParse(sessionData['radius_meters'].toString()) ?? 50.0;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      teacherLat,
      teacherLng,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: distance <= radiusMeters
                      ? [Colors.green, Colors.lightGreen]
                      : [Colors.red, Colors.redAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                distance <= radiusMeters ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                distance <= radiusMeters ? 'Mark Attendance' : 'Too Far',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: distance <= radiusMeters
                      ? [Colors.green.shade50, Colors.green.shade100]
                      : [Colors.red.shade50, Colors.red.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.book, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subject['course_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Distance: ${distance.toInt()} meters',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: distance <= radiusMeters ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (distance > radiusMeters)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You must be closer to the classroom.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          if (distance <= radiusMeters)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/mark-gps-attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'student_name': widget.userName,
          'schedule_id': subject['schedule_id'],
          'session_id': sessionData['session_id'],
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(data['message'] ?? 'Attendance marked')),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchEnrolledSubjects();
        // ✅ ADD THIS - Trigger profile stats refresh
        if (mounted) {
          setState(() {}); // This will cause FutureBuilder to rebuild
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to mark attendance');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // MARK FACE ATTENDANCE
  // ============================================
  Future<void> _markFaceAttendance(Map<String, dynamic> subject) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Check if teacher allows face recognition for this session
      final checkResponse = await http.post(
        Uri.parse('http://192.168.100.63:3000/check-session-for-student'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'schedule_id': subject['schedule_id'],
        }),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context);

      final checkData = jsonDecode(checkResponse.body);

      // Check if attendance marking is allowed at all
      if (!checkData['can_mark_attendance']) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Not Available', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              content: Text(checkData['reason'] ?? 'Cannot mark attendance'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Check if teacher has enabled face recognition
      // If attendance_mode is 'gps_only' or doesn't contain 'face', deny access
      final attendanceMode = checkData['attendance_mode']?.toString().toLowerCase() ?? '';
      if (attendanceMode == 'gps_only' || 
          (attendanceMode.isNotEmpty && !attendanceMode.contains('face'))) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Face Recognition Disabled', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              content: const Text(
                'The teacher has not enabled face recognition for this session. '
                'Please use GPS-based attendance instead.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Face recognition is allowed by teacher, proceed to verification
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceVerificationPage(
              userId: widget.userId,
              userName: widget.userName,
              subject: subject,
              scheduleId: subject['schedule_id'],
              sessionId: checkData['session_id'],
              onAttendanceMarked: () async {
                await _fetchEnrolledSubjects();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overallStats = _calculateOverallStats();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            forceElevated: innerBoxIsScrolled,
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: const Color(0xFF667EEA),
            actions: [
              // GPS Status
              IconButton(
                icon: _isLocationLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _currentPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                        color: Colors.white,
                      ),
                onPressed: _getCurrentLocation,
                tooltip: 'Refresh Location',
              ),
              // Face Registration Status
              IconButton(
                icon: _checkingFaceRegistration
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isFaceRegistered ? Icons.face : Icons.face_retouching_off,
                        color: _isFaceRegistered ? Colors.white : Colors.white70,
                      ),
                onPressed: _isFaceRegistered ? null : _navigateToFaceRegistration,
                tooltip: _isFaceRegistered ? 'Face Registered' : 'Register Face',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              title: const Text(
                "",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 45, 16, 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isLoading) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${overallStats['percentage'].toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  'Overall Attendance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildCompactStat(
                                      '${_enrolledSubjects.length}',
                                      'Subjects',
                                      Icons.book_rounded,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 18,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    _buildCompactStat(
                                      '${overallStats['attended']}',
                                      'Present',
                                      Icons.check_circle_rounded,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 18,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    _buildCompactStat(
                                      '${overallStats['total'] - overallStats['attended']}',
                                      'Absent',
                                      Icons.cancel_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Container(
                color: const Color(0xFFF5F7FB),
                child: _tabController.index == 0
                    ? _buildOverviewTab()
                    : _buildDetailsTab(),
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabController.index = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _tabController.index == 0
                            ? const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              )
                            : null,
                        color: _tabController.index == 0 ? null : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            color: _tabController.index == 0 ? Colors.white : Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Overview',
                            style: TextStyle(
                              color: _tabController.index == 0 ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabController.index = 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _tabController.index == 1
                            ? const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              )
                            : null,
                        color: _tabController.index == 1 ? null : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            color: _tabController.index == 1 ? Colors.white : Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Details',
                            style: TextStyle(
                              color: _tabController.index == 1 ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 12),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 7,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    if (_enrolledSubjects.isEmpty) {
      return _buildEmptyState();
    }

    final sortedSubjects = List<Map<String, dynamic>>.from(_enrolledSubjects)
      ..sort((a, b) {
        final aPerc = (a['percentage'] ?? 0.0) as double;
        final bPerc = (b['percentage'] ?? 0.0) as double;
        return bPerc.compareTo(aPerc);
      });

    return RefreshIndicator(
      onRefresh: _fetchEnrolledSubjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedSubjects.length,
        itemBuilder: (context, index) {
          final subject = sortedSubjects[index];
          return _buildSubjectCard(subject);
        },
      ),
    );
  }

  Widget _buildDetailsTab() {
    if (_enrolledSubjects.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchEnrolledSubjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _enrolledSubjects.length,
        itemBuilder: (context, index) {
          final subject = _enrolledSubjects[index];
          return _buildDetailedSubjectCard(subject);
        },
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final totalClasses = (subject['total_classes'] ?? 0) as int;
    final attendedClasses = (subject['attended_classes'] ?? 0) as int;
    final percentage = (subject['percentage'] ?? 0.0) as double;
    final lastUpdated = subject['last_updated'];

    final Color percentageColor = percentage >= 75
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetailedAttendance(subject),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [percentageColor.withOpacity(0.7), percentageColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: percentageColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.book, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject['course_name'] ?? 'Unknown Subject',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                subject['teacher_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        percentageColor.withOpacity(0.1),
                        percentageColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        percentage >= 75 ? Icons.check_circle : Icons.warning,
                        color: percentageColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${percentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: percentageColor,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: totalClasses > 0 ? percentage / 100 : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(percentageColor),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Total',
                    '$totalClasses',
                    Icons.event_note_rounded,
                    Colors.blue,
                  ),
                  _buildStatColumn(
                    'Present',
                    '$attendedClasses',
                    Icons.check_circle_rounded,
                    Colors.green,
                  ),
                  _buildStatColumn(
                    'Absent',
                    '${totalClasses - attendedClasses}',
                    Icons.cancel_rounded,
                    Colors.red,
                  ),
                ],
              ),
              
              if (lastUpdated != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Updated ${_formatDate(lastUpdated)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDetailedAttendance(subject),
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('History', style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF667EEA),
                        side: const BorderSide(color: Color(0xFF667EEA), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAttendanceMethodDialog(subject),
                      icon: const Icon(Icons.fingerprint, size: 20),
                      label: const Text('Mark', style: TextStyle(fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedSubjectCard(Map<String, dynamic> subject) {
    final totalClasses = (subject['total_classes'] ?? 0) as int;
    final attendedClasses = (subject['attended_classes'] ?? 0) as int;
    final percentage = (subject['percentage'] ?? 0.0) as double;
    final records = List<Map<String, dynamic>>.from(subject['records'] ?? []);

    final Color percentageColor = percentage >= 75
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  percentageColor.withOpacity(0.7),
                  percentageColor,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: percentageColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.book, color: Colors.white, size: 24),
          ),
          title: Text(
            subject['course_name'] ?? 'Unknown',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${subject['teacher_name']} • $attendedClasses/$totalClasses classes',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: percentageColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: percentageColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              '${percentage.toInt()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: percentageColor,
              ),
            ),
          ),
          children: [
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No attendance records yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...records.take(5).map((record) {
                final isPresent = record['status'] == 'present';
                final date = record['date'] ?? 'Unknown Date';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPresent
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPresent
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPresent ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPresent ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPresent ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPresent ? 'Present' : 'Absent',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            if (records.length > 5) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _showDetailedAttendance(subject),
                icon: const Icon(Icons.visibility, size: 20),
                label: const Text('View All Records', style: TextStyle(fontSize: 15)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF667EEA),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetailedAttendance(Map<String, dynamic> subject) {
    final records = List<Map<String, dynamic>>.from(subject['records'] ?? []);
    final percentage = (subject['percentage'] ?? 0.0) as double;

    final Color percentageColor = percentage >= 75
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [percentageColor.withOpacity(0.8), percentageColor],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.book, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject['course_name'] ?? 'Subject Details',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subject['teacher_name'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildHeaderStat('Total', '${subject['total_classes']}'),
                        Container(width: 2, height: 50, color: Colors.white.withOpacity(0.4)),
                        _buildHeaderStat('Present', '${subject['attended_classes']}'),
                        Container(width: 2, height: 50, color: Colors.white.withOpacity(0.4)),
                        _buildHeaderStat(
                          'Absent',
                          '${(subject['total_classes'] ?? 0) - (subject['attended_classes'] ?? 0)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Attendance History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${records.length} records',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No attendance records yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final isPresent = record['status'] == 'present';
                        final date = record['date'] ?? 'Unknown Date';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isPresent
                                  ? Colors.green.withOpacity(0.4)
                                  : Colors.red.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPresent ? Icons.check : Icons.close,
                                color: isPresent ? Colors.green : Colors.red,
                                size: 26,
                              ),
                            ),
                            title: Text(
                              _formatDate(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isPresent ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isPresent ? 'Present' : 'Absent',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateOverallStats() {
    int totalClasses = 0;
    int attendedClasses = 0;

    for (var subject in _enrolledSubjects) {
      totalClasses += (subject['total_classes'] ?? 0) as int;
      attendedClasses += (subject['attended_classes'] ?? 0) as int;
    }

    final percentage =
        totalClasses > 0 ? (attendedClasses / totalClasses * 100) : 0.0;

    return {
      'total': totalClasses,
      'attended': attendedClasses,
      'percentage': percentage,
    };
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('MMM d, y').format(dt);
    } catch (e) {
      return date;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 120, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'No Enrolled Subjects',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Enroll in courses to track your attendance',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FACE REGISTRATION PAGE
// ============================================
class FaceRegistrationPage extends StatefulWidget {
  final int userId;
  final String userName;

  const FaceRegistrationPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<FaceRegistrationPage> createState() => _FaceRegistrationPageState();
}

class _FaceRegistrationPageState extends State<FaceRegistrationPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _faceDetected = false;
  String _instructionText = 'Position your face in the frame';
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        if (faces.isEmpty) {
          setState(() {
            _faceDetected = false;
            _instructionText = 'No face detected. Please face the camera';
          });
        } else if (faces.length > 1) {
          setState(() {
            _faceDetected = false;
            _instructionText = 'Multiple faces detected. Ensure only you are visible';
          });
        } else {
          final face = faces.first;
          
          final headEulerAngleY = face.headEulerAngleY ?? 0;
          final headEulerAngleZ = face.headEulerAngleZ ?? 0;
          
          if (headEulerAngleY.abs() > 10 || headEulerAngleZ.abs() > 15) {
            setState(() {
              _faceDetected = false;
              _instructionText = 'Face the camera directly';
            });
          } else {
            setState(() {
              _faceDetected = true;
              _instructionText = 'Great! Tap to capture';
            });
          }
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final allBytes = <int>[];
      for (final Plane plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }
      final bytes = Uint8List.fromList(allBytes);

      final imageRotation = InputImageRotation.rotation270deg;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  Future<void> _captureFace() async {
    if (!_faceDetected || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please position your face properly first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _cameraController!.stopImageStream();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final XFile imageFile = await _cameraController!.takePicture();
      final bytes = await imageFile.readAsBytes();

      final String base64Image = base64Encode(bytes);

      final faceDescriptor = await _extractFaceDescriptor(bytes);

      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/register-student-face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'face_descriptor': jsonEncode(faceDescriptor),
          'face_image_base64': base64Image,
        }),
      ).timeout(const Duration(seconds: 15));

      Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(data['message'] ?? 'Face registered!')),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to register face');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );

        _cameraController?.startImageStream(_processCameraImage);
      }
    }
  }

  Future<List<double>> _extractFaceDescriptor(Uint8List imageBytes) async {
    final descriptor = List<double>.filled(128, 0.0);
    for (int i = 0; i < 128 && i < imageBytes.length; i++) {
      descriptor[i] = (imageBytes[i] / 255.0) - 0.5;
    }
    return descriptor;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Register Face'),
          backgroundColor: const Color(0xFF11998E),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register Face'),
        backgroundColor: const Color(0xFF11998E),
      ),
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          CustomPaint(
            painter: FaceOverlayPainter(
              faceDetected: _faceDetected,
              screenSize: MediaQuery.of(context).size,
            ),
            child: Container(),
          ),

          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _faceDetected
                    ? Colors.green.withOpacity(0.9)
                    : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _faceDetected ? Icons.check_circle : Icons.info,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _instructionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _captureFace,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _faceDetected
                        ? Colors.green
                        : Colors.grey.shade400,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FACE VERIFICATION PAGE
// ============================================
class FaceVerificationPage extends StatefulWidget {
  final int userId;
  final String userName;
  final Map<String, dynamic> subject;
  final int scheduleId;
  final int sessionId;
  final VoidCallback onAttendanceMarked;

  const FaceVerificationPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.scheduleId,
    required this.sessionId,
    required this.onAttendanceMarked,
  });

  @override
  State<FaceVerificationPage> createState() => _FaceVerificationPageState();
}

class _FaceVerificationPageState extends State<FaceVerificationPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _faceDetected = false;
  String _instructionText = 'Position your face in the frame';
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        if (faces.isEmpty) {
          setState(() {
            _faceDetected = false;
            _instructionText = 'No face detected. Please face the camera';
          });
        } else if (faces.length > 1) {
          setState(() {
            _faceDetected = false;
            _instructionText = 'Multiple faces detected. Ensure only you are visible';
          });
        } else {
          final face = faces.first;
          
          final headEulerAngleY = face.headEulerAngleY ?? 0;
          final headEulerAngleZ = face.headEulerAngleZ ?? 0;
          
          if (headEulerAngleY.abs() > 10 || headEulerAngleZ.abs() > 10) {
            setState(() {
              _faceDetected = false;
              _instructionText = 'Face the camera directly';
            });
          } else {
            setState(() {
              _faceDetected = true;
              _instructionText = 'Great! Tap to verify';
            });
          }
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final allBytes = <int>[];
      for (final Plane plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }
      final bytes = Uint8List.fromList(allBytes);

      final imageRotation = InputImageRotation.rotation270deg;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }


  Future<void> _verifyFace() async {
    if (!_faceDetected || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please position your face properly first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _cameraController!.stopImageStream();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // GET STUDENT'S CURRENT GPS LOCATION
      final position = await _getCurrentLocation();
      if (position == null) {
        Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get your location. Please enable GPS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _cameraController?.startImageStream(_processCameraImage);
        return;
      }

      final XFile imageFile = await _cameraController!.takePicture();
      final bytes = await imageFile.readAsBytes();

      final faceDescriptor = await _extractFaceDescriptor(bytes);

      // SEND WITH GPS COORDINATES
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/mark-face-attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.userId,
          'student_name': widget.userName,
          'schedule_id': widget.scheduleId,
          'session_id': widget.sessionId,
          'face_descriptor': jsonEncode(faceDescriptor),
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 15));

      Navigator.pop(context);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          widget.onAttendanceMarked();
          Navigator.pop(context);
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.lightGreen],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Success!', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['message'] ?? 'Attendance marked successfully!',
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (data['similarity'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.analytics, color: Colors.green),
                          const SizedBox(width: 12),
                          Text(
                            'Match: ${data['similarity']}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Face verification failed');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        _cameraController?.startImageStream(_processCameraImage);
      }
    }
  }
  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<List<double>> _extractFaceDescriptor(Uint8List imageBytes) async {
    final descriptor = List<double>.filled(128, 0.0);
    for (int i = 0; i < 128 && i < imageBytes.length; i++) {
      descriptor[i] = (imageBytes[i] / 255.0) - 0.5;
    }
    return descriptor;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Face Verification'),
          backgroundColor: const Color(0xFF11998E),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Face Verification'),
        backgroundColor: const Color(0xFF11998E),
      ),
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          CustomPaint(
            painter: FaceOverlayPainter(
              faceDetected: _faceDetected,
              screenSize: MediaQuery.of(context).size,
            ),
            child: Container(),
          ),

          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _faceDetected
                    ? Colors.green.withOpacity(0.9)
                    : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _faceDetected ? Icons.check_circle : Icons.info,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _instructionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _verifyFace,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _faceDetected
                        ? Colors.green
                        : Colors.grey.shade400,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FACE OVERLAY PAINTER
// ============================================
class FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;
  final Size screenSize;

  FaceOverlayPainter({
    required this.faceDetected,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = faceDetected
          ? Colors.green.withOpacity(0.3)
          : Colors.orange.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;
    
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2.5),
      paint,
    );

    final cornerPaint = Paint()
      ..color = faceDetected ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final cornerSize = 30.0;
    final corners = [
      [
        Offset(center.dx - radius, center.dy - radius * 1.25),
        Offset(center.dx - radius + cornerSize, center.dy - radius * 1.25),
      ],
      [
        Offset(center.dx - radius, center.dy - radius * 1.25),
        Offset(center.dx - radius, center.dy - radius * 1.25 + cornerSize),
      ],
      [
        Offset(center.dx + radius, center.dy - radius * 1.25),
        Offset(center.dx + radius - cornerSize, center.dy - radius * 1.25),
      ],
      [
        Offset(center.dx + radius, center.dy - radius * 1.25),
        Offset(center.dx + radius, center.dy - radius * 1.25 + cornerSize),
      ],
      [
        Offset(center.dx - radius, center.dy + radius * 1.25),
        Offset(center.dx - radius + cornerSize, center.dy + radius * 1.25),
      ],
      [
        Offset(center.dx - radius, center.dy + radius * 1.25),
        Offset(center.dx - radius, center.dy + radius * 1.25 - cornerSize),
      ],
      [
        Offset(center.dx + radius, center.dy + radius * 1.25),
        Offset(center.dx + radius - cornerSize, center.dy + radius * 1.25),
      ],
      [
        Offset(center.dx + radius, center.dy + radius * 1.25),
        Offset(center.dx + radius, center.dy + radius * 1.25 - cornerSize),
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faceDetected != faceDetected;
  }
}