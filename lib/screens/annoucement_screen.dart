import 'package:flutter/material.dart';
import '../widgets/announcement_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final List<String> announcements = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Announcements")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAnnouncement,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          return AnnouncementCard(
            text: announcements[index],
            onDelete: () {
              setState(() => announcements.removeAt(index));
            },
          );
        },
      ),
    );
  }

  void _addAnnouncement() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Announcement"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter announcement"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => announcements.add(controller.text));
              Navigator.pop(context);
            },
            child: const Text("Post"),
          ),
        ],
      ),
    );
  }
}
