import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/network/api_service.dart';

class ActivityChart extends StatefulWidget {
  final String patientId;

  const ActivityChart({super.key, required this.patientId});

  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>>? _records;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final response = await _apiService.get('/health-report/activity/${widget.patientId}');
      setState(() {
        _records = List<Map<String, dynamic>>.from(response['records'] ?? []);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '活动记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_records != null && _records!.isNotEmpty)
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // 活动线条（绿色）
                      LineChartBarData(
                        spots: _generateSpots('activity'),
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                      // 卧床线条（橙色）
                      LineChartBarData(
                        spots: _generateSpots('bed'),
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    // 用药标记点
                    lineTouchData: LineTouchData(enabled: false),
                  ),
                ),
              )
            else
              const Center(child: Text('暂无数据')),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots(String type) {
    final spots = <FlSpot>[];
    for (int i = 0; i < (_records?.length ?? 0); i++) {
      final record = _records![i];
      if (record['activity_type'] == type) {
        spots.add(FlSpot(
          i.toDouble(),
          (record['value'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    }
    return spots;
  }
}

