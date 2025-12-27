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
        },
        "heart_rate_flat": {
            "severity": "critical",
            "message_template": "患者{patient_name}心跳变平（直线），可能濒临死亡！需要立即通知家属到现场进行救护和临终陪伴！",
            "auto_notify": True,
            "requires_phone_call": True,
            "requires_family_notification": True
        },
        "vital_signs_critical": {
            "severity": "critical",
            "message_template": "患者{patient_name}生命体征异常：{description}，需要立即处理！",
            "auto_notify": True,
            "requires_phone_call": False
        }
    }
    
    async def check_and_create_alert(
        self,
        patient_id: str,
        camera_id: Optional[str],
        analysis_result_id: str,
        analysis_data: Dict,
        image_url: Optional[str] = None
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
            logger.info(f"🔍 [告警服务] 开始分析检测结果，确定告警类型 - 患者: {patient_name}")
            logger.info(f"🔍 [告警服务] 分析数据中的detections: {list(analysis_data.get('detections', {}).keys())}")
            alert_type, alert_info = self._analyze_detections(analysis_data, patient_name)
            
            logger.info(f"🔍 [告警服务] 分析结果: alert_type={alert_type}, alert_info={alert_info.get('title', '无') if alert_info else '无'}")
            
            if not alert_type:
                logger.info(f"ℹ️ [告警服务] 无需告警，返回")
                return  # 无需告警
            
            # 创建告警记录
            logger.info(f"📝 [告警服务] 准备创建告警记录: alert_type={alert_type}, title={alert_info.get('title')}, severity={alert_info.get('severity')}")
            alert_id = await self._create_alert_record(
                patient_id=patient_id,
                camera_id=camera_id,
                analysis_result_id=analysis_result_id,
                alert_type=alert_type,
                severity=alert_info["severity"],
                title=alert_info["title"],
                description=alert_info["description"],
                image_url=image_url
            )
            logger.info(f"✅ [告警服务] 告警记录已创建: alert_id={alert_id}, alert_type={alert_type}, title={alert_info.get('title')}")
            
            # 触发通知
            if alert_info.get("auto_notify"):
                logger.info(f"📢 [告警服务] 触发通知推送: alert_id={alert_id}")
                await self._trigger_notifications(
                    alert_id=alert_id,
                    patient_id=patient_id,
                    severity=alert_info["severity"],
                    message=alert_info["message"]
                )
                logger.info(f"✅ [告警服务] 通知推送完成")
            
            logger.info(f"✅ [告警服务] 告警创建完成: alert_id={alert_id} ({alert_type}) - {alert_info.get('title')}")
            
        except Exception as e:
            logger.error(f"❌ 创建告警失败: {e}")
            import traceback
            traceback.print_exc()
    
    def _analyze_detections(self, analysis_data: Dict, patient_name: str) -> tuple:
        """分析检测结果，返回告警类型和信息
        优先级顺序（从高到低）：
        1. 生命体征异常（心跳变平、心跳变缓等）- 最高优先级
        2. 跌倒检测
        3. 吊瓶监测（完全空、袋子空）
        4. 面色紫绀（缺氧）
        5. 异常活动
        6. 痛苦表情
        7. 离床检测（最低优先级，避免与其他检测混淆）
        """
        detections = analysis_data.get("detections", {})
        
        logger.info(f"🔍 [告警分析] 开始分析检测结果 - 患者: {patient_name}")
        logger.info(f"🔍 [告警分析] 检测到的项目: {list(detections.keys())}")
        
        # ========== 优先级1: 生命体征监测（最高优先级，必须最先检查）==========
        vital_signs = detections.get("vital_signs", {})
        logger.info(f"🔍 [告警分析] 检查生命体征监测: detected={vital_signs.get('detected')}, heart_rate_flat={vital_signs.get('heart_rate_flat')}, critical_life_threat={vital_signs.get('critical_life_threat')}")
        if vital_signs.get("detected"):
            # 优先级1.1: 心跳变平（濒临死亡）- 最高优先级
            if vital_signs.get("heart_rate_flat") or vital_signs.get("critical_life_threat"):
                description = vital_signs.get("description", "心跳监护仪显示直线，病人可能濒临死亡")
                logger.warning(f"🚨 [告警分析] 检测到心跳变平！优先级1 - 返回 heart_rate_flat 告警")
                logger.info(f"🚨 [告警分析] 心跳变平详情: description={description}")
                return "heart_rate_flat", {
                    "severity": "critical",
                    "title": "心跳变平 - 濒临死亡",
                    "description": description,
                    "message": f"患者{patient_name}心跳变平（直线），可能濒临死亡！需要立即通知家属到现场进行救护和临终陪伴！",
                    "auto_notify": True,
                    "requires_phone_call": True,
                    "requires_family_notification": True
                }
            
            # 优先级1.2: 其他生命体征异常
            if (vital_signs.get("heart_rate_slow") or 
                vital_signs.get("oxygen_low") or 
                vital_signs.get("respiration_abnormal") or
                vital_signs.get("blood_pressure_abnormal")):
                description = vital_signs.get("description", "生命体征异常")
                logger.warning(f"🚨 [告警分析] 检测到生命体征异常！优先级1 - 返回 vital_signs_critical 告警")
                return "vital_signs_critical", {
                    "severity": "critical",
                    "title": "生命体征异常",
                    "description": description,
                    "message": f"患者{patient_name}生命体征异常：{description}，需要立即处理！",
                    "auto_notify": True,
                    "requires_phone_call": False
                }
        
        logger.info(f"🔍 [告警分析] 生命体征监测检查完成，未发现异常")
        
        # ========== 优先级2: 跌倒检测 ==========
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
        
        # ========== 优先级3: 吊瓶监测 ==========
        iv_drip = detections.get("iv_drip", {})
        fluid_level = iv_drip.get("fluid_level", "")
        description = iv_drip.get("description", "")
        logger.info(f"🔍 [告警分析] 检查吊瓶监测: detected={iv_drip.get('detected')}, fluid_level={fluid_level}, completely_empty={iv_drip.get('completely_empty')}, bag_empty={iv_drip.get('bag_empty')}")
        
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
        
        # 优先级2: 袋子/玻璃瓶空（紧急警告）
        # 关键判断：如果液体已经流到滴液管，但袋子/玻璃瓶上半部分已空，这是危险情况
        # 1. 明确标记了袋子空
        # 2. fluid_level是"袋子空"
        # 3. 检测到"半满" - 根据我们的提示词，如果袋子/玻璃瓶上半部分还有液体，应该显示"满"或"接近打完"
        #    如果显示"半满"，很可能意味着上半部分已经空了，液体已经流到滴液管
        # 4. 描述中提到袋子空、上半部分空、滴液管等关键词
        bag_empty_indicators = [
            iv_drip.get("bag_empty"),
            iv_drip.get("needs_emergency_alert"),
            fluid_level == "袋子空",
            # 如果显示"半满"，很可能是袋子空的情况（因为如果袋子还有液体，应该显示"满"）
            fluid_level == "半满",
            # 描述中提到的危险关键词
            "空" in description if description else False,
            "上半部分" in description if description else False,
            "滴液管" in description if description else False,
            "静脉滴注" in description if description else False
        ]
        
        if any(bag_empty_indicators):
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
        
        # ========== 优先级4: 面色紫绀（缺氧）==========
        facial = detections.get("facial_analysis", {})
        # 支持中英文肤色值
        skin_color = facial.get("skin_color", "")
        if skin_color in ["紫绀", "cyanotic"]:
            return "facial_cyanotic", {
                "severity": "critical",
                "title": "面色异常",
                "description": "患者面色紫绀，可能缺氧",
                "message": f"患者{patient_name}面色紫绀，可能缺氧，请立即处理！",
                "auto_notify": True
            }
        
        # ========== 优先级5: 异常活动 ==========
        activity = detections.get("activity", {})
        if activity.get("abnormal"):
            return "abnormal_activity", {
                "severity": "high",
                "title": "活动异常",
                "description": activity.get("description", "检测到异常活动"),
                "message": f"患者{patient_name}检测到异常活动：{activity.get('description', '异常活动')}",
                "auto_notify": True
            }
        
        # ========== 优先级6: 异常情绪/表情 ==========
        expression = facial.get("expression", "")
        # 支持中英文情绪值
        negative_emotions = ["痛苦", "pain", "恐惧", "fear", "焦虑", "anxiety", 
                            "担忧", "worried", "沮丧", "depressed", "悲伤", "sad"]
        
        if expression in negative_emotions:
            # 根据情绪类型生成不同的告警消息
            emotion_messages = {
                "痛苦": "表现出痛苦表情",
                "pain": "表现出痛苦表情",
                "恐惧": "表现出恐惧表情",
                "fear": "表现出恐惧表情",
                "焦虑": "表现出焦虑表情",
                "anxiety": "表现出焦虑表情",
                "担忧": "表现出担忧表情，情绪异常",
                "worried": "表现出担忧表情，情绪异常",
                "沮丧": "表现出沮丧表情，情绪低落",
                "depressed": "表现出沮丧表情，情绪低落",
                "悲伤": "表现出悲伤表情，情绪低落",
                "sad": "表现出悲伤表情，情绪低落"
            }
            
            emotion_desc = emotion_messages.get(expression, "情绪异常")
            # 痛苦、恐惧、焦虑为中等优先级，担忧、沮丧、悲伤为低优先级但需要关注
            severity = "medium" if expression in ["痛苦", "pain", "恐惧", "fear", "焦虑", "anxiety"] else "low"
            
            logger.info(f"🔍 [告警分析] 检测到异常情绪: expression={expression}, severity={severity}")
            
            return "facial_pain", {
                "severity": severity,
                "title": "表情异常",
                "description": f"患者{emotion_desc}",
                "message": f"患者{patient_name}{emotion_desc}，请关注",
                "auto_notify": True
            }
        
        # ========== 优先级7: 离床检测（最低优先级，避免与其他检测混淆）==========
        bed_exit = detections.get("bed_exit", {})
        patient_in_bed = bed_exit.get("patient_in_bed")
        logger.info(f"🔍 [告警分析] 检查离床检测: patient_in_bed={patient_in_bed} (类型: {type(patient_in_bed).__name__})")
        # 只有当patient_in_bed明确为False时才触发离床告警，None或True都不触发
        if patient_in_bed is False:
            # 这里简化处理，实际应该查询历史记录判断离床时长
            logger.info(f"⚠️ [告警分析] 检测到离床！优先级7 - 返回 bed_exit_timeout 告警（注意：如果同时有其他检测，应优先其他检测）")
            return "bed_exit_timeout", {
                "severity": "high",
                "title": "离床检测",
                "description": "患者已离床",
                "message": f"患者{patient_name}已离床，请关注",
                "auto_notify": True
            }
        else:
            logger.info(f"🔍 [告警分析] 离床检测：patient_in_bed={patient_in_bed}，不触发离床告警")
        
        logger.info(f"🔍 [告警分析] 所有检测项目检查完成，未发现需要告警的情况")
        return None, {}
    
    async def _create_alert_record(
        self,
        patient_id: str,
        camera_id: Optional[str],
        analysis_result_id: str,
        alert_type: str,
        severity: str,
        title: str,
        description: str,
        image_url: Optional[str] = None
    ) -> str:
        """创建告警记录"""
        alert_id = str(uuid.uuid4())
        
        # 如果提供了image_url但告警记录中还没有，尝试更新分析结果关联的图片
        # 如果告警创建时还没有图片URL，可以稍后通过分析结果关联获取
        if not image_url:
            # 尝试从分析结果获取图片URL（如果有的话）
            try:
                from app.core.database import execute_query
                analysis_results = await execute_query(
                    "SELECT image_url FROM ai_analysis_results WHERE result_id = ?",
                    (analysis_result_id,)
                )
                if analysis_results and analysis_results[0].get("image_url"):
                    image_url = analysis_results[0]["image_url"]
            except:
                pass
        
        await execute_insert(
            """INSERT INTO alerts 
               (alert_id, patient_id, camera_id, analysis_result_id, alert_type, 
                severity, title, description, status, image_url, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
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
                image_url,
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
            # 获取需要通知的用户（护士和家属）
            recipients = await self._get_notification_recipients(patient_id)
            
            # 创建通知记录
            notification_tasks = []
            for recipient in recipients:
                notification_id = await self._create_notification(
                    alert_id=alert_id,
                    recipient_user_id=recipient["user_id"],
                    channel="websocket",
                    title="病房监护预警",
                    message=message
                )
                
                # WebSocket推送
                ws_manager = get_websocket_manager()
                await ws_manager.send_to_user(
                    recipient["user_id"],
                    {
                        "type": "alert",
                        "alert_id": alert_id,
                        "notification_id": notification_id,
                        "patient_id": patient_id,
                        "severity": severity,
                        "title": "病房监护预警",
                        "message": message,
                        "timestamp": datetime.now().isoformat()
                    }
                )
            
            logger.info(f"✅ 已推送通知给 {len(recipients)} 个用户")
            
        except Exception as e:
            logger.error(f"❌ 触发通知失败: {e}")
    
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

