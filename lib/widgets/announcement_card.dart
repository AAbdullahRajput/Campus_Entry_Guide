import 'package:flutter/material.dart';

class AnnouncementCard extends StatelessWidget {
  final String text;
  final VoidCallback onDelete;

  const AnnouncementCard({
    super.key,
    required this.text,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.campaign, color: Colors.orange),
        title: Text(text),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
