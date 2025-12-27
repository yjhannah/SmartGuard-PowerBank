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

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final responseList = await _apiService.getList('/alerts/family/${widget.patientId}');
      setState(() {
        _alerts = responseList.map((item) => item as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts?.where((a) => a['family_acknowledged'] != 1).length ?? 0;

    return Card(
      child: ExpansionTile(
        leading: unreadCount > 0
            ? Badge(
                label: Text('$unreadCount'),
                child: const Icon(Icons.warning),
              )
            : const Icon(Icons.warning),
        title: const Text('智能告警与事件日志'),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_alerts == null || _alerts!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('暂无告警')),
            )
          else
            ..._alerts!.map((alert) => _buildAlertCard(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String?;
    final color = _getSeverityColor(severity);
    final isAcknowledged = alert['family_acknowledged'] == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: ListTile(
        title: Text(alert['title'] ?? '告警'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['description'] ?? ''),
            if (alert['image_url'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Image.network(
                      alert['image_url'],
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: isAcknowledged
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () => _acknowledgeAlert(alert['alert_id']),
                child: const Text('确认知晓'),
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
          SnackBar(content: Text('确认失败: $e')),
        );
      }
    }
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      builder: (context) => AlertDetailsSheet(alertId: alert['alert_id']),
    );
  }
}

class AlertDetailsSheet extends StatelessWidget {
  final String alertId;

  const AlertDetailsSheet({super.key, required this.alertId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '护士处理日志',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _loadNurseLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('加载失败: ${snapshot.error}');
              }
              final logs = snapshot.data?['logs'] as List? ?? [];
              if (logs.isEmpty) {
                return const Text('暂无处理记录');
              }
              return Column(
                children: logs.map<Widget>((log) {
                  return ListTile(
                    title: Text('${log['action']} - ${log['user']}'),
                    subtitle: Text('${log['time']}\n${log['notes']}'),
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

