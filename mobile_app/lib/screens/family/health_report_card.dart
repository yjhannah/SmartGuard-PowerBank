import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_service.dart';

class HealthReportCard extends StatefulWidget {
  final String patientId;

  const HealthReportCard({super.key, required this.patientId});

  @override
  State<HealthReportCard> createState() => _HealthReportCardState();
}

class _HealthReportCardState extends State<HealthReportCard> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final response = await _apiService.get('/health-report/daily/${widget.patientId}');
      setState(() {
        _report = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy年MM月dd日').format(DateTime.now());

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日健康简报',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  today,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_report != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _report!['status_icon'] ?? '✅',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _report!['summary_text'] ?? '暂无数据',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              )
            else
              const Text('暂无数据'),
          ],
        ),
      ),
    );
  }
}

