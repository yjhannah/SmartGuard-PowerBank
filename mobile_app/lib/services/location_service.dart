import 'package:geolocator/geolocator.dart';

class LocationService {
  /// 检查位置权限
  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }

  /// 获取当前位置
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 地址解析在Web平台可能不支持，暂时跳过
      // 如果需要地址信息，可以使用第三方服务或后端API
      String? address;

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'address': address,
        'timestamp': position.timestamp.toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }
}

