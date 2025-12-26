"""
告警管理API路由
"""
from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from app.models.schemas import AlertAcknowledge, AlertResolve, AlertResponse
from app.services.alert_service import alert_service

router = APIRouter(prefix="/api/alerts", tags=["alerts"])


@router.get("", response_model=List[dict])
async def get_alerts(
    patient_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    limit: int = Query(50, le=200)
):
    """获取告警列表"""
    try:
        results = await alert_service.get_alerts(
            patient_id=patient_id,
            status=status,
            severity=severity,
            limit=limit
        )
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{alert_id}", response_model=dict)
async def get_alert(alert_id: str):
    """获取单个告警详情"""
    from app.core.database import execute_query
    
    try:
        results = await execute_query(
            "SELECT * FROM alerts WHERE alert_id = ?",
            (alert_id,)
        )
        if not results:
            raise HTTPException(status_code=404, detail="告警不存在")
        return results[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{alert_id}/acknowledge", response_model=dict)
async def acknowledge_alert(alert_id: str, request: AlertAcknowledge):
    """确认告警"""
    try:
        success = await alert_service.acknowledge_alert(
            alert_id=alert_id,
            user_id=request.user_id
        )
        if not success:
            raise HTTPException(status_code=400, detail="确认失败")
        return {"status": "success", "message": "告警已确认"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{alert_id}/resolve", response_model=dict)
async def resolve_alert(alert_id: str, request: AlertResolve):
    """处理告警"""
    try:
        success = await alert_service.resolve_alert(
            alert_id=alert_id,
            user_id=request.user_id,
            resolution_notes=request.resolution_notes
        )
        if not success:
            raise HTTPException(status_code=400, detail="处理失败")
        return {"status": "success", "message": "告警已处理"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

