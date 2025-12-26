#!/bin/bash

# AuraRecruit 后端服务启动脚本
# 适用于腾讯云服务器 (candaigo.com)
# 包含完整的停止、启动和日志功能

# 设置北京时间（UTC+8）
export TZ="Asia/Shanghai"

# 1. 停止现有应用
echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🛑 停止现有后端服务..."
pkill -f 'app.main:app' && sleep 2 || echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')]    没有运行中的服务"

# 2. 设置环境
export PROJECT_ROOT="/root/AuraRecruit"
export BACKEND_DIR="$PROJECT_ROOT/backend"
export KEY_FILE="$BACKEND_DIR/.env.encryption.key"
export ENCRYPTED_ENV_FILE="$BACKEND_DIR/.env.production.encrypted"
export PLAINTEXT_ENV_FILE="$BACKEND_DIR/.env.production"
export LOG_FILE="$BACKEND_DIR/backend.log"

# 优先使用加密环境变量，如果有密钥文件
USE_ENCRYPTION=false
if [ -f "$KEY_FILE" ] && [ -f "$ENCRYPTED_ENV_FILE" ]; then
    export ENV_ENCRYPTION_KEY=$(cat "$KEY_FILE")
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
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 错误: 找不到环境配置文件"
        echo "   需要以下任一配置:"
        echo "   - 加密模式: $KEY_FILE + $ENCRYPTED_ENV_FILE"
        echo "   - 明文模式: $PLAINTEXT_ENV_FILE"
        exit 1
    fi
fi

# 验证环境变量（如果使用加密模式）
if [ "$USE_ENCRYPTION" = true ]; then
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🔓 解密并验证环境变量..."
    cd "$BACKEND_DIR"
    python3 <<EOF
import os
from pathlib import Path
from utils.env_encryption import decrypt_env_file, parse_env_content

key = os.getenv('ENV_ENCRYPTION_KEY')
encrypted_file = Path('$ENCRYPTED_ENV_FILE')

try:
    content = decrypt_env_file(encrypted_file, key)
    env_vars = parse_env_content(content)
    
    # 显示关键环境变量（前15位）
    print("[验证] 📊 环境变量验证:")
    for key_name in ['GEMINI_API_KEY', 'TENCENT_SECRET_KEY', 'XUNFEI_API_KEY', 'SUPABASE_SERVICE_KEY', 'SUPABASE_ANON_KEY']:
        if key_name in env_vars:
            val = env_vars[key_name]
            print(f"   ✅ {key_name}: {val[:15]}...")
        else:
            print(f"   ⚠️  {key_name}: 未找到")
except Exception as e:
    print(f"   ❌ 解密失败: {e}")
    exit(1)
EOF
    if [ $? -ne 0 ]; then
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 环境变量验证失败"
        exit 1
    fi
fi

# 3. 导出微信登录环境变量（网站应用AppID，不在加密文件中，需要单独设置）
export WECHAT_APP_ID="wxb18b5458a5f09d63"
export WECHAT_APP_SECRET="22f69ff25be1837be828d358095951c8"
export WECHAT_REDIRECT_URI="https://candaigo.com/api/auth/wechat/callback"
echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🔗 微信登录配置已加载 (网站应用: wxb18b...)"

# 4. 启动应用
echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 🚀 启动后端服务..."
cd "$BACKEND_DIR" || exit 1

# 备份旧日志
if [ -f "$LOG_FILE" ]; then
    mv "$LOG_FILE" "$LOG_FILE.$(TZ='Asia/Shanghai' date '+%Y%m%d_%H%M%S').bak"
fi

# 启动服务（后台运行，带北京时间戳日志）
nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8003 2>&1 | \
    while IFS= read -r line; do 
        echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] $line"
    done > "$LOG_FILE" &

# 4. 验证启动
echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ⏳ 等待服务启动..."
sleep 4

if pgrep -f 'app.main:app' > /dev/null; then
    PID=$(pgrep -f 'app.main:app' | head -1)
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ✅ 服务启动成功! PID: $PID"
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📝 日志文件: $LOG_FILE"
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] 📊 查看日志: tail -f $LOG_FILE"
    echo "=========================================="
    echo "最近日志:"
    tail -n 10 "$LOG_FILE"
else
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] ❌ 服务启动失败"
    echo "=========================================="
    cat "$LOG_FILE"
    exit 1
fi
