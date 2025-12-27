# 患者端图片上传功能 - 完整实现总结

## 功能概览

为移动端患者端添加了监护现场图片上传功能，支持拍照/选择图片、AI分析、智能警报和结果展示。

---

## 新增文件

### 1. 服务层
- ✅ `lib/services/image_upload_service.dart` - 图片上传和分析服务

### 2. 文档
- ✅ `URL_FIX_GUIDE.md` - URL路径修复指南
- ✅ `FIXES_APPLIED.md` - 已应用修复说明
- ✅ `ALERT_FEATURES.md` - 警报功能说明
- ✅ `UPLOAD_FEATURE_SUMMARY.md` - 本文档

### 3. 脚本
- ✅ `rebuild_app.sh` - 一键重新编译脚本

---

## 修改文件

### 1. `lib/screens/patient/patient_home_screen.dart`

**新增方法**:
- `_handleImageUpload()` - 图片上传处理
- `_handleAnalysisResult()` - 分析结果处理
- `_triggerCriticalAlert()` - 触发紧急警报
- `_triggerWarningAlert()` - 触发警告警报
- `_triggerNormalAlert()` - 触发正常提示
- `_buildAlertMessage()` - 构建警报消息
- `_showAnalysisResultDialog()` - 显示分析结果对话框
- `_buildDetectionItem()` - 构建检测项显示

**新增变量**:
- `_imageUploadService` - 图片上传服务实例
- `_imagePicker` - 图片选择器实例
- `_isUploading` - 上传状态
- `_uploadStatus` - 上传状态文本

**界面修改**:
- 顶部栏添加相机图标按钮（上传图片）
- 上传时显示加载动画

### 2. `pubspec.yaml`

**新增依赖**:
```yaml
image_picker: ^1.0.7  # 图片选择
```

**已有依赖**（复用）:
```yaml
vibration: ^1.8.4     # 振动功能
flutter_tts: ^4.0.2   # 语音播报
```

---

## 功能流程

### 完整流程图

```
用户点击相机图标
  ↓
显示选择对话框
  ├─ 拍照
  └─ 从相册选择
  ↓
选择/拍摄图片
  ↓
读取图片数据
  ↓
显示上传状态（加载动画）
  ↓
调用 uploadAndAnalyze()
  ├─ 构建URL和参数
  ├─ 创建multipart请求
  ├─ 添加图片文件
  ├─ 添加认证token
  └─ 发送到后端 /api/analysis/analyze
  ↓
后端AI分析
  ├─ 跌倒检测
  ├─ 离床监测
  ├─ 活动分析
  ├─ 面部分析（表情+肤色）
  └─ 吊瓶监测
  ↓
返回分析结果
  ↓
前端处理结果 _handleAnalysisResult()
  ├─ 判断整体状态
  ├─ 触发相应警报
  │   ├─ 紧急：长振动 + 语音 + 红色提示
  │   ├─ 警告：短振动 + 语音 + 橙色提示
  │   └─ 正常：绿色提示
  └─ 显示详情对话框
      ├─ 跌倒检测结果
      ├─ 离床监测结果
      ├─ 活动分析结果
      ├─ 面部分析结果
      ├─ 吊瓶监测结果
      └─ 建议操作
```

---

## 警报级别对应关系

| 整体状态 | 振动模式 | 语音播报 | 视觉提示 | 持续时间 |
|---------|---------|---------|---------|---------|
| 紧急 | 长振动（模式） | "紧急警报！..." | 红色 | 5秒 |
| 注意 | 短振动 | "注意：..." | 橙色 | 3秒 |
| 正常 | 无 | 无 | 绿色 | 2秒 |

---

## 检测项说明

### 1. 跌倒检测 (fall)
```json
{
  "detected": true/false,
  "confidence": 0.95,
  "description": "具体描述",
  "severity": "紧急/高/中/低"
}
```

