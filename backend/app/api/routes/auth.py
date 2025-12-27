"""
用户认证API路由
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Optional
import hashlib
import uuid
from datetime import datetime, timedelta
from app.models.schemas import LoginRequest, LoginResponse
from app.core.database import execute_query, execute_insert, execute_update

router = APIRouter(prefix="/api/auth", tags=["auth"])


def hash_password(password: str) -> str:
    """简单的密码哈希（实际生产环境应使用bcrypt）"""
    return hashlib.sha256(password.encode()).hexdigest()


@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """账号密码登录"""
    try:
        # 查询用户
        users = await execute_query(
            "SELECT * FROM users WHERE username = ? AND is_active = 1",
            (request.username,)
        )
        
        if not users:
            raise HTTPException(status_code=401, detail="用户名或密码错误")
        
        user = users[0]
        
        # 验证密码
        password_hash = hash_password(request.password)
        if user['password_hash'] != password_hash:
            raise HTTPException(status_code=401, detail="用户名或密码错误")
        
        # 生成简单token（实际应使用JWT）
        token = str(uuid.uuid4())
        
        # 更新用户最后登录时间（如果有updated_at字段）
        try:
            await execute_update(
                "UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE user_id = ?",
                (user['user_id'],)
            )
        except:
            pass  # 忽略更新错误
        
        # 获取关联的患者ID（如果是病患用户）
        patient_id = user.get('patient_id')
        
        return LoginResponse(
            user_id=user['user_id'],
            username=user['username'],
            role=user['role'],
            full_name=user.get('full_name'),
            patient_id=patient_id,
            token=token
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"登录失败: {str(e)}")


@router.post("/logout")
async def logout():
    """登出（简单实现，实际应使token失效）"""
    return {"status": "success", "message": "已登出"}


@router.get("/me", response_model=dict)
async def get_current_user(user_id: str):
    """获取当前用户信息"""
    try:
        users = await execute_query(
            "SELECT user_id, username, role, full_name, phone, email, patient_id FROM users WHERE user_id = ? AND is_active = 1",
            (user_id,)
        )
        
        if not users:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        user = users[0]
        return dict(user)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取用户信息失败: {str(e)}")

