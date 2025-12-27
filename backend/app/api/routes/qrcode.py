"""
二维码关联API路由
"""
from fastapi import APIRouter, HTTPException
from typing import Optional
import uuid
import qrcode
import io
import base64
from datetime import datetime, timedelta
from app.models.schemas import QRCodeGenerateResponse, QRCodeScanRequest
from app.core.database import execute_query, execute_insert, execute_update

router = APIRouter(prefix="/api/qrcode", tags=["qrcode"])


@router.get("/generate/{patient_id}", response_model=QRCodeGenerateResponse)
async def generate_qrcode(patient_id: str):
    """病患端生成关联二维码"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 生成token
        token = str(uuid.uuid4())
        expires_at = datetime.now() + timedelta(hours=24)
        
        # 保存token到数据库
        token_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO qrcode_tokens (token_id, patient_id, token, expires_at, used)
               VALUES (?, ?, ?, ?, ?)""",
            (token_id, patient_id, token, expires_at, 0)
        )
        
        # 生成二维码内容（JSON格式）
        qr_data = {
            "patient_id": patient_id,
            "token": token,
            "expires_at": expires_at.isoformat()
        }
        import json
        qr_content = json.dumps(qr_data)
        
        # 生成二维码图片
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(qr_content)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # 转换为base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        img_bytes = buffer.getvalue()
        img_base64 = base64.b64encode(img_bytes).decode()
        qr_code_url = f"data:image/png;base64,{img_base64}"
        
        return QRCodeGenerateResponse(
            qr_code_url=qr_code_url,
            token=token,
            expires_at=expires_at.isoformat()
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"生成二维码失败: {str(e)}")


@router.post("/scan")
async def scan_qrcode(request: QRCodeScanRequest):
    """家属端扫描二维码建立关联"""
    try:
        # 查找token
        tokens = await execute_query(
            """SELECT * FROM qrcode_tokens 
               WHERE token = ? AND used = 0 AND expires_at > datetime('now')""",
            (request.token,)
        )
        
        if not tokens:
            raise HTTPException(status_code=400, detail="二维码无效或已过期")
        
        token_record = tokens[0]
        patient_id = token_record['patient_id']
        
        # 检查用户是否存在
        users = await execute_query(
            "SELECT user_id, role FROM users WHERE user_id = ? AND is_active = 1",
            (request.user_id,)
        )
        if not users:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        user = users[0]
        if user['role'] != 'family':
            raise HTTPException(status_code=403, detail="只有家属用户可以关联患者")
        
        # 检查是否已经关联
        existing = await execute_query(
            """SELECT id FROM patient_guardians 
               WHERE patient_id = ? AND guardian_user_id = ?""",
            (patient_id, request.user_id)
        )
        
        if existing:
            # 标记token为已使用
            await execute_update(
                "UPDATE qrcode_tokens SET used = 1, used_by_user_id = ? WHERE token_id = ?",
                (request.user_id, token_record['token_id'])
            )
            return {
                "status": "success",
                "message": "已关联该患者",
                "patient_id": patient_id
            }
        
        # 建立关联
        import uuid
        guardian_id = str(uuid.uuid4())
        await execute_insert(
            """INSERT INTO patient_guardians (id, patient_id, guardian_user_id, relationship, priority)
               VALUES (?, ?, ?, ?, ?)""",
            (guardian_id, patient_id, request.user_id, "家属", 1)
        )
        
        # 标记token为已使用
        await execute_update(
            "UPDATE qrcode_tokens SET used = 1, used_by_user_id = ? WHERE token_id = ?",
            (request.user_id, token_record['token_id'])
        )
        
        return {
            "status": "success",
            "message": "关联成功",
            "patient_id": patient_id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"扫描二维码失败: {str(e)}")


@router.get("/status/{patient_id}")
async def get_qrcode_status(patient_id: str):
    """查询关联状态"""
    try:
        # 检查患者是否存在
        patients = await execute_query(
            "SELECT patient_id, full_name FROM patients WHERE patient_id = ?",
            (patient_id,)
        )
        if not patients:
            raise HTTPException(status_code=404, detail="患者不存在")
        
        # 查找有效的token
        tokens = await execute_query(
            """SELECT token_id, token, expires_at, used, created_at
               FROM qrcode_tokens 
               WHERE patient_id = ? AND expires_at > datetime('now')
               ORDER BY created_at DESC LIMIT 1""",
            (patient_id,)
        )
        
        if tokens:
            token = tokens[0]
            return {
                "has_active_token": True,
                "token": token['token'],
                "expires_at": token['expires_at'],
                "used": bool(token['used'])
            }
        else:
            return {
                "has_active_token": False,
                "message": "没有有效的二维码"
            }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"查询状态失败: {str(e)}")

