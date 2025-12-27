"""
一键呼叫API路由
"""
from fastapi import APIRouter, HTTPException
import uuid
from datetime import datetime
from app.models.schemas import CallRequest
from app.core.database import execute_query, execute_insert

router = APIRouter(prefix="/api/call", tags=["call"])


@router.post("/nurse")
async def call_nurse(request: CallRequest):
    """呼叫值班护工（Demo模式）"""
    try:
        # 检查用户是否存在
        users = await execute_query(
            "SELECT user_id FROM users WHERE user_id = ? AND is_active = 1",
            (request.user_id,)
        )
        if not users:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 保存呼叫记录
        call_id = str(uuid.uuid4())
        phone_number = request.phone_number or "13800138000"  # 默认护工电话
        
        await execute_insert(
            """INSERT INTO call_records (call_id, user_id, patient_id, call_type, phone_number, status)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (call_id, request.user_id, request.patient_id, 'nurse', phone_number, 'pending')
        )
        
        return {
            "status": "success",
            "message": "呼叫请求已提交（Demo模式）",
            "call_id": call_id,
            "phone_number": phone_number,
            "note": "实际环境中将直接拨打该号码"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"呼叫失败: {str(e)}")


@router.post("/message")
async def send_message(request: CallRequest):
    """发送消息给护士站（Demo模式）"""
    try:
        # 检查用户是否存在
        users = await execute_query(
            "SELECT user_id FROM users WHERE user_id = ? AND is_active = 1",
            (request.user_id,)
        )
        if not users:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 保存消息记录
        call_id = str(uuid.uuid4())
        message_content = request.message_content or "家属发送的消息"
        
        await execute_insert(
            """INSERT INTO call_records (call_id, user_id, patient_id, call_type, message_content, status)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (call_id, request.user_id, request.patient_id, 'message', message_content, 'pending')
        )
        
        return {
            "status": "success",
            "message": "消息已发送（Demo模式）",
            "call_id": call_id,
            "message_content": message_content,
            "note": "实际环境中将推送到护士站"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"发送消息失败: {str(e)}")

