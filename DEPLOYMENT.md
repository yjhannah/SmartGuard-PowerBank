# 本地部署文档

## 快速开始

### 一键部署（推荐）

```bash
bash deploy_local.sh
```

脚本会自动完成：
1. 检查Python环境
2. 安装后端依赖
3. 配置环境变量
4. 初始化数据库
5. 启动服务

### 手动部署

#### 1. 环境要求

- Python 3.10+
- pip
- 浏览器（Chrome/Firefox/Safari）

#### 2. 安装依赖

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### 3. 配置环境变量

**方式1: 使用加密环境变量（推荐）**

```bash
# 1. 复制示例文件
cp .env.example .env

# 2. 编辑 .env 文件，填写实际配置
vim .env

# 3. 加密环境变量
python scripts/encrypt_env.py encrypt

# 4. 验证加密文件
python scripts/encrypt_env.py verify
```

**方式2: 直接使用 .env 文件（开发环境）**

```bash
cp .env.example .env
# 编辑 .env 文件
```

#### 4. 初始化数据库

```bash
python scripts/init_db.py
```

这将创建所有表结构并插入测试数据：
- 2个患者（高风险、中风险各1个）
- 1个护士用户（nurse001 / nurse123）
- 2个家属用户（family001 / family123, family002 / family123）

#### 5. 启动服务

```bash
bash start.sh
```

或直接使用 uvicorn：

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### 6. 访问应用

- **API文档**: http://localhost:8000/docs
- **健康检查**: http://localhost:8000/health
- **病人监控端**: http://localhost:8000/monitor.html
- **家属手机端**: http://localhost:8000/family.html
- **护士工作站**: http://localhost:8000/nurse.html

## 环境变量配置

### 必需配置

#### One-API 模式（推荐）

```bash
USE_ONE_API=true
ONE_API_BASE_URL=http://your-one-api-url/v1
ONE_API_KEY=sk-your-key-here
ONE_API_GEMINI_MODEL=gemini-2.0-flash
ONE_API_GEMINI_VISION_MODEL=gemini-2.0-flash-exp
```

#### 直接 Gemini API 模式

```bash
USE_ONE_API=false
GEMINI_API_KEY=your-gemini-api-key
```

### 可选配置

```bash
# 数据库（默认使用SQLite）
DATABASE_URL=sqlite:///./data/hospital_monitoring.db

# 服务器配置
HOST=0.0.0.0
PORT=8000
DEBUG=false

# CORS配置
CORS_ORIGINS=["*"]
```

## 环境变量加密

### 加密流程

1. **创建明文文件**
   ```bash
   cp .env.example .env
   # 编辑 .env 文件
   ```

2. **加密文件**
   ```bash
   python scripts/encrypt_env.py encrypt
   ```

3. **验证加密文件**
   ```bash
   python scripts/encrypt_env.py verify
   ```

4. **提交加密文件到Git**
   ```bash
   git add .env.encrypted
   git commit -m "Update encrypted env file"
   ```

### 密钥管理

**方式1: 密钥文件（开发环境）**

```bash
# 密钥文件位置
backend/.env.encryption.key

# 设置权限（仅所有者可读写）
chmod 600 .env.encryption.key
```

**方式2: 环境变量（生产环境）**

```bash
# 设置环境变量
export ENV_ENCRYPTION_KEY="your-encryption-key"

# 或添加到 ~/.bashrc / ~/.zshrc
echo 'export ENV_ENCRYPTION_KEY="your-encryption-key"' >> ~/.bashrc
source ~/.bashrc
```

### 加密工具命令

```bash
# 加密
python scripts/encrypt_env.py encrypt

# 验证
python scripts/encrypt_env.py verify

# 解密（调试用）
python scripts/encrypt_env.py decrypt --output .env.decrypted

# 生成新密钥
python scripts/encrypt_env.py encrypt --new-key
```

