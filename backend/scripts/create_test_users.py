#!/usr/bin/env python3
"""
创建测试用户脚本
用于快速创建测试账号
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


async def create_test_user(username: str, password: str, role: str, 
                          full_name: str = None, email: str = None, phone: str = None):
    """创建测试用户"""
    try:
        # 检查用户是否已存在
        existing = await execute_query(
            "SELECT user_id FROM users WHERE username = ?",
            (username,)
        )
        if existing:
            print(f"⚠️  用户 {username} 已存在，跳过创建")
            return existing[0]['user_id']
        
        # 创建新用户
        user_id = str(uuid.uuid4())
        password_hash = hash_password(password)
        
        # 如果没有提供邮箱，生成一个测试邮箱
        if not email:
            email = f"{username}@test.com"
        
        await execute_insert(
            """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, email, is_active)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (user_id, username, password_hash, role, full_name, phone, email, 1)
        )
        
        print(f"✅ 创建用户成功: {username} / {password} (角色: {role})")
        return user_id
    except Exception as e:
        print(f"❌ 创建用户失败 {username}: {e}")
        raise


async def main():
    """主函数"""
    print("=" * 50)
    print("创建测试用户")
    print("=" * 50)
    
    try:
        # 创建测试用户（注意：数据库role约束只允许: nurse, doctor, family, admin）
        # 病患用户使用family角色，通过patient_id字段关联患者
        await create_test_user("test_family", "test123", "family", "测试家属", "test_family@test.com", "13800000002")
        await create_test_user("nurse001", "nurse123", "nurse", "张护士", "nurse001@test.com", "13800138001")
        await create_test_user("family001", "family123", "family", "李家属", "family001@test.com", "13900139001")
        await create_test_user("family002", "family123", "family", "王家属", "family002@test.com", "13900139002")
        
        print("\n" + "=" * 50)
        print("✅ 测试用户创建完成！")
        print("=" * 50)
        print("\n测试账号列表:")
        print("  家属: test_family / test123")
        print("  护士: nurse001 / nurse123")
        print("  家属1: family001 / family123")
        print("  家属2: family002 / family123")
        print("\n注意: 病患用户通过patient_id字段关联患者，角色使用family")
        
    except Exception as e:
        print(f"\n❌ 创建失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())

