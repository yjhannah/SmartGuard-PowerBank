"""
语音提醒服务
监听点滴告警，触发语音提醒
"""
import logging
from typing import Optional, Dict
from app.core.database import execute_query, execute_insert
from app.services.websocket_manager import websocket_manager
import uuid
from datetime import datetime

logger = logging.getLogger(__name__)


class VoiceAlertService:
    """语音提醒服务"""
    
    async def trigger_iv_drip_alert(self, patient_id: str, alert_message: str):
        """
        触发点滴告警语音提醒
        
        Args:
            patient_id: 患者ID
            alert_message: 告警消息
        """
        try:
            # 保存语音提醒记录
            alert_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO voice_alerts (alert_id, patient_id, alert_type, message, played)
                   VALUES (?, ?, ?, ?, ?)""",
                (alert_id, patient_id, 'iv_drip', alert_message, 0)
            )
            
            # 通过WebSocket推送到病患端
            # 查找病患用户（通过patient_id关联）
            users = await execute_query(
                "SELECT user_id FROM users WHERE patient_id = ? AND is_active = 1",
                (patient_id,)
            )
            
            if users:
                user_id = users[0]['user_id']
                await websocket_manager.send_to_user(
                    user_id,
                    {
                        "type": "voice_alert",
                        "alert_type": "iv_drip",
                        "message": alert_message,
                        "alert_id": alert_id
                    }
                )
                logger.info(f"✅ 已推送点滴告警到病患端: {user_id}")
            
            return alert_id
        except Exception as e:
            logger.error(f"❌ 触发点滴告警失败: {e}")
            raise
    
    async def trigger_emotion_companion(self, patient_id: str, message: str):
        """触发心情陪伴语音（Demo）"""
        try:
            alert_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO voice_alerts (alert_id, patient_id, alert_type, message, played)
                   VALUES (?, ?, ?, ?, ?)""",
                (alert_id, patient_id, 'emotion_companion', message, 0)
            )
            
            # 通过WebSocket推送
            users = await execute_query(
                "SELECT user_id FROM users WHERE patient_id = ? AND is_active = 1",
                (patient_id,)
            )
            
            if users:
                user_id = users[0]['user_id']
                await websocket_manager.send_to_user(
                    user_id,
                    {
                        "type": "voice_alert",
                        "alert_type": "emotion_companion",
                        "message": message,
                        "alert_id": alert_id
                    }
                )
            
            return alert_id
        except Exception as e:
            logger.error(f"❌ 触发心情陪伴失败: {e}")
            raise
    
    async def trigger_medication_reminder(self, patient_id: str, message: str):
        """触发吃药提醒（Demo）"""
        try:
            alert_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO voice_alerts (alert_id, patient_id, alert_type, message, played)
                   VALUES (?, ?, ?, ?, ?)""",
                (alert_id, patient_id, 'medication', message, 0)
            )
            
            # 通过WebSocket推送
            users = await execute_query(
                "SELECT user_id FROM users WHERE patient_id = ? AND is_active = 1",
                (patient_id,)
            )
            
            if users:
                user_id = users[0]['user_id']
                await websocket_manager.send_to_user(
                    user_id,
                    {
                        "type": "voice_alert",
                        "alert_type": "medication",
                        "message": message,
                        "alert_id": alert_id
                    }
                )
            
            return alert_id
        except Exception as e:
            logger.error(f"❌ 触发吃药提醒失败: {e}")
            raise


# 创建单例
voice_alert_service = VoiceAlertService()

