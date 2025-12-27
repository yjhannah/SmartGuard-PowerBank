import '../core/network/api_service.dart';
import '../core/storage/storage_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _apiService.post('/auth/login', {
      'username': username,
      'password': password,
    });

    if (response['user_id'] != null) {
      // 保存登录信息
      await _storageService.setString('user_id', response['user_id']);
      await _storageService.setString('username', response['username']);
      await _storageService.setString('role', response['role']);
      if (response['token'] != null) {
        await _storageService.setString('token', response['token']);
        _apiService.setToken(response['token']);
      }
      if (response['patient_id'] != null) {
        await _storageService.setString('patient_id', response['patient_id']);
      }
    }

    return response;
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/auth/logout', null);
    } catch (e) {
      // 忽略登出错误
    }
    await _storageService.clear();
    _apiService.setToken(null);
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final userId = _storageService.getString('user_id');
    if (userId == null) {
      throw Exception('未登录');
    }
    return await _apiService.get('/auth/me?user_id=$userId');
  }

  bool isAuthenticated() {
    return _storageService.getString('user_id') != null;
  }

  String? getUserId() {
    return _storageService.getString('user_id');
  }

  String? getUserRole() {
    return _storageService.getString('role');
  }

  String? getPatientId() {
    return _storageService.getString('patient_id');
  }
}

