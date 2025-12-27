#!/bin/bash
# 后端部署脚本（包含数据库更新）
# 服务器: 34.87.2.104
# 用户: support
# 部署路径: /home/support/smartguard

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 服务器配置
SERVER_IP="34.87.2.104"
SERVER_USER="support"
SSH_KEY="$HOME/.ssh/id_rsa_google_longterm"
DEPLOY_PATH="/home/support/smartguard"
REMOTE_PORT="8001"

echo "=========================================="
echo "  SmartGuard 后端部署（含数据库更新）"
echo "=========================================="
echo ""

# 1. 检查SSH连接
echo "📋 步骤 1/6: 检查SSH连接..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER_USER@$SERVER_IP" "echo 'SSH连接成功'" &>/dev/null; then
    echo "❌ SSH连接失败"
    exit 1
fi
echo "✅ SSH连接成功"
echo ""

# 2. 备份服务器数据库
echo "📋 步骤 2/6: 备份服务器数据库..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
    cd /home/support/smartguard/backend
    if [ -f "data/hospital_monitoring.db" ]; then
        BACKUP_FILE="data/hospital_monitoring_$(date +%Y%m%d_%H%M%S).db"
        cp data/hospital_monitoring.db "$BACKUP_FILE"
        echo "✅ 数据库已备份: $BACKUP_FILE"
        ls -lh "$BACKUP_FILE"
    else
        echo "ℹ️  数据库文件不存在，将创建新数据库"
    fi
EOF
echo ""

# 3. 打包并上传后端代码
echo "📋 步骤 3/6: 打包并上传后端代码..."
TARBALL="smartguard-backend-$(date +%Y%m%d-%H%M%S).tar.gz"
tar --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='venv' \
    --exclude='.env' \
    --exclude='data/*.db' \
    --exclude='logs/*' \
    --exclude='.specstory' \
    -czf "/tmp/$TARBALL" backend/

scp -i "$SSH_KEY" "/tmp/$TARBALL" "$SERVER_USER@$SERVER_IP:/tmp/"
echo "✅ 代码已上传"
echo ""

# 4. 部署代码
echo "📋 步骤 4/6: 部署代码到服务器..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
    set -e
    cd /home/support/smartguard
    
    # 解压新代码
    echo "解压代码..."
    tar -xzf /tmp/$TARBALL -C /home/support/smartguard/
    
    # 恢复数据库（如果备份存在）
    if [ -f "backend/data/hospital_monitoring_"*.db ]; then
        LATEST_BACKUP=\$(ls -t backend/data/hospital_monitoring_*.db | head -1)
        if [ ! -f "backend/data/hospital_monitoring.db" ]; then
            echo "恢复数据库备份..."
            cp "\$LATEST_BACKUP" backend/data/hospital_monitoring.db
        fi
    fi
    
    # 设置权限
    chmod +x backend/start*.sh 2>/dev/null || true
    chmod +x backend/scripts/*.py 2>/dev/null || true
    
    # 清理临时文件
    rm -f /tmp/$TARBALL
EOF
echo "✅ 代码部署完成"
echo ""

# 5. 安装依赖和执行数据库迁移
echo "📋 步骤 5/6: 安装依赖和执行数据库迁移..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
    set -e
    cd /home/support/smartguard/backend
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 安装/更新依赖
    echo "安装依赖..."
    pip install --upgrade pip -q
    pip install -r requirements.txt -q
    
    # 执行数据库迁移
    echo "执行数据库迁移..."
    python scripts/add_mobile_tables.py
    
    echo "✅ 依赖安装和数据库迁移完成"
EOF
echo ""

# 6. 重启后端服务
echo "📋 步骤 6/6: 重启后端服务..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
    set -e
    cd /home/support/smartguard/backend
    
    # 停止旧服务
    echo "停止旧服务..."
    pkill -f "uvicorn app.main:app.*--port $REMOTE_PORT" 2>/dev/null || true
    sleep 2
    
    # 启动新服务
    echo "启动新服务..."
    source venv/bin/activate
    export ENV_ENCRYPTION_KEY=\$(cat .env.encryption.key | tr -d '\n') 2>/dev/null || true
    export PYTHONPATH=/home/support/smartguard/backend
    mkdir -p /home/support/smartguard/logs
    
    nohup uvicorn app.main:app --host 0.0.0.0 --port $REMOTE_PORT > /home/support/smartguard/logs/app-$REMOTE_PORT.log 2>&1 &
    
    sleep 3
    if pgrep -f "uvicorn app.main:app.*--port $REMOTE_PORT" > /dev/null; then
        echo "✅ 服务启动成功"
        echo "访问地址: http://$SERVER_IP:$REMOTE_PORT"
    else
        echo "❌ 服务启动失败，请检查日志"
        tail -30 /home/support/smartguard/logs/app-$REMOTE_PORT.log
        exit 1
    fi
EOF

echo ""
echo "=========================================="
echo "  后端部署完成！"
echo "=========================================="
echo ""
echo "服务器信息:"
echo "  IP: $SERVER_IP"
echo "  部署路径: $DEPLOY_PATH"
echo ""
echo "访问地址:"
echo "  http://$SERVER_IP:$REMOTE_PORT"
echo "  https://smartguard.gitagent.io"
echo ""
echo "查看日志:"
echo "  tail -f /home/support/smartguard/logs/app-$REMOTE_PORT.log"
echo ""