### 2. 离床监测 (bed_exit)
```json
{
  "patient_in_bed": true/false,
  "location": "床上/卫生间/房间",
  "duration_estimate": "估算离床时长"
}
```

### 3. 活动分析 (activity)
```json
{
  "type": "正常/挣扎/僵直/爬行/无活动",
  "description": "活动描述",
  "abnormal": true/false
}
```

### 4. 面部分析 (facial_analysis)
```json
{
  "skin_color": "正常/苍白/潮红/紫绀/异常",
  "expression": "中性/痛苦/恐惧/焦虑/担忧/沮丧/悲伤",
  "emotion_confidence": 0.85,
  "description": "详细描述"
}
```

### 5. 吊瓶监测 (iv_drip)
```json
{
  "detected": true/false,
  "fluid_level": "满/半满/袋子空/已打完",
  "bag_empty": true/false,
  "completely_empty": true/false,
  "needs_replacement": true/false,
  "needs_emergency_alert": true/false,
  "needs_phone_call": true/false,
  "description": "详细描述"
}
```

---

## 日志示例

### 上传成功的完整日志

```
[2025-12-27T19:30:00.123] [INFO] [ImageUploadService] ============================================================
[2025-12-27T19:30:00.123] [INFO] [ImageUploadService] 开始上传图片并进行分析
[2025-12-27T19:30:00.123] [INFO] [ImageUploadService] ============================================================
[2025-12-27T19:30:00.124] [INFO] [ImageUploadService] 📋 配置信息:
[2025-12-27T19:30:00.124] [INFO] [ImageUploadService]   AppConfig.baseUrl = https://smartguard.gitagent.io
[2025-12-27T19:30:00.124] [INFO] [ImageUploadService]   AppConfig.apiBaseUrl = https://smartguard.gitagent.io/api
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService] 📋 请求参数:
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService]   图片大小: 245.67 KB (251567 bytes)
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService]   患者ID: 531182d5-4789-4784-93e4-e4e03a147324
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService]   摄像头ID: 未提供
[2025-12-27T19:30:00.125] [INFO] [ImageUploadService]   时间戳: 1766835859063
[2025-12-27T19:30:00.126] [INFO] [ImageUploadService] 基础URL: https://smartguard.gitagent.io/api/analysis/analyze
[2025-12-27T19:30:00.126] [INFO] [ImageUploadService] 完整请求URL: https://smartguard.gitagent.io/api/analysis/analyze?patient_id=531182d5-4789-4784-93e4-e4e03a147324&timestamp_ms=1766835859063
[2025-12-27T19:30:00.126] [INFO] [ImageUploadService] 查询参数: {patient_id: 531182d5-4789-4784-93e4-e4e03a147324, timestamp_ms: 1766835859063}
[2025-12-27T19:30:00.127] [INFO] [ImageUploadService] 已添加图片文件: monitoring_1766835859063.jpg
[2025-12-27T19:30:00.127] [INFO] [ImageUploadService] 已添加Authorization token: sk-abc123...
[2025-12-27T19:30:00.128] [INFO] [ImageUploadService] 请求头: {Authorization: Bearer sk-...}
[2025-12-27T19:30:00.128] [INFO] [ImageUploadService] 正在发送请求...
[2025-12-27T19:30:00.202] [INFO] [ImageUploadService] 请求完成，耗时: 74ms
[2025-12-27T19:30:00.202] [INFO] [ImageUploadService] 响应状态码: 200
[2025-12-27T19:30:00.202] [INFO] [ImageUploadService] 响应头: {content-type: application/json, ...}
[2025-12-27T19:30:00.202] [INFO] [ImageUploadService] 响应体大小: 1234 bytes
[2025-12-27T19:30:00.203] [INFO] [ImageUploadService] 分析结果:
[2025-12-27T19:30:00.203] [INFO] [ImageUploadService]   - 整体状态: 紧急
[2025-12-27T19:30:00.203] [INFO] [ImageUploadService]   - 状态: success
[2025-12-27T19:30:00.203] [INFO] [ImageUploadService]   - 结果ID: abc-def-123
[2025-12-27T19:30:00.203] [INFO] [ImageUploadService]   - 检测项: fall, bed_exit, facial_analysis, iv_drip
[2025-12-27T19:30:00.204] [INFO] [ImageUploadService] ✅ 上传和分析成功，总耗时: 81ms
[2025-12-27T19:30:00.204] [INFO] [ImageUploadService] ============================================================
[2025-12-27T19:30:00.205] [INFO] [分析结果] 整体状态: 紧急
[2025-12-27T19:30:00.205] [INFO] [分析结果] 检测项: fall, bed_exit, facial_analysis, iv_drip
[2025-12-27T19:30:00.206] [INFO] [警报] 触发紧急警报
[2025-12-27T19:30:00.706] [INFO] [振动] 紧急振动完成
[2025-12-27T19:30:00.707] [INFO] [语音] 播报: 紧急警报！检测到跌倒、检测到痛苦表情
```

