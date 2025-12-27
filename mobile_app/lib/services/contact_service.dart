import '../core/storage/storage_service.dart';
import 'dart:convert';

class ContactService {
  final StorageService _storageService = StorageService();

  /// 初始化存储服务
  Future<void> init() async {
    await _storageService.init();
  }

  /// 获取所有联系人
  Future<List<Map<String, dynamic>>> getContacts() async {
    await init();
    final contactsJson = _storageService.getString('emergency_contacts');
    if (contactsJson == null || contactsJson.isEmpty) {
      // 返回默认联系人（护士站）
      return [
        {
          'name': '护士站',
          'phone': '120', // 默认电话，用户可修改
          'type': 'nurse',
          'isEmergency': true,
        }
      ];
    }
    
    try {
      final List<dynamic> contacts = jsonDecode(contactsJson);
      return contacts.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 保存联系人列表
  Future<void> saveContacts(List<Map<String, dynamic>> contacts) async {
    await init();
    await _storageService.setString('emergency_contacts', jsonEncode(contacts));
  }

  /// 添加联系人
  Future<void> addContact(Map<String, dynamic> contact) async {
    final contacts = await getContacts();
    contacts.add(contact);
    await saveContacts(contacts);
  }

  /// 删除联系人
  Future<void> removeContact(int index) async {
    final contacts = await getContacts();
    if (index >= 0 && index < contacts.length) {
      contacts.removeAt(index);
      await saveContacts(contacts);
    }
  }

  /// 更新联系人
  Future<void> updateContact(int index, Map<String, dynamic> contact) async {
    final contacts = await getContacts();
    if (index >= 0 && index < contacts.length) {
      contacts[index] = contact;
      await saveContacts(contacts);
    }
  }

  /// 获取紧急联系人（最多3位家属 + 护士站）
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final contacts = await getContacts();
    // 筛选紧急联系人（isEmergency为true的，最多3位家属）
    final emergencyContacts = contacts.where((c) => c['isEmergency'] == true).toList();
    
    // 确保护士站在第一位
    final nurseStation = emergencyContacts.firstWhere(
      (c) => c['type'] == 'nurse',
      orElse: () => {
        'name': '护士站',
        'phone': '120',
        'type': 'nurse',
        'isEmergency': true,
      },
    );
    
    final familyContacts = emergencyContacts.where((c) => c['type'] == 'family').take(3).toList();
    
    return [nurseStation, ...familyContacts];
  }
}

