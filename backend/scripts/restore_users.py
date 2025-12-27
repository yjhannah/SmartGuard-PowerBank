#!/usr/bin/env python3
"""
恢复用户数据脚本
创建缺失的用户账号
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


async def create_user_if_not_exists(username: str, password: str, role: str, 
                                    full_name: str, phone: str, patient_id: str = None):
    """创建用户（如果不存在）"""
    # 检查用户是否存在
    existing = await execute_query(
        "SELECT user_id FROM users WHERE username = ?",
        (username,)
    )
    
    if existing:
        user_id = existing[0]['user_id']
        print(f"⚠️  用户 {username} 已存在 (ID: {user_id[:8]}...)")
        
        # 如果有patient_id，更新关联
        if patient_id:
            await execute_update(
                "UPDATE users SET patient_id = ? WHERE user_id = ?",
                (patient_id, user_id)
            )
            print(f"   ✅ 已更新患者关联: {patient_id[:8]}...")
        return user_id
    
    # 创建新用户
    user_id = str(uuid.uuid4())
    password_hash = hash_password(password)
    email = f"{username}@smartguard.local"
    
    await execute_insert(
        """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, email, patient_id, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (user_id, username, password_hash, role, full_name, phone, email, patient_id, 1)
    )
    
    print(f"✅ 创建用户: {username} / {password} (角色: {role})")
    if patient_id:
        print(f"   关联患者ID: {patient_id[:8]}...")
    
    return user_id


async def main():
    """主函数"""
    print("=" * 60)
    print("恢复用户数据")
    print("=" * 60)
    
    try:
        # 1. 查看现有患者
        print("\n📋 查询现有患者...")
        patients = await execute_query(
            "SELECT patient_id, patient_code, full_name FROM patients"
        )
        
        patient_map = {}
        if patients:
            for p in patients:
                patient_map[p['patient_code']] = p
                print(f"   {p['patient_code']}: {p['full_name']} (ID: {p['patient_id'][:8]}...)")
        else:
            print("   ⚠️ 没有找到患者数据")
        
        # 2. 查看现有用户
        print("\n📋 现有用户...")
        users = await execute_query(
            "SELECT user_id, username, role, patient_id FROM users"
        )
        for u in users:
            patient_info = f", 关联患者: {u['patient_id'][:8]}..." if u.get('patient_id') else ""
            print(f"   {u['username']} (角色: {u['role']}{patient_info})")
        
        # 3. 创建/恢复用户
        print("\n📋 创建/恢复用户...")
        
        # 护士
        await create_user_if_not_exists(
            "nurse001", "nurse123", "nurse", "张护士", "13800138001"
        )
        
        # 家属1 - 关联患者P001（张三）
        p001 = patient_map.get('P001')
        family1_patient_id = p001['patient_id'] if p001 else None
        family1_id = await create_user_if_not_exists(
            "family001", "family123", "family", "李家属", "13900139001"
        )
        
        # 家属2 - 关联患者P002（李四）
        p002 = patient_map.get('P002')
        family2_patient_id = p002['patient_id'] if p002 else None
        family2_id = await create_user_if_not_exists(
            "family002", "family123", "family", "王家属", "13900139002"
        )
        
        # 患者1 - 关联患者P001（张三）
        await create_user_if_not_exists(
            "patient001", "patient123", "family", "张三", "13800000001",
            patient_id=family1_patient_id
        )
        
        # 患者2 - 关联患者P002（李四）
        await create_user_if_not_exists(
            "patient002", "patient123", "family", "李四", "13800000002",
            patient_id=family2_patient_id
        )
        
        # 测试家属
        await create_user_if_not_exists(
            "test_family", "test123", "family", "测试家属", "13800000003"
        )
        
        # 4. 更新家属关联（patient_guardians表）
        print("\n📋 更新家属-患者关联...")
        
        # 检查并创建family001与P001的关联
        if p001 and family1_id:
            existing = await execute_query(
                "SELECT id FROM patient_guardians WHERE patient_id = ? AND guardian_user_id = ?",
                (p001['patient_id'], family1_id)
            )
            if not existing:
                await execute_insert(
                    """INSERT INTO patient_guardians (id, patient_id, guardian_user_id, relationship, priority)
                       VALUES (?, ?, ?, ?, ?)""",
                    (str(uuid.uuid4()), p001['patient_id'], family1_id, "子女", 1)
                )
                print(f"   ✅ 关联: family001 -> 张三 (P001)")
            else:
                print(f"   ⚠️ 关联已存在: family001 -> 张三")
        
        # 检查并创建family002与P002的关联
        if p002 and family2_id:
            existing = await execute_query(
                "SELECT id FROM patient_guardians WHERE patient_id = ? AND guardian_user_id = ?",
                (p002['patient_id'], family2_id)
            )
            if not existing:
                await execute_insert(
                    """INSERT INTO patient_guardians (id, patient_id, guardian_user_id, relationship, priority)
                       VALUES (?, ?, ?, ?, ?)""",
                    (str(uuid.uuid4()), p002['patient_id'], family2_id, "配偶", 1)
                )
                print(f"   ✅ 关联: family002 -> 李四 (P002)")
            else:
                print(f"   ⚠️ 关联已存在: family002 -> 李四")
        
        # 5. 显示最终结果
        print("\n" + "=" * 60)
        print("✅ 用户数据恢复完成！")
        print("=" * 60)
        
        print("\n📋 最终用户列表:")
        users = await execute_query(
            "SELECT user_id, username, role, full_name, patient_id FROM users ORDER BY username"
        )
        print(f"\n{'用户名':<15} {'角色':<10} {'姓名':<10} {'关联患者ID':<20}")
        print("-" * 60)
        for u in users:
            patient_id = u.get('patient_id', '')[:20] if u.get('patient_id') else '-'
            print(f"{u['username']:<15} {u['role']:<10} {u.get('full_name', '-'):<10} {patient_id:<20}")
        
        print("\n📋 测试账号:")
        print("   护士: nurse001 / nurse123")
        print("   家属1: family001 / family123 (关联张三)")
        print("   家属2: family002 / family123 (关联李四)")
        print("   患者1: patient001 / patient123 (关联张三)")
        print("   患者2: patient002 / patient123 (关联李四)")
        print("   测试家属: test_family / test123")
        
    except Exception as e:
        print(f"\n❌ 恢复失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())

