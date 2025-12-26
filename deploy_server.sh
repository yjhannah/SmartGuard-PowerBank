#!/bin/bash
# 服务器部署脚本
# 服务器: 34.87.2.104
# 域名: smartguard.gitagent.io
# 用户: support
# 部署路径: /home/support/smartguard
# SSH: ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 服务器配置
SERVER_IP="34.87.2.104"
SERVER_DOMAIN="smartguard.gitagent.io"
SERVER_USER="support"
SSH_KEY="$HOME/.ssh/id_rsa_google_longterm"
DEPLOY_PATH="/home/support/smartguard"
REMOTE_PORT="8001"  # 默认使用8001端口，避免与8000端口冲突

echo "=========================================="
echo "  医院病房智能监护系统 - 服务器部署"
echo "=========================================="
echo ""
echo "服务器: $SERVER_IP ($SERVER_DOMAIN)"
echo "部署路径: $DEPLOY_PATH"
echo ""

# 1. 检查SSH连接
echo "📋 步骤 1/7: 检查SSH连接..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER_USER@$SERVER_IP" "echo 'SSH连接成功'" &>/dev/null; then
    echo "❌ SSH连接失败，请检查："
    echo "   1. SSH key权限: chmod 600 $SSH_KEY"
    echo "   2. 服务器是否可访问"
    echo "   3. SSH key是否已添加到服务器"
    exit 1
fi
echo "✅ SSH连接成功"
echo ""

# 2. 检查服务器环境
echo "📋 步骤 2/7: 检查服务器环境..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
    echo "检查Python..."
    if ! command -v python3 &> /dev/null; then
        echo "安装Python3..."
        sudo apt-get update -qq
        sudo apt-get install -y python3 python3-pip python3-venv &>/dev/null
    fi
    python3 --version
    
    echo "检查Git..."
    if ! command -v git &> /dev/null; then
        sudo apt-get install -y git &>/dev/null
    fi
    git --version
    
    echo "创建部署目录..."
    mkdir -p /home/support/smartguard
EOF
echo "✅ 服务器环境检查完成"
echo ""

# 3. 打包代码
echo "📋 步骤 3/7: 打包代码..."
TARBALL="smartguard-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
tar --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='venv' \
    --exclude='.env' \
    --exclude='data/*.db' \
    --exclude='logs/*' \
    --exclude='.specstory' \
    --exclude='doc' \
    -czf "/tmp/$TARBALL" .
echo "✅ 代码打包完成: /tmp/$TARBALL"
echo ""

# 4. 上传代码
echo "📋 步骤 4/7: 上传代码到服务器..."
scp -i "$SSH_KEY" "/tmp/$TARBALL" "$SERVER_USER@$SERVER_IP:/tmp/"
echo "✅ 代码上传完成"
echo ""

