"""
用户认证API路由
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Optional
import hashlib
import uuid
import re
from datetime import datetime, timedelta
from app.models.schemas import LoginRequest, LoginResponse, RegisterRequest, RegisterResponse
from app.core.database import execute_query, execute_insert, execute_update

router = APIRouter(prefix="/api/auth", tags=["auth"])


def hash_password(password: str) -> str:
    """简单的密码哈希（实际生产环境应使用bcrypt）"""
    return hashlib.sha256(password.encode()).hexdigest()


def validate_email(email: str) -> bool:
    """验证邮箱格式"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


@router.post("/register", response_model=RegisterResponse)
async def register(request: RegisterRequest):
    """邮箱注册新用户"""
    try:
        # 验证邮箱格式
        if not validate_email(request.email):
            raise HTTPException(status_code=400, detail="邮箱格式不正确")
        
        # 验证角色（数据库约束只允许: nurse, doctor, family, admin）
        # 病患用户使用family角色，通过patient_id字段关联患者
        valid_roles = ['nurse', 'doctor', 'family', 'admin']
        if request.role not in valid_roles:
            raise HTTPException(status_code=400, detail=f"角色必须是以下之一: {', '.join(valid_roles)}")
        
        # 检查用户名是否已存在
        existing_users = await execute_query(
            "SELECT user_id FROM users WHERE username = ?",
            (request.username,)
        )
        if existing_users:
            raise HTTPException(status_code=400, detail="用户名已存在")
        
        # 检查邮箱是否已注册
        existing_emails = await execute_query(
            "SELECT user_id FROM users WHERE email = ?",
            (request.email,)
        )
        if existing_emails:
            raise HTTPException(status_code=400, detail="该邮箱已被注册")
        
        # 创建新用户
        user_id = str(uuid.uuid4())
        password_hash = hash_password(request.password)
        
        await execute_insert(
            """INSERT INTO users (user_id, username, password_hash, role, full_name, phone, email, is_active)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                user_id,
                request.username,
                password_hash,
                request.role,
                request.full_name,
                request.phone,
                request.email,
                1  # is_active
            )
        )
        
        return RegisterResponse(
            user_id=user_id,
            username=request.username,
            email=request.email,
            role=request.role,
            message="注册成功！请使用用户名和密码登录。"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"注册失败: {str(e)}")


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
        
        # 判断用户类型：
        # 1. 如果用户有 patient_id，检查是否在 patient_guardians 表中作为 guardian_user_id 存在
        #    - 如果在 patient_guardians 表中，说明是家属端（用户是患者的家属）
        #    - 如果不在 patient_guardians 表中，说明是患者端（用户自己就是患者）
        # 2. 如果用户没有 patient_id，根据 role 判断：
        #    - role 为 'family' 且有 patient_id 关联，是家属端
        #    - role 为其他，不是患者端也不是家属端
        user_type = None
        if patient_id:
            # 检查是否在 patient_guardians 表中作为 guardian_user_id 存在
            guardians = await execute_query(
                "SELECT id FROM patient_guardians WHERE guardian_user_id = ?",
                (user['user_id'],)
            )
            if guardians:
                # 在 patient_guardians 表中存在，说明是家属端（用户是患者的家属）
                user_type = 'family'
            else:
                # 不在 patient_guardians 表中，说明是患者端（用户自己就是患者）
                user_type = 'patient'
        else:
            # 没有 patient_id，检查 role
            # 如果 role 是 'family'，可能是家属但还没关联患者，暂时设为 'family'
            if user.get('role') == 'family':
                user_type = 'family'
            # 其他角色（nurse, doctor, admin）不设置 user_type，前端会显示登录界面
        
        return LoginResponse(
            user_id=user['user_id'],
            username=user['username'],
            role=user['role'],
            full_name=user.get('full_name'),
            patient_id=patient_id,
            user_type=user_type,
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

