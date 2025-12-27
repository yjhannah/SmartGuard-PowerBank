#!/usr/bin/env python3
"""
验证用户类型判断脚本
检查患者端和家属端的用户类型判断是否正确
"""
import asyncio
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_query

async def verify_user_type(username: str):
    """验证用户的类型判断"""
    print(f"\n{'='*60}")
    print(f"验证用户: {username}")
    print(f"{'='*60}")
    
    # 1. 查询用户信息
    users = await execute_query(
        "SELECT user_id, username, role, patient_id FROM users WHERE username = ?",
        (username,)
    )
    
    if not users:
        print(f"❌ 用户 {username} 不存在")
        return
    
    user = users[0]
    user_id = user['user_id']
    role = user['role']
    patient_id = user.get('patient_id')
    
    print(f"📋 用户信息:")
    print(f"   User ID: {user_id}")
    print(f"   Role: {role}")
    print(f"   Patient ID: {patient_id}")
    
    # 2. 检查 patient_guardians 表
    guardians = await execute_query(
        "SELECT id, patient_id, relationship FROM patient_guardians WHERE guardian_user_id = ?",
        (user_id,)
    )
    
    print(f"\n📋 患者-家属关联:")
    if guardians:
        print(f"   ✅ 在 patient_guardians 表中（家属端）")
        for g in guardians:
            # 查询患者信息
            patients = await execute_query(
                "SELECT patient_code, full_name FROM patients WHERE patient_id = ?",
                (g['patient_id'],)
            )
            patient_info = patients[0] if patients else {}
            print(f"      - 关联患者: {patient_info.get('full_name', '未知')} ({patient_info.get('patient_code', '未知')})")
            print(f"        关系: {g.get('relationship', '未知')}")
    else:
        print(f"   ❌ 不在 patient_guardians 表中")
    
    # 3. 判断用户类型（模拟登录接口的逻辑）
    user_type = None
    if patient_id:
        if guardians:
            user_type = 'family'  # 家属端
        else:
            user_type = 'patient'  # 患者端
    else:
        if role == 'family':
            user_type = 'family'
    
    print(f"\n📋 用户类型判断结果:")
    print(f"   User Type: {user_type}")
    
    if user_type == 'patient':
        print(f"   ✅ 应该显示患者端界面")
    elif user_type == 'family':
        print(f"   ✅ 应该显示家属端界面")
    else:
        print(f"   ⚠️  用户类型未确定，可能显示登录界面")
    
    return {
        'username': username,
        'user_id': user_id,
        'role': role,
        'patient_id': patient_id,
        'is_guardian': len(guardians) > 0,
        'user_type': user_type
    }


async def main():
    """主函数"""
    print("="*60)
    print("验证用户类型判断")
    print("="*60)
    
    # 验证患者端账号
    test_users = [
        'patient001',  # 患者1
        'patient002',  # 患者2
        'family001',  # 家属1
        'family002',  # 家属2
    ]
    
    results = []
    for username in test_users:
        result = await verify_user_type(username)
        if result:
            results.append(result)
    
    # 总结
    print(f"\n{'='*60}")
    print("验证总结")
    print(f"{'='*60}")
    
    print(f"\n📊 患者端账号（应该显示患者端界面）:")
    patient_users = [r for r in results if r['user_type'] == 'patient']
    for r in patient_users:
        print(f"   ✅ {r['username']}: user_type = {r['user_type']}")
    
    print(f"\n📊 家属端账号（应该显示家属端界面）:")
    family_users = [r for r in results if r['user_type'] == 'family']
    for r in family_users:
        print(f"   ✅ {r['username']}: user_type = {r['user_type']}")
    
    print(f"\n📊 未确定类型:")
    unknown_users = [r for r in results if r['user_type'] is None]
    if unknown_users:
        for r in unknown_users:
            print(f"   ⚠️  {r['username']}: user_type = {r['user_type']}")
    else:
        print(f"   ✅ 所有用户类型都已确定")
    
    print(f"\n{'='*60}")
    print("验证完成")
    print(f"{'='*60}")


if __name__ == '__main__':
    asyncio.run(main())

