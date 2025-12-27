#!/bin/bash
# 完整部署脚本：提交代码、部署到服务器、重启服务、验证

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  完整部署流程"
echo "=========================================="
echo ""

# 1. 提交代码到GitHub
echo "📋 步骤 1/5: 提交代码到GitHub..."
git add -A
if ! git diff --cached --quiet; then
    git commit -m "添加详细日志：追踪告警创建和类型判断过程

- 在告警服务中添加详细的日志输出
- 记录每个检测项目的检查过程
- 记录告警类型判断的优先级顺序
- 记录最终创建的告警类型和标题
- 修复告警优先级：生命体征监测优先级最高，吊瓶监测优先级高于离床检测" 2>&1
    git push origin main 2>&1
    echo "✅ 代码已推送到GitHub"
else
    echo "✅ 没有需要提交的更改"
fi
echo ""

# 2. 部署到服务器
echo "📋 步骤 2/5: 部署代码到服务器..."
bash deploy_server.sh 2>&1 | tail -30
echo ""

# 3. 验证服务器代码
echo "📋 步骤 3/5: 验证服务器代码..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    
    echo "检查告警服务代码..."
    if grep -q "优先级1: 生命体征监测" app/services/alert_service.py; then
        echo "✅ 服务器代码已更新（包含优先级调整）"
        echo "显示优先级顺序:"
        grep -E "^        # ========== 优先级" app/services/alert_service.py | head -7
    else
        echo "❌ 服务器代码未更新"
    fi
    
    echo ""
    echo "检查前端代码..."
    if grep -q "getAlertDisplayInfo" ../frontend/nurse.html; then
        echo "✅ 前端代码已更新（包含getAlertDisplayInfo函数）"
    else
        echo "❌ 前端代码未更新"
    fi
EOF
echo ""

# 4. 重启服务
echo "📋 步骤 4/5: 重启服务..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    
    echo "停止现有服务..."
    pkill -f 'uvicorn app.main:app.*--port 8001' || true
    sleep 3
    
    echo "启动服务..."
    bash start_production.sh > /tmp/start_$(date +%Y%m%d_%H%M%S).log 2>&1 &
    sleep 6
    
    echo "检查服务状态..."
    if ps aux | grep 'uvicorn app.main:app.*--port 8001' | grep -v grep | head -1; then
        echo "✅ 服务启动成功"
    else
        echo "❌ 服务启动失败，查看启动日志:"
        tail -20 /tmp/start_*.log | tail -10
    fi
EOF
echo ""

# 5. 检查日志和数据库
echo "📋 步骤 5/5: 检查日志和数据库..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    source venv/bin/activate
    
    echo "=== 最近50行日志（告警相关）==="
    tail -50 /home/support/smartguard/logs/app-8001.log | grep -E "(告警|alert|检测|vital_signs|heart_rate|bed_exit|优先级|分析结果|告警服务|告警分析)" | tail -30 || echo "未找到相关日志"
    
    echo ""
    echo "=== 检查数据库中的告警记录 ==="
    python3 << 'PYEOF'
import asyncio
import sys
import json
sys.path.insert(0, '.')
from app.core.database import execute_query

async def check():
    alerts = await execute_query('''
        SELECT alert_id, alert_type, title, description, created_at, analysis_result_id
        FROM alerts 
        ORDER BY created_at DESC 
        LIMIT 5
    ''')
    
    print(f'找到 {len(alerts)} 条最新告警:')
    for i, a in enumerate(alerts, 1):
        print(f'\n告警 #{i}:')
        print(f'  类型: {a["alert_type"]}')
        print(f'  标题: {a["title"]}')
        print(f'  时间: {a["created_at"]}')
        
        if a.get('analysis_result_id'):
            results = await execute_query('''
                SELECT analysis_data FROM ai_analysis_results 
                WHERE result_id = ?
            ''', (a['analysis_result_id'],))
            
            if results:
                analysis_data = json.loads(results[0]['analysis_data']) if isinstance(results[0]['analysis_data'], str) else results[0]['analysis_data']
                detections = analysis_data.get('detections', {})
                
                vital_signs = detections.get('vital_signs', {})
                bed_exit = detections.get('bed_exit', {})
                
                print(f'  检测项目: {list(detections.keys())}')
                if vital_signs.get('detected'):
                    print(f'    vital_signs: detected=True, heart_rate_flat={vital_signs.get("heart_rate_flat")}, critical_life_threat={vital_signs.get("critical_life_threat")}')
                if bed_exit:
                    print(f'    bed_exit: patient_in_bed={bed_exit.get("patient_in_bed")}')
                
                # 判断是否正确
                if vital_signs.get('detected') and (vital_signs.get('heart_rate_flat') or vital_signs.get('critical_life_threat')):
                    if a['alert_type'] == 'heart_rate_flat':
                        print(f'  ✅ 告警类型正确：心跳变平')
                    else:
                        print(f'  ❌ 告警类型错误：应该是heart_rate_flat，但实际是{a["alert_type"]}')
                elif not bed_exit.get('patient_in_bed') and not vital_signs.get('detected'):
                    if a['alert_type'] == 'bed_exit_timeout':
                        print(f'  ✅ 告警类型正确：离床检测')
                    else:
                        print(f'  ❌ 告警类型错误：应该是bed_exit_timeout，但实际是{a["alert_type"]}')

asyncio.run(check())
PYEOF
EOF

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "1. 上传一张包含心跳监测设备的图片进行测试"
echo "2. 查看日志: tail -f /home/support/smartguard/logs/app-8001.log | grep 告警"
echo "3. 检查告警类型是否正确显示为'心跳监测'而不是'离床检测'"

