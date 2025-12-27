import '../core/network/api_service.dart';

class QRCodeService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> generateQRCode(String patientId) async {
    return await _apiService.get('/qrcode/generate/$patientId');
  }

  Future<Map<String, dynamic>> scanQRCode(String token, String userId) async {
    return await _apiService.post('/qrcode/scan', {
      'token': token,
      'user_id': userId,
    });
  }

  Future<Map<String, dynamic>> getQRCodeStatus(String patientId) async {
    return await _apiService.get('/qrcode/status/$patientId');
  }
}

