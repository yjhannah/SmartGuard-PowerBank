#!/usr/bin/env python3
"""
数据库初始化脚本
创建所有表结构和初始测试数据
"""
import asyncio
import sys
from pathlib import Path
from datetime import datetime, timedelta
import uuid

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import execute_script, execute_insert

# SQL表结构定义
CREATE_TABLES_SQL = """
-- 用户表
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('nurse', 'doctor', 'family', 'admin')),
    full_name TEXT,
    phone TEXT,
    email TEXT,
    virtual_phone TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 病房表
CREATE TABLE IF NOT EXISTS wards (
    ward_id TEXT PRIMARY KEY,
    ward_number TEXT UNIQUE NOT NULL,
    floor INTEGER,
    building TEXT,
    capacity INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 患者表
CREATE TABLE IF NOT EXISTS patients (
    patient_id TEXT PRIMARY KEY,
    patient_code TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    gender TEXT,
    age INTEGER,
    admission_date DATE,
    diagnosis TEXT,
    risk_level TEXT CHECK(risk_level IN ('high', 'medium', 'low')) DEFAULT 'medium',
    ward_id TEXT,
    bed_number TEXT,
    is_hospitalized INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

-- 患者-监护人关联表
CREATE TABLE IF NOT EXISTS patient_guardians (
    id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    guardian_user_id TEXT NOT NULL,
    relationship TEXT,
    priority INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (guardian_user_id) REFERENCES users(user_id)
);

-- 摄像头设备表
CREATE TABLE IF NOT EXISTS cameras (
    camera_id TEXT PRIMARY KEY,
    device_code TEXT UNIQUE NOT NULL,
    ward_id TEXT,
    rtsp_url TEXT,
    status TEXT CHECK(status IN ('online', 'offline', 'maintenance')) DEFAULT 'online',
    ip_address TEXT,
    model TEXT,
    firmware_version TEXT,
    last_heartbeat TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

-- AI监测配置表
CREATE TABLE IF NOT EXISTS monitoring_configs (
    config_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    fall_detection_enabled INTEGER DEFAULT 1,
    bed_exit_detection_enabled INTEGER DEFAULT 1,
    prolonged_bed_detection_enabled INTEGER DEFAULT 1,
    abnormal_activity_enabled INTEGER DEFAULT 1,
    facial_analysis_enabled INTEGER DEFAULT 1,
    iv_drip_monitoring_enabled INTEGER DEFAULT 0,
    bed_exit_threshold_minutes INTEGER DEFAULT 10,
    prolonged_bed_threshold_hours INTEGER DEFAULT 12,
    fall_confidence_threshold REAL DEFAULT 0.85,
    monitoring_schedule TEXT,  -- JSON格式
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

-- AI分析结果表
CREATE TABLE IF NOT EXISTS ai_analysis_results (
    result_id TEXT PRIMARY KEY,
    camera_id TEXT,
    patient_id TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    detection_type TEXT NOT NULL,
    analysis_data TEXT NOT NULL,  -- JSON格式
    is_alert_triggered INTEGER DEFAULT 0,
    confidence_score REAL,
    snapshot_url TEXT,
    video_clip_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (camera_id) REFERENCES cameras(camera_id),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE INDEX IF NOT EXISTS idx_analysis_timestamp ON ai_analysis_results(timestamp);
CREATE INDEX IF NOT EXISTS idx_analysis_patient_id ON ai_analysis_results(patient_id);
CREATE INDEX IF NOT EXISTS idx_analysis_detection_type ON ai_analysis_results(detection_type);

-- 告警表
CREATE TABLE IF NOT EXISTS alerts (
    alert_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    camera_id TEXT,
    analysis_result_id TEXT,
    alert_type TEXT NOT NULL,
    severity TEXT CHECK(severity IN ('critical', 'high', 'medium', 'low')) DEFAULT 'medium',
    title TEXT,
    description TEXT,
    status TEXT CHECK(status IN ('pending', 'acknowledged', 'resolved', 'false_alarm')) DEFAULT 'pending',
    acknowledged_by TEXT,
    acknowledged_at TIMESTAMP,
    resolved_by TEXT,
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (camera_id) REFERENCES cameras(camera_id),
    FOREIGN KEY (analysis_result_id) REFERENCES ai_analysis_results(result_id),
    FOREIGN KEY (acknowledged_by) REFERENCES users(user_id),
    FOREIGN KEY (resolved_by) REFERENCES users(user_id)
);

CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status);
CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON alerts(created_at DESC);

-- 通知记录表
CREATE TABLE IF NOT EXISTS notifications (
    notification_id TEXT PRIMARY KEY,
    alert_id TEXT,
    recipient_user_id TEXT NOT NULL,
    channel TEXT CHECK(channel IN ('push', 'sms', 'call', 'websocket')),
    title TEXT,
    message TEXT,
    status TEXT CHECK(status IN ('pending', 'sent', 'failed', 'read')) DEFAULT 'pending',
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    call_sid TEXT,
    call_duration INTEGER,
    call_recording_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (alert_id) REFERENCES alerts(alert_id),
    FOREIGN KEY (recipient_user_id) REFERENCES users(user_id)
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
"""


