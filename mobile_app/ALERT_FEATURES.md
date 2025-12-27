# 患者端图片上传分析结果和警报功能

## 功能概述

患者端上传监护现场图片后，系统会自动：
1. ✅ 展示详细的AI分析结果
2. ✅ 根据严重程度触发不同级别的警报
3. ✅ 支持振动反馈
4. ✅ 支持语音播报
5. ✅ 显示结果详情对话框

---

## 功能详情

### 1. 分析结果处理流程

```
上传图片
  ↓
后端AI分析
  ↓
返回分析结果 {
  overall_status: '正常'/'注意'/'紧急'
  detections: { ... }
  alert_message: '...'
}
  ↓
前端根据状态触发不同警报
  ↓
显示分析结果详情
```

### 2. 三级警报系统

#### 🚨 紧急警报（overall_status = '紧急'）

**触发条件**:
- 检测到跌倒
- 检测到痛苦/恐惧表情
- 吊瓶完全打完
- 其他紧急情况

**警报方式**:
1. **长振动**: 500ms-200ms-500ms-200ms-500ms (模式振动)
2. **语音播报**: "紧急警报！[具体情况]"
3. **红色提示**: 5秒持续显示，可查看详情
4. **详情对话框**: 自动弹出分析结果

**示例消息**:
```
⚠️ 紧急警报：检测到跌倒、检测到痛苦表情
```

#### ⚠️ 警告警报（overall_status = '注意'）

**触发条件**:
- 患者离床
- 吊瓶袋子已空（但滴液管还有液体）
- 检测到担忧/沮丧表情
- 其他需要注意的情况

**警报方式**:
1. **短振动**: 300ms
2. **语音播报**: "注意：[具体情况]"
3. **橙色提示**: 3秒显示
4. **详情对话框**: 点击后查看

**示例消息**:
```
⚠️ 患者已离床、吊瓶袋子已空
```

#### ✅ 正常提示（overall_status = '正常'）

**触发条件**:
- 所有检测项正常
- 无异常情况

**警报方式**:
1. **无振动**
2. **绿色提示**: 2秒显示
3. **详情对话框**: 点击后查看

**示例消息**:
```
✅ 分析完成，一切正常
```

### 3. 分析结果详情对话框

#### 显示内容

对话框会展示所有检测项的详细结果：

1. **跌倒检测**
   - 描述：患者当前状态
   - 示例："未检测到跌倒，患者处于床上，姿势正常"

2. **离床监测**
   - 描述：患者位置
   - 示例："患者在床上" 或 "患者已离床，位于房间"

3. **活动分析**
   - 描述：活动类型
   - 示例："正常活动，无异常挣扎" 或 "长时间僵直不动"

4. **面部分析**
   - 描述：表情和肤色
   - 示例："中性表情，面色正常" 或 "检测到痛苦表情，面色苍白"

5. **吊瓶监测**
   - 描述：液体剩余量
   - 示例："吊瓶基本充满，上半部分有液体，判定为满" 或 "袋子上半部分已空，需要警告"

#### 对话框示例

```
┌─────────────────────────────┐
│ ⚠️ 分析结果 - 紧急          │
├─────────────────────────────┤
│ 跌倒检测                    │
│ 未检测到跌倒                │
│                              │
│ 离床监测                    │
│ 患者在床上                  │
│                              │
│ 面部分析                    │
│ 检测到痛苦表情，眉头紧锁   │
│                              │
│ 吊瓶监测                    │
│ 吊瓶已打完，需要更换       │
│                              │
│ 建议操作: 立即告警          │
├─────────────────────────────┤
│              [关闭]         │
└─────────────────────────────┘
```

---

## 代码实现

### 核心方法

#### 1. `_handleAnalysisResult()` - 处理分析结果

```dart
Future<void> _handleAnalysisResult(Map<String, dynamic>? analysisData) async {
  final overallStatus = analysisData['overall_status'];
  
  if (overallStatus == '紧急') {
    await _triggerCriticalAlert(...);
  } else if (overallStatus == '注意') {
    await _triggerWarningAlert(...);
  } else {
    await _triggerNormalAlert(...);
  }
  
  await _showAnalysisResultDialog(analysisData);
}
```

#### 2. `_triggerCriticalAlert()` - 触发紧急警报

