"""
患者管理API路由
"""
from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from app.models.schemas import PatientCreate, PatientResponse, MonitoringConfigUpdate
from app.core.database import execute_query, execute_insert, execute_update
import uuid

router = APIRouter(prefix="/api/patients", tags=["patients"])


@router.post("", response_model=dict)
async def create_patient(patient: PatientCreate):
    """创建患者"""
    try:
        patient_id = str(uuid.uuid4())
        
        await execute_insert(
            """INSERT INTO patients 
               (patient_id, patient_code, full_name, gender, age, admission_date, 
                diagnosis, risk_level, ward_id, bed_number, is_hospitalized)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                patient_id,
                patient.patient_code,
                patient.full_name,
                patient.gender,
                patient.age,
                patient.admission_date,
                patient.diagnosis,
                patient.risk_level,
                patient.ward_id,
                patient.bed_number,
                1
            )
        )
        
        return {"status": "success", "patient_id": patient_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("", response_model=List[dict])
async def get_patients(
    ward_id: Optional[str] = Query(None),
    is_hospitalized: Optional[bool] = Query(None)
):
    """获取患者列表"""
    try:
        query = "SELECT * FROM patients WHERE 1=1"
        params = []
        
        if ward_id:
            query += " AND ward_id = ?"
            params.append(ward_id)
        
        if is_hospitalized is not None:
            query += " AND is_hospitalized = ?"
            params.append(1 if is_hospitalized else 0)
        
        results = await execute_query(query, tuple(params))
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{patient_id}", response_model=dict)
async def get_patient(patient_id: str):
    """获取患者信息"""
    try:
        results = await execute_query(
            "SELECT * FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not results:
            raise HTTPException(status_code=404, detail="患者不存在")
        return results[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{patient_id}/monitoring-config", response_model=dict)
async def update_monitoring_config(
    patient_id: str,
    config: MonitoringConfigUpdate
):
    """更新监测配置"""
    try:
        # 检查患者是否存在
        patient = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patient:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 检查配置是否存在
        existing = await execute_query(
            "SELECT config_id FROM monitoring_configs WHERE patient_id = ?",
            (patient_id,)
        )
        
        update_fields = []
        params = []
        
        if config.fall_detection_enabled is not None:
            update_fields.append("fall_detection_enabled = ?")
            params.append(1 if config.fall_detection_enabled else 0)
        
        if config.bed_exit_detection_enabled is not None:
            update_fields.append("bed_exit_detection_enabled = ?")
            params.append(1 if config.bed_exit_detection_enabled else 0)
        
        if config.facial_analysis_enabled is not None:
            update_fields.append("facial_analysis_enabled = ?")
            params.append(1 if config.facial_analysis_enabled else 0)
        
        if config.abnormal_activity_enabled is not None:
            update_fields.append("abnormal_activity_enabled = ?")
            params.append(1 if config.abnormal_activity_enabled else 0)
        
        if config.iv_drip_monitoring_enabled is not None:
            update_fields.append("iv_drip_monitoring_enabled = ?")
            params.append(1 if config.iv_drip_monitoring_enabled else 0)
        
        if config.bed_exit_threshold_minutes is not None:
            update_fields.append("bed_exit_threshold_minutes = ?")
            params.append(config.bed_exit_threshold_minutes)
        
        if not update_fields:
            return {"status": "success", "message": "无需更新"}
        
        if existing:
            # 更新现有配置
            update_fields.append("updated_at = CURRENT_TIMESTAMP")
            params.append(patient_id)
            query = f"UPDATE monitoring_configs SET {', '.join(update_fields)} WHERE patient_id = ?"
            await execute_update(query, tuple(params))
        else:
            # 创建新配置
            config_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO monitoring_configs 
                   (config_id, patient_id, fall_detection_enabled, bed_exit_detection_enabled,
                    facial_analysis_enabled, abnormal_activity_enabled, iv_drip_monitoring_enabled,
                    bed_exit_threshold_minutes)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    config_id,
                    patient_id,
                    1 if config.fall_detection_enabled else 0,
                    1 if config.bed_exit_detection_enabled else 0,
                    1 if config.facial_analysis_enabled else 0,
                    1 if config.abnormal_activity_enabled else 0,
                    1 if config.iv_drip_monitoring_enabled else 0,
                    config.bed_exit_threshold_minutes or 10
                )
            )
        
        return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{patient_id}/live-status", response_model=dict)
async def get_live_status(patient_id: str):
    """获取患者实时状态"""
    from datetime import datetime, timedelta
    
    try:
        # 获取最新的分析结果
        results = await execute_query(
            """SELECT * FROM ai_analysis_results 
               WHERE patient_id = ? 
               ORDER BY timestamp DESC LIMIT 1""",
            (patient_id,)
        )
        
        # 只获取最新的告警（最近1小时内的pending告警，按创建时间倒序，只取第一条）
        # 注意：SQLite的datetime比较需要转换为字符串格式
        one_hour_ago = (datetime.now() - timedelta(hours=1)).strftime('%Y-%m-%d %H:%M:%S')
        latest_alerts = await execute_query(
            """SELECT * FROM alerts 
               WHERE patient_id = ? AND status = 'pending' AND datetime(created_at) >= datetime(?)
               ORDER BY created_at DESC LIMIT 1""",
            (patient_id, one_hour_ago)
        )
        
        # 获取所有未处理的告警数量（用于显示历史告警列表）
        all_pending_count = await execute_query(
            """SELECT COUNT(*) as count FROM alerts 
               WHERE patient_id = ? AND status = 'pending'""",
            (patient_id,)
        )
        pending_count = all_pending_count[0]["count"] if all_pending_count else 0
        
        return {
            "patient_id": patient_id,
            "latest_analysis": results[0] if results else None,
            "latest_alert": latest_alerts[0] if latest_alerts else None,  # 只返回最新的一条告警
            "pending_alerts_count": pending_count,  # 未处理告警总数
            "status": "monitoring" if results else "no_data"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{patient_id}/contacts", response_model=dict)
async def get_patient_contacts(patient_id: str):
    """获取患者联系人（护士站和家属）"""
    try:
        # 获取护士站信息（可以从配置或数据库获取）
        nurses = await execute_query(
            "SELECT user_id, full_name, phone FROM users WHERE role = 'nurse' AND is_active = 1 LIMIT 1",
            ()
        )
        
        # 获取家属联系人
        guardians = await execute_query(
            """SELECT u.user_id, u.full_name, u.phone, pg.relationship
               FROM patient_guardians pg
               JOIN users u ON pg.guardian_user_id = u.user_id
               WHERE pg.patient_id = ? AND u.is_active = 1
               ORDER BY pg.priority ASC
               LIMIT 3""",
            (patient_id,)
        )
        
        contacts = {
            "nurse_station": {
                "name": nurses[0]['full_name'] if nurses else "护士站",
                "phone": nurses[0]['phone'] if nurses else "120",
            } if nurses else None,
            "family_contacts": [
                {
                    "user_id": g['user_id'],
                    "name": g['full_name'],
                    "phone": g['phone'],
                    "relationship": g['relationship'],
                }
                for g in guardians
            ]
        }
        
        return contacts
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{patient_id}/medications", response_model=List[dict])
async def get_patient_medications(patient_id: str):
    """获取患者用药计划（Demo数据）"""
    try:
        # 这里返回Demo数据，实际应该从数据库获取
        # 可以创建medications表存储用药计划
        return [
            {
                "id": "1",
                "name": "蓝色降压药",
                "time": "15:00",
                "quantity": 2,
                "unit": "片",
                "description": "下午三点服用",
            },
            {
                "id": "2",
                "name": "维生素",
                "time": "08:00",
                "quantity": 1,
                "unit": "粒",
                "description": "早上八点服用",
            },
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{patient_id}/activity", response_model=dict)
async def get_patient_activity(
    patient_id: str,
    hours: int = Query(24, description="查询最近N小时的活动数据")
):
    """获取患者活动数据（用于判断久坐/久卧）"""
    from datetime import datetime, timedelta
    
    try:
        # 从ai_analysis_results获取活动数据
        start_time = datetime.now() - timedelta(hours=hours)
        results = await execute_query(
            """SELECT timestamp, analysis_data 
               FROM ai_analysis_results 
               WHERE patient_id = ? AND timestamp >= ?
               ORDER BY timestamp DESC""",
            (patient_id, start_time)
        )
        
        # 分析活动数据
        activity_count = 0
        bed_count = 0
        last_activity_time = None
        
        for result in results:
            try:
                import json
                analysis_data = json.loads(result['analysis_data']) if isinstance(result['analysis_data'], str) else result['analysis_data']
                detections = analysis_data.get('detections', {})
                
                # 检查活动
                activity = detections.get('activity', {})
                if activity.get('detected'):
                    activity_count += 1
                    if last_activity_time is None:
                        last_activity_time = result['timestamp']
                
                # 检查离床
                bed_exit = detections.get('bed_exit', {})
                if bed_exit.get('patient_in_bed') is False:
                    bed_count += 1
            except:
                continue
        
        # 判断是否久坐/久卧
        is_sedentary = False
        if last_activity_time:
            time_since_activity = (datetime.now() - datetime.fromisoformat(str(last_activity_time))).total_seconds() / 3600
            is_sedentary = time_since_activity >= 2  # 2小时无活动视为久坐
        
        return {
            "patient_id": patient_id,
            "activity_count": activity_count,
            "bed_exit_count": bed_count,
            "last_activity_time": last_activity_time.isoformat() if last_activity_time else None,
            "is_sedentary": is_sedentary,
            "hours": hours,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