# 5. 部署到服务器
echo "📋 步骤 5/7: 在服务器上部署..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
    set -e
    cd /home/support/smartguard
    
    # 备份现有部署（如果存在）
    if [ -d "backend" ]; then
        echo "备份现有部署..."
        BACKUP_DIR="backup-\$(date +%Y%m%d-%H%M%S)"
        mkdir -p "\$BACKUP_DIR"
        cp -r backend/data/*.db "\$BACKUP_DIR/" 2>/dev/null || true
        cp backend/.env* "\$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    # 解压新代码
    echo "解压代码..."
    tar -xzf /tmp/$TARBALL -C /home/support/smartguard
    
    # 恢复数据库和环境变量（如果存在备份）
    if [ -d "backup-"* ]; then
        echo "恢复数据库和环境变量..."
        cp backup-*/*.db backend/data/ 2>/dev/null || true
        cp backup-*/.env* backend/ 2>/dev/null || true
    fi
    
    # 设置权限
    chmod +x backend/start.sh 2>/dev/null || true
    chmod +x backend/scripts/*.py 2>/dev/null || true
    
    # 创建日志目录
    mkdir -p logs
    
    # 清理临时文件
    rm -f /tmp/$TARBALL
EOF
echo "✅ 服务器部署完成"
echo ""

# 6. 安装依赖和配置
echo "📋 步骤 6/7: 安装依赖和配置..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
    set -e
    cd /home/support/smartguard/backend
    
    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        echo "创建虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境并安装依赖
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install -r requirements.txt -q
    
    # 初始化数据库（如果不存在）
    if [ ! -f "data/hospital_monitoring.db" ]; then
        echo "初始化数据库..."
        python scripts/init_db.py
    fi
    
    echo "依赖安装完成"
EOF
echo "✅ 依赖安装完成"
echo ""

# 7. 启动服务
echo "📋 步骤 7/7: 启动服务..."
echo ""
echo "⚠️  注意：需要手动配置环境变量文件"
echo "   在服务器上执行："
echo "   ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP"
echo "   cd /home/support/smartguard/backend"
echo "   # 创建或上传 .env.encrypted 文件"
echo ""
echo "当前端口配置: $REMOTE_PORT"
echo "检查端口占用情况..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
    echo "检查端口 $REMOTE_PORT..."
    if ss -tlnp 2>/dev/null | grep -q ":$REMOTE_PORT " || netstat -tlnp 2>/dev/null | grep -q ":$REMOTE_PORT "; then
        echo "⚠️  端口 $REMOTE_PORT 已被占用"
        echo "正在运行的端口:"
        ss -tlnp 2>/dev/null | grep -E ':(800[0-9])' || netstat -tlnp 2>/dev/null | grep -E ':(800[0-9])' || echo "无法检查端口"
    else
        echo "✅ 端口 $REMOTE_PORT 可用"
    fi
EOF
echo ""
read -p "是否现在启动服务在端口 $REMOTE_PORT? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
        cd /home/support/smartguard/backend
        
        # 停止本目录下的服务（如果运行在相同端口）
        pkill -f "uvicorn app.main:app.*--port $REMOTE_PORT" 2>/dev/null || true
        sleep 2
        
        # 启动服务
        source venv/bin/activate
        export ENV_ENCRYPTION_KEY=\$(cat .env.encryption.key | tr -d '\n') 2>/dev/null || true
        export PYTHONPATH=/home/support/smartguard/backend
        mkdir -p /home/support/smartguard/logs
        nohup uvicorn app.main:app --host 0.0.0.0 --port $REMOTE_PORT > /home/support/smartguard/logs/app-$REMOTE_PORT.log 2>&1 &
        
        sleep 3
        if pgrep -f "uvicorn app.main:app.*--port $REMOTE_PORT" > /dev/null; then
            echo "✅ 服务启动成功"
            echo "访问地址: http://34.87.2.104:$REMOTE_PORT"
            echo "或: https://smartguard.gitagent.io"
        else
            echo "❌ 服务启动失败，请检查日志: /home/support/smartguard/logs/app-$REMOTE_PORT.log"
            tail -30 /home/support/smartguard/logs/app-$REMOTE_PORT.log
        fi
EOF
fi

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "服务器信息:"
echo "  IP: $SERVER_IP"
echo "  域名: $SERVER_DOMAIN"
echo "  部署路径: $DEPLOY_PATH"
echo ""
echo "访问地址:"
echo "  http://$SERVER_IP:$REMOTE_PORT"
echo "  https://$SERVER_DOMAIN"
echo ""
echo "管理命令:"
echo "  SSH连接: ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP"
echo "  查看日志: tail -f /home/support/smartguard/logs/app-$REMOTE_PORT.log"
echo "  重启服务: cd /home/support/smartguard/backend && source venv/bin/activate && export ENV_ENCRYPTION_KEY=\$(cat .env.encryption.key | tr -d '\n') && export PYTHONPATH=/home/support/smartguard/backend && pkill -f 'uvicorn app.main:app.*--port $REMOTE_PORT' && nohup uvicorn app.main:app --host 0.0.0.0 --port $REMOTE_PORT > /home/support/smartguard/logs/app-$REMOTE_PORT.log 2>&1 &"
echo "  停止服务: pkill -f 'uvicorn app.main:app.*--port $REMOTE_PORT'"
echo "  查看运行的服务: ps aux | grep uvicorn"
echo ""
echo "当前运行的服务:"
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
    echo "检查所有运行中的服务..."
    ps aux | grep "uvicorn app.main:app" | grep -v grep | awk '{for(i=11;i<=NF;i++) if($i ~ /--port/) {port=$i; gsub(/--port=/, "", port); gsub(/--port /, "", port); print "  端口 " port ": PID " $2}}'
    echo ""
    echo "端口占用情况:"
    ss -tlnp 2>/dev/null | grep -E ':(800[0-9])' | awk '{print "  " $4}' || netstat -tlnp 2>/dev/null | grep -E ':(800[0-9])' | awk '{print "  " $4}' || echo "  无法检查"
EOF
echo ""