```dart
Future<void> _triggerCriticalAlert(...) async {
  // 1. 长振动
  await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
  
  // 2. 语音播报
  await _voiceService.speak('紧急警报！$alertText');
  
  // 3. 显示红色提示
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

#### 3. `_triggerWarningAlert()` - 触发警告警报

```dart
Future<void> _triggerWarningAlert(...) async {
  // 1. 短振动
  await Vibration.vibrate(duration: 300);
  
  // 2. 语音播报
  await _voiceService.speak('注意：$alertText');
  
  // 3. 显示橙色提示
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

#### 4. `_buildAlertMessage()` - 构建警报消息

```dart
String _buildAlertMessage(Map<String, dynamic> detections) {
  final alerts = <String>[];
  
  // 检查各项检测
  if (fall?['detected'] == true) alerts.add('检测到跌倒');
  if (bedExit?['patient_in_bed'] == false) alerts.add('患者已离床');
  if (expression == '痛苦') alerts.add('检测到痛苦表情');
  if (ivDrip?['completely_empty'] == true) alerts.add('吊瓶已打完');
  
  return alerts.join('、');
}
```

---

## 振动模式说明

### 紧急振动（Pattern）
```
震动 500ms → 停止 200ms → 震动 500ms → 停止 200ms → 震动 500ms
[0, 500, 200, 500, 200, 500]
```

### 警告振动（Duration）
```
震动 300ms
```

### 振动检查
```dart
if (await Vibration.hasVibrator() ?? false) {
  await Vibration.vibrate(...);
}
```

---

## 分析结果数据结构

### 后端返回格式

```json
{
  "status": "success",
  "overall_status": "紧急",  // "正常" | "注意" | "紧急"
  "result_id": "uuid",
  "detections": {
    "fall": {
      "detected": false,
      "confidence": 0.95,
      "description": "未检测到跌倒，患者处于床上，姿势正常"
    },
    "bed_exit": {
      "patient_in_bed": true,
      "location": "床上",
      "description": "患者在床上"
    },
    "activity": {
      "type": "正常",
      "abnormal": false,
      "description": "正常活动，无异常"
    },
    "facial_analysis": {
      "skin_color": "正常",
      "expression": "痛苦",
      "emotion_confidence": 0.85,
      "description": "检测到痛苦表情，眉头紧锁，面部肌肉紧张"
    },
    "iv_drip": {
      "detected": true,
      "fluid_level": "已打完",
      "completely_empty": true,
      "needs_replacement": true,
      "description": "吊瓶完全空了，滴液管中也没有液体，判定为已打完"
    }
  },
  "recommended_action": "立即告警",
  "alert_message": "检测到痛苦表情、吊瓶已打完"
}
```

---

## 日志输出

### 分析结果处理日志

```
[分析结果] 整体状态: 紧急
[分析结果] 检测项: fall, bed_exit, activity, facial_analysis, iv_drip
[警报] 触发紧急警报
[振动] 开始长振动
[语音] 播报: 紧急警报！检测到痛苦表情、吊瓶已打完
```

---

## 使用场景

### 场景1: 正常监护

1. 患者拍照上传监护现场
2. AI分析：一切正常
3. 手机显示：✅ 绿色提示 "分析完成，一切正常"
4. 患者可查看详情了解具体检测结果

### 场景2: 需要注意

1. 患者拍照上传
2. AI分析：检测到患者离床
3. 手机：短振动 + 语音 "注意：患者已离床" + ⚠️ 橙色提示
4. 患者点击查看详情，确认当前状态

### 场景3: 紧急情况

1. 患者（或家属）拍照上传
2. AI分析：检测到跌倒 + 痛苦表情
3. 手机：长振动（模式振动） + 语音 "紧急警报！检测到跌倒、检测到痛苦表情"
4. 红色提示 5秒显示
5. 自动弹出详情对话框
6. 后端同时通知护士和家属

---

## 依赖和权限

### 依赖包

```yaml
dependencies:
  vibration: ^1.8.4        # 振动功能
  flutter_tts: ^4.0.2      # 语音播报
  image_picker: ^1.0.7     # 图片选择
```

### 权限配置

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机拍摄监护现场</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册选择图片</string>
```

---

## 测试建议

### 测试用例

#### 测试1: 正常状态
- 上传正常场景图片
- 预期：绿色提示，无振动，可查看详情

#### 测试2: 警告状态
- 上传离床场景图片
- 预期：橙色提示，短振动，语音播报，可查看详情

#### 测试3: 紧急状态
- 上传跌倒场景图片
- 预期：红色提示，长振动（模式），语音播报，详情对话框

#### 测试4: 吊瓶监测
- 上传吊瓶已空的图片
- 预期：根据状态触发相应警报，详情中显示液体剩余量

#### 测试5: 振动功能
- 在不同设备上测试振动
- 确认振动模式正确
- 检查无振动器设备的兼容性

---

## 故障排除

### 振动不工作

**问题**: 上传后无振动反馈

**解决方案**:
1. 检查设备是否支持振动
2. 检查权限是否授予（Android VIBRATE）
3. 检查设备静音/振动设置
4. 查看日志：`[振动] 振动失败: ...`

### 语音不播报

**问题**: 无语音播报

**解决方案**:
1. 检查 VoiceService 是否初始化
2. 检查设备音量设置
3. 检查TTS引擎是否可用

### 分析结果不显示

**问题**: 对话框不弹出

**解决方案**:
1. 检查后端返回的数据格式
2. 查看控制台日志的分析结果
3. 确认 `mounted` 状态

---

## 功能特点

✅ **智能分级**: 根据严重程度自动选择警报级别  
✅ **多感官反馈**: 振动 + 语音 + 视觉提示  
✅ **详细信息**: 完整的检测结果展示  
✅ **用户友好**: 清晰的提示和操作引导  
✅ **调试友好**: 详细的日志输出  
✅ **兼容性好**: 处理设备不支持振动的情况  

---

## 更新日志

- **2025-12-27**: 初始版本，添加三级警报系统
- **2025-12-27**: 添加振动功能（模式振动）
- **2025-12-27**: 添加分析结果详情对话框
- **2025-12-27**: 添加智能警报消息构建

---

**功能已完成，等待测试验证** ✅

