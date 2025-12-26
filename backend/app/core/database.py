"""
数据库连接管理
使用 SQLite + SQLAlchemy
"""
import aiosqlite
import logging
from pathlib import Path
from typing import Optional
from app.core.config import project_root

logger = logging.getLogger(__name__)

# 数据库文件路径
db_path = project_root / "data" / "hospital_monitoring.db"
db_path.parent.mkdir(parents=True, exist_ok=True)


async def get_db_connection() -> aiosqlite.Connection:
    """获取数据库连接"""
    conn = await aiosqlite.connect(str(db_path))
    conn.row_factory = aiosqlite.Row  # 使用 Row 工厂，支持字典访问
    return conn


async def execute_query(query: str, params: tuple = ()) -> list:
    """执行查询并返回结果"""
    conn = await get_db_connection()
    try:
        cursor = await conn.execute(query, params)
        rows = await cursor.fetchall()
        await conn.commit()
        return [dict(row) for row in rows]
    finally:
        await conn.close()


async def execute_insert(query: str, params: tuple = ()) -> int:
    """执行插入并返回最后插入的ID"""
    conn = await get_db_connection()
    try:
        cursor = await conn.execute(query, params)
        await conn.commit()
        return cursor.lastrowid
    finally:
        await conn.close()


async def execute_update(query: str, params: tuple = ()) -> int:
    """执行更新并返回影响的行数"""
    conn = await get_db_connection()
    try:
        cursor = await conn.execute(query, params)
        await conn.commit()
        return cursor.rowcount
    finally:
        await conn.close()


async def execute_script(script: str):
    """执行SQL脚本（用于初始化）"""
    conn = await get_db_connection()
    try:
        await conn.executescript(script)
        await conn.commit()
    finally:
        await conn.close()

