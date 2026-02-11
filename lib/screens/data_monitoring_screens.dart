import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';

class DataMonitoringScreen extends StatelessWidget {
  const DataMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Data Monitoring")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: const [
            StatCard(title: "Total Users", value: "1200", icon: Icons.people),
            StatCard(title: "Active Users", value: "860", icon: Icons.check),
            StatCard(title: "Reports", value: "145", icon: Icons.report),
            StatCard(title: "Announcements", value: "35", icon: Icons.announcement),
          ],
        ),
      ),
    );
  }
}
