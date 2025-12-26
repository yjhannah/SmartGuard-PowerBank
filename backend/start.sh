#!/bin/bash
# 启动后端服务脚本

set -e  # 遇到错误立即退出

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

echo "=========================================="
echo "  医院病房智能监护系统 - 启动脚本"
echo "=========================================="
echo ""

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python3，请先安装 Python 3.10+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "✅ Python版本: $PYTHON_VERSION"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

echo "📦 激活虚拟环境并安装依赖..."
source venv/bin/activate

# 升级pip
pip install --upgrade pip -q

# 安装依赖
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt -q
    echo "✅ 依赖安装完成"
else
    echo "⚠️  未找到 requirements.txt"
fi

# 检查环境变量加密文件
if [ -f ".env.encrypted" ]; then
    echo "✅ 找到加密环境变量文件"
    if [ ! -f ".env.encryption.key" ] && [ -z "$ENV_ENCRYPTION_KEY" ]; then
        echo "⚠️  警告: 未找到密钥文件或环境变量 ENV_ENCRYPTION_KEY"
        echo "   服务可能无法加载加密的环境变量"
    fi
elif [ -f ".env" ]; then
    echo "⚠️  警告: 发现明文 .env 文件，建议加密"
    echo "   运行: python scripts/encrypt_env.py encrypt"
fi

# 检查数据库
if [ ! -f "data/hospital_monitoring.db" ]; then
    echo "🗄️  初始化数据库..."
    python scripts/init_db.py
    echo "✅ 数据库初始化完成"
else
    echo "✅ 数据库已存在"
fi

# 检查端口占用
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  警告: 端口 8000 已被占用"
    echo "   请先停止占用该端口的进程，或修改 PORT 环境变量"
    read -p "是否继续? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 启动服务
echo ""
echo "=========================================="
echo "🚀 启动后端服务..."
echo "=========================================="
echo "访问地址: http://localhost:8000"
echo "API文档: http://localhost:8000/docs"
echo "健康检查: http://localhost:8000/health"
echo ""
echo "前端页面:"
echo "  - 病人监控端: http://localhost:8000/monitor.html"
echo "  - 家属手机端: http://localhost:8000/family.html"
echo "  - 护士工作站: http://localhost:8000/nurse.html"
echo ""
echo "按 Ctrl+C 停止服务"
echo "=========================================="
echo ""

# 设置PYTHONPATH
export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH}"

# 启动服务
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

