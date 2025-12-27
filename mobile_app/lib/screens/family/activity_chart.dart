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

  // 配色方案
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);
  static const Color _accentBlue = Color(0xFF90CAF9);

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final response = await _apiService.get('/health-report/activity/${widget.patientId}');
      if (mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(response['records'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '活动记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
                  ),
                ),
              )
            else if (_records != null && _records!.isNotEmpty)
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: _hintColor.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // 活动线条（绿色）
                      LineChartBarData(
                        spots: _generateSpots('activity'),
                        isCurved: true,
                        color: const Color(0xFF66BB6A),
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF66BB6A).withOpacity(0.1),
                        ),
                      ),
                      // 卧床线条（橙色）
                      LineChartBarData(
                        spots: _generateSpots('bed'),
                        isCurved: true,
                        color: const Color(0xFFFFB74D),
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFFFFB74D).withOpacity(0.1),
                        ),
                      ),
                    ],
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    '暂无数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: _hintColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
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
    // 如果没有数据，返回示例数据
    if (spots.isEmpty) {
      return [
        const FlSpot(0, 30),
        const FlSpot(1, 40),
        const FlSpot(2, 35),
        const FlSpot(3, 50),
        const FlSpot(4, 45),
      ];
    }
    return spots;
  }
}