async def init_test_data():
    """创建初始测试数据"""
    import hashlib
    
    # 生成密码哈希（简单示例，实际应使用bcrypt）
    def hash_password(password: str) -> str:
        return hashlib.sha256(password.encode()).hexdigest()
    
    # 1. 创建病房
    ward_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO wards (ward_id, ward_number, floor, building, capacity)
           VALUES (?, ?, ?, ?, ?)""",
        (ward_id, "301", 3, "A栋", 2)
    )
    print("✅ 创建病房: 301")
    
    # 2. 创建用户
    # 护士
    nurse_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (nurse_id, "nurse001", hash_password("nurse123"), "nurse", "张护士", "13800138001", 1)
    )
    print("✅ 创建护士用户: nurse001")
    
    # 家属1
    family1_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (family1_id, "family001", hash_password("family123"), "family", "李家属", "13900139001", 1)
    )
    print("✅ 创建家属用户: family001")
    
    # 家属2
    family2_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (family2_id, "family002", hash_password("family123"), "family", "王家属", "13900139002", 1)
    )
    print("✅ 创建家属用户: family002")
    
    # 3. 创建患者
    # 高风险患者
    patient1_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO patients (patient_id, patient_code, full_name, gender, age, admission_date, 
           diagnosis, risk_level, ward_id, bed_number, is_hospitalized)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (patient1_id, "P001", "张三", "男", 75, datetime.now().date(), 
         "脑梗塞恢复期", "high", ward_id, "301-1", 1)
    )
    print("✅ 创建患者: 张三 (高风险)")
    
    # 中风险患者
    patient2_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO patients (patient_id, patient_code, full_name, gender, age, admission_date, 
           diagnosis, risk_level, ward_id, bed_number, is_hospitalized)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (patient2_id, "P002", "李四", "女", 68, datetime.now().date(), 
         "骨折术后", "medium", ward_id, "301-2", 1)
    )
    print("✅ 创建患者: 李四 (中风险)")
    
    # 4. 关联患者和家属
    await execute_insert(
        """INSERT INTO patient_guardians (id, patient_id, guardian_user_id, relationship, priority)
           VALUES (?, ?, ?, ?, ?)""",
        (str(uuid.uuid4()), patient1_id, family1_id, "子女", 1)
    )
    print("✅ 关联患者和家属: 张三 - 李家属")
    
    await execute_insert(
        """INSERT INTO patient_guardians (id, patient_id, guardian_user_id, relationship, priority)
           VALUES (?, ?, ?, ?, ?)""",
        (str(uuid.uuid4()), patient2_id, family2_id, "配偶", 1)
    )
    print("✅ 关联患者和家属: 李四 - 王家属")
    
    # 5. 创建摄像头
    camera_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO cameras (camera_id, device_code, ward_id, status, ip_address, model)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (camera_id, "CAM001", ward_id, "online", "192.168.1.100", "智能监控摄像头")
    )
    print("✅ 创建摄像头: CAM001")
    
    # 6. 创建监测配置
    config1_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO monitoring_configs (config_id, patient_id, fall_detection_enabled, 
           bed_exit_detection_enabled, facial_analysis_enabled, bed_exit_threshold_minutes)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (config1_id, patient1_id, 1, 1, 1, 10)
    )
    print("✅ 创建监测配置: 张三")
    
    config2_id = str(uuid.uuid4())
    await execute_insert(
        """INSERT INTO monitoring_configs (config_id, patient_id, fall_detection_enabled, 
           bed_exit_detection_enabled, facial_analysis_enabled, bed_exit_threshold_minutes)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (config2_id, patient2_id, 1, 1, 1, 15)
    )
    print("✅ 创建监测配置: 李四")


async def main():
    """主函数"""
    print("=" * 50)
    print("开始初始化数据库...")
    print("=" * 50)
    
    try:
        # 创建表结构
        print("\n📋 创建表结构...")
        await execute_script(CREATE_TABLES_SQL)
        print("✅ 表结构创建完成")
        
        # 创建测试数据
        print("\n📋 创建测试数据...")
        await init_test_data()
        print("✅ 测试数据创建完成")
        
        print("\n" + "=" * 50)
        print("✅ 数据库初始化完成！")
        print("=" * 50)
        print("\n测试账号:")
        print("  护士: nurse001 / nurse123")
        print("  家属1: family001 / family123")
        print("  家属2: family002 / family123")
        
    except Exception as e:
        print(f"\n❌ 初始化失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())

