"""
WebSocket API路由
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from app.services.websocket_manager import websocket_manager
import logging

logger = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])


@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """WebSocket连接端点"""
    logger.info(f"🔌 [WebSocket API] 收到连接请求 - 用户ID: {user_id}")
    await websocket_manager.connect(websocket, user_id)
    
    try:
        while True:
            # 接收客户端消息（用于心跳或确认）
            data = await websocket.receive_text()
            logger.debug(f"📥 [WebSocket API] 收到来自 {user_id} 的消息: {data[:100]}...")
            
            # 可以处理客户端消息，例如确认告警
            # 这里简化处理，仅保持连接
            
    except WebSocketDisconnect:
        logger.info(f"🔌 [WebSocket API] 用户 {user_id} 正常断开连接")
        websocket_manager.disconnect(websocket, user_id)
    except Exception as e:
        logger.error(f"❌ [WebSocket API] WebSocket错误 - 用户: {user_id}, 错误: {e}")
        import traceback
        logger.error(f"❌ [WebSocket API] 堆栈跟踪:\n{traceback.format_exc()}")
        websocket_manager.disconnect(websocket, user_id)

