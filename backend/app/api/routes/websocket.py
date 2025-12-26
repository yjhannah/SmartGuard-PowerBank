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
    await websocket_manager.connect(websocket, user_id)
    
    try:
        while True:
            # 接收客户端消息（用于心跳或确认）
            data = await websocket.receive_text()
            logger.debug(f"收到来自 {user_id} 的消息: {data}")
            
            # 可以处理客户端消息，例如确认告警
            # 这里简化处理，仅保持连接
            
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket, user_id)
        logger.info(f"用户 {user_id} 断开连接")
    except Exception as e:
        logger.error(f"WebSocket错误: {e}")
        websocket_manager.disconnect(websocket, user_id)

