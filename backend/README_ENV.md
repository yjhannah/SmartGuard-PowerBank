# 虚拟环境管理指南

## 概述

本项目使用独立的 Python 虚拟环境，避免与其他项目产生依赖冲突。

## 快速开始

### 1. 设置虚拟环境

```bash
cd backend
bash setup_venv.sh
```

这个脚本会：
- 检查 Python 版本（需要 3.10+）
- 创建独立的虚拟环境 `venv/`
- 安装所有项目依赖
- 验证安装结果

### 2. 检查环境

```bash
bash check_env.sh
```

查看当前环境状态、依赖版本等信息。

### 3. 启动服务

#### 本地开发
```bash
bash start.sh
```

#### 生产环境
```bash
bash start_production.sh
```

启动脚本会自动激活虚拟环境，无需手动操作。

## 手动管理虚拟环境

### 激活虚拟环境
```bash
source venv/bin/activate
```

### 退出虚拟环境
```bash
deactivate
```

### 重新安装依赖
```bash
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 删除虚拟环境（重新开始）
```bash
rm -rf venv
bash setup_venv.sh
```

## 环境隔离说明

### 为什么需要虚拟环境？

1. **依赖隔离**：不同项目可能需要不同版本的同一个包
2. **版本管理**：确保开发和生产环境使用相同的依赖版本
3. **避免冲突**：防止系统 Python 环境被污染

### 本项目虚拟环境特点

- **独立路径**：`backend/venv/`（项目目录内）
- **自动激活**：启动脚本会自动激活虚拟环境
- **版本锁定**：`requirements.txt` 锁定依赖版本

## 多项目管理

如果有多个项目同时运行：

1. **每个项目独立虚拟环境**
   ```bash
   /project1/venv/
   /project2/venv/
   /project3/venv/
   ```

2. **使用不同端口**
   - 项目1: 8000
   - 项目2: 8001
   - 项目3: 8002

3. **使用环境变量区分**
   ```bash
   export PROJECT_NAME=smartguard
   export PORT=8001
   ```

## 常见问题

### Q: 启动时提示 "未在虚拟环境中"
A: 启动脚本会自动激活，如果仍有问题，手动执行：
```bash
source venv/bin/activate
bash start_production.sh
```

### Q: 依赖版本冲突
A: 更新 requirements.txt，然后重新安装：
```bash
source venv/bin/activate
pip install -r requirements.txt --upgrade
```

### Q: 虚拟环境损坏
A: 删除并重建：
```bash
rm -rf venv
bash setup_venv.sh
```

## 使用 direnv（可选）

如果安装了 `direnv`，进入项目目录时会自动激活虚拟环境：

```bash
# macOS
brew install direnv

# Linux
apt-get install direnv

# 配置 shell（添加到 ~/.zshrc 或 ~/.bashrc）
eval "$(direnv hook zsh)"  # 或 bash
```

然后在项目目录创建 `.envrc`（已包含），运行：
```bash
direnv allow
```

之后每次进入项目目录都会自动激活虚拟环境。

