"""
数据库迁移脚本：为alerts表添加image_url字段
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_update


async def add_image_url_column():
    """添加image_url字段到alerts表"""
    try:
        # 检查字段是否已存在
        from app.core.database import execute_query
        
        # SQLite不支持直接检查列是否存在，使用try-except
        try:
            await execute_query("SELECT image_url FROM alerts LIMIT 1")
            print("✅ image_url字段已存在，跳过迁移")
            return
        except:
            pass
        
        # 添加image_url字段
        await execute_update(
            """ALTER TABLE alerts ADD COLUMN image_url TEXT"""
        )
        print("✅ 成功添加image_url字段到alerts表")
        
    except Exception as e:
        if "duplicate column name" in str(e).lower() or "already exists" in str(e).lower():
            print("✅ image_url字段已存在，跳过迁移")
        else:
            print(f"❌ 迁移失败: {e}")
            raise


if __name__ == '__main__':
    asyncio.run(add_image_url_column())

