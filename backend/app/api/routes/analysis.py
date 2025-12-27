"""
AI分析API路由
"""
from fastapi import APIRouter, UploadFile, File, HTTPException, Query, Form
from typing import Optional, List
from datetime import datetime
import json
from app.models.schemas import AnalysisResponse
from app.services.ai_analysis_service import ai_analysis_service

router = APIRouter(prefix="/api/analysis", tags=["analysis"])


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_image(
    file: UploadFile = File(...),
    patient_id: str = Query(..., description="患者ID"),
    camera_id: Optional[str] = Query(None, description="摄像头ID"),
    timestamp_ms: Optional[int] = Query(None, description="时间戳（毫秒）")
):
    """上传图片进行AI分析"""
    import logging
    import traceback
    from datetime import datetime
    
    logger = logging.getLogger(__name__)
    start_time = datetime.now()
    
    try:
        logger.info(f"📥 [API] 收到图片分析请求")
        logger.info(f"📥 [API] 患者ID: {patient_id}")
        logger.info(f"📥 [API] 摄像头ID: {camera_id}")
        logger.info(f"📥 [API] 时间戳: {timestamp_ms}ms")
        logger.info(f"📥 [API] 文件名: {file.filename}, 类型: {file.content_type}, 大小: {file.size if hasattr(file, 'size') else '未知'}")
        
        # 读取图片数据
        logger.info(f"📥 [API] 读取图片数据...")
        image_bytes = await file.read()
        
        if len(image_bytes) == 0:
            logger.error(f"❌ [API] 图片文件为空")
            raise HTTPException(status_code=400, detail="图片文件为空")
        
        logger.info(f"📥 [API] 图片数据读取完成: {len(image_bytes)} bytes")
        
        # 调用AI分析服务
        logger.info(f"📥 [API] 调用AI分析服务...")
        result = await ai_analysis_service.analyze_patient_image(
            image_bytes=image_bytes,
            patient_id=patient_id,
            camera_id=camera_id,
            timestamp_ms=timestamp_ms
        )
        
        total_duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"✅ [API] 分析完成，总耗时: {total_duration:.2f}秒")
        
        return AnalysisResponse(**result)
        
    except HTTPException as e:
        total_duration = (datetime.now() - start_time).total_seconds()
        logger.error(f"❌ [API] HTTP异常 (耗时: {total_duration:.2f}秒): {e.status_code} - {e.detail}")
        raise
    except Exception as e:
        total_duration = (datetime.now() - start_time).total_seconds()
        error_trace = traceback.format_exc()
        logger.error(f"❌ [API] 分析失败 (耗时: {total_duration:.2f}秒)")
        logger.error(f"❌ [API] 异常类型: {type(e).__name__}")
        logger.error(f"❌ [API] 异常消息: {str(e)}")
        logger.error(f"❌ [API] 完整堆栈跟踪:\n{error_trace}")
        raise HTTPException(
            status_code=500, 
            detail=f"分析失败: {str(e)}\n\n错误类型: {type(e).__name__}\n\n堆栈跟踪:\n{error_trace}"
        )


@router.post("/batch", response_model=List[dict])
async def analyze_batch(
    files: List[UploadFile] = File(...),
    frames: str = Form(..., description="帧元数据JSON字符串")
):
    """批量上传图片进行AI分析"""
    try:
        # 解析帧元数据
        try:
            frames_data = json.loads(frames)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="帧元数据格式错误")
        
        if len(files) != len(frames_data):
            raise HTTPException(status_code=400, detail="文件数量与元数据数量不匹配")
        
        # 批量处理
        results = []
        for i, file in enumerate(files):
            try:
                image_bytes = await file.read()
                if len(image_bytes) == 0:
                    results.append({
                        "status": "failed",
                        "error": "图片文件为空",
                        "index": i
                    })
                    continue
                
                frame_info = frames_data[i]
                result = await ai_analysis_service.analyze_patient_image(
                    image_bytes=image_bytes,
                    patient_id=frame_info.get("patient_id"),
                    camera_id=frame_info.get("camera_id"),
                    timestamp_ms=frame_info.get("timestamp_ms")
                )
                
                results.append({
                    "status": "success",
                    "index": i,
                    "result": result
                })
            except Exception as e:
                results.append({
                    "status": "failed",
                    "error": str(e),
                    "index": i
                })
        
        return results
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"批量分析失败: {str(e)}")


