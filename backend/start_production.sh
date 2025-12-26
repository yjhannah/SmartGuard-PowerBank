#!/bin/bash
# 生产环境启动脚本（使用加密配置文件）
# 参考 restart_backend.sh 的环境变量加载方式

set -e

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

# 端口配置（可通过环境变量覆盖）
PORT=${PORT:-8001}

# 设置北京时间（UTC+8）
export TZ="Asia/Shanghai"

echo "=========================================="
echo "  医院病房智能监护系统 - 生产环境启动"
echo "=========================================="
echo ""

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 未找到 Python3"
    exit 1
fi

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📦 虚拟环境不存在，正在创建..."
    python3 -m venv venv
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📦 安装依赖..."
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install -r requirements.txt -q
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ✅ 虚拟环境创建完成"
fi

# 激活虚拟环境（确保使用项目独立的虚拟环境）
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ✅ 已激活项目虚拟环境: $(which python3)"
else
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 虚拟环境激活失败"
    exit 1
fi

# 设置PYTHONPATH（必须在导入模块前设置）
export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH}"

# 环境变量文件路径
KEY_FILE="${PROJECT_ROOT}/.env.encryption.key"
ENCRYPTED_ENV_FILE="${PROJECT_ROOT}/.env.encrypted"
PLAINTEXT_ENV_FILE="${PROJECT_ROOT}/.env.production"

