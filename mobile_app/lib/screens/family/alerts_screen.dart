import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/network/api_service.dart';

class AlertsScreen extends StatefulWidget {
  final String patientId;

  const AlertsScreen({super.key, required this.patientId});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>>? _alerts;
  bool _isLoading = true;
  bool _isExpanded = false;

  // 配色方案
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);
  static const Color _accentBlue = Color(0xFF90CAF9);

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final responseList = await _apiService.getList('/alerts/family/${widget.patientId}');
      if (mounted) {
        setState(() {
          _alerts = responseList.map((item) => item as Map<String, dynamic>).toList();
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

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFE53935);
      case 'high':
        return const Color(0xFFFF7043);
      case 'medium':
        return const Color(0xFFFFCA28);
      default:
        return _hintColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts?.where((a) => a['family_acknowledged'] != 1).length ?? 0;

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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          leading: unreadCount > 0
              ? Badge(
                  label: Text(
                    '$unreadCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: const Color(0xFFE53935),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: _hintColor,
                  ),
                )
              : Icon(
                  Icons.warning_amber_rounded,
                  color: _hintColor,
                ),
          title: const Text(
            '智能告警与事件日志',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
                  ),
                ),
              )
            else if (_alerts == null || _alerts!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    '暂无告警',
                    style: TextStyle(
                      fontSize: 14,
                      color: _hintColor.withOpacity(0.8),
                    ),
                  ),
                ),
              )
            else
              ..._alerts!.map((alert) => _buildAlertCard(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String?;
    final color = _getSeverityColor(severity);
    final isAcknowledged = alert['family_acknowledged'] == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF5F7FA),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          alert['title'] ?? '告警',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              alert['description'] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: _hintColor,
              ),
            ),
            if (alert['image_url'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Image.network(
                      alert['image_url'],
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 80,
                          color: _hintColor.withOpacity(0.1),
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: _hintColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: isAcknowledged
            ? const Icon(Icons.check_circle, color: Color(0xFF66BB6A))
            : TextButton(
                onPressed: () => _acknowledgeAlert(alert['alert_id']),
                style: TextButton.styleFrom(
                  foregroundColor: _accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  '确认知晓',
                  style: TextStyle(fontSize: 13),
                ),
              ),
        onTap: () => _showAlertDetails(alert),
      ),
    );
  }

  Future<void> _acknowledgeAlert(String alertId) async {
    try {
      await _apiService.post('/alerts/$alertId/acknowledge-family?user_id=${widget.patientId}', null);
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('确认失败: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AlertDetailsSheet(alertId: alert['alert_id']),
    );
  }
}

class AlertDetailsSheet extends StatelessWidget {
  final String alertId;

  // 配色方案
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);
  static const Color _accentBlue = Color(0xFF90CAF9);

  const AlertDetailsSheet({super.key, required this.alertId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖动条
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _hintColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '护士处理日志',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _loadNurseLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  '加载失败: ${snapshot.error}',
                  style: TextStyle(color: _hintColor),
                );
              }
              final logs = snapshot.data?['logs'] as List? ?? [];
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      '暂无处理记录',
                      style: TextStyle(color: _hintColor),
                    ),
                  ),
                );
              }
              return Column(
                children: logs.map<Widget>((log) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log['action']} - ${log['user']}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${log['time']}\n${log['notes']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hintColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadNurseLogs() async {
    final apiService = ApiService();
    return await apiService.get('/alerts/$alertId/nurse-logs');
  }
}
