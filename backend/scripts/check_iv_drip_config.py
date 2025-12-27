#!/usr/bin/env python3
"""检查吊瓶监测配置"""
import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from app.core.database import execute_query

async def check():
    configs = await execute_query(
        """SELECT p.patient_code, p.full_name, mc.iv_drip_monitoring_enabled 
           FROM patients p 
           LEFT JOIN monitoring_configs mc ON p.patient_id = mc.patient_id 
           WHERE p.is_hospitalized = 1"""
    )
    print("=" * 50)
    print("患者吊瓶监测配置状态:")
    print("=" * 50)
    for c in configs:
        status = "✅ 已启用" if c.get('iv_drip_monitoring_enabled') else "❌ 未启用"
        print(f"  {c['patient_code']} ({c['full_name']}): {status}")
    print("=" * 50)

if __name__ == '__main__':
    asyncio.run(check())

