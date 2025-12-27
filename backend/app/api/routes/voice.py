"""
语音提醒API路由
"""
from fastapi import APIRouter, HTTPException, Body, Response
from fastapi.responses import StreamingResponse
import uuid
import time
import logging
from datetime import datetime
from typing import Optional
from app.models.schemas import VoiceAlertRequest
from app.core.database import execute_query, execute_insert

router = APIRouter(prefix="/api/voice", tags=["voice"])
logger = logging.getLogger(__name__)


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


@router.post("/tts/synthesize")
async def synthesize_tts(
    text: str = Body(..., description="要合成的文本"),
    child_voice: bool = Body(True, description="是否使用萌童声音"),
    voice_type: Optional[str] = Body(None, description="音色类型（可选）"),
):
    """
    TTS语音合成接口（讯飞TTS）
    
    如果讯飞TTS失败，返回503错误，前端应回退到flutter_tts模式
    """
    try:
        logger.info(f"🎤 [TTS API] 收到合成请求: text={text[:50]}..., child_voice={child_voice}")
        
        # 导入讯飞TTS服务
        from app.services.xunfei_tts_service import get_xunfei_tts_service
        
        tts_service = get_xunfei_tts_service()
        
        if not tts_service or not tts_service.enabled:
            logger.warning(f"⚠️ [TTS API] 讯飞TTS服务未启用，返回503错误，建议前端使用flutter_tts")
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "TTS服务未配置",
                    "fallback": "flutter_tts",
                    "message": "讯飞TTS服务未启用，请使用flutter_tts作为备选方案"
                }
            )
        
        # 调用讯飞TTS合成
        logger.info(f"🎤 [TTS API] 调用讯飞TTS服务...")
        audio_bytes = await tts_service.synthesize(
            text=text,
            child_voice=child_voice,
            voice_type=voice_type,
        )
        
        if not audio_bytes:
            logger.warning(f"⚠️ [TTS API] 讯飞TTS合成失败，返回503错误，建议前端使用flutter_tts")
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "语音合成失败",
                    "fallback": "flutter_tts",
                    "message": "讯飞TTS合成失败，请使用flutter_tts作为备选方案"
                }
            )
        
        logger.info(f"✅ [TTS API] 合成成功: 音频大小={len(audio_bytes)} bytes")
        
        # 返回音频流
        return Response(
            content=audio_bytes,
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": f'attachment; filename="tts_{int(time.time())}.mp3"',
                "X-TTS-Provider": "xunfei",
                "X-TTS-ChildVoice": str(child_voice),
            }
        )
        
    except HTTPException:
        # 重新抛出HTTP异常
        raise
    except Exception as e:
        error_msg = str(e)
        error_type = type(e).__name__
        logger.error(f"❌ [TTS API] ========== 合成异常 ==========")
        logger.error(f"❌ [TTS API] 错误类型: {error_type}")
        logger.error(f"❌ [TTS API] 错误信息: {error_msg}")
        logger.error(f"❌ [TTS API] 文本内容: {text[:100]}...")
        logger.error(f"❌ [TTS API] =================================")
        import traceback
        logger.error(f"❌ [TTS API] 完整堆栈:\n{traceback.format_exc()}")
        logger.error(f"❌ [TTS API] =================================")
        logger.warning(f"⚠️ [TTS API] 返回503错误，建议前端使用flutter_tts")
        
        raise HTTPException(
            status_code=503,
            detail={
                "error": error_type,
                "message": error_msg,
                "fallback": "flutter_tts",
                "suggestion": "讯飞TTS服务异常，请使用flutter_tts作为备选方案"
            }
        )

