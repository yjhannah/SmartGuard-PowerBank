# 图片上传URL路径重复问题 - 修复指南

## 问题描述

**错误现象**: URL 路径出现重复 `/api/api/analysis/analyze`，导致 404 错误

**正确路径**: `/api/analysis/analyze`

## 已修复的文件

1. ✅ `lib/services/image_upload_service.dart`
   - 已修正路径：`${AppConfig.apiBaseUrl}/analysis/analyze`
   - 已添加详细日志输出

2. ✅ `lib/services/video_monitoring_service.dart`
   - 已修正路径：`${AppConfig.apiBaseUrl}/analysis/analyze`
   - 已添加调试日志

3. ✅ `lib/core/config/app_config.dart`
   - 配置正确：`apiBaseUrl = 'https://smartguard.gitagent.io/api'`

## 如何让修复生效

### 方法1: 完全重启应用（推荐）

1. **停止应用**
   ```bash
   # 在 Android Studio 或 VS Code 中点击停止按钮
   # 或在终端按 Ctrl+C
   ```

2. **清理构建缓存**
   ```bash
   cd /Users/a1/work/SmartGuard-PowerBank/mobile_app
   flutter clean
   ```

3. **重新获取依赖**
   ```bash
   flutter pub get
   ```

4. **重新运行应用**
   ```bash
   # iOS 模拟器
   flutter run -d iPhone
   
   # Android 模拟器/设备
   flutter run -d android
   
   # Chrome（Web）
   flutter run -d chrome
   ```

### 方法2: 热重启（可能不够）

如果不想完全重新编译，可以尝试热重启（Hot Restart）：

1. 在应用运行时，按 `R` (大写R) 进行热重启
2. 或在 IDE 中点击热重启按钮（⚡图标旁的刷新按钮）

**注意**: 热重启可能不够，因为配置常量需要完全重新编译

### 方法3: 重新构建（最彻底）

```bash
cd /Users/a1/work/SmartGuard-PowerBank/mobile_app

# 完全清理
flutter clean

# 重新获取依赖
flutter pub get

# iOS
flutter build ios
flutter run -d iPhone

# Android
flutter build apk --debug
flutter run -d android

# Web
flutter build web
flutter run -d chrome
```

## 验证修复

### 1. 检查日志输出

应用启动后，上传图片时查看控制台日志，应该看到：

```
[2025-12-27T...] [INFO] [ImageUploadService] ============================================================
[2025-12-27T...] [INFO] [ImageUploadService] 开始上传图片并进行分析
[2025-12-27T...] [INFO] [ImageUploadService] ============================================================
[2025-12-27T...] [INFO] [ImageUploadService] 📋 配置信息:
[2025-12-27T...] [INFO] [ImageUploadService]   AppConfig.baseUrl = https://smartguard.gitagent.io
[2025-12-27T...] [INFO] [ImageUploadService]   AppConfig.apiBaseUrl = https://smartguard.gitagent.io/api
[2025-12-27T...] [INFO] [ImageUploadService] 📋 请求参数:
...
[2025-12-27T...] [INFO] [ImageUploadService] 完整请求URL: https://smartguard.gitagent.io/api/analysis/analyze?patient_id=...
```

### 2. 检查关键信息

**正确的URL应该是**:
```
https://smartguard.gitagent.io/api/analysis/analyze
```

**错误的URL**（如果看到这个说明修复未生效）:
```
https://smartguard.gitagent.io/api/api/analysis/analyze
```

### 3. 检查响应状态码

- ✅ **200**: 上传成功
- ❌ **404**: 路径仍然错误，需要重新编译

## 如果问题仍然存在

### 检查清单

1. ✅ 确认已执行 `flutter clean`
2. ✅ 确认已执行 `flutter pub get`
3. ✅ 确认已完全重启应用（不是热重载）
4. ✅ 检查日志中的 `AppConfig.apiBaseUrl` 值
5. ✅ 检查日志中的 `完整请求URL` 值

### 额外调试

如果上述方法都不行，尝试：

1. **检查 IDE 缓存**
   ```bash
   # 在 Android Studio: File > Invalidate Caches / Restart
   # 在 VS Code: 重启编辑器
   ```

2. **检查设备缓存**
   - iOS: 卸载应用后重新安装
   - Android: 卸载应用后重新安装
   - Web: 清除浏览器缓存（Ctrl+Shift+Delete）

3. **检查是否有多个版本运行**
   ```bash
   # 检查是否有多个 Flutter 进程
   ps aux | grep flutter
   
   # 杀死所有 Flutter 进程
   pkill -f flutter
   ```

4. **检查 build 目录**
   ```bash
   # 完全删除 build 目录
   rm -rf build/
   rm -rf .dart_tool/
   
   # 重新构建
   flutter pub get
   flutter run
   ```

## 日志示例

### 成功的日志（修复后）

```
[2025-12-27T19:30:00.123] [INFO] [ImageUploadService] ============================================================
[2025-12-27T19:30:00.123] [INFO] [ImageUploadService] 开始上传图片并进行分析
[2025-12-27T19:30:00.123] [INFO] [ImageUploadService] ============================================================
[2025-12-27T19:30:00.124] [INFO] [ImageUploadService] 📋 配置信息:
[2025-12-27T19:30:00.124] [INFO] [ImageUploadService]   AppConfig.baseUrl = https://smartguard.gitagent.io
[2025-12-27T19:30:00.124] [INFO] [ImageUploadService]   AppConfig.apiBaseUrl = https://smartguard.gitagent.io/api
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService] 📋 请求参数:
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService]   图片大小: 245.67 KB
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService]   患者ID: 531182d5-4789-4784-93e4-e4e03a147324
[2025-12-27T19:30:00.126] [INFO] [ImageUploadService] 基础URL: https://smartguard.gitagent.io/api/analysis/analyze
[2025-12-27T19:30:00.126] [INFO] [ImageUploadService] 完整请求URL: https://smartguard.gitagent.io/api/analysis/analyze?patient_id=531182d5-4789-4784-93e4-e4e03a147324&timestamp_ms=1766835859063
[2025-12-27T19:30:00.200] [INFO] [ImageUploadService] 请求完成，耗时: 74ms
[2025-12-27T19:30:00.200] [INFO] [ImageUploadService] 响应状态码: 200
[2025-12-27T19:30:00.201] [INFO] [ImageUploadService] ✅ 上传和分析成功，总耗时: 78ms
```

### 失败的日志（修复前）

```
[2025-12-27T19:25:00.123] [INFO] [ImageUploadService] 完整请求URL: https://smartguard.gitagent.io/api/api/analysis/analyze?patient_id=...
[2025-12-27T19:25:00.200] [INFO] [ImageUploadService] 响应状态码: 404
[2025-12-27T19:25:00.200] [ERROR] [ImageUploadService] ❌ 上传失败 (状态码: 404)
```

## 联系支持

如果问题持续存在，请提供以下信息：

1. 完整的日志输出（从开始上传到错误结束）
2. `flutter doctor -v` 的输出
3. 运行的平台（iOS/Android/Web）
4. 使用的设备或模拟器版本

## 修复历史

- **2025-12-27**: 修复 URL 路径重复问题，添加详细日志
- **2025-12-27**: 添加 AppConfig 配置验证日志

