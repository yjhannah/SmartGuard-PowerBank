"""
FastAPI应用主入口
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import logging
from datetime import datetime

from app.core.config import settings
from app.api.routes import patients, analysis, alerts, websocket

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 创建FastAPI应用
app = FastAPI(
    title="医院病房智能监护系统API",
    description="智能监护系统后端API",
    version="1.0.0"
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(patients.router)
app.include_router(analysis.router)
app.include_router(alerts.router)
app.include_router(websocket.router)

# 静态文件服务（用于前端）
try:
    from pathlib import Path
    frontend_path = Path(__file__).parent.parent.parent / "frontend"
    if frontend_path.exists():
        app.mount("/static", StaticFiles(directory=str(frontend_path / "static")), name="static")
        app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="frontend")
except Exception as e:
    logger.warning(f"无法挂载静态文件: {e}")


@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "医院病房智能监护系统API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """健康检查"""
    import os
    from pathlib import Path
    
    health_status = {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "checks": {}
    }
    
    # 检查数据库
    try:
        db_path = Path(__file__).parent.parent / "data" / "hospital_monitoring.db"
        if db_path.exists():
            health_status["checks"]["database"] = "ok"
        else:
            health_status["checks"]["database"] = "not_found"
            health_status["status"] = "degraded"
    except Exception as e:
        health_status["checks"]["database"] = f"error: {str(e)}"
        health_status["status"] = "unhealthy"
    
    # 检查环境变量
    try:
        if settings.one_api_key or settings.gemini_api_key:
            health_status["checks"]["api_config"] = "ok"
        else:
            health_status["checks"]["api_config"] = "missing"
            health_status["status"] = "degraded"
    except Exception as e:
        health_status["checks"]["api_config"] = f"error: {str(e)}"
    
    # 检查WebSocket连接数
    try:
        from app.services.websocket_manager import websocket_manager
        connection_count = websocket_manager.get_connection_count()
        health_status["checks"]["websocket"] = f"ok ({connection_count} connections)"
    except Exception as e:
        health_status["checks"]["websocket"] = f"error: {str(e)}"
    
    status_code = 200 if health_status["status"] == "healthy" else 503
    return health_status


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )

