import 'dart:convert';

class AppConfig {
  // 生产环境配置
  static const String baseUrl = 'https://smartguard.gitagent.io';
  static const String apiBaseUrl = '$baseUrl/api';
  static const String wsBaseUrl = 'wss://smartguard.gitagent.io/ws';
  
  // 开发环境配置（本地测试时使用）
  // static const String baseUrl = 'http://localhost:8000';
  // static const String apiBaseUrl = '$baseUrl/api';
  // static const String wsBaseUrl = 'ws://localhost:8000/ws';
  
  static void init() {
    // 初始化配置
    // 可以在这里加载环境变量或配置文件
  }
  
  /// 将COS图片URL转换为代理URL（解决CORS跨域问题）
  /// 
  /// 如果URL是腾讯云COS地址，则通过后端代理访问
  /// 否则直接返回原URL
  static String getProxiedImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '';
    }
    
    // 检查是否为腾讯云COS地址
    final cosDomains = [
      'cos.na-siliconvalley.myqcloud.com',
      'cos.ap-beijing.myqcloud.com',
      'cos.ap-shanghai.myqcloud.com',
      'cos.ap-guangzhou.myqcloud.com',
      'cos.ap-chengdu.myqcloud.com',
      'portraitquest-1253756459.cos.na-siliconvalley.myqcloud.com',
    ];
    
    final isCosUrl = cosDomains.any((domain) => originalUrl.contains(domain));
    
    if (isCosUrl) {
      // 通过后端代理访问
      final encodedUrl = Uri.encodeComponent(originalUrl);
      return '$apiBaseUrl/images/proxy?url=$encodedUrl';
    }
    
    // 非COS地址直接返回
    return originalUrl;
  }
}

