#!/bin/bash
# 使用.env.production配置启动服务

cd "$(dirname "$0")"

echo "=========================================="
echo "  启动服务（使用One-API配置）"
echo "=========================================="
echo ""

# 设置环境变量（从.env.production）
export USE_ONE_API=true
export ONE_API_BASE_URL="http://104.154.76.119:3000/v1"
export ONE_API_KEY="sk-7UokIik5JjNUPIft42A9E9F01f7d4738973aC119C5E26e2c"
export ONE_API_GEMINI_VISION_MODEL="gemini-2.0-flash-exp"

echo "📋 配置信息:"
echo "  USE_ONE_API: $USE_ONE_API"
echo "  ONE_API_BASE_URL: $ONE_API_BASE_URL"
echo "  ONE_API_KEY: ${ONE_API_KEY:0:4}...${ONE_API_KEY: -4}"
echo "  模型: $ONE_API_GEMINI_VISION_MODEL"
echo ""

# 激活虚拟环境
source venv/bin/activate

# 设置PYTHONPATH
export PYTHONPATH="${PWD}:${PYTHONPATH}"

# 启动服务
echo "🚀 启动服务..."
echo ""

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

