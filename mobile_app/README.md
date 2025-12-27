# SmartGuard 移动端应用

Flutter移动端应用，包含病患端和家属端功能。

## 功能特性

### 病患端
- 账号密码登录
- 生成关联二维码（供家属扫描）
- 点滴快打完语音提醒（真实功能）
- 心情不好语音陪伴（Demo）
- 吃药提醒（Demo）
- WebSocket实时接收告警

### 家属端
- 账号密码登录
- 扫描二维码关联病患
- 今日健康简报（AI生成，Demo数据）
- 活动记录曲线（Demo数据）
- 情绪监测仪表盘（Demo数据）
- 智能告警与事件日志（真实功能）
- 一键呼叫护工（Demo模式）

## 项目结构

```
mobile_app/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── app.dart                  # 路由管理
│   ├── core/                     # 核心功能
│   │   ├── config/              # 配置
│   │   ├── network/             # 网络请求
│   │   └── storage/             # 本地存储
│   ├── services/                 # 业务服务
│   │   ├── auth_service.dart
│   │   ├── qrcode_service.dart
│   │   ├── voice_service.dart
│   │   └── websocket_service.dart
│   ├── providers/                # 状态管理
│   │   └── auth_provider.dart
│   └── screens/                  # 界面
│       ├── auth/                 # 登录
│       ├── patient/              # 病患端
│       └── family/               # 家属端
└── pubspec.yaml
```

## 开发环境

1. 安装Flutter SDK (>=3.3.0)
2. 安装依赖：
```bash
cd mobile_app
flutter pub get
```

## 配置

修改 `lib/core/config/app_config.dart` 中的API地址：

```dart
static const String baseUrl = 'http://your-server:8000';
```

## 运行

```bash
flutter run
```

## 依赖说明

- `provider`: 状态管理
- `http`: HTTP请求
- `shared_preferences`: 本地存储
- `qr_flutter`: 二维码生成
- `flutter_tts`: 文本转语音
- `fl_chart`: 图表库
- `web_socket_channel`: WebSocket通信
- `wechat_kit`: 微信SDK（二维码扫描）

## 注意事项

1. 确保后端服务已启动
2. 配置正确的API地址
3. 首次运行需要执行数据库迁移脚本

