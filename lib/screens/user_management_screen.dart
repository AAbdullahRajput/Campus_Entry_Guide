import 'package:flutter/material.dart';
import '../widgets/user_card.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> users = [
    {
      "name": "Ali Khan",
      "email": "ali@student.edu",
      "role": "Student",
      "active": true,
    },
    {
      "name": "Sara Ahmed",
      "email": "sara@teacher.edu",
      "role": "Teacher",
      "active": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          return UserCard(
            user: users[index],
            onEdit: () => _showUserDialog(user: users[index]),
            onDelete: () {
              setState(() {
                users.removeAt(index);
              });
            },
            onToggle: () {
              setState(() {
                users[index]['active'] = !users[index]['active'];
              });
            },
          );
        },
      ),
    );
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final nameController =
        TextEditingController(text: user?['name'] ?? '');
    final emailController =
        TextEditingController(text: user?['email'] ?? '');
    String role = user?['role'] ?? 'Student';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user == null ? "Add User" : "Edit User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            DropdownButtonFormField(
              initialValue: role,
              items: const [
                DropdownMenuItem(value: "Student", child: Text("Student")),
                DropdownMenuItem(value: "Teacher", child: Text("Teacher")),
                DropdownMenuItem(value: "Admin", child: Text("Admin")),
              ],
              onChanged: (value) => role = value!,
              decoration: const InputDecoration(labelText: "Role"),
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
              if (user == null) {
                setState(() {
                  users.add({
                    "name": nameController.text,
                    "email": emailController.text,
                    "role": role,
                    "active": true,
                  });
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
