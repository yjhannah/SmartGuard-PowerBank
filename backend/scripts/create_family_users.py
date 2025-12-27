#!/usr/bin/env python3
"""
创建家属用户并关联患者脚本
为家属创建登录账号并关联到指定患者
"""
import asyncio
import sys
from pathlib import Path
import uuid
import hashlib

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_query, execute_insert, execute_update

def hash_password(password: str) -> str:
    """密码哈希"""
    return hashlib.sha256(password.encode()).hexdigest()


async def create_family_user_and_link_patient(
    username: str, 
    password: str, 
    patient_code: str,
    full_name: str = None,
    phone: str = None,
    relationship: str = "家属"
):
    """创建家属用户并关联到患者"""
    try:
        # 1. 查找患者
        patients = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients WHERE patient_code = ?",
            (patient_code,)
        )
        
        if not patients:
            print(f"❌ 未找到患者编号: {patient_code}")
            return None
        
        patient = patients[0]
        patient_id = patient['patient_id']
        patient_name = patient['full_name']
        
        # 2. 检查用户是否已存在
        existing = await execute_query(
            "SELECT user_id, patient_id FROM users WHERE username = ?",
            (username,)
        )
        
        user_id = None
        if existing:
            user_id = existing[0]['user_id']
            existing_patient_id = existing[0].get('patient_id')
            
            if existing_patient_id == patient_id:
                print(f"⚠️  用户 {username} 已存在且已关联到患者 {patient_code}，跳过创建")
            else:
                # 更新关联的患者
                await execute_update(
                    "UPDATE users SET patient_id = ? WHERE user_id = ?",
                    (patient_id, user_id)
                )
                print(f"✅ 更新用户 {username} 关联到患者 {patient_code}")
        else:
            # 3. 创建新用户
            user_id = str(uuid.uuid4())
            password_hash = hash_password(password)
            
            display_name = full_name or f"{patient_name}的家属"
            
            await execute_insert(
                """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, email, patient_id, is_active)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    user_id,
                    username,
                    password_hash,
                    'family',  # 家属角色
                    display_name,
                    phone,
                    f"{username}@family.com",
                    patient_id,  # 关联患者ID
                    1
                )
            )
            print(f"✅ 创建家属用户成功: {username} / {password}")
        
        # 4. 在 patient_guardians 表中创建关联（如果不存在）
        existing_guardian = await execute_query(
            "SELECT id FROM patient_guardians WHERE patient_id = ? AND guardian_user_id = ?",
            (patient_id, user_id)
        )
        
        if not existing_guardian:
            guardian_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO patient_guardians (id, patient_id, guardian_user_id, relationship, priority)
                   VALUES (?, ?, ?, ?, ?)""",
                (guardian_id, patient_id, user_id, relationship, 1)
            )
            print(f"✅ 创建患者-家属关联: {patient_name} ({patient_code}) - {username}")
        else:
            print(f"⚠️  患者-家属关联已存在，跳过创建")
        
        return {
            'user_id': user_id,
            'username': username,
            'patient_id': patient_id,
            'patient_code': patient_code,
            'patient_name': patient_name
        }
        
    except Exception as e:
        print(f"❌ 创建家属用户失败: {e}")
        import traceback
        traceback.print_exc()
        raise


async def main():
    """主函数"""
    print("=" * 60)
    print("创建家属用户并关联患者")
    print("=" * 60)
    
    try:
        # 先查看现有患者
        patients = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients ORDER BY patient_code LIMIT 10"
        )
        
        if not patients:
            print("❌ 数据库中没有患者，请先创建患者")
            return
        
        print("\n📋 现有患者列表:")
        for p in patients:
            print(f"   {p['patient_code']}: {p['full_name']}")
        
        # 查找患者1和患者2
        patient1 = None
        patient2 = None
        
        # 尝试按编号查找（P001, P002）
        p001 = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients WHERE patient_code = 'P001'"
        )
        if p001:
            patient1 = p001[0]
        
        p002 = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients WHERE patient_code = 'P002'"
        )
        if p002:
            patient2 = p002[0]
        
        # 如果没找到P001/P002，使用前两个患者
        if not patient1 and len(patients) > 0:
            patient1 = patients[0]
        if not patient2 and len(patients) > 1:
            patient2 = patients[1]
        
        print("\n" + "=" * 60)
        print("开始创建家属用户...")
        print("=" * 60)
        
        # 创建家属1并关联患者1
        if patient1:
            result1 = await create_family_user_and_link_patient(
                username="family001",
                password="family123",
                patient_code=patient1['patient_code'],
                full_name="家属1",
                phone="13900139001",
                relationship="家属"
            )
            if result1:
                print(f"   → 家属1 (family001) 已关联到患者: {result1['patient_name']} ({result1['patient_code']})")
        else:
            print("⚠️  未找到患者1，跳过创建家属1")
        
        # 创建家属2并关联患者2
        if patient2:
            result2 = await create_family_user_and_link_patient(
                username="family002",
                password="family123",
                patient_code=patient2['patient_code'],
                full_name="家属2",
                phone="13900139002",
                relationship="家属"
            )
            if result2:
                print(f"   → 家属2 (family002) 已关联到患者: {result2['patient_name']} ({result2['patient_code']})")
        else:
            print("⚠️  未找到患者2，跳过创建家属2")
        
        print("\n" + "=" * 60)
        print("✅ 家属用户创建完成！")
        print("=" * 60)
        print("\n📋 家属账号列表:")
        if patient1:
            print(f"   家属1: family001 / family123 → 关联患者: {patient1['full_name']} ({patient1['patient_code']})")
        if patient2:
            print(f"   家属2: family002 / family123 → 关联患者: {patient2['full_name']} ({patient2['patient_code']})")
        print("\n💡 提示: 家属账号使用 family 角色，通过 patient_id 字段和 patient_guardians 表关联患者")
        
    except Exception as e:
        print(f"\n❌ 创建失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())

