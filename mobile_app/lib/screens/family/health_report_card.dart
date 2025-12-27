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

  // 配色方案
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final response = await _apiService.get('/health-report/daily/${widget.patientId}');
      if (mounted) {
        setState(() {
          _report = response;
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
    final today = DateFormat('yyyy年MM月dd日', 'zh_CN').format(DateTime.now());

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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日健康简报',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                Text(
                  today,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF90CAF9)),
                  ),
                ),
              )
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
                      style: const TextStyle(
                        fontSize: 15,
                        color: _textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                '暂无数据',
                style: TextStyle(
                  fontSize: 15,
                  color: _hintColor.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
