import 'package:flutter/material.dart';
import '../widgets/report_card.dart';

class ReportsHandlingScreen extends StatefulWidget {
  const ReportsHandlingScreen({super.key});

  @override
  State<ReportsHandlingScreen> createState() => _ReportsHandlingScreenState();
}

class _ReportsHandlingScreenState extends State<ReportsHandlingScreen> {
  final List<Map<String, dynamic>> reports = [
    {"title": "Lost Wallet", "status": "Pending"},
    {"title": "Found Keys", "status": "Resolved"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reports Handling")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          return ReportCard(
            report: reports[index],
            onResolve: () {
              setState(() {
                reports[index]['status'] = "Resolved";
              });
            },
          );
        },
      ),
    );
  }
}
