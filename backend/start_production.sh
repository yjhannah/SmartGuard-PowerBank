#!/bin/bash
# 生产环境启动脚本（使用加密配置文件）

set -e

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

# 端口配置（可通过环境变量覆盖）
PORT=${PORT:-8001}

echo "=========================================="
echo "  医院病房智能监护系统 - 生产环境启动"
echo "=========================================="
echo ""

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python3"
    exit 1
fi

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 检查加密环境变量文件
if [ -f ".env.encrypted" ]; then
    echo "✅ 找到加密环境变量文件"
    if [ -f ".env.encryption.key" ]; then
        echo "✅ 找到加密密钥文件"
        # 设置密钥到环境变量（如果未设置）
        if [ -z "$ENV_ENCRYPTION_KEY" ]; then
            export ENV_ENCRYPTION_KEY=$(cat .env.encryption.key | tr -d '\n')
        fi
    elif [ -z "$ENV_ENCRYPTION_KEY" ]; then
        echo "⚠️  警告: 未找到密钥文件或环境变量 ENV_ENCRYPTION_KEY"
        echo "   服务可能无法加载加密的环境变量"
    fi
else
    echo "⚠️  警告: 未找到加密环境变量文件 .env.encrypted"
fi

# 创建日志目录
mkdir -p logs
mkdir -p ../logs

# 设置PYTHONPATH
export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH}"

echo "🚀 启动服务在端口 $PORT..."
echo ""

# 启动服务（后台运行）
nohup uvicorn app.main:app --host 0.0.0.0 --port $PORT > ../logs/app-$PORT.log 2>&1 &

# 等待服务启动
sleep 3

# 检查服务是否启动成功
if pgrep -f "uvicorn app.main:app.*--port $PORT" > /dev/null; then
    echo "✅ 服务启动成功"
    echo "   端口: $PORT"
    echo "   日志: /home/support/smartguard/logs/app-$PORT.log"
    echo "   PID: $(pgrep -f "uvicorn app.main:app.*--port $PORT")"
else
    echo "❌ 服务启动失败，请检查日志: ../logs/app-$PORT.log"
    tail -30 ../logs/app-$PORT.log
    exit 1
fi

