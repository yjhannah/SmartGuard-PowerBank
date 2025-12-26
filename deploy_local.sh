#!/bin/bash
# 本地一键部署脚本

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  医院病房智能监护系统 - 本地部署"
echo "=========================================="
echo ""

# 1. 检查Python环境
echo "📋 步骤 1/5: 检查Python环境..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python3，请先安装 Python 3.10+"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo "✅ $PYTHON_VERSION"
echo ""

# 2. 安装后端依赖
echo "📋 步骤 2/5: 安装后端依赖..."
cd backend
if [ ! -d "venv" ]; then
    echo "创建虚拟环境..."
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q
echo "✅ 后端依赖安装完成"
cd ..
echo ""

# 3. 配置环境变量
echo "📋 步骤 3/5: 配置环境变量..."
cd backend
if [ ! -f ".env" ] && [ ! -f ".env.encrypted" ]; then
    echo "⚠️  未找到环境变量文件"
    echo "请创建 .env 文件（参考 .env.example）或提供 .env.encrypted 文件"
    echo ""
    read -p "是否现在创建 .env 文件? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo "✅ 已创建 .env 文件，请编辑后运行: python scripts/encrypt_env.py encrypt"
        else
            echo "请手动创建 .env 文件"
        fi
    fi
elif [ -f ".env" ] && [ ! -f ".env.encrypted" ]; then
    echo "发现 .env 文件，建议加密..."
    read -p "是否现在加密? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        python scripts/encrypt_env.py encrypt
        echo "✅ 环境变量已加密"
    fi
else
    echo "✅ 环境变量配置完成"
fi
cd ..
echo ""

# 4. 初始化数据库
echo "📋 步骤 4/5: 初始化数据库..."
cd backend
if [ ! -f "data/hospital_monitoring.db" ]; then
    echo "初始化数据库..."
    python scripts/init_db.py
    echo "✅ 数据库初始化完成"
else
    echo "✅ 数据库已存在"
    read -p "是否重新初始化数据库? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f data/hospital_monitoring.db
        python scripts/init_db.py
        echo "✅ 数据库已重新初始化"
    fi
fi
cd ..
echo ""

# 5. 启动服务
echo "📋 步骤 5/5: 启动服务..."
echo ""
cd backend
bash start.sh

