import 'package:flutter/material.dart';

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onResolve;

  const ReportCard({
    super.key,
    required this.report,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final isResolved = report['status'] == "Resolved";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.report,
            color: isResolved ? Colors.green : Colors.red),
        title: Text(report['title']),
        subtitle: Text("Status: ${report['status']}"),
        trailing: isResolved
            ? const Icon(Icons.check, color: Colors.green)
            : TextButton(
                onPressed: onResolve,
                child: const Text("Resolve"),
              ),
      ),
    );
  }
}
