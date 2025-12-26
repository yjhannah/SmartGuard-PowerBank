# SmartGuard-PowerBank

# 医院病房智能监护系统

智能监护系统最小原型，支持AI视觉分析、实时告警和WebSocket推送。

## 功能特性

- **AI视觉分析**: 使用Google Gemini 2.0 Flash进行跌倒检测、离床监测、面部分析等
- **智能采样优化**: 前端帧差检测，减少70%+的API调用成本
- **批量上传机制**: 累积多帧后批量上传，提高处理效率
- **时间线回放**: 支持查看分析历史和时间戳跳转
- **实时告警**: 多级告警系统（Critical/High/Medium/Low）
- **WebSocket推送**: 实时推送告警消息给护士和家属
- **环境变量加密**: 支持Fernet加密，保护敏感配置
- **三个前端应用**: 
  - 病人监控端（模拟视频上传，智能采样）
  - 病人家属手机端（响应式设计）
  - 护士工作站PC端（监控大屏）

## 技术栈

- **后端**: Python 3.10+, FastAPI, SQLite, WebSocket
- **AI服务**: Google Gemini 2.0 Flash (通过One-API)
- **前端**: HTML5 + Vanilla JavaScript + WebSocket
- **数据库**: SQLite (本地)

## 项目结构

```
SmartGuard-PowerBank/
├── backend/
│   ├── app/
│   │   ├── api/routes/      # API路由
│   │   ├── core/            # 核心配置
│   │   ├── models/          # 数据模型
│   │   ├── services/        # 业务服务
│   │   └── main.py          # 应用入口
│   ├── utils/               # 工具函数
│   ├── scripts/             # 脚本
│   ├── data/                # 数据库文件
│   └── requirements.txt     # Python依赖
├── frontend/
│   ├── monitor.html         # 病人监控端
│   ├── family.html          # 家属手机端
│   ├── nurse.html           # 护士工作站
│   └── static/              # 静态资源
└── doc/                     # 文档
```

## 快速开始

### 一键部署（推荐）

```bash
bash deploy_local.sh
```

脚本会自动完成所有配置和启动步骤。

### 手动部署

详细步骤请参考 [DEPLOYMENT.md](DEPLOYMENT.md)

#### 1. 安装依赖

```bash
cd backend
pip install -r requirements.txt
```

#### 2. 配置环境变量

创建 `.env` 文件（参考 `.env.example`）并加密：

```bash
cp .env.example .env
# 编辑 .env 文件
python scripts/encrypt_env.py encrypt
```

#### 3. 初始化数据库

```bash
python scripts/init_db.py
```

#### 4. 启动服务

```bash
bash start.sh
# 或
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### 5. 访问应用

- **API文档**: http://localhost:8000/docs
- **健康检查**: http://localhost:8000/health
- **病人监控端**: http://localhost:8000/monitor.html
- **家属手机端**: http://localhost:8000/family.html
- **护士工作站**: http://localhost:8000/nurse.html

## API文档

启动服务后访问: http://localhost:8000/docs

## 使用说明

### 病人监控端

1. 选择患者
2. 上传图片文件（模拟视频帧）
3. 查看AI分析结果
4. 查看历史分析记录

### 家属手机端

1. 查看患者实时状态
2. 查看告警记录
3. 接收WebSocket实时推送

### 护士工作站

1. 查看所有患者监控大屏
2. 管理告警（确认/处理）
3. 查看告警统计

## 开发说明

### 添加新的检测类型

1. 在 `app/services/gemini_service.py` 的 `_build_analysis_prompt` 中添加提示词
2. 在 `app/services/alert_service.py` 的 `_analyze_detections` 中添加告警规则
3. 更新前端显示逻辑

### 数据库迁移

数据库使用SQLite，表结构定义在 `scripts/init_db.py` 中。

## 注意事项

1. **环境变量加密**: 生产环境请使用加密的 `.env.encrypted` 文件
2. **API密钥安全**: 不要将密钥提交到Git仓库
3. **数据库备份**: 定期备份 `backend/data/hospital_monitoring.db`
4. **WebSocket连接**: 前端需要正确配置用户ID才能接收推送

## 许可证

MIT License
