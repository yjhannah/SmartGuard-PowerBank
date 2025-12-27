#!/usr/bin/env python3
"""
移动端数据库扩展脚本
添加移动端所需的表结构和字段
"""
import asyncio
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_script, execute_query

# SQL表结构定义
CREATE_MOBILE_TABLES_SQL = """
-- 二维码令牌表（用于病患-家属关联）
CREATE TABLE IF NOT EXISTS qrcode_tokens (
    token_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used INTEGER DEFAULT 0,
    used_by_user_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (used_by_user_id) REFERENCES users(user_id)
);

CREATE INDEX IF NOT EXISTS idx_qrcode_token ON qrcode_tokens(token);
CREATE INDEX IF NOT EXISTS idx_qrcode_patient ON qrcode_tokens(patient_id);

-- 健康简报表（存储AI生成的每日简报）
CREATE TABLE IF NOT EXISTS health_reports (
    report_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    report_date DATE NOT NULL,
    summary_text TEXT NOT NULL,
    status_icon TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    UNIQUE(patient_id, report_date)
);

CREATE INDEX IF NOT EXISTS idx_health_report_date ON health_reports(report_date DESC);
CREATE INDEX IF NOT EXISTS idx_health_report_patient ON health_reports(patient_id);

-- 活动记录表（卧床、活动、用药事件）
CREATE TABLE IF NOT EXISTS activity_records (
    record_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    record_time TIMESTAMP NOT NULL,
    activity_type TEXT NOT NULL CHECK(activity_type IN ('bed', 'activity', 'medication')),
    activity_value REAL,
    medication_name TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE INDEX IF NOT EXISTS idx_activity_patient_time ON activity_records(patient_id, record_time DESC);
CREATE INDEX IF NOT EXISTS idx_activity_type ON activity_records(activity_type);

-- 情绪记录表
CREATE TABLE IF NOT EXISTS emotion_records (
    record_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    record_time TIMESTAMP NOT NULL,
    emotion_level TEXT CHECK(emotion_level IN ('positive', 'neutral', 'negative')),
    emotion_score REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE INDEX IF NOT EXISTS idx_emotion_patient_time ON emotion_records(patient_id, record_time DESC);

-- 语音提醒记录表
CREATE TABLE IF NOT EXISTS voice_alerts (
    alert_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    alert_type TEXT NOT NULL CHECK(alert_type IN ('iv_drip', 'emotion_companion', 'medication')),
    message TEXT NOT NULL,
    played INTEGER DEFAULT 0,
    played_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE INDEX IF NOT EXISTS idx_voice_alert_patient ON voice_alerts(patient_id, created_at DESC);

-- 呼叫记录表
CREATE TABLE IF NOT EXISTS call_records (
    call_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    patient_id TEXT,
    call_type TEXT NOT NULL CHECK(call_type IN ('nurse', 'message')),
    phone_number TEXT,
    message_content TEXT,
    status TEXT CHECK(status IN ('pending', 'completed', 'failed')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE INDEX IF NOT EXISTS idx_call_user ON call_records(user_id, created_at DESC);
"""

# 修改现有表的SQL
ALTER_TABLES_SQL = """
-- 为users表添加patient_id字段（病患用户关联）
-- 注意：SQLite不支持直接ALTER TABLE ADD COLUMN IF NOT EXISTS，需要检查
-- 为alerts表添加family_acknowledged字段（家属确认状态）
"""


async def check_column_exists(table_name: str, column_name: str) -> bool:
    """检查表中是否存在指定列"""
    try:
        result = await execute_query(
            f"PRAGMA table_info({table_name})"
        )
        columns = [row['name'] for row in result]
        return column_name in columns
    except Exception as e:
        print(f"❌ 检查列失败: {e}")
        return False


async def add_mobile_tables():
    """创建移动端相关表"""
    try:
        print("📋 开始创建移动端数据库表...")
        
        # 创建新表
        await execute_script(CREATE_MOBILE_TABLES_SQL)
        print("✅ 移动端表创建完成")
        
        # 检查并添加users表的patient_id字段
        if not await check_column_exists('users', 'patient_id'):
            try:
                await execute_script(
                    "ALTER TABLE users ADD COLUMN patient_id TEXT REFERENCES patients(patient_id)"
                )
                print("✅ 为users表添加patient_id字段")
            except Exception as e:
                print(f"⚠️  添加users.patient_id字段失败（可能已存在）: {e}")
        else:
            print("ℹ️  users表的patient_id字段已存在")
        
        # 检查并添加alerts表的family_acknowledged字段
        if not await check_column_exists('alerts', 'family_acknowledged'):
            try:
                await execute_script(
                    "ALTER TABLE alerts ADD COLUMN family_acknowledged INTEGER DEFAULT 0"
                )
                print("✅ 为alerts表添加family_acknowledged字段")
            except Exception as e:
                print(f"⚠️  添加alerts.family_acknowledged字段失败（可能已存在）: {e}")
        else:
            print("ℹ️  alerts表的family_acknowledged字段已存在")
        
        print("✅ 移动端数据库扩展完成！")
        
    except Exception as e:
        print(f"❌ 创建表失败: {e}")
        import traceback
        traceback.print_exc()
        raise


if __name__ == "__main__":
    asyncio.run(add_mobile_tables())

