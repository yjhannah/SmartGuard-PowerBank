# 家属端预警自动弹窗功能

## 功能概述

家属端收到新告警时，自动弹出全屏预警详情页面，支持：
- ✅ 自动弹出（无需手动点击）
- ✅ 多个预警滑动翻页
- ✅ 振动提醒（紧急长振动、普通短振动）
- ✅ 简要语音播报（不超过10个字）
- ✅ 显示告警图片
- ✅ 显示详细信息
- ✅ 确认告警操作

---

## 功能流程

### 1. 完整流程图

```
患者端/监控端上传图片
  ↓
后端AI分析
  ↓
检测到异常（overall_status = '紧急'/'注意'）
  ↓
创建告警记录（alerts表）
  ↓
触发WebSocket通知
  ↓
发送消息给家属（通过user_id）
{
  "type": "alert",
  "alert_id": "...",
  "patient_id": "...",
  "severity": "critical",
  "title": "病房监护预警",
  "message": "患者张三心跳变平...",
  "timestamp": "2025-12-27T20:38:07"
}
  ↓
家属端WebSocket接收消息
  ↓
调用后端API获取完整告警详情
GET /api/alerts/{alert_id}
返回：{
  alert_id, title, description, image_url,
  severity, created_at, family_acknowledged, ...
}
  ↓
自动弹出全屏预警详情页面
  ↓
触发振动和语音
  - 紧急：长振动 500-200-500-200-500
  - 普通：短振动 300ms
  - 语音："心跳变平"（不超过10字）
  ↓
显示预警详情
  - 严重程度徽章
  - 告警标题和时间
  - 告警图片（如果有）
  - 详细描述
  ↓
家属操作
  - 左右滑动查看多个预警
  - 点击"确认告警"按钮
  ↓
调用API确认
POST /api/alerts/{alert_id}/family-acknowledge
  ↓
更新数据库
UPDATE alerts SET family_acknowledged = 1
  ↓
关闭预警页面
```

---

## 关键实现

### 1. 家属端主页面（family_home_screen.dart）

#### WebSocket连接

```dart
Future<void> _connectWebSocket() async {
  await _wsService.connect(_userId!);
  
  _wsService.messageStream?.listen((message) {
    if (message['type'] == 'alert') {
      _handleNewAlert(message);  // 收到告警自动处理
    }
  });
}
```

#### 自动弹窗处理

```dart
Future<void> _handleNewAlert(Map<String, dynamic> alertMessage) async {
  final alertId = alertMessage['alert_id'];
  
  // 1. 获取完整告警详情（包括图片URL）
  final alertDetails = await _apiService.get('/alerts/$alertId');
  
  // 2. 添加到待处理列表
  _pendingAlerts.add(alertDetails);
  
  // 3. 立即弹出全屏详情页面
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => AlertDetailPage(
        alerts: List.from(_pendingAlerts),
        initialIndex: _pendingAlerts.length - 1,  // 显示最新的
      ),
      fullscreenDialog: true,  // 全屏模式
    ),
  );
  
  // 4. 关闭后清空列表
  _pendingAlerts.clear();
}
```

### 2. 预警详情页面（alert_detail_page.dart）

#### 初始化时触发振动和语音

```dart
@override
void initState() {
  super.initState();
  _currentIndex = widget.initialIndex;
  _pageController = PageController(initialPage: widget.initialIndex);
  
  // 初始化语音服务
  _init();
}

Future<void> _init() async {
  await _voiceService.init();
  
  // 触发首次振动和语音
  await _triggerAlertFeedback();
}
```

#### 振动反馈

```dart
Future<void> _triggerAlertFeedback() async {
  if (_hasVibrated) return;  // 只振动一次
  
  final alert = widget.alerts[_currentIndex];
  final severity = alert['severity'];
  
  // 振动
  if (await Vibration.hasVibrator() ?? false) {
    if (severity == 'critical') {
      // 紧急：长振动模式
      await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
    } else {
      // 其他：短振动
      await Vibration.vibrate(duration: 300);
    }
  }
  
  // 语音播报（不超过10个字）
  final shortMessage = _buildShortMessage(alert);
  await _voiceService.speak(shortMessage);
  
  _hasVibrated = true;
}
```

#### 简短语音消息

```dart
String _buildShortMessage(Map<String, dynamic> alert) {
  final alertType = alert['alert_type'];
  
  switch (alertType) {
    case 'heart_rate_flat':
      return '心跳变平';       // 4个字
    case 'fall':
      return '跌倒告警';       // 4个字
    case 'iv_drip':
      return '吊瓶已空';       // 4个字
    case 'bed_exit':
      return '离床告警';       // 4个字
    case 'facial':
      return '面部异常';       // 4个字
    default:
      return '紧急告警';       // 4个字
  }
}
```

#### 滑动翻页

```dart
// 页面指示器
Row(
  children: [
    Text('${_currentIndex + 1} / ${widget.alerts.length}'),
    ...List.generate(widget.alerts.length, (index) =>
      Container(
        width: _currentIndex == index ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: _currentIndex == index ? Colors.blue : Colors.grey,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  ],
)

// PageView滑动
PageView.builder(
  controller: _pageController,
  itemCount: widget.alerts.length,
  onPageChanged: (index) {
    setState(() {
      _currentIndex = index;
    });
  },
  itemBuilder: (context, index) {
    return _buildAlertContent(widget.alerts[index]);
  },
)
```

#### 图片显示

```dart
if (imageUrl != null && imageUrl.isNotEmpty)
  Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [...],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.error_outline),
      ),
    ),
  )
```

### 3. 后端API支持

#### 获取单个告警详情

```python
@router.get("/{alert_id}", response_model=dict)
async def get_alert(alert_id: str):
    """获取单个告警详情"""
    results = await execute_query(
        """SELECT a.*, 
                  ar.snapshot_url as image_url,
                  ar.image_url as analysis_image_url
           FROM alerts a
           LEFT JOIN ai_analysis_results ar ON a.analysis_result_id = ar.result_id
           WHERE a.alert_id = ?""",
        (alert_id,)
    )
    
    alert = dict(results[0])
    
    # 优先使用alerts表的image_url
    if not alert.get('image_url'):
        alert['image_url'] = alert.get('analysis_image_url') or alert.get('snapshot_url')
    
    return alert
```

#### 家属确认告警

```python
@router.post("/{alert_id}/family-acknowledge", response_model=dict)
async def family_acknowledge_alert(alert_id: str):
    """家属确认告警"""
    await execute_update(
        "UPDATE alerts SET family_acknowledged = 1, family_acknowledged_at = CURRENT_TIMESTAMP WHERE alert_id = ?",
        (alert_id,)
    )
    
    return {
        "status": "success",
        "message": "告警已确认",
        "alert_id": alert_id
    }
```

---

## 语音消息对照表

| 告警类型 | 语音消息 | 字数 |
|---------|---------|------|
| heart_rate_flat | 心跳变平 | 4字 |
| fall | 跌倒告警 | 4字 |
| iv_drip (完全空) | 吊瓶已空 | 4字 |
| iv_drip (袋子空) | 吊瓶已空 | 4字 |
| bed_exit | 离床告警 | 4字 |
| facial (痛苦) | 面部异常 | 4字 |
| vital_signs | 生命异常 | 4字 |
| 其他 critical | 紧急告警 | 4字 |
| 其他 | 注意 | 2字 |

---

## 振动模式说明

### 紧急告警（severity = 'critical'）
```
振动模式：[0, 500, 200, 500, 200, 500]
效果：震动 500ms → 停止 200ms → 震动 500ms → 停止 200ms → 震动 500ms
时长：约 2 秒
```

### 普通告警（severity = 'high'/'medium'）
```
振动模式：duration = 300
效果：震动 300ms
时长：0.3 秒
```

---

## 数据库字段

### alerts表新增字段

```sql
ALTER TABLE alerts ADD COLUMN family_acknowledged INTEGER DEFAULT 0;
ALTER TABLE alerts ADD COLUMN family_acknowledged_at TIMESTAMP;
```

| 字段 | 类型 | 说明 |
|------|------|------|
| family_acknowledged | INTEGER | 家属是否已确认（0=未确认, 1=已确认） |
| family_acknowledged_at | TIMESTAMP | 家属确认时间 |

---

## WebSocket消息格式

### 后端发送给家属

```json
{
  "type": "alert",
  "alert_id": "d0993d77-ad77-4c85-8d62-93eaaf4fe63e",
  "notification_id": "uuid",
  "patient_id": "531182d5-4789-4784-93e4-e4e03a147324",
  "severity": "critical",
  "title": "病房监护预警",
  "message": "患者张三心跳变平（直线），可能濒临死亡！需要立即通知家属到现场进行救护和临终陪伴！",
  "timestamp": "2025-12-27T20:38:07.029044"
}
```

### 前端接收处理

```dart
_wsService.messageStream?.listen((message) {
  if (message['type'] == 'alert') {
    _handleNewAlert(message);  // 自动弹窗
  }
});
```

---

## API端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/alerts/{alert_id}` | GET | 获取单个告警详情（包含图片URL） |
| `/api/alerts/{alert_id}/family-acknowledge` | POST | 家属确认告警 |
| `/api/alerts/family/{patient_id}` | GET | 获取患者的所有告警列表 |

---

## 测试步骤

### 1. 准备环境

**后端**:
```bash
cd backend
source venv/bin/activate
bash start_production.sh
```

**前端**:
```bash
cd mobile_app
flutter clean
flutter pub get
flutter run
```

### 2. 测试流程

1. **家属登录**
   - 账号：`family001` / `family123`
   - 应自动识别为家属端并关联患者张三

2. **查看WebSocket连接**
   - 控制台应显示：`[家属端] WebSocket连接成功`

3. **触发告警**
   - 方式1：患者端（patient001）上传心跳变平图片
   - 方式2：监控端（monitor.html）上传异常图片

4. **验证自动弹窗**
   - 家属端应自动弹出全屏预警页面
   - 手机振动（长振动或短振动）
   - 语音播报（"心跳变平"等）
   - 显示告警图片和详情

5. **测试多预警翻页**
   - 连续触发多个告警
   - 左右滑动查看不同告警
   - 查看页面指示器（1/3, 2/3, 3/3）

6. **确认告警**
   - 点击"确认告警"按钮
   - 验证按钮变为"已确认"
   - 验证数据库 family_acknowledged = 1

### 3. 验证日志

**家属端控制台应显示**:
```
[家属端] 连接WebSocket: {user_id}
[家属端] WebSocket连接成功
[家属端] ======================================
[家属端] 收到新告警WebSocket消息
[家属端] 消息类型: alert
[家属端] 告警ID: d0993d77-...
[家属端] 患者ID: 531182d5-...
[家属端] 严重程度: critical
[家属端] 消息: 患者张三心跳变平...
[家属端] ======================================
[家属端] 正在获取告警详情: d0993d77-...
[家属端] 告警详情获取成功
[家属端] 告警类型: heart_rate_flat
[家属端] 标题: 心跳变平 - 濒临死亡
[家属端] 图片URL: https://...
[家属端] 弹出告警详情页面（1个告警）
[振动] 紧急振动模式
[语音] 播报: 心跳变平
```

**后端日志应显示**:
```
[INFO] 检测到异常状态: 紧急，触发告警检查
[INFO] 检测到心跳变平！优先级1 - 返回 heart_rate_flat 告警
[INFO] 告警记录已创建: alert_id=d0993d77-...
[INFO] 触发通知推送: alert_id=d0993d77-...
[WebSocket] 准备发送消息给用户: {family_user_id}
[WebSocket] 消息类型: alert
[WebSocket] 消息已发送给用户
```

---

## 界面设计

### 预警详情页面布局

```
┌─────────────────────────────────┐
│ ⚠️ 预警详情            [X]      │  ← 顶部栏
├─────────────────────────────────┤
│      2 / 3  ● ● ○               │  ← 页面指示器（如有多个）
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ [紧急] 心跳变平 - 濒临死亡  │ │  ← 标题卡片
│ │ 5分钟前                      │ │
│ └─────────────────────────────┘ │
│                                  │
│ ┌─────────────────────────────┐ │  ← 告警图片
│ │                              │ │
│ │     [监护现场图片]           │ │
│ │                              │ │
│ └─────────────────────────────┘ │
│                                  │
│ ┌─────────────────────────────┐ │  ← 详细描述
│ │ 详细信息                     │ │
│ │                              │ │
│ │ 心电图显示为直线，心率为0   │ │
│ │ 表示病人可能已经心脏骤停    │ │
│ │ 或濒临死亡。需要立即通知    │ │
│ │ 家属到现场进行救护和临终    │ │
│ │ 陪伴！                       │ │
│ └─────────────────────────────┘ │
│                                  │
│    （可滑动查看更多内容）        │
│                                  │
├─────────────────────────────────┤
│ ◀  2/3  ▶    [确认告警]        │  ← 底部操作
└─────────────────────────────────┘
```

### 多预警翻页

```
预警1（当前）       预警2              预警3
┌──────────┐      ┌──────────┐      ┌──────────┐
│心跳变平  │ ◀滑动▶│吊瓶已空  │ ◀滑动▶│患者跌倒  │
│[图片]    │      │[图片]    │      │[图片]    │
│详细信息  │      │详细信息  │      │详细信息  │
└──────────┘      └──────────┘      └──────────┘
   1/3              2/3              3/3
```

---

## 严重程度配色方案

| 严重程度 | 背景色 | 标题颜色 | 徽章颜色 | 图标 |
|---------|--------|---------|---------|------|
| critical | 红色浅色调 | 红色深色调 | 红色 | ⚠️ warning_amber_rounded |
| high | 橙色浅色调 | 橙色深色调 | 橙色 | ❗ error_outline |
| medium | 黄色浅色调 | 橙色深色调 | 黄色 | ℹ️ info_outline |
| low | 灰色浅色调 | 灰色深色调 | 蓝色 | ℹ️ info_outline |

---

## 确认操作