## 数据库管理

### 初始化数据库

```bash
python scripts/init_db.py
```

### 数据库位置

```
backend/data/hospital_monitoring.db
```

### 备份数据库

```bash
cp backend/data/hospital_monitoring.db backend/data/hospital_monitoring.db.backup
```

### 重置数据库

```bash
rm backend/data/hospital_monitoring.db
python scripts/init_db.py
```

## 功能优化说明

### 智能采样（Layer 1）

系统已集成前端帧差检测，自动过滤静止画面：
- **默认阈值**: 15%变化
- **预期效果**: 减少70-75%的API调用
- **配置**: 在监控端页面可开启/关闭智能采样

### 批量上传（Layer 4）

支持批量上传多帧图片：
- **批量大小**: 5帧
- **超时时间**: 15秒
- **API端点**: `/api/analysis/batch`

### 时间线回放

- 支持查看分析历史时间线
- 点击时间线项可跳转到对应时间点
- 时间戳格式：MM:SS

## 故障排查

### 服务无法启动

1. **检查Python版本**
   ```bash
   python3 --version  # 需要 3.10+
   ```

2. **检查端口占用**
   ```bash
   lsof -i :8000
   # 或
   netstat -an | grep 8000
   ```

3. **检查依赖安装**
   ```bash
   pip list | grep fastapi
   ```

### 环境变量加载失败

1. **检查加密文件**
   ```bash
   python scripts/encrypt_env.py verify
   ```

2. **检查密钥**
   ```bash
   # 检查密钥文件
   ls -la .env.encryption.key
   
   # 检查环境变量
   echo $ENV_ENCRYPTION_KEY
   ```

### 数据库错误

1. **检查数据库文件**
   ```bash
   ls -la data/hospital_monitoring.db
   ```

2. **重新初始化**
   ```bash
   rm data/hospital_monitoring.db
   python scripts/init_db.py
   ```

### AI分析失败

1. **检查API配置**
   ```bash
   # 检查环境变量
   python -c "from app.core.config import settings; print(settings.use_one_api)"
   ```

2. **测试API连接**
   ```bash
   curl http://localhost:8000/health
   ```

## 性能优化建议

1. **启用智能采样**: 在监控端页面开启智能采样开关
2. **使用批量上传**: 系统自动使用批量上传机制
3. **数据库优化**: SQLite适合小规模部署，大规模建议使用PostgreSQL
4. **缓存策略**: 考虑添加Redis缓存分析结果

## 安全建议

1. **生产环境**:
   - 使用加密的环境变量文件
   - 密钥存储在环境变量中，不在代码中
   - 限制CORS来源
   - 使用HTTPS

2. **密钥管理**:
   - 定期轮换密钥（每6个月）
   - 备份密钥到安全位置
   - 不要提交密钥到Git

3. **数据库安全**:
   - 定期备份数据库
   - 限制数据库文件访问权限

## 测试账号

系统初始化后提供以下测试账号：

- **护士**: `nurse001` / `nurse123`
- **家属1**: `family001` / `family123`
- **家属2**: `family002` / `family123`

## 常见问题

### Q: 如何修改端口？

A: 修改环境变量 `PORT=8080` 或使用 `--port` 参数：
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

### Q: 如何查看日志？

A: 服务日志直接输出到控制台，也可以重定向到文件：
```bash
uvicorn app.main:app > logs/app.log 2>&1
```

### Q: 如何更新环境变量？

A: 修改 `.env` 文件后重新加密：
```bash
python scripts/encrypt_env.py encrypt
```

### Q: 如何重置所有数据？

A: 删除数据库文件并重新初始化：
```bash
rm backend/data/hospital_monitoring.db
python backend/scripts/init_db.py
```

## 技术支持

如遇问题，请检查：
1. 日志输出
2. 健康检查端点：http://localhost:8000/health
3. API文档：http://localhost:8000/docs

