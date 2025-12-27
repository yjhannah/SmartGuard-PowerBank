#!/bin/bash
# 验证部署并检查告警逻辑

echo "=========================================="
echo "  验证部署和告警逻辑"
echo "=========================================="
echo ""

# 1. 检查本地代码
echo "📋 步骤 1/3: 检查本地代码..."
cd /Users/a1/work/SmartGuard-PowerBank

if grep -q "优先级1: 生命体征监测" backend/app/services/alert_service.py; then
    echo "✅ 本地代码包含优先级调整"
else
    echo "❌ 本地代码未包含优先级调整"
fi

if grep -q "getAlertDisplayInfo" frontend/nurse.html; then
    echo "✅ 本地前端代码包含getAlertDisplayInfo函数"
else
    echo "❌ 本地前端代码未包含getAlertDisplayInfo函数"
fi
echo ""

# 2. 检查服务器代码
echo "📋 步骤 2/3: 检查服务器代码..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    
    echo "检查告警服务代码..."
    if grep -q "优先级1: 生命体征监测" app/services/alert_service.py; then
        echo "✅ 服务器代码已更新（包含优先级调整）"
        echo "显示优先级1的代码:"
        grep -A 10 "优先级1: 生命体征监测" app/services/alert_service.py | head -12
    else
        echo "❌ 服务器代码未更新"
    fi
    
    echo ""
    echo "检查前端代码..."
    if grep -q "getAlertDisplayInfo" ../frontend/nurse.html; then
        echo "✅ 前端代码已更新"
    else
        echo "❌ 前端代码未更新"
    fi
EOF
echo ""

# 3. 检查数据库中的告警记录
echo "📋 步骤 3/3: 检查数据库中的告警记录..."
ssh -i ~/.ssh/id_rsa_google_longterm support@34.87.2.104 << 'EOF'
    cd /home/support/smartguard/backend
    source venv/bin/activate
    
    python3 << 'PYEOF'
import asyncio
import sys
import json
sys.path.insert(0, '.')
from app.core.database import execute_query

async def check():
    print("=== 检查最新的告警记录 ===")
    alerts = await execute_query('''
        SELECT alert_id, alert_type, title, description, created_at, analysis_result_id
        FROM alerts 
        ORDER BY created_at DESC 
        LIMIT 5
    ''')
    
    for i, a in enumerate(alerts, 1):
        print(f"\n告警 #{i}:")
        print(f"  ID: {a['alert_id'][:8]}...")
        print(f"  类型: {a['alert_type']}")
        print(f"  标题: {a['title']}")
        print(f"  描述: {(a['description'] or '')[:60]}...")
        print(f"  时间: {a['created_at']}")
        
        # 检查关联的分析结果
        if a.get('analysis_result_id'):
            results = await execute_query('''
                SELECT analysis_data FROM ai_analysis_results 
                WHERE result_id = ?
            ''', (a['analysis_result_id'],))
            
            if results:
                analysis_data = json.loads(results[0]['analysis_data']) if isinstance(results[0]['analysis_data'], str) else results[0]['analysis_data']
                detections = analysis_data.get('detections', {})
                
                print(f"  分析结果检测项目: {list(detections.keys())}")
                
                # 检查vital_signs
                vital_signs = detections.get('vital_signs', {})
                if vital_signs:
                    print(f"    vital_signs.detected: {vital_signs.get('detected')}")
                    print(f"    heart_rate_flat: {vital_signs.get('heart_rate_flat')}")
                    print(f"    critical_life_threat: {vital_signs.get('critical_life_threat')}")
                
                # 检查bed_exit
                bed_exit = detections.get('bed_exit', {})
                if bed_exit:
                    print(f"    bed_exit.patient_in_bed: {bed_exit.get('patient_in_bed')}")
                
                # 判断是否正确
                if vital_signs.get('detected') and (vital_signs.get('heart_rate_flat') or vital_signs.get('critical_life_threat')):
                    if a['alert_type'] == 'heart_rate_flat':
                        print(f"  ✅ 告警类型正确：心跳变平")
                    else:
                        print(f"  ❌ 告警类型错误：应该是heart_rate_flat，但实际是{a['alert_type']}")
                elif not bed_exit.get('patient_in_bed') and not vital_signs.get('detected'):
                    if a['alert_type'] == 'bed_exit_timeout':
                        print(f"  ✅ 告警类型正确：离床检测")
                    else:
                        print(f"  ❌ 告警类型错误：应该是bed_exit_timeout，但实际是{a['alert_type']}")

asyncio.run(check())
PYEOF
EOF

echo ""
echo "=========================================="
echo "  验证完成！"
echo "=========================================="

