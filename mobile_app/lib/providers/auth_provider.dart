import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../core/storage/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  bool _isAuthenticated = false;
  String? _userId;
  String? _username;
  String? _role;
  String? _patientId;
  String? _userType;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get username => _username;
  String? get userRole => _role;
  String? get patientId => _patientId;
  String? get userType => _userType;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    await _storageService.init();
    _isAuthenticated = _authService.isAuthenticated();
    if (_isAuthenticated) {
      _userId = _authService.getUserId();
      _username = _storageService.getString('username');
      _role = _authService.getUserRole();
      _patientId = _authService.getPatientId();
      _userType = _authService.getUserType();
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _authService.login(username, password);
      _isAuthenticated = true;
      _userId = response['user_id'];
      _username = response['username'];
      _role = response['role'];
      _patientId = response['patient_id'];
      _userType = response['user_type'];
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _userId = null;
    _username = null;
    _role = null;
    _patientId = null;
    _userType = null;
    notifyListeners();
  }
}

