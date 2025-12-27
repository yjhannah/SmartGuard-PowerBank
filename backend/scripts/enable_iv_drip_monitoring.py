#!/usr/bin/env python3
"""
为所有患者启用吊瓶监测
"""
import asyncio
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_query, execute_update

async def enable_iv_drip_for_all_patients():
    """为所有患者启用吊瓶监测"""
    print("=" * 50)
    print("为所有患者启用吊瓶监测...")
    print("=" * 50)
    
    try:
        # 1. 获取所有患者ID
        patients = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients WHERE is_hospitalized = 1"
        )
        
        if not patients:
            print("⚠️  未找到住院患者")
            return
        
        print(f"\n📋 找到 {len(patients)} 位住院患者")
        
        # 2. 为每个患者更新或创建监测配置
        updated_count = 0
        created_count = 0
        
        for patient in patients:
            patient_id = patient['patient_id']
            patient_code = patient['patient_code']
            patient_name = patient['full_name']
            
            # 检查是否已有配置
            existing_config = await execute_query(
                "SELECT config_id FROM monitoring_configs WHERE patient_id = ?",
                (patient_id,)
            )
            
            if existing_config:
                # 更新现有配置
                await execute_update(
                    """UPDATE monitoring_configs 
                       SET iv_drip_monitoring_enabled = 1, 
                           updated_at = CURRENT_TIMESTAMP
                       WHERE patient_id = ?""",
                    (patient_id,)
                )
                updated_count += 1
                print(f"✅ 更新患者 {patient_code} ({patient_name}) 的监测配置 - 启用吊瓶监测")
            else:
                # 创建新配置（启用所有检测）
                import uuid
                config_id = str(uuid.uuid4())
                from app.core.database import execute_insert
                await execute_insert(
                    """INSERT INTO monitoring_configs 
                       (config_id, patient_id, fall_detection_enabled, 
                        bed_exit_detection_enabled, facial_analysis_enabled, 
                        abnormal_activity_enabled, iv_drip_monitoring_enabled,
                        bed_exit_threshold_minutes)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                    (config_id, patient_id, 1, 1, 1, 1, 1, 10)
                )
                created_count += 1
                print(f"✅ 创建患者 {patient_code} ({patient_name}) 的监测配置 - 启用吊瓶监测")
        
        print("\n" + "=" * 50)
        print(f"✅ 完成！")
        print(f"   更新配置: {updated_count} 位患者")
        print(f"   创建配置: {created_count} 位患者")
        print("=" * 50)
        
        # 3. 验证结果
        print("\n📊 验证配置...")
        configs = await execute_query(
            """SELECT p.patient_code, p.full_name, mc.iv_drip_monitoring_enabled
               FROM patients p
               LEFT JOIN monitoring_configs mc ON p.patient_id = mc.patient_id
               WHERE p.is_hospitalized = 1"""
        )
        
        for config in configs:
            status = "✅ 已启用" if config.get('iv_drip_monitoring_enabled') else "❌ 未启用"
            print(f"   {config['patient_code']} ({config['full_name']}): {status}")
        
    except Exception as e:
        print(f"\n❌ 操作失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(enable_iv_drip_for_all_patients())

