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
    try:
        # 获取最新的分析结果
        results = await execute_query(
            """SELECT * FROM ai_analysis_results 
               WHERE patient_id = ? 
               ORDER BY timestamp DESC LIMIT 1""",
            (patient_id,)
        )
        
        # 获取未处理的告警
        alerts = await execute_query(
            """SELECT * FROM alerts 
               WHERE patient_id = ? AND status = 'pending'
               ORDER BY created_at DESC LIMIT 5""",
            (patient_id,)
        )
        
        return {
            "patient_id": patient_id,
            "latest_analysis": results[0] if results else None,
            "pending_alerts": alerts,
            "status": "monitoring" if results else "no_data"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