@router.get("/history/{patient_id}", response_model=list)
async def get_analysis_history(
    patient_id: str,
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    limit: int = Query(100, le=1000)
):
    """获取分析历史"""
    try:
        start = datetime.fromisoformat(start_date) if start_date else None
        end = datetime.fromisoformat(end_date) if end_date else None
        
        results = await ai_analysis_service.get_analysis_history(
            patient_id=patient_id,
            start_date=start,
            end_date=end,
            limit=limit
        )
        
        return results
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"日期格式错误: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/upload-image", response_model=AnalysisResponse)
async def upload_image(
    file: UploadFile = File(...),
    patient_id: str = Query(..., description="患者ID"),
    camera_id: Optional[str] = Query(None, description="摄像头ID"),
    timestamp_ms: Optional[int] = Query(None, description="时间戳（毫秒）")
):
    """上传图片并进行分析（患者端摄像头拍摄）"""
    # 复用analyze接口的逻辑
    return await analyze_image(file, patient_id, camera_id, timestamp_ms)


@router.post("/upload-video", response_model=AnalysisResponse)
async def upload_video(
    file: UploadFile = File(...),
    patient_id: str = Query(..., description="患者ID"),
    camera_id: Optional[str] = Query(None, description="摄像头ID"),
    timestamp_ms: Optional[int] = Query(None, description="时间戳（毫秒）")
):
    """上传视频并进行分析（患者端录制）"""
    import logging
    import traceback
    from datetime import datetime
    
    logger = logging.getLogger(__name__)
    start_time = datetime.now()
    
    try:
        logger.info(f"📥 [API] 收到视频上传请求")
        logger.info(f"📥 [API] 患者ID: {patient_id}")
        logger.info(f"📥 [API] 文件名: {file.filename}, 类型: {file.content_type}")
        
        # 读取视频数据
        video_bytes = await file.read()
        
        if len(video_bytes) == 0:
            raise HTTPException(status_code=400, detail="视频文件为空")
        
        logger.info(f"📥 [API] 视频数据读取完成: {len(video_bytes)} bytes")
        
        # 对于视频，可以提取关键帧进行分析
        # 这里简化处理，直接返回成功（实际应该提取帧并分析）
        # TODO: 实现视频帧提取和AI分析
        
        return AnalysisResponse(
            status="success",
            result_id=None,
            analysis={"message": "视频已接收，待处理"},
            error=None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        error_trace = traceback.format_exc()
        logger.error(f"❌ [API] 视频上传失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"视频上传失败: {str(e)}")


@router.get("/timeline/{patient_id}", response_model=list)
async def get_timeline(
    patient_id: str,
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    limit: int = Query(100, le=1000)
):
    """获取时间轴数据（按时间查询分析结果）"""
    try:
        start = datetime.fromisoformat(start_date) if start_date else None
        end = datetime.fromisoformat(end_date) if end_date else None
        
        results = await ai_analysis_service.get_analysis_history(
            patient_id=patient_id,
            start_date=start,
            end_date=end,
            limit=limit
        )
        
        # 格式化返回数据
        timeline = []
        for result in results:
            try:
                import json
                analysis_data = json.loads(result['analysis_data']) if isinstance(result['analysis_data'], str) else result['analysis_data']
                timeline.append({
                    "result_id": result['result_id'],
                    "timestamp": result['timestamp'],
                    "detection_type": result['detection_type'],
                    "analysis_data": analysis_data,
                    "snapshot_url": result.get('snapshot_url'),
                    "is_alert_triggered": result.get('is_alert_triggered', 0) == 1,
                })
            except:
                continue
        
        return timeline
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"日期格式错误: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/summary/{patient_id}", response_model=dict)
async def get_analysis_summary(
    patient_id: str,
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None)
):
    """获取时间段汇总分析"""
    from datetime import datetime, timedelta
    
    try:
        start = datetime.fromisoformat(start_date) if start_date else datetime.now() - timedelta(days=1)
        end = datetime.fromisoformat(end_date) if end_date else datetime.now()
        
        results = await ai_analysis_service.get_analysis_history(
            patient_id=patient_id,
            start_date=start,
            end_date=end,
            limit=1000
        )
        
        # 统计汇总
        total_count = len(results)
        alert_count = sum(1 for r in results if r.get('is_alert_triggered', 0) == 1)
        
        # 按检测类型统计
        detection_types = {}
        for result in results:
            dt = result.get('detection_type', 'unknown')
            detection_types[dt] = detection_types.get(dt, 0) + 1
        
        # 分析异常情况
        anomalies = []
        for result in results:
            if result.get('is_alert_triggered', 0) == 1:
                try:
                    import json
                    analysis_data = json.loads(result['analysis_data']) if isinstance(result['analysis_data'], str) else result['analysis_data']
                    detections = analysis_data.get('detections', {})
                    
                    # 提取异常信息
                    for key, value in detections.items():
                        if isinstance(value, dict) and value.get('detected'):
                            anomalies.append({
                                "timestamp": result['timestamp'],
                                "type": key,
                                "description": value.get('description', ''),
                            })
                except:
                    continue
        
        return {
            "patient_id": patient_id,
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "total_count": total_count,
            "alert_count": alert_count,
            "detection_types": detection_types,
            "anomalies": anomalies[:20],  # 最多返回20条异常
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"日期格式错误: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