### 确认按钮状态

**未确认时**:
```dart
ElevatedButton.icon(
  icon: Icon(Icons.check),
  label: Text('确认告警'),
  backgroundColor: Colors.blue,
  onPressed: () => _acknowledgeAlert(alertId),
)
```

**已确认时**:
```dart
ElevatedButton.icon(
  icon: Icon(Icons.check_circle),
  label: Text('已确认'),
  backgroundColor: Colors.grey,
  onPressed: () => Navigator.pop(context),  // 只能关闭
)
```

### 确认后效果

1. 按钮变为灰色"已确认"
2. 数据库更新 `family_acknowledged = 1`
3. 记录确认时间 `family_acknowledged_at`
4. 告警列表中该告警不再显示徽章

---

## 异常处理

### 获取告警详情失败

如果API调用失败，使用WebSocket消息中的基本信息：

```dart
catch (e) {
  // 使用基本信息构建告警对象
  final basicAlert = {
    'alert_id': alertId,
    'patient_id': alertMessage['patient_id'],
    'severity': alertMessage['severity'],
    'title': alertMessage['title'] ?? '病房监护预警',
    'description': alertMessage['message'] ?? '',
    'created_at': alertMessage['timestamp'],
    'status': 'pending',
    'family_acknowledged': 0,
  };
  
  // 仍然弹出（但可能无图片）
  _pendingAlerts.add(basicAlert);
  ...
}
```

### WebSocket未连接

如果WebSocket未连接，家属端：
1. 无法收到实时告警推送
2. 需要手动刷新告警列表
3. 日志显示警告信息

解决方案：
- 定时重连WebSocket
- 提供手动刷新按钮
- 显示连接状态指示器

---

## 部署清单

### 后端部署

```bash
# 1. 更新数据库表结构
cd backend
source venv/bin/activate
python scripts/add_mobile_tables.py

# 2. 部署到服务器
cd ..
scp backend/app/api/routes/alerts.py support@34.87.2.104:/home/support/smartguard/backend/app/api/routes/
scp backend/scripts/add_mobile_tables.py support@34.87.2.104:/home/support/smartguard/backend/scripts/

# 3. 在服务器上执行
ssh support@34.87.2.104
cd /home/support/smartguard/backend
source venv/bin/activate
python scripts/add_mobile_tables.py
bash start_production.sh
```

### 移动端部署

```bash
cd mobile_app
flutter clean
flutter pub get
flutter run

# 或构建发布版本
flutter build apk --release     # Android
flutter build ios --release     # iOS
flutter build web --release     # Web
```

---

## 测试场景

### 场景1: 单个紧急告警

1. 患者端上传心跳变平图片
2. 家属端应：
   - 立即弹出全屏页面
   - 长振动（2秒模式振动）
   - 语音"心跳变平"
   - 显示红色背景
   - 显示监护图片
   - 显示详细描述

### 场景2: 多个告警连续触发

1. 连续上传3张异常图片（跌倒、吊瓶空、离床）
2. 家属端应：
   - 弹出页面显示"3个告警"
   - 页面指示器显示 1/3
   - 可左右滑动翻页
   - 每个告警都有图片和详情
   - 底部显示翻页按钮

### 场景3: 确认操作

1. 点击"确认告警"
2. 应看到：
   - 按钮变为"已确认"（灰色）
   - Toast提示"已确认告警"
   - 页面自动关闭
   - 告警列表刷新

---

## 故障排除

### 问题1: 未自动弹窗

**可能原因**:
- WebSocket未连接
- 用户ID不正确
- 后端未发送消息

**检查方法**:
1. 查看控制台是否有"WebSocket连接成功"
2. 查看后端日志是否有"发送消息给用户"
3. 验证 user_id 是否匹配

### 问题2: 振动不工作

**可能原因**:
- 设备不支持振动
- 权限未授予
- 设备静音模式

**解决方案**:
1. 检查 AndroidManifest.xml 振动权限
2. 查看日志错误信息
3. 测试设备振动功能

### 问题3: 图片不显示

**可能原因**:
- image_url 为 null
- 图片URL无效
- 网络问题

**解决方案**:
1. 查看后端日志确认图片是否上传
2. 检查返回的 image_url 字段
3. 验证图片URL可访问

---

## 功能特点

✅ **零操作**: 告警自动弹出，无需手动点击  
✅ **多感官**: 振动 + 语音 + 视觉  
✅ **批量处理**: 支持多个告警滑动查看  
✅ **图片展示**: 显示监护现场图片  
✅ **详细信息**: 完整的告警描述  
✅ **快速确认**: 一键确认操作  
✅ **异常容错**: API失败时使用基本信息  

---

**功能已完成，等待测试验证** ✅

**最后更新**: 2025-12-27

