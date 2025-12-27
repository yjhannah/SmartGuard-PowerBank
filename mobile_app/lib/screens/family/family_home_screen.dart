import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'health_report_card.dart';
import 'activity_chart.dart';
import 'emotion_gauge.dart';
import 'alerts_screen.dart';
import 'call_fab.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  String? _patientId;

  @override
  void initState() {
    super.initState();
    _loadPatientId();
  }

  void _loadPatientId() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // 从关联表中获取患者ID（简化处理，实际应从API获取）
    _patientId = 'patient_id_placeholder';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家属端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
            },
          ),
        ],
      ),
      body: _patientId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HealthReportCard(patientId: _patientId!),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ActivityChart(patientId: _patientId!),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: EmotionGauge(patientId: _patientId!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AlertsScreen(patientId: _patientId!),
                ],
              ),
            ),
      floatingActionButton: CallFAB(patientId: _patientId),
    );
  }
}

