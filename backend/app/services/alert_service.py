"""
告警服务
告警规则判断，创建告警记录，触发通知
"""
import json
import logging
import uuid
from datetime import datetime, timedelta
from typing import Dict, Optional, List
from app.core.database import execute_insert, execute_query, execute_update
# 延迟导入避免循环依赖
def get_websocket_manager():
    from app.services.websocket_manager import websocket_manager
    return websocket_manager

logger = logging.getLogger(__name__)


class AlertService:
    """告警服务"""
    
    # 告警规则
    ALERT_RULES = {
        "fall_detected": {
            "severity": "critical",
            "message_template": "患者{patient_name}检测到跌倒，请立即查看！",
            "auto_notify": True
        },
        "facial_cyanotic": {
            "severity": "critical",
            "message_template": "患者{patient_name}面色紫绀，可能缺氧，请立即处理！",
            "auto_notify": True
        },
        "bed_exit_timeout": {
            "severity": "high",
            "message_template": "患者{patient_name}离床超过{duration}分钟，请关注",
            "auto_notify": True
        },
        "abnormal_activity": {
            "severity": "high",
            "message_template": "患者{patient_name}检测到异常活动：{description}",
            "auto_notify": True
        },
        "iv_drip_empty": {
            "severity": "medium",
            "message_template": "患者{patient_name}输液即将完成，请准备更换",
            "auto_notify": True
        },
        "iv_drip_bag_empty": {
            "severity": "critical",
            "message_template": "患者{patient_name}吊瓶袋子/玻璃瓶已空，需要立即紧急处理！请立即联系护士！",
            "auto_notify": True,
            "requires_phone_call": False
        },
        "iv_drip_completely_empty": {
            "severity": "critical",
            "message_template": "患者{patient_name}吊瓶完全空了，需要立即电话呼叫护士！",
            "auto_notify": True,
            "requires_phone_call": True
        },
        "facial_pain": {
            "severity": "medium",
            "message_template": "患者{patient_name}表现出痛苦表情，请关注",
            "auto_notify": True
        }
    }
    
    async def check_and_create_alert(
        self,
        patient_id: str,
        camera_id: Optional[str],
        analysis_result_id: str,
        analysis_data: Dict
    ):
        """检查分析结果并创建告警"""
        try:
            # 获取患者信息
            patient_info = await self._get_patient_info(patient_id)
            if not patient_info:
                logger.error(f"患者不存在: {patient_id}")
                return
            
            patient_name = patient_info.get("full_name", "患者")
            
            # 分析检测结果，确定告警类型
            alert_type, alert_info = self._analyze_detections(analysis_data, patient_name)
            
            if not alert_type:
                return  # 无需告警
            
            # 创建告警记录
            alert_id = await self._create_alert_record(
                patient_id=patient_id,
                camera_id=camera_id,
                analysis_result_id=analysis_result_id,
                alert_type=alert_type,
                severity=alert_info["severity"],
                title=alert_info["title"],
                description=alert_info["description"]
            )
            
            # 触发通知
            if alert_info.get("auto_notify"):
                await self._trigger_notifications(
                    alert_id=alert_id,
                    patient_id=patient_id,
                    severity=alert_info["severity"],
                    message=alert_info["message"]
                )
            
            logger.info(f"✅ 已创建告警: {alert_id} ({alert_type})")
            
        except Exception as e:
            logger.error(f"❌ 创建告警失败: {e}")
            import traceback
            traceback.print_exc()
    
    def _analyze_detections(self, analysis_data: Dict, patient_name: str) -> tuple:
        """分析检测结果，返回告警类型和信息"""
        detections = analysis_data.get("detections", {})
        
        # 1. 跌倒检测
        if detections.get("fall", {}).get("detected"):
            fall_desc = detections["fall"].get("description", "检测到患者跌倒")
            # 确保描述是中文
            if not any('\u4e00' <= char <= '\u9fff' for char in fall_desc):
                # 如果描述是英文，翻译成中文
                fall_desc = fall_desc.replace("Patient is on the floor", "患者在地面上")
                fall_desc = fall_desc.replace("near the nurse station", "靠近护士站")
                fall_desc = fall_desc.replace("indicating a fall", "表明跌倒")
                fall_desc = fall_desc.replace("Possible head trauma", "可能头部受伤")
                fall_desc = fall_desc.replace("lying motionless", "躺着一动不动")
                fall_desc = fall_desc.replace("on the floor", "在地面上")
            
            return "fall_detected", {
                "severity": "critical",
                "title": "跌倒检测",
                "description": fall_desc,
                "message": f"患者{patient_name}检测到跌倒，请立即查看！",
                "auto_notify": True
            }
        
        # 2. 面色紫绀（缺氧）
        facial = detections.get("facial_analysis", {})
        if facial.get("skin_color") == "cyanotic":
            return "facial_cyanotic", {
                "severity": "critical",
                "title": "面色异常",
                "description": "患者面色紫绀，可能缺氧",
                "message": f"患者{patient_name}面色紫绀，可能缺氧，请立即处理！",
                "auto_notify": True
            }
        
        # 3. 痛苦表情
        if facial.get("expression") == "pain":
            return "facial_pain", {
                "severity": "medium",
                "title": "表情异常",
                "description": "患者表现出痛苦表情",
                "message": f"患者{patient_name}表现出痛苦表情，请关注",
                "auto_notify": True
            }
        
        # 4. 异常活动
        activity = detections.get("activity", {})
        if activity.get("abnormal"):
            return "abnormal_activity", {
                "severity": "high",
                "title": "活动异常",
                "description": activity.get("description", "检测到异常活动"),
                "message": f"患者{patient_name}检测到异常活动：{activity.get('description', '异常活动')}",
                "auto_notify": True
            }
        
        # 5. 离床检测（需要结合历史记录判断超时）
        bed_exit = detections.get("bed_exit", {})
        if not bed_exit.get("patient_in_bed"):
            # 这里简化处理，实际应该查询历史记录判断离床时长
            return "bed_exit_timeout", {
                "severity": "high",
                "title": "离床检测",
                "description": "患者已离床",
                "message": f"患者{patient_name}已离床，请关注",
                "auto_notify": True
            }
        
        # 6. 吊瓶监测
        iv_drip = detections.get("iv_drip", {})
        fluid_level = iv_drip.get("fluid_level", "")
        
        # 优先级1: 完全空了 - 需要电话呼叫
        if iv_drip.get("completely_empty") or fluid_level == "已打完":
            return "iv_drip_completely_empty", {
                "severity": "critical",
                "title": "吊瓶完全空",
                "description": "吊瓶完全空了，需要立即电话呼叫护士",
                "message": f"患者{patient_name}吊瓶完全空了，需要立即电话呼叫护士！",
                "auto_notify": True,
                "requires_phone_call": True
            }
        
        # 优先级2: 袋子/玻璃瓶空 - 紧急警告
        # 包括：bag_empty=true, needs_emergency_alert=true, fluid_level="袋子空"
        # 或者：fluid_level="半满"但实际是袋子空的情况（通过后处理已修正）
        if (iv_drip.get("bag_empty") or 
            iv_drip.get("needs_emergency_alert") or 
            fluid_level == "袋子空" or
            (fluid_level in ["半满", "接近打完"] and iv_drip.get("bag_empty"))):
            return "iv_drip_bag_empty", {
                "severity": "critical",
                "title": "吊瓶袋子空",
                "description": "吊瓶袋子/玻璃瓶已空，液体已流到滴液管，需要立即紧急处理",
                "message": f"患者{patient_name}吊瓶袋子/玻璃瓶已空，液体已流到滴液管，需要立即紧急处理！请立即联系护士！",
                "auto_notify": True,
                "requires_phone_call": False
            }
        
        # 优先级3: 需要更换（一般情况）
        if iv_drip.get("needs_replacement"):
            return "iv_drip_empty", {
                "severity": "medium",
                "title": "输液监测",
                "description": "输液即将完成或已打完",
                "message": f"患者{patient_name}输液即将完成，请准备更换",
                "auto_notify": True
            }
        
        return None, {}
    
    async def _create_alert_record(
        self,
        patient_id: str,
        camera_id: Optional[str],
        analysis_result_id: str,
        alert_type: str,
        severity: str,
        title: str,
        description: str
    ) -> str:
        """创建告警记录"""
        alert_id = str(uuid.uuid4())
        
        await execute_insert(
            """INSERT INTO alerts 
               (alert_id, patient_id, camera_id, analysis_result_id, alert_type, 
                severity, title, description, status, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                alert_id,
                patient_id,
                camera_id,
                analysis_result_id,
                alert_type,
                severity,
                title,
                description,
                "pending",
                datetime.now()
            )
        )
        
        return alert_id
    
    async def _trigger_notifications(
        self,
        alert_id: str,
        patient_id: str,
        severity: str,
        message: str
    ):
        """触发通知推送"""
        try:
            logger.info(f"📢 [通知] 开始触发通知 - alert_id: {alert_id}, patient_id: {patient_id}, severity: {severity}")
            
            # 获取需要通知的用户（护士和家属）
            recipients = await self._get_notification_recipients(patient_id)
            logger.info(f"📢 [通知] 找到 {len(recipients)} 个接收者: {[r.get('user_id') for r in recipients]}")
            
            if len(recipients) == 0:
                logger.warning(f"⚠️ [通知] 未找到接收者，患者ID: {patient_id}")
                return
            
            # 创建通知记录并推送
            ws_manager = get_websocket_manager()
            sent_count = 0
            
            for recipient in recipients:
                try:
                    notification_id = await self._create_notification(
                        alert_id=alert_id,
                        recipient_user_id=recipient["user_id"],
                        channel="websocket",
                        title="病房监护预警",
                        message=message
                    )
                    
                    # WebSocket推送
                    ws_message = {
                        "type": "alert",
                        "alert_id": alert_id,
                        "notification_id": notification_id,
                        "patient_id": patient_id,
                        "severity": severity,
                        "title": "病房监护预警",
                        "message": message,
                        "timestamp": datetime.now().isoformat()
                    }
                    logger.info(f"📢 [通知] 准备通过WebSocket发送给用户: {recipient['user_id']} (角色: {recipient.get('role', 'unknown')})")
                    success = await ws_manager.send_to_user(recipient["user_id"], ws_message)
                    if success:
                        sent_count += 1
                        logger.info(f"✅ [通知] WebSocket消息已成功发送给用户: {recipient['user_id']} (角色: {recipient.get('role', 'unknown')})")
                    else:
                        logger.warning(f"⚠️ [通知] WebSocket消息发送失败 - 用户: {recipient['user_id']} 可能未连接")
                except Exception as e:
                    logger.error(f"❌ [通知] 发送给用户 {recipient.get('user_id')} 失败: {e}")
            
            logger.info(f"✅ [通知] 已推送通知给 {sent_count}/{len(recipients)} 个用户")
            
        except Exception as e:
            logger.error(f"❌ [通知] 触发通知失败: {e}")
            import traceback
            traceback.print_exc()
    
    async def _get_notification_recipients(self, patient_id: str) -> List[Dict]:
        """获取需要通知的用户列表"""
        # 获取关联的家属
        guardians = await execute_query(
            """SELECT u.user_id, u.role 
               FROM patient_guardians pg
               JOIN users u ON pg.guardian_user_id = u.user_id
               WHERE pg.patient_id = ? AND u.is_active = 1""",
            (patient_id,)
        )
        
        # 获取所有护士
        nurses = await execute_query(
            "SELECT user_id, role FROM users WHERE role = 'nurse' AND is_active = 1"
        )
        
        # 合并列表
        recipients = guardians + nurses
        
        return recipients
    
    async def _create_notification(
        self,
        alert_id: str,
        recipient_user_id: str,
        channel: str,
        title: str,
        message: str
    ) -> str:
        """创建通知记录"""
        notification_id = str(uuid.uuid4())
        
        await execute_insert(
            """INSERT INTO notifications 
               (notification_id, alert_id, recipient_user_id, channel, title, message, status)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                notification_id,
                alert_id,
                recipient_user_id,
                channel,
                title,
                message,
                "sent"
            )
        )
        
        return notification_id
    
    async def _get_patient_info(self, patient_id: str) -> Optional[Dict]:
        """获取患者信息"""
        results = await execute_query(
            "SELECT * FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        return results[0] if results else None
    
    async def acknowledge_alert(self, alert_id: str, user_id: str) -> bool:
        """确认告警"""
        try:
            await execute_update(
                """UPDATE alerts 
                   SET status = 'acknowledged', acknowledged_by = ?, acknowledged_at = ?
                   WHERE alert_id = ? AND status = 'pending'""",
                (user_id, datetime.now(), alert_id)
            )
            logger.info(f"✅ 告警已确认: {alert_id}")
            return True
        except Exception as e:
            logger.error(f"❌ 确认告警失败: {e}")
            return False
    
    async def resolve_alert(
        self,
        alert_id: str,
        user_id: str,
        resolution_notes: str
    ) -> bool:
        """处理告警"""
        try:
            await execute_update(
                """UPDATE alerts 
                   SET status = 'resolved', resolved_by = ?, resolved_at = ?, resolution_notes = ?
                   WHERE alert_id = ?""",
                (user_id, datetime.now(), resolution_notes, alert_id)
            )
            logger.info(f"✅ 告警已处理: {alert_id}")
            return True
        except Exception as e:
            logger.error(f"❌ 处理告警失败: {e}")
            return False
    
    async def get_alerts(
        self,
        patient_id: Optional[str] = None,
        status: Optional[str] = None,
        severity: Optional[str] = None,
        limit: int = 50
    ) -> List[Dict]:
        """获取告警列表"""
        query = "SELECT * FROM alerts WHERE 1=1"
        params = []
        
        if patient_id:
            query += " AND patient_id = ?"
            params.append(patient_id)
        
        if status:
            query += " AND status = ?"
            params.append(status)
        
        if severity:
            query += " AND severity = ?"
            params.append(severity)
        
        query += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)
        
        results = await execute_query(query, tuple(params))
        return results


# 创建全局实例
alert_service = AlertService()

