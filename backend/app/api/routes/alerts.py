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


@router.get("/family/{patient_id}", response_model=List[dict])
async def get_family_alerts(patient_id: str):
    """家属端获取告警列表（分级显示）"""
    from app.core.database import execute_query
    
    try:
        # 获取所有告警，按优先级和创建时间排序
        alerts = await execute_query(
            """SELECT a.*, ar.snapshot_url as image_url
               FROM alerts a
               LEFT JOIN ai_analysis_results ar ON a.analysis_result_id = ar.result_id
               WHERE a.patient_id = ?
               ORDER BY 
                 CASE a.severity 
                   WHEN 'critical' THEN 1
                   WHEN 'high' THEN 2
                   WHEN 'medium' THEN 3
                   WHEN 'low' THEN 4
                 END,
                 a.created_at DESC
               LIMIT 100""",
            (patient_id,)
        )
        
        # 分类告警
        critical_alerts = []
        high_alerts = []
        medium_alerts = []
        low_alerts = []
        
        for alert in alerts:
            alert_dict = dict(alert)
            severity = alert_dict.get('severity', 'medium')
            
            if severity == 'critical':
                critical_alerts.append(alert_dict)
            elif severity == 'high':
                high_alerts.append(alert_dict)
            elif severity == 'medium':
                medium_alerts.append(alert_dict)
            else:
                low_alerts.append(alert_dict)
        
        # 合并返回，高优先级在前
        result = critical_alerts + high_alerts + medium_alerts + low_alerts
        
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取告警列表失败: {str(e)}")


@router.post("/{alert_id}/acknowledge-family", response_model=dict)
async def acknowledge_family_alert(alert_id: str, user_id: str = Query(...)):
    """家属确认告警"""
    from app.core.database import execute_query, execute_update
    
    try:
        # 检查告警是否存在
        alerts = await execute_query(
            "SELECT * FROM alerts WHERE alert_id = ?",
            (alert_id,)
        )
        if not alerts:
            raise HTTPException(status_code=404, detail="告警不存在")
        
        # 更新家属确认状态
        await execute_update(
            "UPDATE alerts SET family_acknowledged = 1 WHERE alert_id = ?",
            (alert_id,)
        )
        
        return {
            "status": "success",
            "message": "告警已确认",
            "alert_id": alert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"确认告警失败: {str(e)}")


@router.get("/{alert_id}/nurse-logs", response_model=dict)
async def get_nurse_logs(alert_id: str):
    """查看护士处理日志"""
    from app.core.database import execute_query
    
    try:
        # 获取告警信息
        alerts = await execute_query(
            """SELECT a.*, 
                      u1.full_name as acknowledged_by_name,
                      u2.full_name as resolved_by_name
               FROM alerts a
               LEFT JOIN users u1 ON a.acknowledged_by = u1.user_id
               LEFT JOIN users u2 ON a.resolved_by = u2.user_id
               WHERE a.alert_id = ?""",
            (alert_id,)
        )
        
        if not alerts:
            raise HTTPException(status_code=404, detail="告警不存在")
        
        alert = alerts[0]
        
        # 构建处理日志
        logs = []
        
        if alert.get('acknowledged_at'):
            logs.append({
                "action": "确认",
                "user": alert.get('acknowledged_by_name', '未知'),
                "time": alert.get('acknowledged_at'),
                "notes": "告警已确认"
            })
        
        if alert.get('resolved_at'):
            logs.append({
                "action": "处理",
                "user": alert.get('resolved_by_name', '未知'),
                "time": alert.get('resolved_at'),
                "notes": alert.get('resolution_notes', '')
            })
        
        return {
            "alert_id": alert_id,
            "alert_type": alert.get('alert_type'),
            "title": alert.get('title'),
            "description": alert.get('description'),
            "status": alert.get('status'),
            "logs": logs,
            "created_at": alert.get('created_at')
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取处理日志失败: {str(e)}")