# 优先使用加密环境变量，如果有密钥文件
USE_ENCRYPTION=false
if [ -f "$KEY_FILE" ] && [ -f "$ENCRYPTED_ENV_FILE" ]; then
    export ENV_ENCRYPTION_KEY=$(cat "$KEY_FILE" | tr -d '\n')
    if [ -n "$ENV_ENCRYPTION_KEY" ]; then
        USE_ENCRYPTION=true
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🔑 使用加密环境变量模式"
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🔑 加密密钥已加载 (长度: ${#ENV_ENCRYPTION_KEY})"
    fi
fi

# 如果没有加密配置，检查明文环境文件
if [ "$USE_ENCRYPTION" = false ]; then
    if [ -f "$PLAINTEXT_ENV_FILE" ]; then
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📁 使用明文环境变量: $PLAINTEXT_ENV_FILE"
    else
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ⚠️  警告: 未找到环境配置文件"
        echo "   需要以下任一配置:"
        echo "   - 加密模式: $KEY_FILE + $ENCRYPTED_ENV_FILE"
        echo "   - 明文模式: $PLAINTEXT_ENV_FILE"
    fi
fi

# 验证环境变量（如果使用加密模式）
if [ "$USE_ENCRYPTION" = true ]; then
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🔓 解密并验证环境变量..."
    python3 <<EOF
import os
import sys
from pathlib import Path

# 确保可以导入 utils 模块
sys.path.insert(0, '${PROJECT_ROOT}')
from utils.env_encryption import decrypt_env_file, parse_env_content

key = os.getenv('ENV_ENCRYPTION_KEY')
encrypted_file = Path('${ENCRYPTED_ENV_FILE}')

try:
    content = decrypt_env_file(encrypted_file, key)
    env_vars = parse_env_content(content)
    
    # 加载到系统环境（不覆盖已存在的）
    for k, v in env_vars.items():
        if k not in os.environ:
            os.environ[k] = v
    
    # 显示关键环境变量（前20位）
    print("[验证] 📊 环境变量验证:")
    key_names = ['USE_ONE_API', 'ONE_API_BASE_URL', 'ONE_API_KEY', 'ONE_API_GEMINI_MODEL', 'ONE_API_GEMINI_VISION_MODEL', 'GEMINI_API_KEY']
    for key_name in key_names:
        val = os.getenv(key_name)
        if val:
            if 'KEY' in key_name:
                print(f"   ✅ {key_name}: {val[:10]}...{val[-4:] if len(val) > 14 else ''}")
            else:
                print(f"   ✅ {key_name}: {val}")
        else:
            print(f"   ⚠️  {key_name}: 未找到")
    
    print(f"\n[验证] ✅ 共加载 {len(env_vars)} 个环境变量")
except Exception as e:
    print(f"   ❌ 解密失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF
    if [ $? -ne 0 ]; then
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 环境变量验证失败"
        exit 1
    fi
    
    # 如果加密文件中没有 One-API 配置，尝试从 .env.production 读取或使用默认配置
    if [ -z "$ONE_API_BASE_URL" ] || [ -z "$ONE_API_KEY" ]; then
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ⚠️  加密文件中未找到 One-API 配置"
        
        # 尝试从 .env.production 读取
        if [ -f "$PLAINTEXT_ENV_FILE" ]; then
            echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📁 尝试从 .env.production 读取 One-API 配置..."
            source <(grep -E "^USE_ONE_API=|^ONE_API_BASE_URL=|^ONE_API_KEY=|^ONE_API_GEMINI_VISION_MODEL=" "$PLAINTEXT_ENV_FILE" 2>/dev/null || true)
        fi
        
        # 如果还是没有，使用默认配置
        export USE_ONE_API="${USE_ONE_API:-true}"
        export ONE_API_BASE_URL="${ONE_API_BASE_URL:-http://104.154.76.119:3000/v1}"
        export ONE_API_KEY="${ONE_API_KEY:-sk-7UokIik5JjNUPIft42A9E9F01f7d4738973aC119C5E26e2c}"
        export ONE_API_GEMINI_VISION_MODEL="${ONE_API_GEMINI_VISION_MODEL:-gemini-2.0-flash-exp}"
        
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📋 One-API 配置:"
        echo "   USE_ONE_API: $USE_ONE_API"
        echo "   ONE_API_BASE_URL: $ONE_API_BASE_URL"
        echo "   ONE_API_KEY: ${ONE_API_KEY:0:10}...${ONE_API_KEY: -4}"
        echo "   ONE_API_GEMINI_VISION_MODEL: $ONE_API_GEMINI_VISION_MODEL"
    fi
fi

# 如果没有使用加密模式，尝试从 .env.production 加载
if [ "$USE_ENCRYPTION" = false ] && [ -f "$PLAINTEXT_ENV_FILE" ]; then
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📁 从 .env.production 加载环境变量..."
    set -a
    source "$PLAINTEXT_ENV_FILE"
    set +a
fi

# 创建日志目录
mkdir -p logs
mkdir -p ../logs

# 清空旧日志（启动时清空，避免日志文件过大）
LOG_FILE="../logs/app-$PORT.log"
if [ -f "$LOG_FILE" ]; then
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🗑️  清空旧日志文件: $LOG_FILE"
    > "$LOG_FILE"  # 清空文件内容
fi

# 确保 One-API 配置已设置（如果还没有）
export USE_ONE_API="${USE_ONE_API:-true}"
export ONE_API_BASE_URL="${ONE_API_BASE_URL:-http://104.154.76.119:3000/v1}"
export ONE_API_KEY="${ONE_API_KEY:-sk-7UokIik5JjNUPIft42A9E9F01f7d4738973aC119C5E26e2c}"
export ONE_API_GEMINI_VISION_MODEL="${ONE_API_GEMINI_VISION_MODEL:-gemini-2.0-flash-exp}"

# 最终验证环境变量
echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🔍 最终环境变量检查..."
echo "  USE_ONE_API: $USE_ONE_API"
echo "  ONE_API_BASE_URL: $ONE_API_BASE_URL"
echo "  ONE_API_KEY: ${ONE_API_KEY:0:10}...${ONE_API_KEY: -4}"
echo "  ONE_API_GEMINI_VISION_MODEL: $ONE_API_GEMINI_VISION_MODEL"
echo ""

echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🚀 启动服务在端口 $PORT..."
echo ""

# 导出所有必要的环境变量（确保在启动前设置）
export PORT=$PORT
export USE_ONE_API="${USE_ONE_API:-true}"
export ONE_API_BASE_URL="${ONE_API_BASE_URL:-http://104.154.76.119:3000/v1}"
export ONE_API_KEY="${ONE_API_KEY:-sk-7UokIik5JjNUPIft42A9E9F01f7d4738973aC119C5E26e2c}"
export ONE_API_GEMINI_VISION_MODEL="${ONE_API_GEMINI_VISION_MODEL:-gemini-2.0-flash-exp}"

# 启动服务（直接使用 uvicorn，确保环境变量被传递）
nohup env USE_ONE_API="$USE_ONE_API" \
         ONE_API_BASE_URL="$ONE_API_BASE_URL" \
         ONE_API_KEY="$ONE_API_KEY" \
         ONE_API_GEMINI_VISION_MODEL="$ONE_API_GEMINI_VISION_MODEL" \
         ENV_ENCRYPTION_KEY="$ENV_ENCRYPTION_KEY" \
         PYTHONPATH="$PYTHONPATH" \
         PORT="$PORT" \
         uvicorn app.main:app --host 0.0.0.0 --port $PORT > ../logs/app-$PORT.log 2>&1 &

# 记录启动命令（用于调试）
echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📝 启动命令已执行"
echo "   端口: $PORT"
echo "   环境变量已设置: USE_ONE_API, ONE_API_BASE_URL, ONE_API_KEY, ONE_API_GEMINI_VISION_MODEL"

# 等待服务启动
sleep 4

# 检查服务是否启动成功
if pgrep -f "uvicorn app.main:app.*--port $PORT" > /dev/null; then
    PID=$(pgrep -f "uvicorn app.main:app.*--port $PORT" | head -1)
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ✅ 服务启动成功! PID: $PID"
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📝 日志文件: $LOG_FILE"
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📊 查看日志: tail -f $LOG_FILE"
    echo ""
    echo "=========================================="
    echo "日志文件位置:"
    echo "  主日志: $LOG_FILE"
    echo "  应用日志: logs/smartguard_\$(date +%Y-%m-%d).log"
    echo "  错误日志: logs/smartguard_error_\$(date +%Y-%m-%d).log"
    echo "=========================================="
    echo ""
    echo "最近日志:"
    if [ -f "$LOG_FILE" ]; then
        tail -n 15 "$LOG_FILE"
    else
        echo "  日志文件尚未生成，请稍候..."
    fi
else
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 服务启动失败"
    echo "=========================================="
    if [ -f "$LOG_FILE" ]; then
        tail -30 "$LOG_FILE"
    else
        echo "  未找到日志文件，请检查启动命令"
    fi
    exit 1
fi

