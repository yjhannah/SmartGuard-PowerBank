#!/bin/bash
# 部署代码并跟踪详细日志

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  部署代码到服务器并跟踪详细日志"
echo "=========================================="
echo ""

# 1. 提交代码到GitHub
echo "📋 步骤 1/4: 提交代码到GitHub..."
git add -A
if ! git diff --cached --quiet; then
    git commit -m "添加详细日志：追踪告警创建和类型判断过程

- 在告警服务中添加详细的日志输出
- 记录每个检测项目的检查过程
- 记录告警类型判断的优先级顺序
- 记录最终创建的告警类型和标题" || echo "提交失败或无需提交"
    git push origin main || echo "推送失败"
    echo "✅ 代码已推送到GitHub"
else
    echo "✅ 没有需要提交的更改"
fi
echo ""

# 2. 部署到服务器
echo "📋 步骤 2/4: 部署代码到服务器..."
bash deploy_server.sh
echo ""

# 3. 检查服务器代码
echo "📋 步骤 3/4: 检查服务器代码..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    
    echo "检查告警服务代码..."
    if grep -q "优先级1: 生命体征监测" app/services/alert_service.py; then
        echo "✅ 服务器代码已更新（包含优先级调整）"
    else
        echo "❌ 服务器代码未更新"
        echo "显示前10行:"
        head -10 app/services/alert_service.py | grep -E "(优先级|vital_signs|bed_exit)" || echo "未找到相关代码"
    fi
    
    echo ""
    echo "检查前端代码..."
    if grep -q "getAlertDisplayInfo" frontend/nurse.html; then
        echo "✅ 前端代码已更新（包含getAlertDisplayInfo函数）"
    else
        echo "❌ 前端代码未更新"
    fi
EOF
echo ""

# 4. 重启服务并检查日志
echo "📋 步骤 4/4: 重启服务并检查日志..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    
    echo "停止现有服务..."
    pkill -f 'uvicorn app.main:app.*--port 8001' || true
    sleep 3
    
    echo "启动服务..."
    bash start_production.sh > /tmp/start_$(date +%Y%m%d_%H%M%S).log 2>&1 &
    sleep 6
    
    echo ""
    echo "检查服务状态..."
    if ps aux | grep 'uvicorn app.main:app.*--port 8001' | grep -v grep; then
        echo "✅ 服务启动成功"
    else
        echo "❌ 服务启动失败"
        echo "启动日志:"
        tail -30 /tmp/start_*.log | tail -10
    fi
    
    echo ""
    echo "检查最新告警记录..."
    source venv/bin/activate
    python3 << 'PYEOF'
import asyncio
import sys
sys.path.insert(0, '.')
from app.core.database import execute_query

async def check():
    # 检查最新的告警
    alerts = await execute_query('''
        SELECT alert_id, alert_type, title, description, created_at 
        FROM alerts 
        ORDER BY created_at DESC 
        LIMIT 5
    ''')
    
    print(f'=== 最新的5条告警 ===')
    for a in alerts:
        print(f'时间: {a["created_at"]}')
        print(f'类型: {a["alert_type"]}')
        print(f'标题: {a["title"]}')
        print(f'描述: {a["description"][:50] if a["description"] else "无"}...')
        print('---')

asyncio.run(check())
PYEOF
    
    echo ""
    echo "最近50行日志（包含告警相关）:"
    tail -50 /home/support/smartguard/logs/app-8001.log | grep -E "(告警|alert|检测|vital_signs|heart_rate|bed_exit|优先级|分析结果)" | tail -20 || echo "未找到相关日志"
EOF

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="

