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
        try:
            await websocket.accept()
            
            if user_id not in self.active_connections:
                self.active_connections[user_id] = set()
            
            self.active_connections[user_id].add(websocket)
            total_connections = sum(len(conns) for conns in self.active_connections.values())
            logger.info(f"🔌 [WebSocket] 用户 {user_id} 已连接 (用户连接数: {len(self.active_connections[user_id])}, 总连接数: {total_connections})")
            logger.info(f"🔌 [WebSocket] 当前在线用户: {list(self.active_connections.keys())}")
        except Exception as e:
            logger.error(f"❌ [WebSocket] 连接失败 - 用户: {user_id}, 错误: {e}")
            raise
    
    def disconnect(self, websocket: WebSocket, user_id: str):
        """断开WebSocket连接"""
        try:
            if user_id in self.active_connections:
                self.active_connections[user_id].discard(websocket)
                if not self.active_connections[user_id]:
                    del self.active_connections[user_id]
                logger.info(f"🔌 [WebSocket] 用户 {user_id} 已断开 (剩余连接数: {len(self.active_connections.get(user_id, set()))})")
            else:
                logger.warning(f"🔌 [WebSocket] 尝试断开不存在的连接 - 用户: {user_id}")
        except Exception as e:
            logger.error(f"❌ [WebSocket] 断开连接失败 - 用户: {user_id}, 错误: {e}")
    
    async def send_to_user(self, user_id: str, message: Dict):
        """发送消息给特定用户"""
        logger.info(f"📤 [WebSocket] 准备发送消息给用户: {user_id}")
        logger.info(f"📤 [WebSocket] 消息类型: {message.get('type')}, 消息内容: {json.dumps(message, ensure_ascii=False)[:200]}...")
        
        if user_id not in self.active_connections:
            logger.warning(f"⚠️ [WebSocket] 用户 {user_id} 未连接 WebSocket，无法发送消息")
            logger.warning(f"⚠️ [WebSocket] 当前在线用户: {list(self.active_connections.keys())}")
            return False
        
        disconnected = set()
        message_json = json.dumps(message, ensure_ascii=False)
        connection_count = len(self.active_connections[user_id])
        logger.info(f"📤 [WebSocket] 用户 {user_id} 有 {connection_count} 个活跃连接")
        
        success_count = 0
        for idx, connection in enumerate(self.active_connections[user_id]):
            try:
                await connection.send_text(message_json)
                success_count += 1
                logger.info(f"✅ [WebSocket] 消息已发送给用户 {user_id} (连接 {idx+1}/{connection_count})")
            except Exception as e:
                logger.error(f"❌ [WebSocket] 发送消息失败 - 用户: {user_id}, 连接 {idx+1}, 错误: {e}")
                disconnected.add(connection)
        
        # 清理断开的连接
        if disconnected:
            self.active_connections[user_id] -= disconnected
            logger.warning(f"🧹 [WebSocket] 清理了 {len(disconnected)} 个断开的连接 - 用户: {user_id}")
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
                logger.info(f"🗑️ [WebSocket] 用户 {user_id} 的所有连接已断开，已从活跃连接中移除")
        
        logger.info(f"📊 [WebSocket] 发送结果 - 用户: {user_id}, 成功: {success_count}/{connection_count}")
        return success_count > 0
    
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

