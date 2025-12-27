"""
健康简报生成服务
使用Gemini生成每日健康简报
"""
import logging
from datetime import datetime
from typing import Optional, Dict
from app.services.gemini_service import gemini_analyzer
from app.core.database import execute_query, execute_insert
from openai import OpenAI
from app.core.config import settings
import uuid

logger = logging.getLogger(__name__)


class HealthReportService:
    """健康简报生成服务"""
    
    def __init__(self):
        self.use_one_api = settings.use_one_api
        self.one_api_client = None
        self.gemini_client = None
    
    async def generate_daily_report(
        self,
        patient_id: str,
        use_ai: bool = False
    ) -> Dict:
        """
        生成每日健康简报
        
        Args:
            patient_id: 患者ID
            use_ai: 是否使用AI生成（默认False，使用Demo数据）
        
        Returns:
            健康简报字典
        """
        try:
            # 获取患者信息
            patients = await execute_query(
                "SELECT * FROM patients WHERE patient_id = ?",
                (patient_id,)
            )
            if not patients:
                raise ValueError(f"患者不存在: {patient_id}")
            
            patient = patients[0]
            patient_name = patient['full_name']
            today = datetime.now().date()
            
            # 检查是否已有今日简报
            reports = await execute_query(
                "SELECT * FROM health_reports WHERE patient_id = ? AND report_date = ?",
                (patient_id, today.isoformat())
            )
            
            if reports:
                report = reports[0]
                return {
                    "report_id": report['report_id'],
                    "report_date": report['report_date'],
                    "summary_text": report['summary_text'],
                    "status_icon": report['status_icon']
                }
            
            # 获取今日活动记录和情绪数据
            activity_records = await execute_query(
                """SELECT * FROM activity_records 
                   WHERE patient_id = ? AND date(record_time) = date('now')
                   ORDER BY record_time ASC""",
                (patient_id,)
            )
            
            emotion_records = await execute_query(
                """SELECT * FROM emotion_records 
                   WHERE patient_id = ? AND date(record_time) = date('now')
                   ORDER BY record_time DESC LIMIT 1""",
                (patient_id,)
            )
            
            # 获取今日告警
            alerts = await execute_query(
                """SELECT * FROM alerts 
                   WHERE patient_id = ? AND date(created_at) = date('now')
                   ORDER BY created_at DESC""",
                (patient_id,)
            )
            
            if use_ai:
                # 使用AI生成简报
                summary_text, status_icon = await self._generate_ai_report(
                    patient_name,
                    activity_records,
                    emotion_records,
                    alerts
                )
            else:
                # 使用Demo数据
                summary_text, status_icon = self._generate_demo_report(
                    patient_name,
                    activity_records,
                    emotion_records,
                    alerts
                )
            
            # 保存到数据库
            report_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO health_reports (report_id, patient_id, report_date, summary_text, status_icon)
                   VALUES (?, ?, ?, ?, ?)""",
                (report_id, patient_id, today.isoformat(), summary_text, status_icon)
            )
            
            return {
                "report_id": report_id,
                "report_date": today.isoformat(),
                "summary_text": summary_text,
                "status_icon": status_icon
            }
        except Exception as e:
            logger.error(f"生成健康简报失败: {e}")
            raise
    
    def _get_client(self):
        """获取OpenAI客户端（用于One-API或直接Gemini）"""
        if self.use_one_api:
            if not self.one_api_client:
                self.one_api_client = OpenAI(
                    base_url=settings.one_api_base_url,
                    api_key=settings.one_api_key
                )
            return self.one_api_client
        else:
            # 直接Gemini API模式（简化处理，使用Demo）
            logger.warning("直接Gemini API模式暂不支持文本生成，使用Demo数据")
            return None
    
    async def _generate_ai_report(
        self,
        patient_name: str,
        activity_records: list,
        emotion_records: list,
        alerts: list
    ) -> tuple:
        """使用AI生成健康简报"""
        try:
            # 构建提示词
            prompt = f"""请为患者{patient_name}生成今日健康简报。

患者今日情况：
- 活动记录：{len(activity_records)}条
- 情绪状态：{'积极' if emotion_records and emotion_records[0].get('emotion_level') == 'positive' else '一般' if emotion_records else '未知'}
- 告警数量：{len(alerts)}条

请生成一句简洁、温暖、带情感温度的总结句（30-50字），用于向家属汇报患者今日状态。
要求：
1. 语言自然、亲切
2. 包含具体信息（如活动、情绪、服药等）
3. 结尾要让人放心

只返回简报文本，不要其他内容。"""
            
            # 尝试使用One-API生成
            client = self._get_client()
            if client and self.use_one_api:
                try:
                    response = client.chat.completions.create(
                        model=settings.one_api_gemini_model,
                        messages=[
                            {"role": "user", "content": prompt}
                        ],
                        temperature=0.7,
                        max_tokens=200
                    )
                    summary_text = response.choices[0].message.content.strip()
                    
                    # 根据内容判断状态图标
                    if any(word in summary_text for word in ['不错', '良好', '稳定', '正常', '放心']):
                        status_icon = "😊"
                    else:
                        status_icon = "✅"
                    
                    return summary_text, status_icon
                except Exception as e:
                    logger.warning(f"One-API生成失败: {e}")
            
            # 降级到Demo数据
            return self._generate_demo_report(patient_name, activity_records, emotion_records, alerts)
        except Exception as e:
            logger.warning(f"AI生成简报失败，使用Demo数据: {e}")
            return self._generate_demo_report(patient_name, activity_records, emotion_records, alerts)
    
    def _generate_demo_report(
        self,
        patient_name: str,
        activity_records: list,
        emotion_records: list,
        alerts: list
    ) -> tuple:
        """生成Demo健康简报"""
        import random
        
        demo_summaries = [
            f"{patient_name}今日活动规律，午睡后精神不错，已完成下午的服药。整体状态平稳，请您放心。",
            f"{patient_name}今日情绪稳定，按时完成各项活动，饮食正常。整体状态良好。",
            f"{patient_name}今日休息充足，下午有轻微活动，已按时服药。状态平稳。"
        ]
        
        summary_text = random.choice(demo_summaries)
        status_icon = "😊" if "不错" in summary_text or "良好" in summary_text else "✅"
        
        return summary_text, status_icon


# 创建单例
health_report_service = HealthReportService()

