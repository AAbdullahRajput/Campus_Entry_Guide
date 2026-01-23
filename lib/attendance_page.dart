import 'package:flutter/material.dart';

class AttendanceHomePage extends StatefulWidget {
  final String role; // Required role parameter
  const AttendanceHomePage({super.key, required this.role});

  @override
  _AttendanceHomePageState createState() => _AttendanceHomePageState();
}


class _AttendanceHomePageState extends State<AttendanceHomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'student') {
      _selectedIndex = 1; // default to student view
    }
  }

  final List<Widget> _teacherPages = [
    TeacherMarkAttendancePage(),
    TeacherViewAttendancePage(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isTeacher = widget.role == 'teacher';
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Module (${widget.role.toUpperCase()})'),
        centerTitle: true,
      ),
      body: isTeacher
          ? _teacherPages[_selectedIndex]
          : StudentAttendancePage(), // only student view for students
      bottomNavigationBar: isTeacher
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: Colors.indigo,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.check_circle_outline),
                  label: 'Mark Attendance',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.visibility),
                  label: 'View Attendance',
                ),
              ],
            )
          : null,
    );
  }
}

// ---------------- Teacher Pages ----------------
class TeacherMarkAttendancePage extends StatelessWidget {
  const TeacherMarkAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mark Attendance',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade200,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text('Student ${index + 1}'),
                    subtitle: Text('Roll No: ${100 + index}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // Placeholder for AI face recognition
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Attendance marked for Student ${index + 1}')),
                        );
                      },
                      child: const Text('Mark'),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.camera_alt),
            label: const Text('Start Face Recognition'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.indigo,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherViewAttendancePage extends StatelessWidget {
  const TeacherViewAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          int attendance = 80 + index; // Example
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade200,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text('Student ${index + 1}'),
              subtitle: Text('Attendance: ${attendance.toInt()}%'),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Student Page ----------------
class StudentAttendancePage extends StatelessWidget {
  const StudentAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    double attendancePercent = 90; // Example

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Your Attendance',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: attendancePercent / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 7, 245, 114)),
                ),
              ),
              Text(
                '${attendancePercent.toInt()}%',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.info, color: Colors.indigo),
              title: Text('Classes Attended'),
              subtitle: Text('17 out of 20 classes'),
            ),
          ),
        ],
      ),
    );
  }
}