---

## 与PC端对比

| 功能 | PC端（monitor.html） | 移动端（患者端） |
|------|---------------------|-----------------|
| 图片上传 | ✅ 拖拽/点击上传 | ✅ 拍照/相册选择 |
| AI分析 | ✅ 支持 | ✅ 支持 |
| 结果展示 | ✅ 卡片+表格 | ✅ 对话框详情 |
| 智能采样 | ✅ 支持 | ❌ 暂不支持 |
| 批量上传 | ✅ 支持 | ❌ 暂不支持 |
| 振动反馈 | ❌ 不支持 | ✅ 支持 |
| 语音播报 | ❌ 不支持 | ✅ 支持 |
| 实时上传 | ✅ 视频流 | ✅ 定时拍照 |
| 告警通知 | ✅ WebSocket | ✅ WebSocket |

---

## 技术栈

### 后端API
- **端点**: `POST /api/analysis/analyze`
- **参数**: `patient_id`, `camera_id`, `timestamp_ms`
- **格式**: `multipart/form-data`
- **认证**: Bearer Token

### 前端技术
- **框架**: Flutter
- **状态管理**: Provider
- **网络请求**: http package
- **图片选择**: image_picker
- **振动**: vibration
- **语音**: flutter_tts

---

## 使用说明

### 患者端操作步骤

1. **登录患者账号**
   - 用户名: `patient001`
   - 密码: `patient123`

2. **进入患者端界面**
   - 应自动识别为患者端
   - 显示时间、用药提醒等

3. **上传监护图片**
   - 点击顶部左侧的相机图标
   - 选择"拍照"或"从相册选择"
   - 等待上传和分析

4. **查看分析结果**
   - 自动显示警报提示
   - 点击查看详情对话框
   - 查看各项检测结果

### 调试和测试

1. **查看日志**
   - Flutter 控制台会显示详细日志
   - 包括URL、参数、响应等

2. **测试不同场景**
   - 正常场景：一切正常的病房
   - 警告场景：患者离床、吊瓶半空
   - 紧急场景：跌倒、痛苦表情、吊瓶打完

3. **验证警报**
   - 检查振动是否触发
   - 检查语音是否播报
   - 检查提示颜色是否正确

---

## 部署清单

### 本地测试

```bash
cd /Users/a1/work/SmartGuard-PowerBank/mobile_app

# 1. 清理缓存
flutter clean

# 2. 获取依赖
flutter pub get

# 3. 运行（选择设备）
flutter run

# 或使用脚本
bash rebuild_app.sh
```

### 生产环境

```bash
# Android APK
flutter build apk --release

# iOS IPA
flutter build ios --release

# Web
flutter build web --release
```

---

## 权限配置

### Android 权限

编辑 `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- 振动权限 -->
    <uses-permission android:name="android.permission.VIBRATE"/>
    
    <!-- 相机权限 -->
    <uses-permission android:name="android.permission.CAMERA"/>
    
    <!-- 存储权限（读取相册） -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    
    <!-- Android 13+ 图片权限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
</manifest>
```

