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
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        # JOIN ai_analysis_results表获取图片URL
        results = await execute_query(
            """SELECT a.*, 
                      ar.snapshot_url as image_url,
                      ar.image_url as analysis_image_url
               FROM alerts a
               LEFT JOIN ai_analysis_results ar ON a.analysis_result_id = ar.result_id
               WHERE a.alert_id = ?""",
            (alert_id,)
        )
        
        if not results:
            raise HTTPException(status_code=404, detail="告警不存在")
        
        alert = dict(results[0])
        
        # 优先使用alerts表的image_url，如果没有则使用analysis_results的
        if not alert.get('image_url'):
            alert['image_url'] = alert.get('analysis_image_url') or alert.get('snapshot_url')
        
        logger.info(f"📥 [API] 获取告警详情: {alert_id}")
        logger.info(f"📥 [API] 告警类型: {alert.get('alert_type')}")
        logger.info(f"📥 [API] 图片URL: {alert.get('image_url') or '无'}")
        
        return alert
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


@router.post("/{alert_id}/family-acknowledge", response_model=dict)
async def family_acknowledge_alert(alert_id: str):
    """家属确认告警"""
    from app.core.database import execute_query, execute_update
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"📥 [API] 家属确认告警: {alert_id}")
        
        # 检查告警是否存在
        alerts = await execute_query(
            "SELECT * FROM alerts WHERE alert_id = ?",
            (alert_id,)
        )
        if not alerts:
            logger.warning(f"⚠️ [API] 告警不存在: {alert_id}")
            raise HTTPException(status_code=404, detail="告警不存在")
        
        # 更新家属确认状态
        await execute_update(
            "UPDATE alerts SET family_acknowledged = 1, family_acknowledged_at = CURRENT_TIMESTAMP WHERE alert_id = ?",
            (alert_id,)
        )
        
        logger.info(f"✅ [API] 家属已确认告警: {alert_id}")
        
        return {
            "status": "success",
            "message": "告警已确认",
            "alert_id": alert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ [API] 确认告警失败: {e}")
        raise HTTPException(status_code=500, detail=f"确认告警失败: {str(e)}")


@router.post("/{alert_id}/acknowledge-family", response_model=dict)
async def acknowledge_family_alert(alert_id: str, user_id: str = Query(...)):
    """家属确认告警（别名，兼容旧代码）"""
    return await family_acknowledge_alert(alert_id)


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


@router.post("/sos", response_model=dict)
async def trigger_sos(
    patient_id: str = Query(...),
    user_id: str = Query(...),
    latitude: Optional[float] = Query(None),
    longitude: Optional[float] = Query(None),
    address: Optional[str] = Query(None),
    timestamp: Optional[str] = Query(None)
):
    """SOS紧急报警"""
    from app.core.database import execute_query, execute_insert
    from app.services.websocket_manager import websocket_manager
    from datetime import datetime
    import uuid
    
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id, full_name FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        patient = patients[0]
        patient_name = patient.get('full_name', '患者')
        
        # 创建SOS告警
        alert_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO alerts 
               (alert_id, patient_id, alert_type, severity, title, description, status, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                alert_id,
                patient_id,
                'sos_emergency',
                'critical',
                'SOS紧急报警',
                f'患者{patient_name}触发SOS紧急报警。位置：{address or "未知"}（{latitude}, {longitude}）',
                'pending',
                timestamp or datetime.now()
            )
        )
        
        # 推送到护士站和家属端
        # 1. 查找护士用户
        nurses = await execute_query(
            "SELECT user_id FROM users WHERE role = 'nurse' AND is_active = 1 LIMIT 10",
            ()
        )
        for nurse in nurses:
            await websocket_manager.send_to_user(
                nurse['user_id'],
                {
                    "type": "alert",
                    "alert_id": alert_id,
                    "alert_type": "sos_emergency",
                    "patient_id": patient_id,
                    "patient_name": patient_name,
                    "title": "SOS紧急报警",
                    "description": f"患者{patient_name}触发SOS紧急报警",
                    "latitude": latitude,
                    "longitude": longitude,
                    "address": address,
                    "timestamp": timestamp or datetime.now().isoformat(),
                }
            )
        
        # 2. 查找家属用户（通过patient_guardians表）
        guardians = await execute_query(
            """SELECT u.user_id 
               FROM patient_guardians pg
               JOIN users u ON pg.guardian_user_id = u.user_id
               WHERE pg.patient_id = ? AND u.is_active = 1
               LIMIT 3""",
            (patient_id,)
        )
        for guardian in guardians:
            await websocket_manager.send_to_user(
                guardian['user_id'],
                {
                    "type": "alert",
                    "alert_id": alert_id,
                    "alert_type": "sos_emergency",
                    "patient_id": patient_id,
                    "patient_name": patient_name,
                    "title": "SOS紧急报警",
                    "description": f"患者{patient_name}触发SOS紧急报警",
                    "latitude": latitude,
                    "longitude": longitude,
                    "address": address,
                    "timestamp": timestamp or datetime.now().isoformat(),
                }
            )
        
        return {
            "status": "success",
            "message": "SOS报警已发送",
            "alert_id": alert_id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"SOS报警失败: {str(e)}")

