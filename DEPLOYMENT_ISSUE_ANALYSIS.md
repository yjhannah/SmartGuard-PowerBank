# Flutter Web部署问题分析

## 🔍 问题描述

访问 https://smartguard.gitagent.io/ 显示的是旧的HTML页面（病人监控端），而不是新开发的Flutter Web应用。

## 📊 当前状态分析

### 1. 服务器文件状态 ✅

**Flutter Web文件已部署**:
- ✅ `/home/support/smartguard/frontend/index.html` (1.2K) - Flutter的index.html
- ✅ `/home/support/smartguard/frontend/main.dart.js` (2.6M) - Flutter应用代码
- ✅ `/home/support/smartguard/frontend/flutter.js` (9.2K) - Flutter框架
- ✅ `/home/support/smartguard/frontend/assets/` - 资源文件
- ✅ `/home/support/smartguard/frontend/canvaskit/` - Flutter渲染引擎

**旧的HTML文件也存在**:
- ⚠️ `/home/support/smartguard/frontend/monitor.html` (39K) - 旧的病人监控端
- ⚠️ `/home/support/smartguard/frontend/family.html` (29K) - 旧的家属端
- ⚠️ `/home/support/smartguard/frontend/nurse.html` (37K) - 旧的护士端

### 2. HTTP响应分析

**访问 https://smartguard.gitagent.io/ 返回**:
- Content-Length: 39378 bytes (对应 monitor.html 的 39K)
- Last-Modified: Sat, 27 Dec 2025 03:02:02 GMT
- Content-Type: text/html
- 内容: 显示"病人监控端"的旧HTML页面

**Flutter index.html特征**:
- 大小: 1.2K (1215 bytes)
- 内容: 包含 `<base href="/">`, `flutter_bootstrap.js` 等Flutter标识

### 3. 问题根源分析

#### 可能原因1: nginx配置优先级问题
nginx可能配置了特定的location规则，优先匹配 `monitor.html` 而不是 `index.html`。

**检查点**:
- nginx配置中的 `location /` 规则
- 是否有 `index` 指令指定了 `monitor.html`
- 是否有 `try_files` 指令优先匹配特定文件

#### 可能原因2: 文件优先级问题
nginx的默认行为是：
1. 如果访问 `/`，会查找 `index.html`
2. 但如果配置了 `index monitor.html`，会优先返回 `monitor.html`

#### 可能原因3: 路径映射问题
nginx可能将根路径 `/` 映射到了 `monitor.html` 而不是 `index.html`。

## 🔧 问题根源确认

### nginx配置问题（已确认）

**当前nginx配置** (`/etc/nginx/sites-available/smartguard.gitagent.io`):

```nginx
location / {
    root /home/support/smartguard/frontend;
    try_files $uri $uri/ =404;
    index monitor.html family.html nurse.html;  # ❌ 问题在这里！
}
```

### 问题分析

1. **index指令配置错误**:
   - 当前配置: `index monitor.html family.html nurse.html;`
   - 问题: 没有包含 `index.html`（Flutter应用）
   - 结果: 访问 `/` 时，nginx按顺序查找：
     1. `monitor.html` ✅ 找到 → 返回（39K的旧页面）
     2. 不会继续查找 `index.html`

2. **文件优先级**:
   - Flutter的 `index.html` (1.2K) 存在但被忽略
   - 旧的 `monitor.html` (39K) 被优先返回

3. **HTTP响应验证**:
   - Content-Length: 39378 bytes = monitor.html 的大小
   - 内容: "病人监控端" 的旧HTML页面
   - 确认: 返回的是 monitor.html 而不是 Flutter 的 index.html

## 📋 问题总结

### 核心问题 ✅ 已确认

**nginx配置的 `index` 指令没有包含 `index.html`**，导致访问根路径 `/` 时优先返回 `monitor.html` 而不是 Flutter 的 `index.html`。

### 文件状态
- ✅ Flutter Web文件已正确部署（index.html, main.dart.js等）
- ⚠️ 旧的HTML文件与Flutter文件共存（monitor.html, family.html, nurse.html）
- ❌ nginx配置的 `index` 指令错误：`index monitor.html family.html nurse.html;`

### 问题验证

1. **HTTP响应**:
   - Content-Length: 39378 bytes = monitor.html 的大小
   - 内容: "病人监控端" 的旧HTML页面
   - ✅ 确认返回的是 monitor.html

2. **文件对比**:
   - Flutter index.html: 1.2K，包含 `flutter_bootstrap.js`
   - monitor.html: 39K，包含 "病人监控端" 标题
   - ✅ 确认两个文件都存在，但nginx返回了错误的文件

### 解决方案

#### 方案1: 修改nginx配置（推荐）

修改 `/etc/nginx/sites-available/smartguard.gitagent.io`:

```nginx
location / {
    root /home/support/smartguard/frontend;
    try_files $uri $uri/ /index.html;  # 修改：添加 /index.html 作为fallback
    index index.html;  # 修改：优先返回 index.html (Flutter)
}
```

**优点**:
- 根路径 `/` 返回 Flutter 应用
- 旧的HTML页面仍可通过 `/monitor.html`, `/family.html`, `/nurse.html` 访问
- 不需要移动文件

#### 方案2: 移动旧文件到子目录

将旧的HTML文件移到 `legacy/` 子目录：
- `/home/support/smartguard/frontend/legacy/monitor.html`
- `/home/support/smartguard/frontend/legacy/family.html`
- `/home/support/smartguard/frontend/legacy/nurse.html`

然后修改nginx配置：
```nginx
location / {
    root /home/support/smartguard/frontend;
    index index.html;  # Flutter应用
}

location /legacy/ {
    root /home/support/smartguard/frontend;
    # 旧页面通过 /legacy/monitor.html 访问
}
```

#### 方案3: 重命名旧文件

将旧文件重命名为 `.old` 后缀：
- `monitor.html` → `monitor.html.old`
- `family.html` → `family.html.old`
- `nurse.html` → `nurse.html.old`

然后修改nginx配置：
```nginx
location / {
    root /home/support/smartguard/frontend;
    index index.html;  # 只返回 Flutter 的 index.html
}
```

## 🔍 推荐方案

**推荐使用方案1**：修改nginx配置，将 `index` 指令改为 `index index.html;`，并更新 `try_files` 指令。

这样：
- ✅ 根路径 `/` 返回 Flutter 应用
- ✅ 旧的HTML页面仍可通过完整路径访问（如 `/monitor.html`）
- ✅ 不需要移动或删除文件
- ✅ 向后兼容

