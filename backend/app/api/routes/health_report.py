"""
健康简报API路由
"""
from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta
import uuid
import random
from app.models.schemas import HealthReportResponse, ActivityChartResponse, ActivityRecord, EmotionGaugeResponse
from app.core.database import execute_query, execute_insert

router = APIRouter(prefix="/api/health-report", tags=["health-report"])


@router.get("/daily/{patient_id}", response_model=HealthReportResponse)
async def get_daily_health_report(patient_id: str):
    """获取今日健康简报（Demo数据）"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id, full_name FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
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
            return HealthReportResponse(
                report_date=report['report_date'],
                summary_text=report['summary_text'],
                status_icon=report['status_icon']
            )
        
        # 生成Demo简报（实际应使用AI生成）
        demo_summaries = [
            f"{patient_name}今日活动规律，午睡后精神不错，已完成下午的服药。整体状态平稳，请您放心。",
            f"{patient_name}今日情绪稳定，按时完成各项活动，饮食正常。整体状态良好。",
            f"{patient_name}今日休息充足，下午有轻微活动，已按时服药。状态平稳。"
        ]
        
        summary_text = random.choice(demo_summaries)
        status_icon = "😊" if "不错" in summary_text or "良好" in summary_text else "✅"
        
        # 保存到数据库
        report_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO health_reports (report_id, patient_id, report_date, summary_text, status_icon)
               VALUES (?, ?, ?, ?, ?)""",
            (report_id, patient_id, today.isoformat(), summary_text, status_icon)
        )
        
        return HealthReportResponse(
            report_date=today.isoformat(),
            summary_text=summary_text,
            status_icon=status_icon
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取健康简报失败: {str(e)}")


@router.get("/activity/{patient_id}", response_model=ActivityChartResponse)
async def get_activity_records(patient_id: str):
    """获取活动记录（Demo数据）"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 查询活动记录
        records = await execute_query(
            """SELECT * FROM activity_records 
               WHERE patient_id = ? AND date(record_time) = date('now')
               ORDER BY record_time ASC""",
            (patient_id,)
        )
        
        if records:
            activity_records = [
                ActivityRecord(
                    time=record['record_time'],
                    activity_type=record['activity_type'],
                    value=record.get('activity_value'),
                    medication_name=record.get('medication_name')
                )
                for record in records
            ]
        else:
            # 生成Demo数据
            today = datetime.now().date()
            demo_records = []
            
            # 生成24小时的数据点（每小时一个）
            for hour in range(24):
                record_time = datetime.combine(today, datetime.min.time().replace(hour=hour))
                
                # 随机生成活动类型
                if hour in [8, 14, 20]:  # 用药时间
                    activity_type = "medication"
                    medication_name = "常规药物"
                    value = None
                elif 6 <= hour <= 22:  # 活动时间
                    activity_type = "activity"
                    value = random.uniform(0.3, 1.0)
                    medication_name = None
                else:  # 卧床时间
                    activity_type = "bed"
                    value = 0.0
                    medication_name = None
                
                demo_records.append(ActivityRecord(
                    time=record_time.isoformat(),
                    activity_type=activity_type,
                    value=value,
                    medication_name=medication_name
                ))
            
            activity_records = demo_records
        
        return ActivityChartResponse(records=activity_records)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取活动记录失败: {str(e)}")


@router.get("/emotion/{patient_id}", response_model=EmotionGaugeResponse)
async def get_emotion_data(patient_id: str):
    """获取情绪监测数据（Demo数据）"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 查询最新情绪记录
        records = await execute_query(
            """SELECT * FROM emotion_records 
               WHERE patient_id = ? 
               ORDER BY record_time DESC LIMIT 1""",
            (patient_id,)
        )
        
        if records:
            record = records[0]
            return EmotionGaugeResponse(
                emotion_level=record['emotion_level'],
                score=record.get('emotion_score')
            )
        else:
            # 生成Demo数据
            emotion_levels = ['positive', 'neutral', 'negative']
            weights = [0.5, 0.3, 0.2]  # 积极50%，中性30%，消极20%
            emotion_level = random.choices(emotion_levels, weights=weights)[0]
            
            # 根据情绪等级生成分数
            if emotion_level == 'positive':
                score = random.uniform(0.7, 1.0)
            elif emotion_level == 'neutral':
                score = random.uniform(0.4, 0.7)
            else:
                score = random.uniform(0.0, 0.4)
            
            # 保存到数据库
            record_id = str(uuid.uuid4())
            await execute_insert(
                """INSERT INTO emotion_records (record_id, patient_id, record_time, emotion_level, emotion_score)
                   VALUES (?, ?, ?, ?, ?)""",
                (record_id, patient_id, datetime.now(), emotion_level, score)
            )
            
            return EmotionGaugeResponse(
                emotion_level=emotion_level,
                score=score
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取情绪数据失败: {str(e)}")

