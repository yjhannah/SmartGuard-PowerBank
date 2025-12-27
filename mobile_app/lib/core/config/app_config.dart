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
}

