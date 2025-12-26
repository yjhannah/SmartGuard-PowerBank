"""
WebSocket管理器
管理WebSocket连接，实现实时推送
"""
import json
import logging
from typing import Dict, Set, Optional
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)


class WebSocketManager:
    """WebSocket连接管理器"""
    
    def __init__(self):
        # user_id -> Set[WebSocket]
        self.active_connections: Dict[str, Set[WebSocket]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: str):
        """建立WebSocket连接"""
        await websocket.accept()
        
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        
        self.active_connections[user_id].add(websocket)
        logger.info(f"✅ 用户 {user_id} 已连接 WebSocket (当前连接数: {len(self.active_connections[user_id])})")
    
    def disconnect(self, websocket: WebSocket, user_id: str):
        """断开WebSocket连接"""
        if user_id in self.active_connections:
            self.active_connections[user_id].discard(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        logger.info(f"❌ 用户 {user_id} 已断开 WebSocket")
    
    async def send_to_user(self, user_id: str, message: Dict):
        """发送消息给特定用户"""
        if user_id not in self.active_connections:
            logger.warning(f"用户 {user_id} 未连接 WebSocket")
            return
        
        disconnected = set()
        message_json = json.dumps(message, ensure_ascii=False)
        
        for connection in self.active_connections[user_id]:
            try:
                await connection.send_text(message_json)
            except Exception as e:
                logger.warning(f"发送消息失败: {e}")
                disconnected.add(connection)
        
        # 清理断开的连接
        self.active_connections[user_id] -= disconnected
        if not self.active_connections[user_id]:
            del self.active_connections[user_id]
    
    async def broadcast_to_role(self, role: str, message: Dict):
        """广播消息给特定角色的所有用户"""
        from app.core.database import execute_query
        
        # 获取该角色的所有在线用户
        users = await execute_query(
            "SELECT user_id FROM users WHERE role = ? AND is_active = 1",
            (role,)
        )
        
        for user in users:
            user_id = user["user_id"]
            if user_id in self.active_connections:
                await self.send_to_user(user_id, message)
    
    async def broadcast_to_nurses(self, message: Dict):
        """广播消息给所有护士"""
        await self.broadcast_to_role("nurse", message)
    
    def get_connected_users(self) -> Set[str]:
        """获取所有已连接的用户ID"""
        return set(self.active_connections.keys())
    
    def get_connection_count(self, user_id: Optional[str] = None) -> int:
        """获取连接数"""
        if user_id:
            return len(self.active_connections.get(user_id, set()))
        return sum(len(conns) for conns in self.active_connections.values())


# 创建全局实例
websocket_manager = WebSocketManager()

