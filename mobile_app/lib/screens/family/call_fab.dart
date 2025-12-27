import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_service.dart';
import '../../providers/auth_provider.dart';

class CallFAB extends StatelessWidget {
  final String? patientId;

  const CallFAB({super.key, this.patientId});

  void _showCallOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('呼叫值班护工'),
              onTap: () => _callNurse(context),
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('发送消息给护士站'),
              onTap: () => _sendMessage(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callNurse(BuildContext context) async {
    final apiService = ApiService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId ?? 'unknown';
    
    try {
      await apiService.post('/call/nurse', {
        'user_id': userId,
        'patient_id': patientId,
        'call_type': 'nurse',
        'phone_number': '13800138000',
      });
      if (context.mounted) {
        final uri = Uri.parse('tel:13800138000');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法拨打电话')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('呼叫失败: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage(BuildContext context) async {
    final apiService = ApiService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId ?? 'unknown';
    
    try {
      await apiService.post('/call/message', {
        'user_id': userId,
        'patient_id': patientId,
        'call_type': 'message',
        'message_content': '家属发送的消息',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('消息已发送（Demo模式）')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCallOptions(context),
      child: const Icon(Icons.phone),
      tooltip: '联系护工',
    );
  }
}