### iOS 权限

编辑 `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- 相机权限 -->
    <key>NSCameraUsageDescription</key>
    <string>SmartGuard需要使用相机拍摄监护现场照片进行AI分析</string>
    
    <!-- 相册权限 -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>SmartGuard需要访问相册选择监护照片进行AI分析</string>
</dict>
```

---

## 测试账号

### 患者端账号

| 用户名 | 密码 | 关联患者 | 用途 |
|--------|------|---------|------|
| patient001 | patient123 | 张三 (P001) | 患者1端测试 |
| patient002 | patient123 | 李四 (P002) | 患者2端测试 |

### 家属端账号

| 用户名 | 密码 | 关联患者 | 用途 |
|--------|------|---------|------|
| family001 | family123 | 张三 (P001) | 家属1端测试 |
| family002 | family123 | 李四 (P002) | 家属2端测试 |

---

## 功能验证清单

### 图片上传功能
- [ ] 点击相机图标显示选择对话框
- [ ] 拍照功能正常
- [ ] 相册选择功能正常
- [ ] 上传时显示加载动画
- [ ] 日志输出完整URL（无重复 /api）

### 分析结果
- [ ] 上传成功后收到分析结果
- [ ] 日志显示分析结果关键信息
- [ ] 正确识别整体状态

### 警报功能
- [ ] 紧急状态：长振动 + 语音 + 红色提示
- [ ] 警告状态：短振动 + 语音 + 橙色提示
- [ ] 正常状态：绿色提示（无振动）

### 详情对话框
- [ ] 自动弹出（紧急状态）或点击查看
- [ ] 显示所有检测项结果
- [ ] 显示建议操作

### 消息通知
- [ ] 后端生成告警记录
- [ ] WebSocket推送给家属端
- [ ] 护士端收到通知

---

## 故障排除

### 问题1: URL仍然是 /api/api/...

**原因**: 应用未重新编译  
**解决**: 执行 `flutter clean` 后重新运行

### 问题2: 振动不工作

**原因**: 权限未配置或设备不支持  
**解决**: 
1. 检查AndroidManifest.xml权限
2. 检查设备设置
3. 查看日志错误信息

### 问题3: 上传后无反应

**原因**: 网络错误或后端异常  
**解决**: 
1. 检查控制台日志
2. 查看响应状态码
3. 确认后端服务正常

### 问题4: 详情对话框不显示

**原因**: 数据格式不匹配  
**解决**: 
1. 查看日志中的分析结果
2. 检查后端返回的JSON格式
3. 确认所有检测项都存在

---

## 下一步优化

### 功能增强
- [ ] 添加智能采样（避免重复分析相似画面）
- [ ] 添加批量上传（一次上传多张）
- [ ] 添加分析历史记录查看
- [ ] 添加图片缓存（本地保存上传的图片）

### UI优化
- [ ] 上传进度条（百分比显示）
- [ ] 分析结果卡片（更美观的展示）
- [ ] 动画效果（淡入淡出）
- [ ] 暗黑模式支持

### 性能优化
- [ ] 图片压缩优化（减少上传时间）
- [ ] 离线缓存（网络恢复后自动上传）
- [ ] 上传队列（避免并发冲突）

---

## 相关文档

- 📖 [URL_FIX_GUIDE.md](./URL_FIX_GUIDE.md) - URL修复指南
- 📖 [FIXES_APPLIED.md](./FIXES_APPLIED.md) - 已应用修复
- 📖 [ALERT_FEATURES.md](./ALERT_FEATURES.md) - 警报功能说明
- 📖 [README.md](./README.md) - 项目说明
- 📖 [QUICK_START.md](./QUICK_START.md) - 快速开始

---

**功能开发完成，等待测试验证** ✅

**最后更新**: 2025-12-27

