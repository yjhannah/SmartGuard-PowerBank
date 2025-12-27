"""
语音提醒API路由
"""
from fastapi import APIRouter, HTTPException
import uuid
from datetime import datetime
from app.models.schemas import VoiceAlertRequest
from app.core.database import execute_query, execute_insert

router = APIRouter(prefix="/api/voice", tags=["voice"])


@router.post("/iv-drip-alert")
async def iv_drip_alert(request: VoiceAlertRequest):
    """点滴快打完语音提醒（真实功能）"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (request.patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 保存语音提醒记录
        alert_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO voice_alerts (alert_id, patient_id, alert_type, message, played)
               VALUES (?, ?, ?, ?, ?)""",
            (alert_id, request.patient_id, 'iv_drip', request.message, 0)
        )
        
        return {
            "status": "success",
            "message": "语音提醒已创建",
            "alert_id": alert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"创建语音提醒失败: {str(e)}")


@router.post("/emotion-companion")
async def emotion_companion(request: VoiceAlertRequest):
    """心情不好语音陪伴（Demo）"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (request.patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 保存语音提醒记录
        alert_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO voice_alerts (alert_id, patient_id, alert_type, message, played)
               VALUES (?, ?, ?, ?, ?)""",
            (alert_id, request.patient_id, 'emotion_companion', request.message, 0)
        )
        
        return {
            "status": "success",
            "message": "陪伴语音已创建（Demo）",
            "alert_id": alert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"创建陪伴语音失败: {str(e)}")


@router.post("/medication-reminder")
async def medication_reminder(request: VoiceAlertRequest):
    """吃药提醒（Demo）"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (request.patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 保存语音提醒记录
        alert_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO voice_alerts (alert_id, patient_id, alert_type, message, played)
               VALUES (?, ?, ?, ?, ?)""",
            (alert_id, request.patient_id, 'medication', request.message, 0)
        )
        
        return {
            "status": "success",
            "message": "吃药提醒已创建（Demo）",
            "alert_id": alert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"创建吃药提醒失败: {str(e)}")

