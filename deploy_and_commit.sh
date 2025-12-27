#!/bin/bash
# 部署代码到服务器并提交到GitHub

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  部署代码到服务器并提交到GitHub"
echo "=========================================="
echo ""

# 1. 提交代码到GitHub
echo "📋 步骤 1/3: 提交代码到GitHub..."
git add -A
git status --short

if git diff --cached --quiet; then
    echo "✅ 没有需要提交的更改"
else
    git commit -m "优化告警显示：修复心跳检测和吊瓶检测归类问题

- 调整告警检测优先级：生命体征监测（心跳变平）优先级最高，吊瓶监测优先级高于离床检测
- 添加getAlertDisplayInfo函数：为每种告警类型提供图标、类型标签和专用标题
- 优化前端显示：护士端和家属端显示告警时显示类型标签（心跳监测、吊瓶监测、离床检测等）
- 修复告警类型显示一致性：确保心跳检测和吊瓶检测不再归类到离床检测
- 添加图片上传功能：分析图片后自动上传到腾讯云COS并保存URL到数据库
- 优化API查询：get_live_status只返回最近1小时内的最新告警
- 数据库迁移：为alerts和ai_analysis_results表添加image_url字段"
    
    echo "📤 推送到GitHub..."
    git push origin main
    echo "✅ 代码已推送到GitHub"
fi
echo ""

# 2. 部署到服务器
echo "📋 步骤 2/3: 部署代码到服务器..."
bash deploy_server.sh
echo ""

# 3. 重启服务并跟踪日志
echo "📋 步骤 3/3: 重启服务并跟踪日志..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    
    echo "停止现有服务..."
    pkill -f 'uvicorn app.main:app.*--port 8001' || true
    sleep 2
    
    echo "启动服务..."
    bash start_production.sh > /tmp/start_$(date +%Y%m%d_%H%M%S).log 2>&1 &
    sleep 5
    
    echo "检查服务状态..."
    if ps aux | grep 'uvicorn app.main:app.*--port 8001' | grep -v grep; then
        echo "✅ 服务启动成功"
    else
        echo "❌ 服务启动失败"
        tail -30 /tmp/start_*.log
    fi
    
    echo ""
    echo "最近日志:"
    tail -30 /home/support/smartguard/logs/app-8001.log 2>/dev/null || echo "日志文件不存在"
EOF

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="

