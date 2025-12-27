# Flutter移动端快速启动指南

## 前置条件

1. Flutter SDK >= 3.3.0
2. 后端服务已启动（端口8000）
3. 数据库迁移已完成

## 快速启动步骤

### 1. 安装Flutter依赖

```bash
cd mobile_app
flutter pub get
```

### 2. 配置API地址

编辑 `lib/core/config/app_config.dart`，修改API地址：

```dart
static const String baseUrl = 'http://your-server-ip:8000';
```

### 3. 运行应用

```bash
# iOS模拟器
flutter run -d ios

# Android模拟器
flutter run -d android

# 连接的真机
flutter run
```

## 测试账号

使用后端初始化脚本创建的测试账号：

- **病患用户**: 需要先在数据库中创建patient用户并关联patient_id
- **家属用户**: 
  - 用户名: `family001`
  - 密码: `family123`

## 功能测试清单

### 病患端
- [ ] 登录功能
- [ ] 生成二维码
- [ ] 接收WebSocket推送
- [ ] 语音提醒播放

### 家属端
- [ ] 登录功能
- [ ] 扫描二维码关联病患
- [ ] 查看健康简报
- [ ] 查看活动记录图表
- [ ] 查看情绪监测
- [ ] 查看告警列表
- [ ] 确认告警
- [ ] 一键呼叫功能

## 常见问题

### 1. 连接后端失败

检查：
- 后端服务是否运行
- API地址配置是否正确
- 网络连接是否正常

### 2. WebSocket连接失败

检查：
- WebSocket地址配置
- 后端WebSocket服务是否正常
- 用户ID是否正确

### 3. 二维码扫描失败

检查：
- 相机权限是否授予
- 二维码是否过期（24小时有效期）
- 网络连接是否正常

