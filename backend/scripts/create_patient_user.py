#!/usr/bin/env python3
"""
创建患者端用户脚本
为患者创建登录账号（使用family角色，通过patient_id关联患者）
"""
import asyncio
import sys
from pathlib import Path
import uuid
import hashlib

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_query, execute_insert

def hash_password(password: str) -> str:
    """密码哈希"""
    return hashlib.sha256(password.encode()).hexdigest()


async def create_patient_user(patient_code: str, username: str, password: str, 
                              full_name: str = None, phone: str = None):
    """为患者创建登录账号"""
    try:
        # 查找患者
        patients = await execute_query(
            "SELECT patient_id, full_name FROM patients WHERE patient_code = ?",
            (patient_code,)
        )
        
        if not patients:
            print(f"❌ 未找到患者编号: {patient_code}")
            return None
        
        patient = patients[0]
        patient_id = patient['patient_id']
        patient_name = patient['full_name']
        
        # 检查用户是否已存在
        existing = await execute_query(
            "SELECT user_id FROM users WHERE username = ? OR patient_id = ?",
            (username, patient_id)
        )
        if existing:
            print(f"⚠️  用户 {username} 或患者 {patient_code} 已有关联账号，跳过创建")
            return existing[0]['user_id']
        
        # 创建患者用户（使用family角色，通过patient_id关联）
        user_id = str(uuid.uuid4())
        password_hash = hash_password(password)
        
        display_name = full_name or patient_name
        
        await execute_insert(
            """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, email, patient_id, is_active)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                user_id,
                username,
                password_hash,
                'family',  # 使用family角色（数据库约束不允许patient角色）
                display_name,
                phone,
                f"{username}@patient.com",
                patient_id,  # 关联患者ID
                1
            )
        )
        
        print(f"✅ 创建患者端用户成功:")
        print(f"   用户名: {username} / 密码: {password}")
        print(f"   患者: {patient_name} ({patient_code})")
        print(f"   患者ID: {patient_id}")
        return user_id
    except Exception as e:
        print(f"❌ 创建患者用户失败: {e}")
        import traceback
        traceback.print_exc()
        raise


async def main():
    """主函数"""
    print("=" * 50)
    print("创建患者端用户")
    print("=" * 50)
    
    try:
        # 先查看现有患者
        patients = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients LIMIT 10"
        )
        
        if not patients:
            print("❌ 数据库中没有患者，请先创建患者")
            return
        
        print("\n📋 现有患者列表:")
        for p in patients:
            print(f"   {p['patient_code']}: {p['full_name']}")
        
        # 为第一个患者创建账号（如果存在P001）
        p001 = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients WHERE patient_code = 'P001'"
        )
        if p001:
            await create_patient_user("P001", "patient001", "patient123", 
                                     p001[0]['full_name'], "13800000001")
        
        # 为第二个患者创建账号（如果存在P002）
        p002 = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients WHERE patient_code = 'P002'"
        )
        if p002:
            await create_patient_user("P002", "patient002", "patient123", 
                                     p002[0]['full_name'], "13800000002")
        
        print("\n" + "=" * 50)
        print("✅ 患者端用户创建完成！")
        print("=" * 50)
        print("\n📋 患者端测试账号:")
        if p001:
            print(f"   患者1: patient001 / patient123 (患者: {p001[0]['full_name']})")
        if p002:
            print(f"   患者2: patient002 / patient123 (患者: {p002[0]['full_name']})")
        
    except Exception as e:
        print(f"\n❌ 创建失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())

