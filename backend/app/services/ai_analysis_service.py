"""
AI分析服务
调用Gemini服务，保存分析结果，触发告警
"""
import json
import logging
import uuid
from datetime import datetime
from typing import Dict, Optional
from app.core.database import execute_insert, execute_query
from app.services.gemini_service import gemini_analyzer
# 延迟导入避免循环依赖
def get_alert_service():
    from app.services.alert_service import alert_service
    return alert_service

logger = logging.getLogger(__name__)


class AIAnalysisService:
    """AI分析服务"""
    
    async def analyze_patient_image(
        self,
        image_bytes: bytes,
        patient_id: str,
        camera_id: Optional[str] = None,
        timestamp_ms: Optional[int] = None
    ) -> Dict:
        """
        分析患者图像
        
        Args:
            image_bytes: 图片字节流
            patient_id: 患者ID
            camera_id: 摄像头ID（可选）
        
        Returns:
            分析结果字典
        """
        import traceback
        start_time = datetime.now()
        
        try:
            logger.info(f"📊 [AI分析] 开始分析患者图像 - patient_id: {patient_id}, timestamp_ms: {timestamp_ms}")
            logger.info(f"📊 [AI分析] 图片大小: {len(image_bytes)} bytes")
            
            # 1. 获取患者信息和监测配置
            logger.info(f"📊 [AI分析] 步骤1/7: 获取患者信息...")
            patient_info = await self._get_patient_info(patient_id)
            if not patient_info:
                logger.error(f"❌ [AI分析] 患者不存在: {patient_id}")
                return {"error": "患者不存在", "status": "failed"}
            
            logger.info(f"📊 [AI分析] 患者信息: {patient_info.get('full_name')} ({patient_info.get('risk_level')}风险)")
            
            monitoring_config = await self._get_monitoring_config(patient_id)
            logger.info(f"📊 [AI分析] 监测配置: {monitoring_config}")
            
            # 2. 确定检测模式
            logger.info(f"📊 [AI分析] 步骤2/7: 确定检测模式...")
            detection_modes = self._get_detection_modes(monitoring_config)
            logger.info(f"📊 [AI分析] 检测模式: {detection_modes}")
            
            # 3. 构建患者上下文
            logger.info(f"📊 [AI分析] 步骤3/7: 构建患者上下文...")
            patient_context = {
                "name": patient_info.get("full_name", "未知"),
                "age": patient_info.get("age", "未知"),
                "diagnosis": patient_info.get("diagnosis", "未知"),
                "risk_level": patient_info.get("risk_level", "medium")
            }
            logger.info(f"📊 [AI分析] 患者上下文: {patient_context}")
            
            # 4. 调用Gemini分析
            logger.info(f"📊 [AI分析] 步骤4/7: 调用Gemini AI分析...")
            analysis_start = datetime.now()
            analysis_result = await gemini_analyzer.analyze_hospital_scene(
                image_bytes=image_bytes,
                patient_context=patient_context,
                detection_modes=detection_modes
            )
            analysis_duration = (datetime.now() - analysis_start).total_seconds()
            logger.info(f"📊 [AI分析] Gemini分析完成，耗时: {analysis_duration:.2f}秒")
            
            if analysis_result.get("status") == "failed" or "error" in analysis_result:
                error_msg = analysis_result.get('error', '未知错误')
                logger.error(f"❌ [AI分析] AI分析失败: {error_msg}")
                logger.error(f"❌ [AI分析] 完整错误信息: {analysis_result}")
                return {
                    "error": error_msg,
                    "status": "failed",
                    "details": analysis_result
                }
            
            logger.info(f"📊 [AI分析] 分析结果状态: {analysis_result.get('overall_status')}")
            logger.info(f"📊 [AI分析] 检测结果: {json.dumps(analysis_result.get('detections', {}), ensure_ascii=False, indent=2)}")
            
            # 5. 保存分析结果到数据库
            logger.info(f"📊 [AI分析] 步骤5/7: 保存分析结果到数据库...")
            result_id = await self._save_analysis_result(
                patient_id=patient_id,
                camera_id=camera_id,
                analysis_result=analysis_result,
                detection_modes=detection_modes,
                timestamp_ms=timestamp_ms
            )
            logger.info(f"📊 [AI分析] 结果已保存: {result_id}")
            
            # 6. 检查是否需要触发告警
            logger.info(f"📊 [AI分析] 步骤6/7: 检查告警条件...")
            if analysis_result.get("overall_status") in ["attention", "critical"]:
                logger.warning(f"⚠️ [AI分析] 检测到异常状态: {analysis_result.get('overall_status')}，触发告警检查")
                alert_service = get_alert_service()
                await alert_service.check_and_create_alert(
                    patient_id=patient_id,
                    camera_id=camera_id,
                    analysis_result_id=result_id,
                    analysis_data=analysis_result
                )
                logger.info(f"📊 [AI分析] 告警检查完成")
            else:
                logger.info(f"📊 [AI分析] 状态正常，无需告警")
            
            # 7. 返回结果
            total_duration = (datetime.now() - start_time).total_seconds()
            logger.info(f"✅ [AI分析] 分析完成，总耗时: {total_duration:.2f}秒")
            logger.info(f"📊 [AI分析] 步骤7/7: 返回结果")
            
            return {
                "status": "success",
                "result_id": result_id,
                "analysis": analysis_result,
                "duration_seconds": total_duration
            }
            
        except Exception as e:
            total_duration = (datetime.now() - start_time).total_seconds()
            error_trace = traceback.format_exc()
            logger.error(f"❌ [AI分析] AI分析服务异常 (耗时: {total_duration:.2f}秒)")
            logger.error(f"❌ [AI分析] 异常类型: {type(e).__name__}")
            logger.error(f"❌ [AI分析] 异常消息: {str(e)}")
            logger.error(f"❌ [AI分析] 完整堆栈跟踪:\n{error_trace}")
            
            return {
                "error": str(e),
                "error_type": type(e).__name__,
                "error_traceback": error_trace,
                "status": "failed",
                "duration_seconds": total_duration
            }
    
    async def _get_patient_info(self, patient_id: str) -> Optional[Dict]:
        """获取患者信息"""
        results = await execute_query(
            "SELECT * FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        return results[0] if results else None
    
    async def _get_monitoring_config(self, patient_id: str) -> Optional[Dict]:
        """获取监测配置"""
        results = await execute_query(
            "SELECT * FROM monitoring_configs WHERE patient_id = ?",
            (patient_id,)
        )
        return results[0] if results else None
    
    def _get_detection_modes(self, config: Optional[Dict]) -> list:
        """根据配置确定检测模式"""
        if not config:
            # 默认启用所有检测
            return ['fall', 'bed_exit', 'facial', 'activity', 'iv_drip']
        
        modes = []
        if config.get('fall_detection_enabled'):
            modes.append('fall')
        if config.get('bed_exit_detection_enabled'):
            modes.append('bed_exit')
        if config.get('facial_analysis_enabled'):
            modes.append('facial')
        if config.get('abnormal_activity_enabled'):
            modes.append('activity')
        if config.get('iv_drip_monitoring_enabled'):
            modes.append('iv_drip')
        
        return modes if modes else ['fall', 'bed_exit', 'facial']
    
    async def _save_analysis_result(
        self,
        patient_id: str,
        camera_id: Optional[str],
        analysis_result: Dict,
        detection_modes: list,
        timestamp_ms: Optional[int] = None
    ) -> str:
        """保存分析结果到数据库"""
        result_id = str(uuid.uuid4())
        # 如果有相对时间戳，使用它；否则使用当前时间
        if timestamp_ms is not None:
            # 从患者开始监控时间计算绝对时间（简化处理，使用当前时间减去相对时间）
            timestamp = datetime.now()
        else:
            timestamp = datetime.now()
        
        # 确定检测类型（取第一个检测到的类型）
        detection_type = "general"
        detections = analysis_result.get("detections", {})
        for mode in detection_modes:
            if mode in detections and detections[mode].get("detected") or \
               (mode == "bed_exit" and not detections.get("bed_exit", {}).get("patient_in_bed")):
                detection_type = mode
                break
        
        # 获取置信度
        confidence_score = None
        if "detections" in analysis_result:
            for mode in detection_modes:
                if mode in analysis_result["detections"]:
                    conf = analysis_result["detections"][mode].get("confidence")
                    if conf:
                        confidence_score = float(conf)
                        break
        
        # 保存到数据库（包含相对时间戳）
        analysis_data_with_timestamp = analysis_result.copy()
        if timestamp_ms is not None:
            analysis_data_with_timestamp['timestamp_ms'] = timestamp_ms
        
        await execute_insert(
            """INSERT INTO ai_analysis_results 
               (result_id, camera_id, patient_id, timestamp, detection_type, 
                analysis_data, is_alert_triggered, confidence_score)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                result_id,
                camera_id,
                patient_id,
                timestamp,
                detection_type,
                json.dumps(analysis_data_with_timestamp, ensure_ascii=False),
                1 if analysis_result.get("overall_status") in ["attention", "critical"] else 0,
                confidence_score
            )
        )
        
        logger.info(f"✅ 已保存分析结果: {result_id}")
        return result_id
    
    async def get_analysis_history(
        self,
        patient_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        limit: int = 100
    ) -> list:
        """获取分析历史"""
        query = "SELECT * FROM ai_analysis_results WHERE patient_id = ?"
        params = [patient_id]
        
        if start_date:
            query += " AND timestamp >= ?"
            params.append(start_date)
        
        if end_date:
            query += " AND timestamp <= ?"
            params.append(end_date)
        
        query += " ORDER BY timestamp DESC LIMIT ?"
        params.append(limit)
        
        results = await execute_query(query, tuple(params))
        
        # 解析JSON数据
        for result in results:
            if result.get("analysis_data"):
                try:
                    result["analysis_data"] = json.loads(result["analysis_data"])
                except:
                    pass
        
        return results


# 创建全局实例
ai_analysis_service = AIAnalysisService()

