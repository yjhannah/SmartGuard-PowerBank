import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> contacts;
  final Function(Map<String, dynamic>) onContactSelected;

  const ContactListScreen({
    super.key,
    required this.contacts,
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('最近联系人'),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final name = contact['name'] as String? ?? '未知';
          final phone = contact['phone'] as String? ?? '';
          final type = contact['type'] as String? ?? '';
          
          // 根据类型显示图标
          IconData icon;
          Color color;
          if (type == 'nurse') {
            icon = Icons.local_hospital;
            color = Colors.blue;
          } else {
            icon = Icons.person;
            color = Colors.green;
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(phone),
            trailing: const Icon(Icons.phone),
            onTap: () {
              onContactSelected(contact);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}

