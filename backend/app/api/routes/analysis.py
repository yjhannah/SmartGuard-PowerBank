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
    try:
        # 读取图片数据
        image_bytes = await file.read()
        
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="图片文件为空")
        
        # 调用AI分析服务
        result = await ai_analysis_service.analyze_patient_image(
            image_bytes=image_bytes,
            patient_id=patient_id,
            camera_id=camera_id,
            timestamp_ms=timestamp_ms
        )
        
        return AnalysisResponse(**result)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"分析失败: {str(e)}")


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

